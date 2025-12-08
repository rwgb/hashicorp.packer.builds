<?xml version="1.0" encoding="UTF-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
   <settings pass="windowsPE">
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <SetupUILanguage>
            <UILanguage>${inst_os_language}</UILanguage>
         </SetupUILanguage>
         <InputLocale>${inst_os_keyboard}</InputLocale>
         <SystemLocale>${inst_os_language}</SystemLocale>
         <UILanguage>${inst_os_language}</UILanguage>
         <UILanguageFallback>${inst_os_language}</UILanguageFallback>
         <UserLocale>${inst_os_language}</UserLocale>
      </component>
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-PnpCustomizationsWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <DriverPaths>
            <PathAndCredentials wcm:action="add" wcm:keyValue="1">
               <Path>D:\drivers</Path>
            </PathAndCredentials>
         </DriverPaths>
      </component>
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <!-- Bypass Windows 11 TPM/SecureBoot/RAM checks during setup -->
         <RunSynchronous>
            <RunSynchronousCommand wcm:action="add">
               <Order>1</Order>
               <Path>cmd /c reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
            </RunSynchronousCommand>
            <RunSynchronousCommand wcm:action="add">
               <Order>2</Order>
               <Path>cmd /c reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
            </RunSynchronousCommand>
            <RunSynchronousCommand wcm:action="add">
               <Order>3</Order>
               <Path>cmd /c reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
            </RunSynchronousCommand>
            <RunSynchronousCommand wcm:action="add">
               <Order>4</Order>
               <Path>cmd /c reg add HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
            </RunSynchronousCommand>
            <RunSynchronousCommand wcm:action="add">
               <Order>5</Order>
               <Path>cmd /c reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
            </RunSynchronousCommand>
         </RunSynchronous>
%{ if is_efi == true ~}         
         <DiskConfiguration>
            <Disk wcm:action="add">
               <DiskID>0</DiskID>
               <WillWipeDisk>true</WillWipeDisk>
               <CreatePartitions>
                  <!-- Windows RE Tools partition -->
                  <CreatePartition wcm:action="add">
                     <Order>1</Order>
                     <Type>Primary</Type>
                     <Size>300</Size>
                  </CreatePartition>
                  <!-- System partition (ESP) -->
                  <CreatePartition wcm:action="add">
                     <Order>2</Order>
                     <Type>EFI</Type>
                     <Size>100</Size>
                  </CreatePartition>
                  <!-- Microsoft reserved partition (MSR) -->
                  <CreatePartition wcm:action="add">
                     <Order>3</Order>
                     <Type>MSR</Type>
                     <Size>128</Size>
                  </CreatePartition>
                  <!-- Windows partition -->
                  <CreatePartition wcm:action="add">
                     <Order>4</Order>
                     <Type>Primary</Type>
                     <Extend>true</Extend>
                  </CreatePartition>
               </CreatePartitions>
               <ModifyPartitions>
                  <!-- Windows RE Tools partition -->
                  <ModifyPartition wcm:action="add">
                     <Order>1</Order>
                     <PartitionID>1</PartitionID>
                     <Label>WINRE</Label>
                     <Format>NTFS</Format>
                     <TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>
                  </ModifyPartition>
                  <!-- System partition (ESP) -->
                  <ModifyPartition wcm:action="add">
                     <Order>2</Order>
                     <PartitionID>2</PartitionID>
                     <Label>System</Label>
                     <Format>FAT32</Format>
                  </ModifyPartition>
                  <!-- MSR partition does not need to be modified -->
                  <ModifyPartition wcm:action="add">
                     <Order>3</Order>
                     <PartitionID>3</PartitionID>
                  </ModifyPartition>
                  <!-- Windows partition -->
                  <ModifyPartition wcm:action="add">
                     <Order>4</Order>
                     <PartitionID>4</PartitionID>
                     <Label>OS</Label>
                     <Letter>C</Letter>
                     <Format>NTFS</Format>
                  </ModifyPartition>
               </ModifyPartitions>
            </Disk>
         </DiskConfiguration>
%{ else ~}
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Size>500</Size>
                            <Type>Primary</Type>
                        </CreatePartition>
                        <CreatePartition wcm:action="add">
                            <Extend>true</Extend>
                            <Order>2</Order>
                            <Type>Primary</Type>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Letter>C</Letter>
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                        </ModifyPartition>
                        <ModifyPartition wcm:action="add">
                            <Active>true</Active>
                            <Format>NTFS</Format>
                            <Label>System</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
