<#
    .SYNOPSIS
    Installs Atomic Red Team and its dependencies for security testing.
    
    .DESCRIPTION
    This script installs Atomic Red Team framework along with required dependencies:
    - PowerShell execution policy configuration
    - Invoke-AtomicRedTeam PowerShell module
    - Atomic Red Team test definitions
    - Optional: Additional tools (PsExec, 7zip, etc.)
    
    .NOTES
    File Name      : install-atomic-redteam.ps1
    Prerequisite   : PowerShell 5.1 or later, Internet connectivity
    Author         : Packer Build Script
    
    .EXAMPLE
    .\install-atomic-redteam.ps1
#>

# Enable verbose logging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

# Create log file
$LogFile = "C:\Windows\Temp\install-atomic-redteam.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

Write-Log "=== Starting Atomic Red Team Installation ===" "INFO"
Write-Log "Current User: $env:USERNAME" "INFO"
Write-Log "Computer Name: $env:COMPUTERNAME" "INFO"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"

# Ensure TLS 1.2 is enabled for downloads
Write-Log "Enabling TLS 1.2 for secure downloads..." "INFO"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Log "TLS 1.2 enabled successfully" "INFO"
} catch {
    Write-Log "Failed to enable TLS 1.2: $($_.Exception.Message)" "ERROR"
    throw
}

# Set execution policy to allow script execution
Write-Log "Configuring PowerShell execution policy..." "INFO"
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force
    Write-Log "Execution policy set to Bypass for CurrentUser" "INFO"
} catch {
    Write-Log "Failed to set execution policy: $($_.Exception.Message)" "WARN"
}

# Configure PSGallery as trusted repository
Write-Log "Configuring PSGallery as trusted repository..." "INFO"
try {
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($psGallery.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Log "PSGallery set as trusted repository" "INFO"
    } else {
        Write-Log "PSGallery already trusted" "INFO"
    }
} catch {
    Write-Log "Failed to configure PSGallery: $($_.Exception.Message)" "ERROR"
    throw
}

# Install NuGet provider if not present
Write-Log "Checking for NuGet package provider..." "INFO"
try {
    $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $nuget) {
        Write-Log "Installing NuGet package provider..." "INFO"
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
        Write-Log "NuGet provider installed successfully" "INFO"
    } else {
        Write-Log "NuGet provider already installed (Version: $($nuget.Version))" "INFO"
    }
} catch {
    Write-Log "Failed to install NuGet provider: $($_.Exception.Message)" "ERROR"
    throw
}

# Install PowerShellGet module (required for module management)
Write-Log "Checking PowerShellGet module..." "INFO"
try {
    $psGet = Get-Module -Name PowerShellGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if ($psGet.Version -lt [Version]"2.0.0") {
        Write-Log "Updating PowerShellGet module..." "INFO"
        Install-Module -Name PowerShellGet -Force -AllowClobber -Confirm:$false -SkipPublisherCheck
        Write-Log "PowerShellGet module updated" "INFO"
    } else {
        Write-Log "PowerShellGet module is up to date (Version: $($psGet.Version))" "INFO"
    }
} catch {
    Write-Log "Failed to update PowerShellGet: $($_.Exception.Message)" "WARN"
}

# Install Invoke-AtomicRedTeam module
Write-Log "Installing Invoke-AtomicRedTeam PowerShell module..." "INFO"
try {
    $atomicModule = Get-Module -Name invoke-atomicredteam -ListAvailable -ErrorAction SilentlyContinue
    if ($atomicModule) {
        Write-Log "Invoke-AtomicRedTeam already installed (Version: $($atomicModule.Version))" "INFO"
        Write-Log "Updating to latest version..." "INFO"
        Update-Module -Name invoke-atomicredteam -Force -Confirm:$false
        Write-Log "Module updated successfully" "INFO"
    } else {
        Write-Log "Installing Invoke-AtomicRedTeam module from PSGallery..." "INFO"
        Install-Module -Name invoke-atomicredteam -Scope AllUsers -Force -Confirm:$false
        Write-Log "Invoke-AtomicRedTeam module installed successfully" "INFO"
    }
    
    # Verify installation
    Import-Module invoke-atomicredteam -Force
    $installedVersion = (Get-Module invoke-atomicredteam).Version
    Write-Log "Invoke-AtomicRedTeam version $installedVersion loaded successfully" "INFO"
} catch {
    Write-Log "Failed to install Invoke-AtomicRedTeam module: $($_.Exception.Message)" "ERROR"
    throw
}

# Install Atomic Red Team atomics (test definitions)
Write-Log "Installing Atomic Red Team test definitions..." "INFO"
$atomicsPath = "C:\AtomicRedTeam\atomics"
try {
    # Check if atomics already exist
    if (Test-Path $atomicsPath) {
        Write-Log "Atomics directory already exists at $atomicsPath" "INFO"
        Write-Log "Updating existing atomics..." "INFO"
        Invoke-AtomicTest ALL -GetPrereqs -Force
    } else {
        Write-Log "Installing atomics to $atomicsPath..." "INFO"
        # Install atomics from GitHub
        $installCommand = 'IEX (IWR ''https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1'' -UseBasicParsing);'
        $installCommand += 'Install-AtomicRedTeam -getAtomics -Force'
        Invoke-Expression $installCommand
        Write-Log "Atomic Red Team atomics installed successfully" "INFO"
    }
    
    # Verify atomics installation
    if (Test-Path $atomicsPath) {
        $atomicCount = (Get-ChildItem -Path $atomicsPath -Directory).Count
        Write-Log "Found $atomicCount atomic test directories" "INFO"
    } else {
        Write-Log "Atomics directory not found after installation" "WARN"
    }
} catch {
    Write-Log "Failed to install atomics: $($_.Exception.Message)" "ERROR"
    throw
}

