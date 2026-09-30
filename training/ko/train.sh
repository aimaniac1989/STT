#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -z "${SR_DATA:-}" ]]; then
  echo "SR_DATA is not set." >&2
  exit 2
fi
python "$ROOT/training/scripts/toy_gpu_step.py"
python "$ROOT/training/ko/train_from_scratch.py" \
  --train-manifest "$SR_DATA/ko/train_manifest.jsonl" \
  --val-manifest "$SR_DATA/ko/val_manifest.jsonl" \
  --tokenizer-dir "$SR_DATA/ko/tokenizer" \
  --output "$ROOT/training/ko/exp"
