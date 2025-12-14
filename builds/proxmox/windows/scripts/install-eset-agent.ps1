# Install ESET Protect Agent
# Downloads and installs the latest ESET Protect agent with silent installation

$ErrorActionPreference = "Stop"

# Configuration
$AgentUrl = "https://download.eset.com/com/eset/apps/business/era/agent/latest/agent_x64.msi"
$TempDir = "C:\Windows\Temp"
$InstallerPath = Join-Path $TempDir "agent_x64.msi"
$ConfigPath = Join-Path $TempDir "install_config.ini"
$LogPath = Join-Path $env:TEMP "era-agent-install.log"

Write-Host "======================================="
Write-Host "ESET Protect Agent Installation"
Write-Host "======================================="
Write-Host ""

# Check if config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Configuration file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}
Write-Host "Found configuration file: $ConfigPath" -ForegroundColor Green

# Download the agent installer
Write-Host ""
Write-Host "Downloading ESET Protect Agent from: $AgentUrl"
try {
    # Use TLS 1.2 for secure download
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($AgentUrl, $InstallerPath)
    
    Write-Host "Download completed successfully" -ForegroundColor Green
    Write-Host "Installer saved to: $InstallerPath"
    
    # Verify the file was downloaded
    if (Test-Path $InstallerPath) {
        $FileSize = (Get-Item $InstallerPath).Length / 1MB
        Write-Host "Installer file size: $([math]::Round($FileSize, 2)) MB"
    } else {
        throw "Installer file not found after download"
    }
} catch {
    Write-Host "ERROR: Failed to download ESET Protect Agent" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    exit 1
}

# Install the agent silently
Write-Host ""
Write-Host "Installing ESET Protect Agent..."
Write-Host "Installation log will be saved to: $LogPath"

try {
    $MsiArgs = @(
        "/i"
        "`"$InstallerPath`""
        "/qn"
        "/norestart"
        "/l*v"
        "`"$LogPath`""
    )
    
    Write-Host "Starting silent installation..."
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArgs -Wait -PassThru -NoNewWindow
    
    $ExitCode = $Process.ExitCode
    
    if ($ExitCode -eq 0) {
        Write-Host ""
        Write-Host "=======================================" -ForegroundColor Green
        Write-Host "ESET Protect Agent installed successfully" -ForegroundColor Green
        Write-Host "=======================================" -ForegroundColor Green
    } elseif ($ExitCode -eq 3010) {
        Write-Host ""
        Write-Host "=======================================" -ForegroundColor Yellow
        Write-Host "ESET Protect Agent installed successfully" -ForegroundColor Yellow
        Write-Host "A reboot is required to complete installation" -ForegroundColor Yellow
        Write-Host "=======================================" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "=======================================" -ForegroundColor Red
        Write-Host "Installation failed with exit code: $ExitCode" -ForegroundColor Red
        Write-Host "=======================================" -ForegroundColor Red
        Write-Host "Check the installation log for details: $LogPath"
        exit $ExitCode
    }
} catch {
    Write-Host "ERROR: Failed to install ESET Protect Agent" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host "Check the installation log for details: $LogPath"
    exit 1
}

# Cleanup installer file
Write-Host ""
Write-Host "Cleaning up installer file..."
try {
    Remove-Item -Path $InstallerPath -Force -ErrorAction SilentlyContinue
    Write-Host "Installer file removed successfully" -ForegroundColor Green
} catch {
    Write-Host "Warning: Could not remove installer file: $InstallerPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "ESET Protect Agent installation completed"
Write-Host "Installation log: $LogPath"
