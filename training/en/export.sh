#!/usr/bin/env bash
# Export an English pack. pack.json is written only after the int8 check.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-}"
if [[ -z "$OUT" ]]; then
  echo "Usage: export.sh <output-directory> [fp32-hyp] [int8-hyp]" >&2
  exit 2
fi
python "$ROOT/training/en/export.py" \
  --checkpoint "$ROOT/training/en/exp/parakeet-en-finetuned.nemo" \
  --out "$OUT" \
  ${2:+--fp32-hyp "$2"} \
  ${3:+--int8-hyp "$3"}
