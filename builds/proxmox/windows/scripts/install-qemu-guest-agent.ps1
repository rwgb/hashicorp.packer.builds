# Install QEMU Guest Agent for Proxmox
# This script downloads and installs the QEMU Guest Agent

Write-Host "Installing QEMU Guest Agent..."

# Define the download URL for QEMU Guest Agent
$qemuGuestAgentUrl = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-qemu-ga/qemu-ga-x86_64.msi"
$installerPath = "$env:TEMP\qemu-ga-x86_64.msi"

try {
    # Download QEMU Guest Agent installer
    Write-Host "Downloading QEMU Guest Agent from $qemuGuestAgentUrl..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $qemuGuestAgentUrl -OutFile $installerPath -UseBasicParsing
    
    if (Test-Path $installerPath) {
        Write-Host "Download completed successfully."
        
        # Install QEMU Guest Agent silently
        Write-Host "Installing QEMU Guest Agent..."
        $installArgs = @(
            "/i"
            "`"$installerPath`""
            "/qn"
            "/norestart"
        )
        
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "QEMU Guest Agent installed successfully."
            
            # Start the QEMU Guest Agent service
            Write-Host "Starting QEMU Guest Agent service..."
            Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
            
            # Set service to start automatically
            Set-Service -Name "QEMU-GA" -StartupType Automatic -ErrorAction SilentlyContinue
            
            # Verify service is running
            $service = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
            if ($service.Status -eq "Running") {
                Write-Host "QEMU Guest Agent service is running."
            } else {
                Write-Host "Warning: QEMU Guest Agent service is not running."
            }
        } else {
            Write-Host "Error: QEMU Guest Agent installation failed with exit code $($process.ExitCode)"
            exit $process.ExitCode
        }
        
        # Clean up installer
        Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
        Write-Host "Installer cleaned up."
    } else {
        Write-Host "Error: Failed to download QEMU Guest Agent installer."
        exit 1
    }
} catch {
    Write-Host "Error occurred during QEMU Guest Agent installation: $_"
    exit 1
}

Write-Host "QEMU Guest Agent installation completed."
