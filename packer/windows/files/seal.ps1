# Last step of the Packer build: prepare what a clone does on its first boot,
# then generalise the installation with sysprep.
#
# Inputs (environment): CLONE_ADMIN_PASSWORD, CLONE_TIME_ZONE,
# WINRM_ALLOWED_SOURCES.

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path C:\Windows\Setup\Scripts -Force | Out-Null

# --- what every clone runs once, as SYSTEM, during its specialize pass --------
@"
`$ErrorActionPreference = 'Continue'
Start-Transcript -Path C:\Windows\Temp\clone-first-boot.log -Force

# Take back what the Packer build needed. These are the registry values behind
# winrm/config/service; the WinRM service is not running this early.
`$svc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service'
Set-ItemProperty -Path `$svc -Name allow_unencrypted -Value 0 -Type DWord
Set-ItemProperty -Path `$svc -Name auth_basic -Value 0 -Type DWord
Get-NetFirewallRule -DisplayName 'packer-winrm' -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Until the machine joins a domain its network is "Public", where the built-in
# WinRM rule admits the local subnet only. Let the management networks in so
# Ansible can make its first connection. NTLM over HTTP is still encrypted at
# the message level.
New-NetFirewallRule -DisplayName 'WinRM bootstrap' -Direction Inbound -Protocol TCP -LocalPort 5985 ``
    -Action Allow -Profile Any -RemoteAddress ('$($env:WINRM_ALLOWED_SOURCES)' -split ',') | Out-Null
Set-Service -Name WinRM -StartupType Automatic

# The clone's disk is usually bigger than the template's.
`$max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
if (`$max -gt (Get-Partition -DriveLetter C).Size + 1GB) { Resize-Partition -DriveLetter C -Size `$max }

# The answer file sysprep was given holds the Administrator password.
Remove-Item C:\Windows\Panther\clone-unattend.xml -Force -ErrorAction SilentlyContinue
Stop-Transcript
"@ | Set-Content -Path C:\Windows\Setup\Scripts\clone-first-boot.ps1 -Encoding UTF8

# --- the answer file for a clone's first boot --------------------------------
@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="generalize">
    <component name="Microsoft-Windows-PnpSysprep" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <TimeZone>$($env:CLONE_TIME_ZONE)</TimeZone>
    </component>
    <component name="Microsoft-Windows-ServerManager-SvrMgrNc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DoNotOpenServerManagerAtLogon>true</DoNotOpenServerManagerAtLogon>
    </component>
    <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Close the build's WinRM settings, open WinRM to the management networks, grow C:</Description>
          <Path>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\clone-first-boot.ps1</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-AU</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>true</HideLocalAccountScreen>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <AdministratorPassword>
          <Value>$($env:CLONE_ADMIN_PASSWORD)</Value>
          <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
    </component>
  </settings>
</unattend>
"@ | Set-Content -Path C:\Windows\Panther\clone-unattend.xml -Encoding UTF8

# --- generalise ---------------------------------------------------------------
# /quit rather than /shutdown: Packer stops the VM itself once this script
# returns, and it must not do that while sysprep is still working.
$sysprep = Start-Process -FilePath C:\Windows\System32\Sysprep\sysprep.exe `
    -ArgumentList '/generalize', '/oobe', '/quit', '/unattend:C:\Windows\Panther\clone-unattend.xml' -Wait -PassThru

$state = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState
if ($state -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
    Get-Content C:\Windows\System32\Sysprep\Panther\setuperr.log -Tail 20 -ErrorAction SilentlyContinue
    throw "sysprep exited with $($sysprep.ExitCode) and left the image in state '$state'"
}
Write-Output "generalised: $state"
