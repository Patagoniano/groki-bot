# SPDX-License-Identifier: MIT
# Copy a 64-bit opus.dll into gateway\vendor\ (found via opus_codec.py).
# Source: the Windows wheel of the PyPI package "PyOgg", which bundles opus.dll.
# Opus ships no official Windows binaries; review the DLL source before use,
# or point STACKCHAN_LIBOPUS_PATH at a build you trust instead.
. "$PSScriptRoot\_common.ps1"
$uv = Get-UvPath
$vendor = Join-Path $GatewayDir 'vendor'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
$dest = Join-Path $vendor 'opus.dll'
if (Test-Path $dest) { Write-Host "Already present: $dest"; exit 0 }

$code = "import importlib.util,sys; s=importlib.util.find_spec('pyogg'); print(s.submodule_search_locations[0])"
$pkgDir = & $uv run --no-project --with pyogg python -I -c $code
if ($LASTEXITCODE -ne 0 -or -not $pkgDir) { throw 'Could not install/locate pyogg via uv.' }
$src = Join-Path $pkgDir.Trim() 'opus.dll'
if (-not (Test-Path $src)) { throw "opus.dll not found in $pkgDir" }
Copy-Item $src $dest
Write-Host "Copied: $dest"
