# Copyright 2023 Broadcom. All Rights Reserved.
# SPDX-License-Identifier: BSD-2

<#
    .DESCRIPTION
    Prepares a Windows guest operating system for Proxmox builds.
#>

param(
    [string] $BUILD_USERNAME = $env:BUILD_USER
)

# Enable verbose logging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Continue"

# Create log file
$LogFile = "C:\Windows\Temp\windows-prepare.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

Write-Log "=== Starting windows-prepare.ps1 script ===" "INFO"
Write-Log "BUILD_USERNAME parameter: $BUILD_USERNAME" "INFO"
Write-Log "Current User: $env:USERNAME" "INFO"
Write-Log "Computer Name: $env:COMPUTERNAME" "INFO"

function Try-Run {
    param (
        [ScriptBlock]$Action,
        [string]$Description,
        [int]$MaxRetries = 1
    )

    $retryCount = 0
    $success = $false
    
    while (-not $success -and $retryCount -lt $MaxRetries) {
        try {
            $retryCount++
            if ($MaxRetries -gt 1) {
                Write-Log "$Description (Attempt $retryCount of $MaxRetries)" "INFO"
            } else {
                Write-Log $Description "INFO"
            }
            & $Action
            $success = $true
            Write-Log "$Description - SUCCESS" "INFO"
        } catch {
            Write-Log "$Description - FAILED: $_" "ERROR"
            if ($retryCount -lt $MaxRetries) {
                Write-Log "Retrying in 5 seconds..." "INFO"
                Start-Sleep -Seconds 5
            } else {
                Write-Log "$Description - FAILED after $MaxRetries attempts" "WARN"
            }
        }
    }
    
    return $success
}

# === STEP 1: Disable password complexity ===
Try-Run -Description "Disabling local password complexity policy" -MaxRetries 2 -Action {
    $cfgPath = "C:\secpol.cfg"
    Write-Log "Exporting security policy to: $cfgPath" "INFO"
    secedit /export /cfg $cfgPath | Out-Null

    $content = Get-Content $cfgPath
    if ($content -match "PasswordComplexity\s*=\s*1") {
        Write-Log "Password complexity is currently enabled, disabling..." "INFO"
        $content = $content -replace "PasswordComplexity\s*=\s*1", "PasswordComplexity = 0"
        Set-Content -Path $cfgPath -Value $content
        secedit /configure /db secedit.sdb /cfg $cfgPath /areas SECURITYPOLICY | Out-Null
        Write-Log "Password complexity disabled" "INFO"
    } else {
        Write-Log "Password complexity already disabled" "INFO"
    }

    Remove-Item $cfgPath -ErrorAction SilentlyContinue
}

# === STEP 2: Create user with password ===
Try-Run -Description "Creating local user: $BUILD_USERNAME with matching password" -MaxRetries 2 -Action {
    if (-not $BUILD_USERNAME) {
        throw "BUILD_USER environment variable is not set."
    }

    Write-Log "Creating user: $BUILD_USERNAME" "INFO"
    $securePass = ConvertTo-SecureString -String $BUILD_USERNAME -AsPlainText -Force

    $existingUser = Get-LocalUser -Name $BUILD_USERNAME -ErrorAction SilentlyContinue
    if (-not $existingUser) {
        Write-Log "User $BUILD_USERNAME does not exist, creating..." "INFO"
        New-LocalUser -Name $BUILD_USERNAME -Password $securePass -FullName $BUILD_USERNAME -PasswordNeverExpires
        Write-Log "User $BUILD_USERNAME created successfully" "INFO"
    } else {
        Write-Log "User $BUILD_USERNAME already exists" "INFO"
    }

    # Optional: Add to Administrators group
    Write-Log "Adding $BUILD_USERNAME to Administrators group..." "INFO"
    try {
        Add-LocalGroupMember -Group "Administrators" -Member $BUILD_USERNAME -ErrorAction Stop
        Write-Log "User added to Administrators group" "INFO"
    } catch {
        if ($_.Exception.Message -match "already a member") {
            Write-Log "User already in Administrators group" "INFO"
        } else {
            throw
        }
    }
}

# Optional: Import the Root CA certificate to the Trusted Root Certification Authorities.
# This option will require the use of a file provisioner to copy the certificate to the guest.
# Write-Output "Importing the Root CA certificate to the Trusted Root Certification Authorities..."
# Import-Certificate -FilePath C:\windows\temp\root-ca.cer -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
# Remove-Item C:\windows\temp\root-ca.cer -Confirm:$false

# Optional: Import the Issuing CA certificate to the Trusted Root Certification Authoriries.
# This option will require the use of a file provisioner to copy the certificate to the guest.
# Write-Output "Importing the Issuing CA certificate to the Trusted Root Certification Authoriries..."
# Import-Certificate -FilePath C:\windows\temp\issuing-ca.cer -CertStoreLocation 'Cert:\LocalMachine\CA' | Out-Null
# Remove-Item C:\windows\temp\issuing-ca.cer -Confirm:$false

# Set the Windows Explorer options.
Try-Run -Description "Setting the Windows Explorer options" -MaxRetries 1 -Action {
    Write-Log "Configuring Explorer to show hidden files..." "INFO"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    
    Write-Log "Configuring Explorer to show file extensions..." "INFO"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    
    Write-Log "Configuring Explorer to show drives with no media..." "INFO"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideDrivesWithNoMedia" -Value 0
    
    Write-Log "Disabling sync provider notifications..." "INFO"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0
}

