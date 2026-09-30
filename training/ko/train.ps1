# Train Korean FastConformer-Transducer from scratch on the project corpus. No network.
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $env:SR_DATA) { throw "Set SR_DATA to the corpus directory on this machine." }
python (Join-Path $Root "training\scripts\toy_gpu_step.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $Root "training\ko\train_from_scratch.py") `
    --train-manifest (Join-Path $env:SR_DATA "ko\train_manifest.jsonl") `
    --val-manifest (Join-Path $env:SR_DATA "ko\val_manifest.jsonl") `
    --tokenizer-dir (Join-Path $env:SR_DATA "ko\tokenizer") `
    --output (Join-Path $Root "training\ko\exp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
