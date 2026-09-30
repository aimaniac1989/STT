# Install the Chinese LoRA environment from local Windows wheels. No network.
# Run this in a separate Python 3.12 environment from the NeMo install.
param(
    [Parameter(Mandatory = $true)]
    [string]$Bundle
)
$ErrorActionPreference = "Stop"
$Bundle = (Resolve-Path $Bundle).Path
$Wheels = Join-Path $Bundle "wheels"
if (-not (Test-Path $Wheels)) { throw "Missing $Wheels. Run vendor\fetch-online.ps1 on the online PC first." }
python -m pip install --no-index --find-links $Wheels --only-binary=:all: torch torchvision torchaudio
if ($LASTEXITCODE -ne 0) { throw "torch install failed" }
$Req = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "requirements-zh.txt"
python -m pip install --no-index --find-links $Wheels --only-binary=:all: -r $Req
if ($LASTEXITCODE -ne 0) { throw "requirements install failed" }
python -c "import torch; from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration; print('torch', torch.__version__, 'qwen3_asr', Qwen3ASRForConditionalGeneration.__name__, 'cuda', torch.cuda.is_available())"
