<?xml version="1.0" encoding="UTF-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
   <settings pass="oobeSystem">
      <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <AutoLogon>
            <Password>
               <Value>${password}</Value>
               <PlainText>true</PlainText>
            </Password>
            <Enabled>true</Enabled>
            <Username>Administrator</Username>
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
         </UserAccounts>
         <TimeZone>UTC</TimeZone>
         <RegisteredOrganization></RegisteredOrganization>
         <RegisteredOwner></RegisteredOwner>
      </component>
      <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <InputLocale>${inst_os_keyboard}</InputLocale>
         <SystemLocale>${inst_os_language}</SystemLocale>
         <UILanguage>${inst_os_language}</UILanguage>
         <UserLocale>${inst_os_language}</UserLocale>
      </component>
   </settings>
   <settings pass="specialize">
      <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
         <ComputerName>*</ComputerName>
         <TimeZone>UTC</TimeZone>
      </component>
   </settings>
</unattend>
