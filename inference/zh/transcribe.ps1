# Transcribe with Qwen3-ASR. Uses the LoRA adapter when training\zh\exp has one. Chinese environment. No network.
param(
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Audio
)
$ErrorActionPreference = "Stop"
$env:HF_HUB_OFFLINE = "1"
$env:TRANSFORMERS_OFFLINE = "1"
$env:HF_DATASETS_OFFLINE = "1"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Model = if ($env:SR_QWEN) { $env:SR_QWEN } else { Join-Path $Root "vendor\checkpoints\Qwen3-ASR-0.6B-hf" }
$Adapter = if ($env:SR_ADAPTER) { $env:SR_ADAPTER } else { Join-Path $Root "training\zh\exp" }
$PyArgs = @(
    (Join-Path $PSScriptRoot "transcribe.py"),
    "--model", $Model
)
if (Test-Path (Join-Path $Adapter "adapter_config.json")) {
    $PyArgs += @("--adapter", $Adapter)
}
python @PyArgs @Audio
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
