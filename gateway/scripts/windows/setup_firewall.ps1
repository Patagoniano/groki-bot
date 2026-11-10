# SPDX-License-Identifier: MIT
# Allow the robot to reach the gateway: inbound TCP 8765, Private networks, local subnet only.
# Run from an elevated (Administrator) PowerShell. Port 8766 stays closed.
param([int]$Port = 8765, [switch]$Remove)
$ErrorActionPreference = 'Stop'
$ruleName = 'Groki Bot gateway (robot WebSocket)'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this script in an Administrator PowerShell.' }

Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if ($Remove) { Write-Host 'Rule removed.'; exit 0 }
New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort $Port -Profile Private -RemoteAddress LocalSubnet | Out-Null
Write-Host "Allowed inbound TCP $Port from the local subnet on Private networks."
$pub = @(Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' -and $_.IPv4Connectivity -ne 'Disconnected' })
foreach ($p in $pub) {
    Write-Warning ("Network '{0}' is Public, so this rule does not apply to it. If it is your home LAN, set it to Private:" -f $p.InterfaceAlias)
    Write-Warning "  Settings > Network & internet > (Ethernet or Wi-Fi) > Network profile type > Private"
}
