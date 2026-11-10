# SPDX-License-Identifier: MIT
# Register run_gateway.ps1 in Task Scheduler (starts at logon, restarts on failure).
# Run as the normal user (no Administrator needed). Use -Remove to unregister.
param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$taskName = 'GrokiBotGateway'
if ($Remove) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host 'Task removed.'; exit 0
}
$script = Join-Path $PSScriptRoot 'run_gateway.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
    -Description 'Groki Bot gateway for the ATOMS3R robot' -Force | Out-Null
Write-Host "Registered task '$taskName' (runs at logon). Start now: Start-ScheduledTask $taskName"
