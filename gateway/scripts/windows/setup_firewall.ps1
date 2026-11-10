# SPDX-License-Identifier: MIT
# Allow the robot to reach the gateway: inbound TCP 8765, Private networks only.
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
    -Protocol TCP -LocalPort $Port -Profile Private | Out-Null
Write-Host "Allowed inbound TCP $Port on Private networks."
Write-Host 'If the robot cannot connect, check the PC network profile: Get-NetConnectionProfile'
