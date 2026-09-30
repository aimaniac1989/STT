# Export the fine-tuned English checkpoint. pack.json is written only after the int8 check.
param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$Fp32Hyp,
    [string]$Int8Hyp
)
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Checkpoint = Join-Path $Root "training\en\exp\parakeet-en-finetuned.nemo"
$pyArgs = @(
    (Join-Path $Root "training\en\export.py"),
    "--checkpoint", $Checkpoint,
    "--out", $Out
)
if ($Fp32Hyp) { $pyArgs += @("--fp32-hyp", $Fp32Hyp) }
if ($Int8Hyp) { $pyArgs += @("--int8-hyp", $Int8Hyp) }
python @pyArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
