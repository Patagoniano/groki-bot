# SPDX-License-Identifier: MIT
# Create gateway\.env for the Windows setup. Never prints or logs the API key.
#   powershell -ExecutionPolicy Bypass -File scripts\windows\init_env.ps1
param([switch]$Force)
. "$PSScriptRoot\_common.ps1"

$envPath = Join-Path $GatewayDir '.env'
if ((Test-Path $envPath) -and -not $Force) {
    Write-Host ".env already exists. Use -Force to rebuild it (the old file is kept as .env.bak)."
    exit 0
}
if (Test-Path $envPath) { Copy-Item $envPath "$envPath.bak" -Force }
Copy-Item (Join-Path $GatewayDir '.env.example') $envPath -Force

# Random shared secret between the robot and this gateway (32 hex chars).
$bytes = New-Object byte[] 16
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
Set-EnvValue $envPath 'STACKCHAN_TOKEN' $token

# Windows: no Apple Vision face tracking, no USB serial takeover.
Set-EnvValue $envPath 'STACKCHAN_FACE_TRACKER_AUTOSTART' '0'
Set-EnvValue $envPath 'STACKCHAN_HEAD_FOLLOW_DEFAULT' '0'
Set-EnvValue $envPath 'STACKCHAN_USB_DISABLE' '1'

$secure = Read-Host 'Paste your Gemini API key (input is hidden; Enter to skip)' -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
if ($key) { Set-EnvValue $envPath 'GEMINI_API_KEY' $key.Trim() }
else { Write-Host 'GEMINI_API_KEY left empty. Edit .env later.' }

Write-Host ''
Write-Host "Wrote $envPath"
Write-Host "Robot 'token' setting (same value must be set on the robot):"
Write-Host "  $token"
Write-Host 'Do not paste the token or the API key into chat or commit .env.'
