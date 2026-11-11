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

$extras = '--extra gemini-live --extra tts --extra wakeword'

function Start-Child([string]$Command, [string]$LogPath) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$env:SystemRoot\System32\cmd.exe"
    $psi.Arguments = '/d /c "' + $Command + ' < NUL >> "' + $LogPath + '" 2>&1"'
    $psi.WorkingDirectory = $GatewayDir
    $psi.UseShellExecute = $false
    # Logs and gbot replies contain Japanese; avoid cp932 encode errors.
    $psi.EnvironmentVariables['PYTHONUTF8'] = '1'
    $psi.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    # Share this console so Ctrl+C reaches cmd/uv/python (answer Y if cmd asks).
    $psi.CreateNoWindow = $false
    return [System.Diagnostics.Process]::Start($psi)
}

# Grok Bot hand-off: start the loopback forwarding service (port 18770) too
# when .env names a target bot. Same uv extras as the gateway so the two
# uv runs never re-sync the shared .venv against each other.
$proxy = $null
$toolBot = Get-EnvValue (Join-Path $GatewayDir '.env') 'STACKCHAN_TOOL_BOT'
if ($toolBot) {
    $proxyLog = Join-Path $logDir 'gbot-proxy.log'
    $proxy = Start-Child ('"{0}" run {1} stackchan-gbot-proxy' -f $uv, $extras) $proxyLog
    "[{0}] gbot forwarding service started (cmd pid {1}), log: {2}" -f (Get-Date -Format s), $proxy.Id, $proxyLog | Write-Host
    Start-Sleep -Seconds 2
}

$proc = Start-Child ('"{0}" run {1} python -m stackchan_mcp --no-stdio' -f $uv, $extras) $log
"[{0}] gateway started (cmd pid {1}), log: {2}" -f (Get-Date -Format s), $proc.Id, $log | Write-Host
try {
    $proc.WaitForExit()
    exit $proc.ExitCode
}
finally {
    foreach ($p in @($proc, $proxy)) {
        if ($p -and -not $p.HasExited) {
            & "$env:SystemRoot\System32\taskkill.exe" /T /F /PID $p.Id | Out-Null
        }
    }
}
