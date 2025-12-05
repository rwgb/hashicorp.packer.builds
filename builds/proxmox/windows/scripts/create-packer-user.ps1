# Create Packer Administrative User and Configure Auto-Logon
# This script creates a local administrator account and configures automatic logon

Write-Host "Creating Packer administrative user..."

$username = "packer"
$password = "packer"
$fullName = "Packer Build User"
$description = "Administrator account for Packer builds"

try {
    # Create the user account
    Write-Host "Creating user account: $username"
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    
    # Check if user already exists
    $existingUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "User $username already exists. Updating password..."
        Set-LocalUser -Name $username -Password $securePassword
    } else {
        New-LocalUser -Name $username -Password $securePassword -FullName $fullName -Description $description -PasswordNeverExpires -UserMayNotChangePassword
        Write-Host "User $username created successfully."
    }
    
    # Add user to Administrators group
    Write-Host "Adding $username to Administrators group..."
    Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue
    Write-Host "User added to Administrators group."
    
    # Configure automatic logon
    Write-Host "Configuring automatic logon for $username..."
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    
    Set-ItemProperty -Path $registryPath -Name "AutoAdminLogon" -Value "1" -Type String
    Set-ItemProperty -Path $registryPath -Name "DefaultUsername" -Value $username -Type String
    Set-ItemProperty -Path $registryPath -Name "DefaultPassword" -Value $password -Type String
    Set-ItemProperty -Path $registryPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type String
    
    # Disable legal notice (can interfere with auto-logon)
    Set-ItemProperty -Path $registryPath -Name "LegalNoticeCaption" -Value "" -Type String -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $registryPath -Name "LegalNoticeText" -Value "" -Type String -ErrorAction SilentlyContinue
    
    Write-Host "Automatic logon configured successfully."
    
    # Set user account control to minimum (for build automation)
    Write-Host "Configuring User Account Control settings..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0 -Type DWord
    Write-Host "UAC settings configured."
    
    Write-Host "Packer user setup completed successfully."
    Write-Host "Username: $username"
    Write-Host "Password: $password"
    Write-Host "Auto-logon: Enabled"
    
} catch {
    Write-Host "Error occurred during user setup: $_"
    exit 1
}

Write-Host "User configuration completed."
