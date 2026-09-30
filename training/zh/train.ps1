# LoRA fine-tune of Qwen3-ASR-0.6B on the Windows H100. Same cu130 stack as English. No network.
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Model = if ($env:SR_QWEN) { $env:SR_QWEN } else { Join-Path $Root "vendor\checkpoints\Qwen3-ASR-0.6B-hf" }
if (-not $env:SR_DATA) { throw "Set SR_DATA to the corpus directory on this machine." }
$Train = Join-Path $env:SR_DATA "zh\train_manifest.jsonl"
foreach ($f in @($Model, $Train)) {
    if (-not (Test-Path $f)) { throw "Missing $f" }
}
python (Join-Path $Root "training\scripts\toy_gpu_step.py")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$MaxSteps = if ($env:SR_MAX_STEPS) { $env:SR_MAX_STEPS } else { "2000" }
python (Join-Path $Root "training\zh\finetune_lora.py") `
    --model $Model `
    --train-manifest $Train `
    --max-steps $MaxSteps `
    --output (Join-Path $Root "training\zh\exp")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
