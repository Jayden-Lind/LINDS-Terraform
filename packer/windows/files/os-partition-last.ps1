# Setup adds a recovery partition straight after C:, whatever the answer file
# asks for. A partition can only grow into free space that follows it, so with
# that layout C: could never be extended: a clone given a bigger disk than the
# template's kept a 59 GB C: with the rest of the disk unallocated behind the
# recovery partition.
#
# Move the recovery environment onto C: and delete the partition, so that C:
# is the last thing on the disk in the template and in every clone.

$ErrorActionPreference = 'Stop'

$os = Get-Partition -DriveLetter C
$after = @(Get-Partition -DiskNumber $os.DiskNumber | Where-Object { $_.Offset -gt $os.Offset })

if ($after) {
    if ($after | Where-Object { $_.Type -ne 'Recovery' }) {
        throw "Unexpected partition after C: ($(($after | ForEach-Object Type) -join ', ')); not touching the disk."
    }

    # Puts winre.wim back under C:\Windows\System32\Recovery.
    & reagentc.exe /disable | Write-Output
    if ($LASTEXITCODE -ne 0) { throw "reagentc /disable failed ($LASTEXITCODE)" }

    $after | Remove-Partition -Confirm:$false
    Resize-Partition -DriveLetter C -Size (Get-PartitionSupportedSize -DriveLetter C).SizeMax

    # With no recovery partition to use, this sets it up in C:\Recovery. A
    # server without it still boots and still repairs from the ISO, so a
    # failure here is reported and not fatal.
    & reagentc.exe /enable | Write-Output
    if ($LASTEXITCODE -ne 0) { Write-Warning "reagentc /enable failed ($LASTEXITCODE); the template has no recovery environment." }
}

$os = Get-Partition -DriveLetter C
if (Get-Partition -DiskNumber $os.DiskNumber | Where-Object { $_.Offset -gt $os.Offset }) {
    throw 'C: is still not the last partition on the disk.'
}
Write-Output ("C: is the last partition, {0:N1} GB. {1}" -f ($os.Size / 1GB), ((& reagentc.exe /info | Select-String 'status|location') -join ' | '))
