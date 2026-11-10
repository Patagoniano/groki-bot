# SPDX-License-Identifier: MIT
# Shared helpers for the Windows scripts. Dot-source: . "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Stop'
$GatewayDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Get-UvPath {
    $cmd = Get-Command uv -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { throw 'uv not found. Install: winget install --id astral-sh.uv' }
    return $cmd.Source
}

# Set KEY=value in a dotenv file: replace an existing (or commented) line, else append.
function Set-EnvValue {
    param([string]$Path, [string]$Key, [string]$Value)
    $lines = @()
    if (Test-Path $Path) { $lines = @(Get-Content -LiteralPath $Path) }
    $pattern = '^\s*#?\s*' + [regex]::Escape($Key) + '='
    $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $done -and $lines[$i] -match $pattern) {
            $lines[$i] = "$Key=$Value"; $done = $true
        }
    }
    if (-not $done) { $lines += "$Key=$Value" }
    Set-Content -LiteralPath $Path -Value $lines -Encoding utf8
}

function Get-EnvValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path $Path)) { return $null }
    foreach ($l in Get-Content -LiteralPath $Path) {
        if ($l -match ('^\s*' + [regex]::Escape($Key) + '=(.*)$')) { return $Matches[1].Trim() }
    }
    return $null
}