# Disable system hibernation.
Try-Run -Description "Disabling system hibernation" -MaxRetries 2 -Action {
    Write-Log "Turning off hibernation..." "INFO"
    powercfg.exe -h off
    
    Write-Log "Setting hibernation file size to 0..." "INFO"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileSizePercent" -Value 0
}

# Disable TLS 1.0 and 1.1
function Disable-TLSVersion {
    param($Version)
    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Version"
    Try-Run -Description "Disabling $Version" -MaxRetries 1 -Action {
        Write-Log "Creating registry paths for $Version..." "INFO"
        if (-not (Test-Path "$basePath\Server")) { 
            New-Item "$basePath\Server" -Force | Out-Null 
            Write-Log "Created $basePath\Server" "INFO"
        }
        if (-not (Test-Path "$basePath\Client")) { 
            New-Item "$basePath\Client" -Force | Out-Null 
            Write-Log "Created $basePath\Client" "INFO"
        }

        Write-Log "Setting $Version registry values..." "INFO"
        New-ItemProperty -Path "$basePath\Server" -Name "Enabled" -Value 0 -Force | Out-Null
        New-ItemProperty -Path "$basePath\Server" -Name "DisabledByDefault" -Value 1 -Force | Out-Null
        New-ItemProperty -Path "$basePath\Client" -Name "Enabled" -Value 0 -Force | Out-Null
        New-ItemProperty -Path "$basePath\Client" -Name "DisabledByDefault" -Value 1 -Force | Out-Null
        Write-Log "$Version disabled successfully" "INFO"
    }
}

Write-Log "Disabling legacy TLS versions..." "INFO"
Disable-TLSVersion -Version "TLS 1.0"
Disable-TLSVersion -Version "TLS 1.1"

# Installing Cloudbase-Init
Write-Log "Starting Cloudbase-Init installation..." "INFO"
$msiLocation = 'https://cloudbase.it/downloads'
$msiFileName = 'CloudbaseInitSetup_Stable_x64.msi'
$msiPath = "C:\$msiFileName"

Try-Run -Description "Downloading and installing Cloudbase-Init" -MaxRetries 3 -Action {
    if (-not (Test-Path $msiPath)) {
        Write-Log "Downloading Cloudbase-Init from: $msiLocation/$msiFileName" "INFO"
        Invoke-WebRequest -Uri ($msiLocation + '/' + $msiFileName) -OutFile $msiPath
        Write-Log "Download completed" "INFO"
        Unblock-File -Path $msiPath
        Write-Log "File unblocked" "INFO"
    } else {
        Write-Log "Cloudbase-Init installer already downloaded" "INFO"
    }
    
    $fileSize = (Get-Item $msiPath).Length
    Write-Log "MSI file size: $fileSize bytes" "INFO"
    
    Write-Log "Starting Cloudbase-Init installation..." "INFO"
    $installProcess = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart RUN_SERVICE_AS_LOCAL_SYSTEM=1" -Wait -PassThru
    Write-Log "Cloudbase-Init installation exit code: $($installProcess.ExitCode)" "INFO"
    
    if ($installProcess.ExitCode -ne 0) {
        throw "Cloudbase-Init installation failed with exit code: $($installProcess.ExitCode)"
    }
}

Try-Run -Description "Configuring Cloudbase-Init" -MaxRetries 2 -Action {
    $confFile = 'cloudbase-init.conf'
    $confPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\"
    
    if (-not (Test-Path $confPath)) {
        throw "Cloudbase-Init configuration directory not found: $confPath"
    }
    
    Write-Log "Creating Cloudbase-Init configuration file..." "INFO"
    $confContent = @"
[DEFAULT]
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
metadata_services=cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService
plugins=cloudbaseinit.plugins.common.userdata.UserDataPlugin
"@
    
    $confFilePath = "$confPath\$confFile"
    if (-not (Test-Path $confFilePath)) {
        Set-Content -Path $confFilePath -Value $confContent -Force
        Write-Log "Configuration file created: $confFilePath" "INFO"
    } else {
        Write-Log "Configuration file already exists: $confFilePath" "INFO"
    }
    
    Write-Log "Setting Cloudbase-Init service to delayed-auto start..." "INFO"
    sc.exe config cloudbase-init start= delayed-auto | Out-Null
    
    Write-Log "Removing unattend configuration files..." "INFO"
    Remove-Item -Path "$confPath\cloudbase-init-unattend.conf","$confPath\Unattend.xml" -Force -ErrorAction SilentlyContinue
    
    Write-Log "Removing MSI installer..." "INFO"
    Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
}

# Enable Remote Desktop
Try-Run -Description "Enabling Remote Desktop" -MaxRetries 2 -Action {
    Write-Log "Setting Terminal Server registry to allow RDP connections..." "INFO"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force
    
    Write-Log "Disabling Network Level Authentication requirement..." "INFO"
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 0 -Force
    
    Write-Log "Enabling Remote Desktop firewall rules..." "INFO"
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    
    Write-Log "Remote Desktop enabled successfully" "INFO"
}

Write-Log "=== windows-prepare.ps1 script completed successfully ===" "INFO"
Write-Log "Log file saved to: $LogFile" "INFO"

