#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODEL="${SR_QWEN:-$ROOT/vendor/checkpoints/Qwen3-ASR-0.6B-hf}"
if [[ -z "${SR_DATA:-}" ]]; then
  echo "SR_DATA is not set." >&2
  exit 2
fi
python "$ROOT/training/scripts/toy_gpu_step.py"
python "$ROOT/training/zh/finetune_lora.py" \
  --model "$MODEL" \
  --train-manifest "$SR_DATA/zh/train_manifest.jsonl" \
  --output "$ROOT/training/zh/exp"