# Install common prerequisites and tools
Write-Log "Installing common prerequisites for atomic tests..." "INFO"
try {
    # Create tools directory
    $toolsPath = "C:\AtomicRedTeam\Tools"
    if (-not (Test-Path $toolsPath)) {
        New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
        Write-Log "Created tools directory: $toolsPath" "INFO"
    }
    
    # Download and install 7-Zip (required by many atomics)
    Write-Log "Checking for 7-Zip..." "INFO"
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $7zipPath)) {
        Write-Log "Installing 7-Zip..." "INFO"
        $7zipInstaller = "$env:TEMP\7z-installer.exe"
        $7zipUrl = "https://www.7-zip.org/a/7z2408-x64.exe"
        
        Invoke-WebRequest -Uri $7zipUrl -OutFile $7zipInstaller -UseBasicParsing
        Start-Process -FilePath $7zipInstaller -ArgumentList "/S" -Wait -NoNewWindow
        Remove-Item $7zipInstaller -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $7zipPath) {
            Write-Log "7-Zip installed successfully" "INFO"
        } else {
            Write-Log "7-Zip installation could not be verified" "WARN"
        }
    } else {
        Write-Log "7-Zip already installed" "INFO"
    }
    
    # Download PsExec (Sysinternals) - commonly used in atomic tests
    Write-Log "Checking for PsExec..." "INFO"
    $psexecPath = "$toolsPath\PsExec64.exe"
    if (-not (Test-Path $psexecPath)) {
        Write-Log "Downloading PsExec..." "INFO"
        $psexecUrl = "https://live.sysinternals.com/PsExec64.exe"
        
        try {
            Invoke-WebRequest -Uri $psexecUrl -OutFile $psexecPath -UseBasicParsing
            Write-Log "PsExec downloaded to $psexecPath" "INFO"
        } catch {
            Write-Log "Failed to download PsExec: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Log "PsExec already exists at $psexecPath" "INFO"
    }
    
    # Add tools directory to PATH
    Write-Log "Adding tools directory to system PATH..." "INFO"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$toolsPath*") {
        $newPath = "$currentPath;$toolsPath"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Log "Tools directory added to PATH" "INFO"
    } else {
        Write-Log "Tools directory already in PATH" "INFO"
    }
} catch {
    Write-Log "Failed to install prerequisites: $($_.Exception.Message)" "WARN"
}

# Configure Atomic Red Team environment variables
Write-Log "Configuring Atomic Red Team environment variables..." "INFO"
try {
    [Environment]::SetEnvironmentVariable("ATOMIC_RED_TEAM_PATH", "C:\AtomicRedTeam", "Machine")
    Write-Log "ATOMIC_RED_TEAM_PATH environment variable set" "INFO"
} catch {
    Write-Log "Failed to set environment variables: $($_.Exception.Message)" "WARN"
}

# Create shortcut on desktop for easy access
Write-Log "Creating desktop shortcut..." "INFO"
try {
    $desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    $shortcutPath = "$desktopPath\Atomic Red Team.lnk"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-NoExit -Command `"Import-Module invoke-atomicredteam; Write-Host 'Atomic Red Team loaded. Use Invoke-AtomicTest to run tests.' -ForegroundColor Green`""
    $Shortcut.WorkingDirectory = "C:\AtomicRedTeam"
    $Shortcut.Description = "Launch PowerShell with Atomic Red Team module loaded"
    $Shortcut.IconLocation = "powershell.exe,0"
    $Shortcut.Save()
    
    Write-Log "Desktop shortcut created successfully" "INFO"
} catch {
    Write-Log "Failed to create desktop shortcut: $($_.Exception.Message)" "WARN"
}

# Display installation summary
Write-Log "=== Atomic Red Team Installation Summary ===" "INFO"
Write-Log "Module Location: $((Get-Module invoke-atomicredteam).ModuleBase)" "INFO"
Write-Log "Atomics Location: $atomicsPath" "INFO"
Write-Log "Tools Location: $toolsPath" "INFO"
Write-Log "" "INFO"
Write-Log "Installation completed successfully!" "INFO"
Write-Log "" "INFO"
Write-Log "Usage Examples:" "INFO"
Write-Log "  Import-Module invoke-atomicredteam" "INFO"
Write-Log "  Invoke-AtomicTest T1003.001 -ShowDetailsBrief" "INFO"
Write-Log "  Invoke-AtomicTest T1059.001 -TestNumbers 1,2 -CheckPrereqs" "INFO"
Write-Log "  Invoke-AtomicTest ALL -CheckPrereqs" "INFO"
Write-Log "" "INFO"
Write-Log "=== Installation Complete ===" "INFO"

# Exit successfully
exit 0
