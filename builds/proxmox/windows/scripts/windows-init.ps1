<#
    .DESCRIPTION
    Enables Windows Remote Management on Windows builds, downloads QEMU GA MSI installer, and runs it.
#>

# Enable verbose logging
$VerbosePreference = "Continue"
$ErrorActionPreference = "Continue"

# Create log file
$LogFile = "C:\Windows\Temp\windows-init.log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Output $logMessage
    Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

Write-Log "=== Starting windows-init.ps1 script ===" "INFO"
Write-Log "Current User: $env:USERNAME" "INFO"
Write-Log "Computer Name: $env:COMPUTERNAME" "INFO"

# Set network connection profile to Private mode.
Write-Log "Setting the network connection profile to Private..." "INFO"
try {
    $connectionProfile = Get-NetConnectionProfile
    Write-Log "Initial connection profile: $($connectionProfile.Name)" "INFO"
    $timeout = 0
    While ($connectionProfile.Name -eq 'Identifying...' -and $timeout -lt 30) {
        Write-Log "Waiting for network profile identification... ($timeout/30 seconds)" "INFO"
        Start-Sleep -Seconds 10
        $timeout += 10
        $connectionProfile = Get-NetConnectionProfile
    }
    Set-NetConnectionProfile -Name $connectionProfile.Name -NetworkCategory Private
    Write-Log "Network profile set to Private successfully" "INFO"
} catch {
    Write-Log "Could not set network profile: $($_.Exception.Message)" "WARN"
}

# Set the Windows Remote Management configuration.
Write-Log "Setting the Windows Remote Management configuration..." "INFO"

$maxRetries = 3
$retryCount = 0
$winrmConfigured = $false

while (-not $winrmConfigured -and $retryCount -lt $maxRetries) {
    try {
        $retryCount++
        Write-Log "WinRM configuration attempt $retryCount of $maxRetries" "INFO"
        
        # Enable WinRM service
        Write-Log "Enabling WinRM service..." "INFO"
        Set-Service -Name WinRM -StartupType Automatic
        Start-Service WinRM
        Write-Log "WinRM service started" "INFO"
        
        # Configure WinRM
        Write-Log "Running winrm quickconfig..." "INFO"
        $quickConfigResult = winrm quickconfig -quiet -force 2>&1
        Write-Log "quickconfig result: $quickConfigResult" "INFO"
        
        Write-Log "Setting AllowUnencrypted=true..." "INFO"
        $result1 = winrm set winrm/config/service '@{AllowUnencrypted="true"}' 2>&1
        Write-Log "AllowUnencrypted result: $result1" "INFO"
        
        Write-Log "Setting Basic auth=true..." "INFO"
        $result2 = winrm set winrm/config/service/auth '@{Basic="true"}' 2>&1
        Write-Log "Basic auth result: $result2" "INFO"
        
        Write-Log "Setting CredSSP auth=true..." "INFO"
        $result3 = winrm set winrm/config/service/auth '@{CredSSP="true"}' 2>&1
        Write-Log "CredSSP result: $result3" "INFO"
        
        # Set trusted hosts to allow all
        Write-Log "Setting TrustedHosts=*..." "INFO"
        $result4 = winrm set winrm/config/client '@{TrustedHosts="*"}' 2>&1
        Write-Log "TrustedHosts result: $result4" "INFO"
        
        # Configure WinRM listener
        Write-Log "Checking WinRM listeners..." "INFO"
        $listeners = winrm enumerate winrm/config/listener 2>&1
        Write-Log "Existing listeners: $listeners" "INFO"
        
        if ($listeners -notmatch "HTTP") {
            Write-Log "Creating HTTP listener..." "INFO"
            $listenerResult = winrm create winrm/config/listener?Address=*+Transport=HTTP 2>&1
            Write-Log "Listener creation result: $listenerResult" "INFO"
        } else {
            Write-Log "HTTP listener already exists" "INFO"
        }
        
        # Restart WinRM to apply changes
        Write-Log "Restarting WinRM service..." "INFO"
        Restart-Service WinRM -Force
        Start-Sleep -Seconds 10
        
        # Verify WinRM is running
        $winrmStatus = Get-Service WinRM
        Write-Log "WinRM service status: $($winrmStatus.Status)" "INFO"
        
        if ($winrmStatus.Status -eq 'Running') {
            Write-Log "WinRM configuration completed successfully" "INFO"
            $winrmConfigured = $true
        } else {
            throw "WinRM service is not running after configuration"
        }
        
    } catch {
        Write-Log "WinRM configuration attempt $retryCount failed: $($_.Exception.Message)" "ERROR"
        if ($retryCount -lt $maxRetries) {
            Write-Log "Retrying in 10 seconds..." "INFO"
            Start-Sleep -Seconds 10
        } else {
            Write-Log "WinRM configuration failed after $maxRetries attempts" "ERROR"
        }
    }
}

