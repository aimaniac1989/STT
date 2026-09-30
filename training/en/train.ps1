# Fine-tune Parakeet TDT 0.6B v2 on the Windows H100. No network.
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Checkpoint = if ($env:SR_CHECKPOINT) { $env:SR_CHECKPOINT } else { Join-Path $Root "vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo" }
if (-not $env:SR_DATA) { throw "Set SR_DATA to the corpus directory on this machine." }
$Train = Join-Path $env:SR_DATA "en\train_manifest.jsonl"
$Val = Join-Path $env:SR_DATA "en\val_manifest.jsonl"
foreach ($f in @($Checkpoint, $Train, $Val)) {
    if (-not (Test-Path $f)) {
        throw "Missing $f. Each manifest line is JSON: {""audio_filepath"":""..."",""duration"":1.2,""text"":""...""}"
    }
}
python (Join-Path $Root "training\scripts\toy_gpu_step.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$MaxSteps = if ($env:SR_MAX_STEPS) { $env:SR_MAX_STEPS } else { "10000" }
python (Join-Path $Root "training\en\finetune.py") `
    --checkpoint $Checkpoint `
    --train-manifest $Train `
    --val-manifest $Val `
    --max-steps $MaxSteps `
    --output (Join-Path $Root "training\en\exp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
