# Build Chinese train_manifest.jsonl and val_manifest.jsonl. No network.
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $env:SR_DATA) { throw "Set SR_DATA to the corpus directory on this machine." }
$Src = Join-Path $env:SR_DATA "zh"
python (Join-Path $Root "training\scripts\build_manifest.py") --root $Src --out $Src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
