# SPDX-License-Identifier: MIT
# Collect a Windows setup report into logs\diagnose.txt (secrets are redacted).
#   powershell -ExecutionPolicy Bypass -File scripts\windows\diagnose.ps1 [-RobotIp 192.168.3.10]
param([string]$RobotIp = '')
. "$PSScriptRoot\_common.ps1"
$ErrorActionPreference = 'Continue'
Set-Location $GatewayDir
$logDir = Join-Path $GatewayDir 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$out = Join-Path $logDir 'diagnose.txt'
$script:buf = New-Object System.Collections.Generic.List[string]
function Say([string]$s) { $script:buf.Add($s); Write-Host $s }
function Redact([string]$s) {
    $s = $s -replace 'AIza[0-9A-Za-z_\-]{20,}', 'AIza***'
    $s = $s -replace '(?i)(token|api[_-]?key|secret|password)(["'':= ]+)[^\s"'',]{6,}', '$1$2***'
    return $s
}
function Section([string]$t) { Say ''; Say "=== $t ===" }

Section 'System'
Say ("date: " + (Get-Date -Format s))
Say ("os: " + [Environment]::OSVersion.VersionString + " / 64bit=" + [Environment]::Is64BitOperatingSystem)
Say ("powershell: " + $PSVersionTable.PSVersion)
Say ("git: " + ((git --version) 2>&1))
$uv = Get-Command uv -ErrorAction SilentlyContinue
Say ("uv: " + $(if ($uv) { (& $uv.Source --version) } else { 'NOT FOUND' }))
Say ("gateway dir: $GatewayDir")

Section '.env (values hidden)'
$envPath = Join-Path $GatewayDir '.env'
if (-not (Test-Path $envPath)) { Say '.env: MISSING (run init_env.ps1)' }
else {
    foreach ($k in 'GEMINI_API_KEY', 'STACKCHAN_TOKEN') {
        $v = Get-EnvValue $envPath $k
        Say ("{0}: {1}" -f $k, $(if ($v) { "set (length $($v.Length))" } else { 'EMPTY' }))
    }
    foreach ($k in 'HOST', 'WS_PORT', 'CAPTURE_PORT', 'STACKCHAN_FACE_TRACKER_AUTOSTART',
                   'STACKCHAN_HEAD_FOLLOW_DEFAULT', 'STACKCHAN_USB_DISABLE', 'STACKCHAN_WAKE_WORD',
                   'STACKCHAN_KWS_THRESHOLD', 'STACKCHAN_KWS_SCORE', 'STACKCHAN_LIBOPUS_PATH') {
        Say ("{0}: {1}" -f $k, (Get-EnvValue $envPath $k))
    }
}

Section 'Files'
$dll = Join-Path $GatewayDir 'vendor\opus.dll'
Say ("vendor\opus.dll: " + $(if (Test-Path $dll) { 'present' } else { 'MISSING (run get_opus_dll.ps1)' }))
$kws = Join-Path $GatewayDir 'models\kws'
$kwsDirs = @(); if (Test-Path $kws) { $kwsDirs = @(Get-ChildItem $kws -Directory | Select-Object -ExpandProperty Name) }
Say ("models\kws: " + $(if ($kwsDirs.Count) { $kwsDirs -join ', ' } else { 'MISSING (run get_kws_model.ps1)' }))

if ($uv) {
    Section 'Python imports and libopus (uv run)'
    $probe = @'
import sys, platform
print("python", sys.version.split()[0], platform.machine())
for m in ("websockets","aiohttp","google.genai","sounddevice","numpy","sherpa_onnx"):
    try:
        __import__(m); print("import", m, "OK")
    except Exception as e:
        print("import", m, "FAIL", type(e).__name__, e)
from stackchan_mcp import opus_codec
opus_codec._patch_find_library_for_brew()
try:
    import opuslib
    enc = opuslib.Encoder(24000, 1, opuslib.APPLICATION_AUDIO)
    print("opuslib encoder OK")
except Exception as e:
    print("opuslib FAIL", type(e).__name__, e)
try:
    import sounddevice as sd
    print("audio devices:", len(sd.query_devices()))
except Exception as e:
    print("sounddevice query FAIL", type(e).__name__, e)
'@
    $tmp = Join-Path $logDir '_probe.py'
    Set-Content -LiteralPath $tmp -Value $probe -Encoding utf8
    $r = & $uv.Source run --extra gemini-live --extra tts --extra wakeword python $tmp 2>&1
    foreach ($l in $r) { Say (Redact "$l") }
    Remove-Item $tmp -ErrorAction SilentlyContinue

    Section 'stackchan-mcp --check'
    $r = & $uv.Source run --extra gemini-live --extra tts --extra wakeword stackchan-mcp --check 2>&1
    foreach ($l in $r) { Say (Redact "$l") }
}

Section 'Network'
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*' -or $_.IPAddress -like '172.1[6-9].*' -or $_.IPAddress -like '172.2?.*' -or $_.IPAddress -like '172.3[0-1].*' }
foreach ($i in $ips) { Say ("ip: {0} ({1})" -f $i.IPAddress, $i.InterfaceAlias) }
foreach ($p in Get-NetConnectionProfile -ErrorAction SilentlyContinue) {
    Say ("profile: {0} = {1}" -f $p.InterfaceAlias, $p.NetworkCategory)
}
$rule = Get-NetFirewallRule -DisplayName 'Groki Bot gateway (robot WebSocket)' -ErrorAction SilentlyContinue
Say ("firewall rule: " + $(if ($rule) { "present, enabled=$($rule.Enabled), profile=$($rule.Profile)" } else { 'MISSING (run setup_firewall.ps1 as admin)' }))
foreach ($port in 8765, 8766) {
    $c = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
    Say ("port ${port}: " + $(if ($c) { 'LISTENING on ' + (($c | Select-Object -ExpandProperty LocalAddress -Unique) -join ',') } else { 'not listening' }))
}
if ($RobotIp) {
    Say ("ping ${RobotIp}: " + (Test-Connection -ComputerName $RobotIp -Count 2 -Quiet))
}
try {
    $st = Invoke-RestMethod -Uri 'http://127.0.0.1:8766/debug/status' -TimeoutSec 3
    Say ('debug/status: ' + (Redact ($st | ConvertTo-Json -Compress -Depth 4)))
} catch { Say ('debug/status: unreachable (' + $_.Exception.Message + ')') }

Section 'gateway.log (last 60 lines, redacted)'
$gl = Join-Path $logDir 'gateway.log'
if (Test-Path $gl) { foreach ($l in Get-Content $gl -Tail 60) { Say (Redact $l) } } else { Say 'no gateway.log yet' }

Set-Content -LiteralPath $out -Value $script:buf -Encoding utf8
Write-Host ''
Write-Host "Report saved: $out"
