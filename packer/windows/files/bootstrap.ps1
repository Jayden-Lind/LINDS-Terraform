# First logon of the Packer build VM. Runs once, as Administrator, from the
# answer-file CD.
#
# Order matters: the guest agent goes in before WinRM is opened, because Packer
# learns the VM's address from the agent and starts provisioning the moment
# WinRM answers.

$ErrorActionPreference = 'Stop'
Start-Transcript -Path C:\Windows\Temp\packer-bootstrap.log -Force

# An unidentified network is "Public", and the built-in WinRM rule for Public
# only admits the local subnet. Packer is on another one.
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# virtio drivers, balloon service and the QEMU guest agent, from the driver CD.
$tools = Get-Volume | Where-Object DriveType -eq 'CD-ROM' |
    ForEach-Object { "$($_.DriveLetter):\virtio-win-guest-tools.exe" } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $tools) { throw 'virtio-win-guest-tools.exe was not found on any CD drive' }
$p = Start-Process -FilePath $tools -ArgumentList '/install', '/passive', '/norestart' -Wait -PassThru
if ($p.ExitCode -notin 0, 3010) { throw "virtio guest tools exited with $($p.ExitCode)" }

# The driver install can bounce the network adapter.
Start-Sleep -Seconds 15
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# WinRM over HTTP with Basic authentication: for the build only.
# clone-first-boot.ps1 switches both back off on every clone's first boot.
Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
New-NetFirewallRule -DisplayName 'packer-winrm' -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -Profile Any | Out-Null

Stop-Transcript
