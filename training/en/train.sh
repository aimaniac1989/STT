#!/usr/bin/env bash
# Fine-tune Parakeet TDT 0.6B v2 from a local .nemo file. No network.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CKPT="${SR_CHECKPOINT:-$ROOT/vendor/checkpoints/parakeet-tdt-0.6b-v2.nemo}"
if [[ -z "${SR_DATA:-}" ]]; then
  echo "Set SR_DATA to the directory copied onto this server." >&2
  exit 2
fi
TRAIN="$SR_DATA/en/train_manifest.jsonl"
VAL="$SR_DATA/en/val_manifest.jsonl"
for f in "$CKPT" "$TRAIN" "$VAL"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing $f" >&2
    echo "Each manifest line is JSON: {\"audio_filepath\":\"...\",\"duration\":1.2,\"text\":\"...\"}" >&2
    exit 2
  fi
done
python "$ROOT/training/scripts/toy_gpu_step.py"
python "$ROOT/training/en/finetune.py" \
  --checkpoint "$CKPT" \
  --train-manifest "$TRAIN" \
  --val-manifest "$VAL" \
  --output "$ROOT/training/en/exp"
