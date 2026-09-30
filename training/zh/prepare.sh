#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -z "${SR_DATA:-}" ]]; then
  echo "SR_DATA is not set." >&2
  exit 2
fi
python "$ROOT/training/scripts/build_manifest.py" --root "$SR_DATA/zh" --out "$SR_DATA/zh"
