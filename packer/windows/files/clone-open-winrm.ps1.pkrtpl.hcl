# Opens WinRM on a fresh clone to the management networks, once.
#
# Until a machine joins a domain its network is "Public", where the built-in
# WinRM rule admits the local subnet only, so Ansible on another network needs
# letting in for its first connection (NTLM over HTTP is still encrypted at the
# message level).
#
# Not before setup has finished, though. Windows refuses every logon until
# then, and Server 2025 locks the Administrator account for ten minutes after
# ten refusals: a playbook that starts knocking early locks itself out. So an
# open port is the signal that the clone is ready.

$state = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState
if ($state -ne 'IMAGE_STATE_COMPLETE') { exit 0 }

if (-not (Get-NetFirewallRule -DisplayName 'WinRM bootstrap' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'WinRM bootstrap' -Direction Inbound -Protocol TCP -LocalPort 5985 `
        -Action Allow -Profile Any -RemoteAddress ${allowed_sources} | Out-Null
}
Unregister-ScheduledTask -TaskName 'clone-open-winrm' -Confirm:$false
