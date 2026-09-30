"""Build NeMo JSONL manifests from a local corpus directory. No network."""

from __future__ import annotations

import argparse
import json
import sys
import wave
from pathlib import Path

AUDIO_SUFFIXES = (".flac", ".wav", ".mp3", ".ogg")


def duration_seconds(path: Path) -> float:
    if path.suffix.lower() == ".wav":
        with wave.open(str(path), "rb") as handle:
            rate = handle.getframerate()
            if rate <= 0:
                raise ValueError(f"bad sample rate in {path}")
            return handle.getnframes() / float(rate)
    import soundfile as sf

    return float(sf.info(str(path)).duration)


def _row(audio: Path, text: str) -> dict:
    text = " ".join(text.split())
    if not text:
        raise ValueError(f"empty transcript for {audio}")
    return {
        "audio_filepath": str(audio.resolve()),
        "duration": round(duration_seconds(audio), 3),
        "text": text,
    }


def from_trans_txt(root: Path) -> list[dict]:
    rows = []
    for trans in root.rglob("*.trans.txt"):
        for line in trans.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if not line:
                continue
            utt, _, text = line.partition(" ")
            audio = next((trans.parent / f"{utt}{ext}" for ext in AUDIO_SUFFIXES if (trans.parent / f"{utt}{ext}").is_file()), None)
            if audio is None or not text:
                print(f"skip {utt}: audio or text missing", file=sys.stderr)
                continue
            rows.append(_row(audio, text))
    return rows


def from_aishell(root: Path) -> list[dict]:
    rows = []
    transcripts = list(root.rglob("aishell_transcript*.txt"))
    wavs = {path.stem: path for path in root.rglob("*.wav")}
    for transcript in transcripts:
        for line in transcript.read_text(encoding="utf-8-sig").splitlines():
            line = line.strip()
            if not line:
                continue
            utt, _, text = line.partition(" ")
            audio = wavs.get(utt)
            if audio is None or not text:
                continue
            rows.append(_row(audio, text))
    return rows


def from_sidecar(root: Path) -> list[dict]:
    rows = []
    for audio in root.rglob("*"):
        if audio.suffix.lower() not in AUDIO_SUFFIXES:
            continue
        text_path = audio.with_suffix(".txt")
        if not text_path.is_file():
            continue
        rows.append(_row(audio, text_path.read_text(encoding="utf-8-sig")))
    return rows


def split_rows(rows: list[dict]) -> tuple[list[dict], list[dict]]:
    train, val = [], []
    for row in rows:
        path = row["audio_filepath"].replace("\\", "/").lower()
        if "/dev" in path or "/test" in path:
            val.append(row)
        else:
            train.append(row)
    if train and not val:
        holdout = max(1, len(train) // 50)
        val = train[-holdout:]
        train = train[:-holdout]
    return train, val


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if not args.root.is_dir():
        print(f"Missing {args.root}", file=sys.stderr)
        return 2
    rows = from_trans_txt(args.root)
    rows.extend(from_aishell(args.root))
    if not rows:
        rows = from_sidecar(args.root)
    if not rows:
        print(f"No audio/transcript pairs under {args.root}", file=sys.stderr)
        return 2
    train, val = split_rows(rows)
    if not train or not val:
        print(f"Need both a train and a val split, got {len(train)} train and {len(val)} val", file=sys.stderr)
        return 2
    write_jsonl(args.out / "train_manifest.jsonl", train)
    write_jsonl(args.out / "val_manifest.jsonl", val)
    print(f"train {len(train)} val {len(val)} -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
