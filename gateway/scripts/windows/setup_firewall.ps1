# SPDX-License-Identifier: MIT
# Allow the robot to reach the gateway: inbound TCP 8765, Private networks, local subnet only.
# Run from an elevated (Administrator) PowerShell. Port 8766 stays closed.
# Uses netsh because the NetSecurity cmdlets (New-NetFirewallRule) hung on some PCs.
param([int]$Port = 8765, [switch]$Remove)
$ErrorActionPreference = 'Stop'
$ruleName = 'Groki Bot gateway (robot WebSocket)'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this script in an Administrator PowerShell.' }

$netsh = "$env:SystemRoot\System32\netsh.exe"
& $netsh advfirewall firewall delete rule name="$ruleName" | Out-Null
if ($Remove) { Write-Host 'Rule removed.'; exit 0 }
& $netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP `
    localport=$Port profile=private remoteip=localsubnet
if ($LASTEXITCODE -ne 0) { throw 'netsh failed to add the rule.' }
Write-Host "Allowed inbound TCP $Port from the local subnet on Private networks."
Write-Host 'If your LAN is set to Public, switch it to Private:'
Write-Host '  Settings > Network & internet > Ethernet/Wi-Fi > Network profile type > Private'
