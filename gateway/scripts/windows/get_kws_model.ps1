# SPDX-License-Identifier: MIT
# Download the "Hi Grok" wake word model (sherpa-onnx zipformer zh-en, ~33 MB).
. "$PSScriptRoot\_common.ps1"
$name = 'sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20'
$url  = "https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/$name.tar.bz2"
$dir  = Join-Path $GatewayDir 'models\kws'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
if (Test-Path (Join-Path $dir $name)) { Write-Host "Already present: $dir\$name"; exit 0 }

$archive = Join-Path $dir "$name.tar.bz2"
# curl.exe ships with Windows 10/11. Invoke-WebRequest is very slow in Windows
# PowerShell 5.1 because of its progress bar, so avoid it for ~33 MB downloads.
& "$env:SystemRoot\System32\curl.exe" -L --fail --retry 3 --progress-bar -o $archive $url
if ($LASTEXITCODE -ne 0) { throw 'Download failed (curl.exe).' }
& "$env:SystemRoot\System32\tar.exe" -xf $archive -C $dir
if ($LASTEXITCODE -ne 0) { throw 'tar.exe failed to extract the model.' }
Remove-Item $archive
Write-Host "Model ready: $dir\$name"
