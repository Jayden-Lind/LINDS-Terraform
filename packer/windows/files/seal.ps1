# Last step of the Packer build: generalise the installation with sysprep.
#
# The files a clone needs on its first boot (clone-unattend.xml,
# clone-first-boot.ps1, clone-open-winrm.ps1) have already been uploaded by the
# file provisioners in windows-server.pkr.hcl.

$ErrorActionPreference = 'Stop'

foreach ($f in 'C:\Windows\Panther\clone-unattend.xml',
               'C:\Windows\Setup\Scripts\clone-first-boot.ps1',
               'C:\Windows\Setup\Scripts\clone-open-winrm.ps1') {
    if (-not (Test-Path $f)) { throw "$f is missing; refusing to seal a template whose clones could not be reached." }
}

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
