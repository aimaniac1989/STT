# Transcribe with the English Parakeet model. NeMo environment. No network.
param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Audio
)
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Checkpoint = if ($env:SR_CHECKPOINT) { $env:SR_CHECKPOINT } else { Join-Path $Root "training\en\exp\parakeet-en-finetuned.nemo" }
if (-not (Test-Path $Checkpoint)) {
    $Checkpoint = Join-Path $Root "vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo"
}
python (Join-Path $PSScriptRoot "transcribe.py") --checkpoint $Checkpoint @Audio
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