%{ endif ~}         
         <ImageInstall>
            <OSImage>
               <InstallFrom>
                  <MetaData wcm:action="add">
                     <Key>/IMAGE/NAME</Key>
                     <Value>${inst_os_image}</Value>
                  </MetaData>
               </InstallFrom>
%{ if is_efi == true ~}               
               <InstallTo>
                  <DiskID>0</DiskID>
                  <PartitionID>4</PartitionID>
               </InstallTo>
%{ else ~}
               <InstallTo>
                  <DiskID>0</DiskID>
                  <PartitionID>2</PartitionID>
               </InstallTo>                
%{ endif ~}
            </OSImage>
         </ImageInstall>
         <UserData>
            <AcceptEula>true</AcceptEula>
            <FullName>${username}</FullName>
            <Organization>${username}</Organization>
            <ProductKey>
               <!-- <Key>${kms_key}</Key> -->
               <WillShowUI>OnError</WillShowUI>
            </ProductKey>
         </UserData>
         <EnableFirewall>false</EnableFirewall>
      </component>
   </settings>
   <settings pass="offlineServicing">
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <EnableLUA>false</EnableLUA>
      </component>
   </settings>
   <settings pass="generalize">
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Security-SPP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <SkipRearm>1</SkipRearm>
      </component>
   </settings>
   <settings pass="specialize">
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <OEMInformation>
            <HelpCustomized>false</HelpCustomized>
         </OEMInformation>
         <TimeZone>${guest_os_timezone}</TimeZone>
         <RegisteredOwner />
      </component>
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <SkipAutoActivation>true</SkipAutoActivation>
      </component>
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <RunSynchronous>
            <RunSynchronousCommand wcm:action="add">
               <Order>1</Order>
               <Description>Disable First Logon Animation</Description>
               <Path>reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f</Path>
            </RunSynchronousCommand>
         </RunSynchronous>
      </component>
   </settings>
   <settings pass="oobeSystem">
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <AutoLogon>
            <Password>
               <Value>${password}</Value>
               <PlainText>true</PlainText>
            </Password>
            <Enabled>true</Enabled>
            <Username>${username}</Username>
         </AutoLogon>
         <OOBE>
            <HideEULAPage>true</HideEULAPage>
            <HideLocalAccountScreen>true</HideLocalAccountScreen>
            <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
            <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
            <NetworkLocation>Work</NetworkLocation>
            <ProtectYourPC>3</ProtectYourPC>
            <SkipUserOOBE>true</SkipUserOOBE>
            <SkipMachineOOBE>true</SkipMachineOOBE>
         </OOBE>
         <UserAccounts>
            <AdministratorPassword>
               <Value>${password}</Value>
               <PlainText>true</PlainText>
            </AdministratorPassword>
            <LocalAccounts>
               <LocalAccount wcm:action="add">
                  <Password>
                     <Value>${password}</Value>
                     <PlainText>true</PlainText>
                  </Password>
                  <Group>administrators</Group>
                  <DisplayName>${username}</DisplayName>
                  <Name>${username}</Name>
                  <Description>Build Account</Description>
               </LocalAccount>
            </LocalAccounts>
         </UserAccounts>
         <FirstLogonCommands>
            <SynchronousCommand wcm:action="add">
               <CommandLine>%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</CommandLine>
               <Description>Set Execution Policy 64-Bit</Description>
               <Order>1</Order>
               <RequiresUserInput>true</RequiresUserInput>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
               <CommandLine>%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force"</CommandLine>
               <Description>Set Execution Policy 32-Bit</Description>
               <Order>2</Order>
               <RequiresUserInput>true</RequiresUserInput>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
               <CommandLine>%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -File E:\scripts\windows-init.ps1</CommandLine>
               <Order>4</Order>
               <Description>Initial Configuration</Description>
            </SynchronousCommand>
            <SynchronousCommand wcm:action="add">
               <CommandLine>%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -File E:\scripts\windows-prepare.ps1</CommandLine>
               <Order>5</Order>
               <Description>Initial Configuration</Description>
            </SynchronousCommand>            
         </FirstLogonCommands>
      </component>
      <component xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <InputLocale>${guest_os_keyboard}</InputLocale>
         <SystemLocale>${guest_os_language}</SystemLocale>
         <UILanguage>${guest_os_language}</UILanguage>
         <UserLocale>${guest_os_language}</UserLocale>
      </component>
   </settings>
</unattend>
