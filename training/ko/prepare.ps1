# Build Korean manifests from the project corpus, then train the SentencePiece model. No network.
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $env:SR_DATA) { throw "Set SR_DATA to the corpus directory on this machine." }
$Src = Join-Path $env:SR_DATA "ko"
python (Join-Path $Root "training\scripts\build_manifest.py") --root $Src --out $Src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $Root "training\ko\prepare_tokenizer.py") `
    --manifest (Join-Path $Src "train_manifest.jsonl") `
    --out (Join-Path $Src "tokenizer")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
