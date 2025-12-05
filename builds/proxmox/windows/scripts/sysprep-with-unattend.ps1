# Create Unattend.xml and Prepare Sysprep for OOB Automation
# This script generates an unattend.xml file to automate the Out-of-Box Experience

Write-Host "Creating unattend.xml for OOB automation..."

$unattendPath = "C:\Windows\System32\Sysprep\unattend.xml"
$username = "packer"
$password = "packer"
$computerName = "*"  # Use * for random computer name generation

# Create the unattend.xml content
$unattendXml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$computerName</ComputerName>
            <TimeZone>UTC</TimeZone>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>cmd.exe /c powershell -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>cmd.exe /c powershell -ExecutionPolicy Bypass -Command "Set-Item WSMan:\localhost\Service\Auth\Basic -Value `$true"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>cmd.exe /c powershell -ExecutionPolicy Bypass -Command "Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value `$true"</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Path>cmd.exe /c powershell -ExecutionPolicy Bypass -Command "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False"</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipUserOOBE>true</SkipUserOOBE>
                <SkipMachineOOBE>true</SkipMachineOOBE>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Password>
                            <Value>$password</Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <DisplayName>$username</DisplayName>
                        <Group>Administrators</Group>
                        <Name>$username</Name>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Enabled>true</Enabled>
                <Username>$username</Username>
                <Password>
                    <Value>$password</Value>
                    <PlainText>true</PlainText>
                </Password>
                <LogonCount>999</LogonCount>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>cmd.exe /c powershell -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</CommandLine>
                    <Description>Set PowerShell Execution Policy</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
    </settings>
</unattend>
"@

try {
    # Write the unattend.xml file
    Write-Host "Writing unattend.xml to $unattendPath..."
    $unattendXml | Out-File -FilePath $unattendPath -Encoding utf8 -Force
    
    if (Test-Path $unattendPath) {
        Write-Host "unattend.xml created successfully at $unattendPath"
        
        # Verify the file is valid XML
        try {
            [xml]$testXml = Get-Content $unattendPath
            Write-Host "unattend.xml is valid XML."
        } catch {
            Write-Host "Warning: unattend.xml may not be valid XML: $_"
        }
        
        # Run Sysprep with the unattend file
        Write-Host "Running Sysprep with unattend.xml..."
        Write-Host "NOTE: The system will shut down after sysprep completes."
        
        $sysprepPath = "C:\Windows\System32\Sysprep\sysprep.exe"
        $sysprepArgs = "/generalize /oobe /shutdown /mode:vm /unattend:`"$unattendPath`""
        
        Write-Host "Executing: $sysprepPath $sysprepArgs"
        Start-Process -FilePath $sysprepPath -ArgumentList $sysprepArgs -NoNewWindow -Wait
        
    } else {
        Write-Host "Error: Failed to create unattend.xml file."
        exit 1
    }
    
} catch {
    Write-Host "Error occurred during unattend.xml creation or sysprep: $_"
    exit 1
}

Write-Host "Sysprep with unattend.xml initiated. System will shut down shortly."
