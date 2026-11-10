# SPDX-License-Identifier: MIT
# Run the gateway as a long-lived process on Windows.
# The gateway is a stdio MCP server and exits when stdin reaches EOF, so the
# child gets a redirected stdin pipe that is never written to or closed.
# Output goes to logs\gateway.log. Stop with Ctrl+C or by ending this script.
. "$PSScriptRoot\_common.ps1"
$uv = Get-UvPath
Set-Location $GatewayDir

$logDir = Join-Path $GatewayDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'gateway.log'
if ((Test-Path $log) -and (Get-Item $log).Length -gt 10MB) {
    Move-Item $log "$log.1" -Force
}

$inner = '"{0}" run --extra gemini-live --extra tts --extra wakeword python -m stackchan_mcp >> "{1}" 2>&1' -f $uv, $log
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "$env:SystemRoot\System32\cmd.exe"
$psi.Arguments = '/d /c "' + $inner + '"'
$psi.WorkingDirectory = $GatewayDir
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.RedirectStandardInput = $true

$proc = [System.Diagnostics.Process]::Start($psi)
"[{0}] gateway started (cmd pid {1}), log: {2}" -f (Get-Date -Format s), $proc.Id, $log | Write-Host
try {
    $proc.WaitForExit()
    exit $proc.ExitCode
}
finally {
    if (-not $proc.HasExited) {
        & "$env:SystemRoot\System32\taskkill.exe" /T /F /PID $proc.Id | Out-Null
    }
}
