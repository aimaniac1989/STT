# Transcribe with the Korean FastConformer trained from scratch. NeMo environment. No network.
param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Audio
)
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Checkpoint = if ($env:SR_CHECKPOINT) { $env:SR_CHECKPOINT } else { Join-Path $Root "training\ko\exp\fastconformer-ko.nemo" }
if (-not (Test-Path $Checkpoint)) {
    throw "Missing $Checkpoint. Train with training\ko\train.ps1 or set SR_CHECKPOINT."
}
python (Join-Path $PSScriptRoot "transcribe.py") --checkpoint $Checkpoint @Audio
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