if (-not $winrmConfigured) {
    Write-Log "CRITICAL: WinRM configuration failed completely" "ERROR"
}

# Allow Windows Remote Management in the Windows Firewall.
Write-Log "Allowing Windows Remote Management in the Windows Firewall..." "INFO"
try {
    Write-Log "Setting firewall rule for Windows Remote Administration..." "INFO"
    $firewallResult1 = netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes 2>&1
    Write-Log "Firewall rule 1 result: $firewallResult1" "INFO"
    
    Write-Log "Setting firewall rule for WinRM HTTP-In..." "INFO"
    $firewallResult2 = netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow 2>&1
    Write-Log "Firewall rule 2 result: $firewallResult2" "INFO"
    
    Write-Log "Firewall rules configured successfully" "INFO"
} catch {
    Write-Log "Firewall rule configuration failed: $($_.Exception.Message)" "WARN"
}

# Drop the firewall while building and re-enable as a standalone provisioner in the Packer file if needs be.
Write-Log "Disabling Windows Firewall for build..." "INFO"
$firewallOff = netsh Advfirewall set allprofiles state off 2>&1
Write-Log "Firewall disabled: $firewallOff" "INFO"

# Reset the autologon count.
# Reference: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
Write-Log "Resetting AutoLogonCount..." "INFO"
try {
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0
    Write-Log "AutoLogonCount reset to 0" "INFO"
} catch {
    Write-Log "Failed to reset AutoLogonCount: $($_.Exception.Message)" "WARN"
}

# Download the appropriate QEMU GA MSI installer based on architecture.
Write-Log "Starting QEMU Guest Agent download and installation..." "INFO"

$url = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/"
$uri = [System.Uri]$url
$rootUrl = $uri.GetLeftPart([System.UriPartial]::Authority)
$arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "i386" }
Write-Log "System architecture: $arch" "INFO"

$qemuInstalled = $false
$qemuRetries = 0
$qemuMaxRetries = 3

