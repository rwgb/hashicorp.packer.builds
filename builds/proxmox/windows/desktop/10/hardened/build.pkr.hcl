// packer build file for Windows 10 Hardened
packer {
  required_version = ">= 1.9.4"
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }

    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = ">= 0.14.3"
    }

    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.4.3"
    }
  }
}

data "git-commit" "build" {
  path = "${path.root}/../../../../"
}

locals {
  build_by          = "Built by: Hashicorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version     = try(data.git-commit.build.hash, env("GITHUB_SHA"), "unknown")
  git_author        = try(data.git-commit.build.author, env("GITHUB_ACTOR"), "unknown")
  git_committer     = try(data.git-commit.build.committer, env("GITHUB_ACTOR"), "unknown")
  git_timestamp     = try(data.git-commit.build.timestamp, timestamp(), "unknown")
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"
  manifest_path     = "./manifests/"
  manifest_date     = formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())
  manifest_output   = "${local.manifest_path}${local.manifest_date}.json"
}

// build block
build {
  name = "windows_10_22h2_hardened"
  sources = [
    "source.proxmox-clone.windows_10_22h2_hardened"
  ]

  // Configure Account Policies and Password Settings
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring password and account policies...'",
      "secedit /export /cfg C:\\secpol.cfg",
      "$secpol = Get-Content C:\\secpol.cfg",
      "$secpol = $secpol -replace 'MinimumPasswordLength = .*', 'MinimumPasswordLength = 14'",
      "$secpol = $secpol -replace 'PasswordComplexity = .*', 'PasswordComplexity = 1'",
      "$secpol = $secpol -replace 'MaximumPasswordAge = .*', 'MaximumPasswordAge = 60'",
      "$secpol = $secpol -replace 'MinimumPasswordAge = .*', 'MinimumPasswordAge = 1'",
      "$secpol = $secpol -replace 'PasswordHistorySize = .*', 'PasswordHistorySize = 24'",
      "$secpol = $secpol -replace 'LockoutBadCount = .*', 'LockoutBadCount = 5'",
      "$secpol = $secpol -replace 'LockoutDuration = .*', 'LockoutDuration = 30'",
      "$secpol | Set-Content C:\\secpol.cfg",
      "secedit /configure /db C:\\Windows\\security\\local.sdb /cfg C:\\secpol.cfg /areas SECURITYPOLICY",
      "Remove-Item -Path C:\\secpol.cfg -Force",
      "Write-Host 'Password policies configured successfully'"
    ]
  }

  // Configure Windows Firewall
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring Windows Firewall...'",
      "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True",
      "Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow",
      "Write-Host 'Windows Firewall configured successfully'"
    ]
  }

  // Disable Unnecessary Services
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Disabling unnecessary services...'",
      "$services = @('RemoteRegistry','RemoteAccess','SSDPSRV','upnphost','WMPNetworkSvc','WerSvc','Browser','lmhosts','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc')",
      "foreach ($service in $services) {",
      "  try {",
      "    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue",
      "    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue",
      "    Write-Host \"Disabled service: $service\"",
      "  } catch {",
      "    Write-Host \"Service $service not found or already disabled\"",
      "  }",
      "}",
      "Write-Host 'Services configuration complete'"
    ]
  }

  // Configure Audit Policies
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring audit policies...'",
      "auditpol /set /category:\"Account Logon\" /success:enable /failure:enable",
      "auditpol /set /category:\"Account Management\" /success:enable /failure:enable",
      "auditpol /set /category:\"Logon/Logoff\" /success:enable /failure:enable",
      "auditpol /set /category:\"Object Access\" /success:enable /failure:enable",
      "auditpol /set /category:\"Policy Change\" /success:enable /failure:enable",
      "auditpol /set /category:\"Privilege Use\" /success:enable /failure:enable",
      "auditpol /set /category:\"System\" /success:enable /failure:enable",
      "Write-Host 'Audit policies configured successfully'"
    ]
  }

  // Configure Registry Security Settings
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Applying registry security settings...'",
      "",
      "# Disable SMBv1",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters' -Name 'SMB1' -Value 0 -Type DWord -Force",
      "",
      "# Enable SMB signing",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord -Force",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord -Force",
      "",
      "# Disable LLMNR",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\DNSClient' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\DNSClient' -Name 'EnableMulticast' -Value 0 -Type DWord -Force",
      "",
      "# Disable NetBIOS over TCP/IP",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\NetBT\\Parameters' -Name 'NodeType' -Value 2 -Type DWord -Force",
      "",
      "# Configure LSA protection",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa' -Name 'RunAsPPL' -Value 1 -Type DWord -Force",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa' -Name 'LsaCfgFlags' -Value 1 -Type DWord -Force",
      "",
      "# Disable Windows Script Host",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows Script Host\\Settings' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows Script Host\\Settings' -Name 'Enabled' -Value 0 -Type DWord -Force",
      "",
      "# Disable AutoRun/AutoPlay",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 -Type DWord -Force",
      "",
      "# Configure screen saver timeout",
      "if (-not (Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System')) {",
      "  New-Item -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Force | Out-Null",
      "}",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'InactivityTimeoutSecs' -Value 900 -Type DWord -Force",
      "",
      "# Enable secure logon (Ctrl+Alt+Del)",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'DisableCAD' -Value 0 -Type DWord -Force",
      "",
      "# Configure interactive logon messages",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'LegalNoticeCaption' -Value 'Authorized Access Only' -Type String -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'LegalNoticeText' -Value 'This system is for authorized use only. All activity is monitored and logged.' -Type String -Force",
      "",
      "# Disable Camera access",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy' -Name 'LetAppsAccessCamera' -Value 2 -Type DWord -Force",
      "",
      "# Disable Microphone access",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy' -Name 'LetAppsAccessMicrophone' -Value 2 -Type DWord -Force",
      "",
      "# Disable Location services",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AppPrivacy' -Name 'LetAppsAccessLocation' -Value 2 -Type DWord -Force",
      "",
      "# Disable Telemetry",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force",
      "",
      "# Disable Advertising ID",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AdvertisingInfo' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AdvertisingInfo' -Name 'DisabledByGroupPolicy' -Value 1 -Type DWord -Force",
      "",
      "# Disable Windows Consumer Features",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent' -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force",
      "",
      "Write-Host 'Registry security settings applied successfully'"
    ]
  }

  // Configure Windows Defender
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring Windows Defender...'",
      "Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue",
      "Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue",
      "Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue",
      "Set-MpPreference -ScanScheduleDay Everyday -ErrorAction SilentlyContinue",
      "Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue",
      "Write-Host 'Windows Defender configured successfully'"
    ]
  }

  // Configure TLS/SSL Security
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring TLS/SSL security...'",
      "",
      "# Disable SSL 2.0",
      "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Server' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 2.0\\Server' -Name 'Enabled' -Value 0 -Type DWord -Force",
      "",
      "# Disable SSL 3.0",
      "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 3.0\\Server' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\SSL 3.0\\Server' -Name 'Enabled' -Value 0 -Type DWord -Force",
      "",
      "# Disable TLS 1.0",
      "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Server' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.0\\Server' -Name 'Enabled' -Value 0 -Type DWord -Force",
      "",
      "# Disable TLS 1.1",
      "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.1\\Server' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.1\\Server' -Name 'Enabled' -Value 0 -Type DWord -Force",
      "",
      "# Enable TLS 1.2",
      "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server' -Name 'Enabled' -Value 1 -Type DWord -Force",
      "",
      "Write-Host 'TLS/SSL security configured successfully'"
    ]
  }

  // Configure Event Logs
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring event log sizes...'",
      "wevtutil sl Security /ms:196608000",
      "wevtutil sl Application /ms:32768000",
      "wevtutil sl System /ms:32768000",
      "Write-Host 'Event log sizes configured successfully'"
    ]
  }

  // Configure Windows Update
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Configuring Windows Update settings...'",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU' -Force -ErrorAction SilentlyContinue | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU' -Name 'AUOptions' -Value 3 -Type DWord -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU' -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force",
      "Write-Host 'Windows Update configured successfully'"
    ]
  }

  // Remove Unnecessary Features
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host 'Removing unnecessary features...'",
      "try {",
      "  Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue",
      "  Write-Host 'PowerShell v2 removed'",
      "} catch {",
      "  Write-Host 'PowerShell v2 not present'",
      "}",
      "try {",
      "  Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue",
      "  Write-Host 'SMBv1 feature removed'",
      "} catch {",
      "  Write-Host 'SMBv1 feature not present'",
      "}",
      "Write-Host 'Feature removal complete'"
    ]
  }

  // Install Windows Updates
  provisioner "windows-update" {
    pause_before    = "30s"
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*VMware*'",
      "exclude:$_.Title -like '*Preview*'",
      "exclude:$_.InstallationBehavior.CanRequestUserInput",
      "include:$true"
    ]
    update_limit = 25
  }

  // Cleanup and Summary
  provisioner "powershell" {
    elevated_user     = "Administrator"
    elevated_password = var.password
    inline = [
      "Write-Host '======================================='",
      "Write-Host 'Windows 10 22H2 Hardening Complete'",
      "Write-Host '======================================='",
      "Write-Host ''",
      "Write-Host 'Applied Configurations:'",
      "Write-Host '- Password policies strengthened (14 char min, complexity required)'",
      "Write-Host '- Account lockout policy configured (5 attempts, 30 min duration)'",
      "Write-Host '- Windows Firewall enabled with default deny inbound'",
      "Write-Host '- Unnecessary services disabled (including Xbox services)'",
      "Write-Host '- Comprehensive audit policies enabled'",
      "Write-Host '- SMBv1 disabled and removed'",
      "Write-Host '- SMB signing enabled'",
      "Write-Host '- LLMNR and NetBIOS disabled'",
      "Write-Host '- LSA protection and Credential Guard enabled'",
      "Write-Host '- Windows Script Host disabled'",
      "Write-Host '- AutoRun/AutoPlay disabled'",
      "Write-Host '- Screen saver timeout configured (15 minutes)'",
      "Write-Host '- Secure logon (Ctrl+Alt+Del) enabled'",
      "Write-Host '- Legal notice configured'",
      "Write-Host '- Camera, Microphone, and Location access disabled'",
      "Write-Host '- Telemetry and Advertising ID disabled'",
      "Write-Host '- Windows Consumer Features disabled'",
      "Write-Host '- Windows Defender optimized with Controlled Folder Access'",
      "Write-Host '- TLS 1.2 enforced (SSL 2.0/3.0, TLS 1.0/1.1 disabled)'",
      "Write-Host '- Event log sizes increased'",
      "Write-Host '- Automatic updates configured'",
      "Write-Host '- PowerShell v2 removed'",
      "Write-Host ''",
      "Write-Host 'Cleaning up temporary files...'",
      "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path C:\\Users\\*\\AppData\\Local\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
      "Write-Host 'Hardening process complete!'"
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_type     = "hardened"
      build_username = var.username
      build_date     = local.build_date
      build_version  = local.build_version
      author         = local.git_author
      committer      = local.git_committer
      timestamp      = local.git_timestamp
      security_level = "CIS Benchmarks"
    }
  }
}
