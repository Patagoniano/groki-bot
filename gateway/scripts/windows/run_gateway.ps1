# SPDX-License-Identifier: MIT
# Run the gateway as a long-lived process on Windows.
# Runs with --no-stdio: no stdio MCP server, so stdin is not read. (Reading a
# stdin pipe on Windows deadlocked native-module loading on robot connect.)
# Output goes to logs\gateway.log. Stop with Ctrl+C (then Y), or:
#   taskkill /T /F /PID <cmd pid shown at start>
. "$PSScriptRoot\_common.ps1"
$uv = Get-UvPath
Set-Location $GatewayDir

$logDir = Join-Path $GatewayDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'gateway.log'
if ((Test-Path $log) -and (Get-Item $log).Length -gt 10MB) {
    Move-Item $log "$log.1" -Force
}

$inner = '"{0}" run --extra gemini-live --extra tts --extra wakeword python -m stackchan_mcp --no-stdio < NUL >> "{1}" 2>&1' -f $uv, $log
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "$env:SystemRoot\System32\cmd.exe"
$psi.Arguments = '/d /c "' + $inner + '"'
$psi.WorkingDirectory = $GatewayDir
$psi.UseShellExecute = $false
# Share this console so Ctrl+C reaches cmd/uv/python (answer Y if cmd asks).
$psi.CreateNoWindow = $false

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
