"""Transcribe audio with a local Parakeet .nemo file. No network."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

AUDIO_SUFFIXES = {".flac", ".wav", ".mp3", ".ogg"}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def collect_audio(paths: list[Path]) -> list[Path]:
    files = []
    for path in paths:
        if path.is_dir():
            files.extend(item for item in sorted(path.rglob("*")) if item.suffix.lower() in AUDIO_SUFFIXES)
        elif path.is_file() and path.suffix.lower() in AUDIO_SUFFIXES:
            files.append(path)
        else:
            print(f"Missing audio {path}", file=sys.stderr)
            return []
    return files


def as_text(item) -> str:
    if isinstance(item, str):
        return item.strip()
    text = getattr(item, "text", None)
    if isinstance(text, str):
        return text.strip()
    return str(item).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("audio", nargs="+", type=Path)
    args = parser.parse_args()
    if not args.checkpoint.is_file():
        print(f"Missing {args.checkpoint}", file=sys.stderr)
        return 2
    files = collect_audio(args.audio)
    if not files:
        print("No audio files.", file=sys.stderr)
        return 2

    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    os.environ["HF_DATASETS_OFFLINE"] = "1"

    import torch
    from nemo.collections.asr.models import ASRModel

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    model = ASRModel.restore_from(str(args.checkpoint))
    model.eval()
    model = model.cuda()
    print(f"model {args.checkpoint}", file=sys.stderr)
    hypotheses = model.transcribe(
        [str(path) for path in files],
        batch_size=1,
        num_workers=0,
        verbose=False,
    )
    if isinstance(hypotheses, tuple):
        hypotheses = hypotheses[0]
    for path, item in zip(files, hypotheses):
        print(path)
        print(as_text(item))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
