# Runs once on every clone of the template, as SYSTEM, during the specialize
# pass of its first boot (see clone-unattend.xml).

$ErrorActionPreference = 'Continue'
Start-Transcript -Path C:\Windows\Temp\clone-first-boot.log -Force

# Take back what the Packer build needed. These are the registry values behind
# winrm/config/service; the WinRM service is not running this early.
$svc = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WSMAN\Service'
Set-ItemProperty -Path $svc -Name allow_unencrypted -Value 0 -Type DWord
Set-ItemProperty -Path $svc -Name auth_basic -Value 0 -Type DWord
Get-NetFirewallRule -DisplayName 'packer-winrm' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Set-Service -Name WinRM -StartupType Automatic

# WinRM is opened to the management networks by clone-open-winrm.ps1, and not
# before setup has finished. Run it every minute until it has done so.
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\clone-open-winrm.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
Register-ScheduledTask -TaskName 'clone-open-winrm' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

# The clone's disk is usually bigger than the template's.
$max = (Get-PartitionSupportedSize -DriveLetter C).SizeMax
if ($max -gt (Get-Partition -DriveLetter C).Size + 1GB) { Resize-Partition -DriveLetter C -Size $max }

# The answer file sysprep was given holds the Administrator password.
Remove-Item C:\Windows\Panther\clone-unattend.xml -Force -ErrorAction SilentlyContinue

Stop-Transcript
