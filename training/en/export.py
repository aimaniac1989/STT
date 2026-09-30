"""Export a fine-tuned Parakeet checkpoint to an English pack. No network.

pack.json is written only after int8 hypotheses stay within 0.3 CER points of fp32
on at least 50 utterances.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def cer(reference: str, hypothesis: str) -> float:
    ref = list(reference)
    hyp = list(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    prev = list(range(len(hyp) + 1))
    for i, left in enumerate(ref, start=1):
        cur = [i]
        for j, right in enumerate(hyp, start=1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (left != right)))
        prev = cur
    return prev[-1] / len(ref)


def mean_cer(path_a: Path, path_b: Path) -> tuple[float, int]:
    left = [line.rstrip("\n") for line in path_a.read_text(encoding="utf-8").splitlines() if line.strip()]
    right = [line.rstrip("\n") for line in path_b.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(left) < 50 or len(right) < 50:
        raise ValueError("the int8 check needs at least 50 utterances in each hypothesis file")
    count = min(len(left), len(right))
    return sum(cer(a, b) for a, b in zip(left, right)) / count, count


def file_record(path: Path) -> dict:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {"name": path.name, "sha256": digest, "size_bytes": path.stat().st_size}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--fp32-hyp", type=Path)
    parser.add_argument("--int8-hyp", type=Path)
    args = parser.parse_args()
    if not args.checkpoint.is_file():
        print(f"Missing {args.checkpoint}", file=sys.stderr)
        return 2

    import torch
    from nemo.collections.asr.models import ASRModel

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    args.out.mkdir(parents=True, exist_ok=True)
    model = ASRModel.restore_from(str(args.checkpoint))
    model.export(str(args.out / "model.onnx"))
    onnx_files = sorted(args.out.glob("*.onnx"))
    if not onnx_files:
        print("NeMo export did not write an ONNX file.", file=sys.stderr)
        return 2

    if args.fp32_hyp is None or args.int8_hyp is None:
        print("ONNX written. pack.json is withheld until --fp32-hyp and --int8-hyp are passed.", file=sys.stderr)
        return 2
    try:
        score, count = mean_cer(args.fp32_hyp, args.int8_hyp)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    if score > 0.003:
        print(f"int8 mean CER vs fp32 is {score:.4f} on {count} lines. Limit is 0.003.", file=sys.stderr)
        return 2

    pack = {
        "language": "en",
        "model_type": "nemo_transducer",
        "version": "parakeet-en-finetuned-int8",
        "emits_punctuation": False,
        "min_free_ram_mb": 2048,
        "min_sherpa_onnx_version": "1.12.0",
        "files": [file_record(path) for path in onnx_files],
    }
    (args.out / "pack.json").write_text(json.dumps(pack, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.out / 'pack.json'} mean_cer {score:.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
