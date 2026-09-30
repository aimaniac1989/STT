# Install the H100 environment from local Windows wheels. No network.
param(
    [Parameter(Mandatory = $true)]
    [string]$Bundle
)
$ErrorActionPreference = "Stop"
$Bundle = (Resolve-Path $Bundle).Path
$Wheels = Join-Path $Bundle "wheels"
$Lock = Join-Path $Bundle "requirements-lock.txt"
if (-not (Test-Path $Wheels)) { throw "Missing $Wheels. Run vendor\fetch-online.ps1 on the online PC first." }
if (-not (Test-Path $Lock)) { throw "Missing $Lock. Run vendor\fetch-online.ps1 on the online PC first." }
python -m pip install --no-index --find-links $Wheels --only-binary=:all: torch torchvision torchaudio
if ($LASTEXITCODE -ne 0) { throw "torch install failed" }
$Req = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "requirements-h100.txt"
python -m pip install --no-index --find-links $Wheels --only-binary=:all: -r $Req
if ($LASTEXITCODE -ne 0) { throw "requirements install failed" }
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'available', torch.cuda.is_available())"
