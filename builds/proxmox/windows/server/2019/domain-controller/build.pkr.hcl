// packer build file for Windows Server 2019 Domain Controller
packer {
  required_version = ">= 1.9.4"
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
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
  name = "windows_server_2k19_domain_controller"
  sources = [
    "source.proxmox-clone.windows_server_2k19_domain_controller"
  ]

  // Set computer hostname
  provisioner "powershell" {
    inline = [
      "Write-Host 'Setting computer name to DC01...'",
      "Rename-Computer -NewName DC01 -Force",
      "Write-Host 'Computer renamed. Reboot required.'"
    ]
  }

  // Reboot after hostname change
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  // Install AD DS and management tools
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing AD DS and management tools...'",
      "Install-WindowsFeature -Name AD-Domain-Services,RSAT-AD-Tools,RSAT-ADDS,RSAT-AD-PowerShell,RSAT-ADDS-Tools,DNS,GPMC -IncludeManagementTools",
      "Write-Host 'Features installed successfully.'"
    ]
  }

  // Reboot after feature installation
  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  // Promote server to Domain Controller
  provisioner "powershell" {
    environment_vars = [
      "DOMAIN_NAME=${var.domain_name}",
      "DOMAIN_NETBIOS=${var.domain_netbios_name}",
      "SAFE_MODE_PWD=${var.safe_mode_password}"
    ]
    inline = [
      "$SecurePassword = ConvertTo-SecureString $env:SAFE_MODE_PWD -AsPlainText -Force",
      "Write-Host 'Promoting server to Domain Controller...'",
      "Write-Host 'Domain: ' $env:DOMAIN_NAME",
      "Write-Host 'NetBIOS: ' $env:DOMAIN_NETBIOS",
      "Install-ADDSForest -DomainName $env:DOMAIN_NAME -DomainNetbiosName $env:DOMAIN_NETBIOS -SafeModeAdministratorPassword $SecurePassword -DomainMode WinThreshold -ForestMode WinThreshold -InstallDns -CreateDnsDelegation:$false -DatabasePath 'C:\\Windows\\NTDS' -SysvolPath 'C:\\Windows\\SYSVOL' -LogPath 'C:\\Windows\\Logs' -Force -NoRebootOnCompletion:$false",
      "Write-Host 'Domain Controller promotion initiated. System will reboot.'"
    ]
  }

  // Wait for system to reboot after domain promotion
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  // Configure DNS forwarders and create OUs
  provisioner "powershell" {
    pause_before = "60s"
    environment_vars = [
      "DOMAIN_NAME=${var.domain_name}"
    ]
    inline = [
      "Write-Host 'Waiting for Active Directory Web Services...'",
      "Start-Sleep -Seconds 30",
      "$retries = 0",
      "while ($retries -lt 10) {",
      "  try {",
      "    $service = Get-Service ADWS -ErrorAction Stop",
      "    if ($service.Status -eq 'Running') { break }",
      "    Start-Service ADWS -ErrorAction Stop",
      "    Start-Sleep -Seconds 10",
      "  } catch {",
      "    Write-Host 'Waiting for ADWS... attempt ' ($retries + 1)",
      "    Start-Sleep -Seconds 10",
      "  }",
      "  $retries++",
      "}",
      "",
      "Write-Host 'Configuring DNS forwarders...'",
      "try {",
      "  Add-DnsServerForwarder -IPAddress 8.8.8.8 -PassThru",
      "  Add-DnsServerForwarder -IPAddress 1.1.1.1 -PassThru",
      "} catch {",
      "  Write-Host 'DNS forwarders may already exist'",
      "}",
      "",
      "Write-Host 'Creating default organizational units...'",
      "$DomainDN = (Get-ADDomain).DistinguishedName",
      "$OUs = @('Servers', 'Workstations', 'Users', 'Groups', 'Service Accounts')",
      "foreach ($OU in $OUs) {",
      "  try {",
      "    New-ADOrganizationalUnit -Name $OU -Path $DomainDN -ProtectedFromAccidentalDeletion $true -ErrorAction SilentlyContinue",
      "    Write-Host 'Created OU: ' $OU",
      "  } catch {",
      "    Write-Host 'OU ' $OU ' may already exist'",
      "  }",
      "}",
      "",
      "Write-Host 'Enabling AD Recycle Bin...'",
      "try {",
      "  Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target $env:DOMAIN_NAME -Confirm:$false",
      "} catch {",
      "  Write-Host 'AD Recycle Bin may already be enabled'",
      "}",
      "",
      "Write-Host 'Setting DNS client settings...'",
      "Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses 127.0.0.1",
      "",
      "Write-Host 'Configuring Windows Firewall rules...'",
      "$firewallRules = @(",
      "  @{Name='DNS-TCP'; Port='53'; Protocol='TCP'},",
      "  @{Name='DNS-UDP'; Port='53'; Protocol='UDP'},",
      "  @{Name='Kerberos-TCP'; Port='88'; Protocol='TCP'},",
      "  @{Name='Kerberos-UDP'; Port='88'; Protocol='UDP'},",
      "  @{Name='LDAP-TCP'; Port='389'; Protocol='TCP'},",
      "  @{Name='LDAP-UDP'; Port='389'; Protocol='UDP'},",
      "  @{Name='LDAPS-TCP'; Port='636'; Protocol='TCP'},",
      "  @{Name='SMB-TCP'; Port='445'; Protocol='TCP'},",
      "  @{Name='Global-Catalog-TCP'; Port='3268'; Protocol='TCP'},",
      "  @{Name='Global-Catalog-SSL-TCP'; Port='3269'; Protocol='TCP'}",
      ")",
      "foreach ($rule in $firewallRules) {",
      "  New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -LocalPort $rule.Port -Protocol $rule.Protocol -Action Allow -ErrorAction SilentlyContinue",
      "}",
      "",
      "Write-Host '==================================='",
      "Write-Host 'Domain Controller Configuration Complete'",
      "Write-Host 'Domain Name: ' $env:DOMAIN_NAME",
      "Write-Host 'Computer Name: DC01'",
      "Write-Host '==================================='",
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_type     = "domain-controller"
      build_username = var.username
      build_date     = local.build_date
      build_version  = local.build_version
      author         = local.git_author
      committer      = local.git_committer
      timestamp      = local.git_timestamp
      domain_name    = var.domain_name
    }
  }
}
