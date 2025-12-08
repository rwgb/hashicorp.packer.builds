<#
    .DESCRIPTION
    Enables Windows Remote Management on Windows builds, downloads QEMU GA MSI installer, and runs it.
#>

# Set network connection profile to Private mode.
Write-Output 'Setting the network connection profile to Public...'
try {
    $connectionProfile = Get-NetConnectionProfile
    $timeout = 0
    While ($connectionProfile.Name -eq 'Identifying...' -and $timeout -lt 30) {
        Start-Sleep -Seconds 10
        $timeout += 10
        $connectionProfile = Get-NetConnectionProfile
    }
    Set-NetConnectionProfile -Name $connectionProfile.Name -NetworkCategory Public
} catch {
    Write-Output "Warning: Could not set network profile: $($_.Exception.Message)"
}

# Set the Windows Remote Management configuration.
Write-Output 'Setting the Windows Remote Management configuration...'
try {
    # Enable WinRM service
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service WinRM
    
    # Configure WinRM
    winrm quickconfig -quiet -force
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service/auth '@{CredSSP="true"}'
    
    # Set trusted hosts to allow all
    winrm set winrm/config/client '@{TrustedHosts="*"}'
    
    # Configure WinRM listener
    $listeners = winrm enumerate winrm/config/listener
    if ($listeners -notmatch "HTTP") {
        winrm create winrm/config/listener?Address=*+Transport=HTTP
    }
    
    # Restart WinRM to apply changes
    Restart-Service WinRM
    Start-Sleep -Seconds 5
    Write-Output 'WinRM configuration completed successfully.'
} catch {
    Write-Output "Warning: WinRM configuration issue: $($_.Exception.Message)"
}

# Allow Windows Remote Management in the Windows Firewall.
Write-Output 'Allowing Windows Remote Management in the Windows Firewall...'
try {
    netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes
    netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow
} catch {
    Write-Output "Warning: Firewall rule issue: $($_.Exception.Message)"
}

# Drop the firewall while building and re-enable as a standalone provisioner in the Packer file if needs be.
netsh Advfirewall set allprofiles state off 

# Reset the autologon count.
# Reference: https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0

# Download the appropriate QEMU GA MSI installer based on architecture.
$url = "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/"
$uri = [System.Uri]$url
$rootUrl = $uri.GetLeftPart([System.UriPartial]::Authority)

try {
    $response = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction Stop -UseBasicParsing
    $link = [regex]::Match($response.Content, 'href="([^"]*latest-qemu-ga[^"]*)"').Groups[1].Value
    if (-not [string]::IsNullOrEmpty($link)) {
        $full_url = "$url$link"
        $response = (Invoke-WebRequest -Uri $full_url -MaximumRedirection 1 -ErrorAction Stop -UseBasicParsing)
        $redirected_url = [regex]::Match($response.Content, 'href="([^"]*qemu-ga[^"]*)"').Groups[1].Value
        $download_url = "$rootUrl$redirected_url"
        $arch = if ([Environment]::Is64BitOperatingSystem) { "x86_64" } else { "i386" }
        $msi_link = (Invoke-WebRequest -Uri $download_url -ErrorAction Stop -UseBasicParsing).Content
        $htmlContent = "$msi_link"
        $regexPattern = '<a href="([^"]*qemu-ga-win-[^"]*/)">([^<]+)</a>\s+([0-9-]+\s[0-9:]+)'
        $matches = [regex]::Matches($htmlContent, $regexPattern)
        $entryList = @()

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

        # Output the sorted entries
        if ($sortedEntries.Count -gt 0) {
            $firstLink = $sortedEntries[0].Link
            $msi_link = "$download_url$firstLink"+"qemu-ga-$arch.msi"
        } else {
            Write-Output "No sorted entries found."
        }

        if (-not [string]::IsNullOrEmpty($msi_link)) {
            $full_msi_link = "$msi_link"
            Write-Output "Downloading QEMU GA MSI Installer..."
            Invoke-WebRequest -Uri $full_msi_link -OutFile "$env:TEMP/qemu-ga-$arch.msi"
            Write-Output "Download completed: qemu-ga-$arch.msi"

            # Run the downloaded MSI installer.
            Write-Output "Running QEMU GA MSI Installer..."
            $logFilePath="$env:TEMP/quemu-ga-installation.log"
            Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i", "$env:TEMP\qemu-ga-$arch.msi", "/qn", "/norestart", "/L*v", $logFilePath
            Write-Output "Installation of QEMU GA MSI completed."
        }
        else {
            Write-Output "No qemu-ga-$arch.msi link found."
        }
    }
    else {
        Write-Output "No latest QEMU GA link found."
    }
}
catch {
    Write-Output "Error: $($_.Exception.Message)"
}