while (-not $qemuInstalled -and $qemuRetries -lt $qemuMaxRetries) {
    try {
        $qemuRetries++
        Write-Log "QEMU GA download attempt $qemuRetries of $qemuMaxRetries" "INFO"
        
        Write-Log "Fetching download URL from: $url" "INFO"
        $response = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction Stop -UseBasicParsing
        $link = [regex]::Match($response.Content, 'href="([^"]*latest-qemu-ga[^"]*)"').Groups[1].Value
        
        if (-not [string]::IsNullOrEmpty($link)) {
            Write-Log "Found latest QEMU GA link: $link" "INFO"
            $full_url = "$url$link"
            
            Write-Log "Fetching redirected URL from: $full_url" "INFO"
            $response = (Invoke-WebRequest -Uri $full_url -MaximumRedirection 1 -ErrorAction Stop -UseBasicParsing)
            $redirected_url = [regex]::Match($response.Content, 'href="([^"]*qemu-ga[^"]*)"').Groups[1].Value
            $download_url = "$rootUrl$redirected_url"
            Write-Log "Download URL: $download_url" "INFO"
            
            Write-Log "Fetching MSI link from: $download_url" "INFO"
            $msi_link = (Invoke-WebRequest -Uri $download_url -ErrorAction Stop -UseBasicParsing).Content
            $htmlContent = "$msi_link"
            $regexPattern = '<a href="([^"]*qemu-ga-win-[^"]*/)">([^<]+)</a>\s+([0-9-]+\s[0-9:]+)'
            $matches = [regex]::Matches($htmlContent, $regexPattern)
            $entryList = @()

            Write-Log "Parsing MSI entries..." "INFO"
            foreach ($match in $matches) {
                $link = $match.Groups[1].Value
                $name = $match.Groups[2].Value
                $modified = [DateTime]::ParseExact($match.Groups[3].Value, "yyyy-MM-dd HH:mm", $null)
            
                $entryObject = [PSCustomObject]@{
                    Link = $link
                    Name = $name
                    Modified = $modified
                }
            
                $entryList += $entryObject
            }

            # Sort the entries by descending last modified date
            $sortedEntries = $entryList | Sort-Object -Property Modified -Descending
            Write-Log "Found $($sortedEntries.Count) MSI entries" "INFO"

            # Output the sorted entries
            if ($sortedEntries.Count -gt 0) {
                $firstLink = $sortedEntries[0].Link
                $msi_link = "$download_url$firstLink"+"qemu-ga-$arch.msi"
                Write-Log "Selected MSI link: $msi_link" "INFO"
            } else {
                throw "No sorted MSI entries found"
            }

            if (-not [string]::IsNullOrEmpty($msi_link)) {
                $full_msi_link = "$msi_link"
                # Use backslashes for Windows paths
                $msiPath = "$env:TEMP\qemu-ga-$arch.msi"
                
                Write-Log "Downloading QEMU GA MSI from: $full_msi_link" "INFO"
                Write-Log "Download destination: $msiPath" "INFO"
                
                # Remove old file if exists
                if (Test-Path $msiPath) {
                    Write-Log "Removing existing MSI file..." "INFO"
                    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
                }
                
                Invoke-WebRequest -Uri $full_msi_link -OutFile $msiPath -UseBasicParsing
                
                if (Test-Path $msiPath) {
                    $fileSize = (Get-Item $msiPath).Length
                    Write-Log "Download completed: qemu-ga-$arch.msi (Size: $fileSize bytes)" "INFO"
                    
                    # Verify file is not corrupted (should be > 1MB)
                    if ($fileSize -lt 1048576) {
                        throw "Downloaded file is too small ($fileSize bytes), may be corrupted"
                    }

                    # Run the downloaded MSI installer.
                    Write-Log "Running QEMU GA MSI Installer..." "INFO"
                    $logFilePath = "$env:TEMP\qemu-ga-installation.log"
                    Write-Log "Installation log will be saved to: $logFilePath" "INFO"
                    Write-Log "MSI full path: $msiPath" "INFO"
                    
                    # Verify MSI path exists before installation
                    if (-not (Test-Path $msiPath)) {
                        throw "MSI file not found at: $msiPath"
                    }
                    
                    # Use quoted path for msiexec
                    $installArgs = @("/i", "`"$msiPath`"", "/qn", "/norestart", "/L*v", "`"$logFilePath`"")
                    Write-Log "Installation arguments: $($installArgs -join ' ')" "INFO"
                    
                    $installProcess = Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList $installArgs -PassThru -NoNewWindow
                    Write-Log "Installation process exit code: $($installProcess.ExitCode)" "INFO"
                    
                    # Log installation log content if failed
                    if ($installProcess.ExitCode -ne 0) {
                        if (Test-Path $logFilePath) {
                            Write-Log "Installation failed. Last 20 lines of installation log:" "ERROR"
                            $installLogContent = Get-Content $logFilePath -Tail 20 -ErrorAction SilentlyContinue
                            foreach ($line in $installLogContent) {
                                Write-Log "  $line" "ERROR"
                            }
                        }
                        throw "MSI installation failed with exit code: $($installProcess.ExitCode)"
                    }
                    
                    if ($installProcess.ExitCode -eq 0) {
                        Write-Log "QEMU GA installation completed successfully" "INFO"
                        
                        # Verify service is running
                        Start-Sleep -Seconds 5
                        $qemuService = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
                        if ($qemuService) {
                            Write-Log "QEMU-GA service status: $($qemuService.Status)" "INFO"
                            if ($qemuService.Status -ne 'Running') {
                                Write-Log "Starting QEMU-GA service..." "INFO"
                                Start-Service -Name "QEMU-GA"
                                Start-Sleep -Seconds 3
                                $qemuService = Get-Service -Name "QEMU-GA"
                                Write-Log "QEMU-GA service status after start: $($qemuService.Status)" "INFO"
                            }
                            $qemuInstalled = $true
                        } else {
                            Write-Log "QEMU-GA service not found after installation" "WARN"
                        }
                    } else {
                        throw "MSI installation failed with exit code: $($installProcess.ExitCode)"
                    }
                } else {
                    throw "Downloaded MSI file not found at: $msiPath"
                }
            }
            else {
                throw "No qemu-ga-$arch.msi link found"
            }
        }
        else {
            throw "No latest QEMU GA link found"
        }
    }
    catch {
        Write-Log "QEMU GA installation attempt $qemuRetries failed: $($_.Exception.Message)" "ERROR"
        if ($qemuRetries -lt $qemuMaxRetries) {
            Write-Log "Retrying in 15 seconds..." "INFO"
            Start-Sleep -Seconds 15
        } else {
            Write-Log "QEMU GA installation failed after $qemuMaxRetries attempts" "ERROR"
        }
    }
}

if ($qemuInstalled) {
    Write-Log "=== QEMU Guest Agent successfully installed and running ===" "INFO"
} else {
    Write-Log "=== CRITICAL: QEMU Guest Agent installation failed ===" "ERROR"
}

Write-Log "=== windows-init.ps1 script completed ===" "INFO"