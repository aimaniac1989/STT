"""Train a SentencePiece model from a local Korean manifest. No network."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--vocab-size", type=int, default=5000)
    args = parser.parse_args()
    if not args.manifest.is_file():
        print(f"Missing {args.manifest}", file=sys.stderr)
        return 2
    texts = []
    for line in args.manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        texts.append(json.loads(line)["text"])
    if len(texts) < 100:
        print("Need at least 100 transcript lines to train the tokenizer.", file=sys.stderr)
        return 2
    args.out.mkdir(parents=True, exist_ok=True)
    corpus = args.out / "corpus.txt"
    corpus.write_text("\n".join(texts) + "\n", encoding="utf-8")
    import sentencepiece as spm

    spm.SentencePieceTrainer.Train(
        input=str(corpus),
        model_prefix=str(args.out / "tokenizer"),
        vocab_size=args.vocab_size,
        model_type="bpe",
        character_coverage=0.9995,
        bos_id=-1,
        eos_id=-1,
    )
    print(f"wrote {args.out / 'tokenizer.model'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
