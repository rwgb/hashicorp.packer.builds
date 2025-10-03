# Copyright 2023 Broadcom. All Rights Reserved.
# SPDX-License-Identifier: BSD-2

<#
    .DESCRIPTION
    Prepares a Windows guest operating system for Proxmox builds.
#>

param(
    [string] $BUILD_USERNAME = $env:BUILD_USER
)

$ErrorActionPreference = "Continue"
Write-Host "`n[INFO] Starting provisioning..."

function Try-Run {
    param (
        [ScriptBlock]$Action,
        [string]$Description
    )

    try {
        Write-Host "`n[INFO] $Description"
        & $Action
    } catch {
        Write-Warning "[WARN] Failed: $Description - $_"
    }
}

# === STEP 1: Disable password complexity ===
Try-Run -Description "Disabling local password complexity policy" -Action {
    $cfgPath = "C:\secpol.cfg"
    secedit /export /cfg $cfgPath | Out-Null

    $content = Get-Content $cfgPath
    if ($content -match "PasswordComplexity\s*=\s*1") {
        $content = $content -replace "PasswordComplexity\s*=\s*1", "PasswordComplexity = 0"
        Set-Content -Path $cfgPath -Value $content
        secedit /configure /db secedit.sdb /cfg $cfgPath /areas SECURITYPOLICY | Out-Null
    }

    Remove-Item $cfgPath -ErrorAction SilentlyContinue
}

# === STEP 2: Create user with password ===
Try-Run -Description "Creating local user: $BUILD_USERNAME with matching password" -Action {
    if (-not $BUILD_USERNAME) {
        throw "BUILD_USER environment variable is not set."
    }

    $securePass = ConvertTo-SecureString -String $BUILD_USERNAME -AsPlainText -Force

    if (-not (Get-LocalUser -Name $BUILD_USERNAME -ErrorAction SilentlyContinue)) {
        New-LocalUser -Name $BUILD_USERNAME -Password $securePass -FullName $BUILD_USERNAME -PasswordNeverExpires
    } else {
        Write-Host "User $BUILD_USERNAME already exists."
    }

    # Optional: Add to Administrators group
    Add-LocalGroupMember -Group "Administrators" -Member $BUILD_USERNAME -ErrorAction SilentlyContinue
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
Try-Run -Description "Setting the Windows Explorer options" -Action {
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideDrivesWithNoMedia" -Value 0
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0
}

# Disable system hibernation.
Try-Run -Description "Disabling system hibernation" -Action {
    powercfg.exe -h off
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileSizePercent" -Value 0
}

# Disable TLS 1.0 and 1.1
function Disable-TLSVersion {
    param($Version)
    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Version"
    Try-Run -Description "Disabling $Version" -Action {
        if (-not (Test-Path "$basePath\Server")) { New-Item "$basePath\Server" -Force | Out-Null }
        if (-not (Test-Path "$basePath\Client")) { New-Item "$basePath\Client" -Force | Out-Null }

        New-ItemProperty -Path "$basePath\Server" -Name "Enabled" -Value 0 -Force
        New-ItemProperty -Path "$basePath\Server" -Name "DisabledByDefault" -Value 1 -Force
        New-ItemProperty -Path "$basePath\Client" -Name "Enabled" -Value 0 -Force
        New-ItemProperty -Path "$basePath\Client" -Name "DisabledByDefault" -Value 1 -Force
    }
}

Disable-TLSVersion -Version "TLS 1.0"
Disable-TLSVersion -Version "TLS 1.1"

# Installing Cloudbase-Init
Write-Host "`n[INFO] Installing Cloudbase-Init ..."
$msiLocation = 'https://cloudbase.it/downloads'
$msiFileName = 'CloudbaseInitSetup_Stable_x64.msi'
$msiPath = "C:\$msiFileName"

Try-Run -Description "Downloading and installing Cloudbase-Init" -Action {
    if (-not (Test-Path $msiPath)) {
        Invoke-WebRequest -Uri ($msiLocation + '/' + $msiFileName) -OutFile $msiPath
        Unblock-File -Path $msiPath
    }
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart RUN_SERVICE_AS_LOCAL_SYSTEM=1" -Wait
}

Try-Run -Description "Configuring Cloudbase-Init" -Action {
    $confFile = 'cloudbase-init.conf'
    $confPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\"
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
    if (-not (Test-Path "$confPath\$confFile")) {
        Set-Content -Path "$confPath\$confFile" -Value $confContent -Force
    }
    sc.exe config cloudbase-init start= delayed-auto | Out-Null
    Remove-Item -Path "$confPath\cloudbase-init-unattend.conf","$confPath\Unattend.xml" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
}

# Enable Remote Desktop
Try-Run -Description "Enabling Remote Desktop" -Action {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 0 -Force
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

Write-Host "`n[INFO] Provisioning completed successfully.`n"

