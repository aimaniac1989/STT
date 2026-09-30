#!/usr/bin/env bash
# Install the H100 environment from local files. No network.
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: install_offline.sh <path-to-vendor/h100>" >&2
  exit 2
fi
BUNDLE="$(cd "$1" && pwd)"
WHEELS="$BUNDLE/wheels"
LOCK="$BUNDLE/requirements-lock.txt"
if [[ ! -d "$WHEELS" ]]; then
  echo "Missing $WHEELS. Copy vendor/h100 from the Windows PC first." >&2
  exit 2
fi
if [[ ! -f "$LOCK" ]]; then
  echo "Missing $LOCK. Run vendor/fetch-online.ps1 on the Windows PC first." >&2
  exit 2
fi
python -m pip install --no-index --find-links "$WHEELS" --only-binary=:all: torch torchvision torchaudio
REQ="$(cd "$(dirname "$0")/.." && pwd)/requirements-h100.txt"
python -m pip install --no-index --find-links "$WHEELS" --only-binary=:all: -r "$REQ"
python - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.version.cuda, "available", torch.cuda.is_available())
PY
