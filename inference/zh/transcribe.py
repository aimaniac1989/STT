"""Transcribe audio with local Qwen3-ASR weights, plus a LoRA adapter when one exists. No network."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

AUDIO_SUFFIXES = {".flac", ".wav", ".mp3", ".ogg"}


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


def move_inputs(inputs, device, dtype):
    moved = {}
    for key, value in inputs.items():
        if hasattr(value, "to"):
            value = value.to(device)
            if getattr(value, "is_floating_point", lambda: False)():
                value = value.to(dtype=dtype)
        moved[key] = value
    return moved


def transcript_text(processor, generated, prompt_len: int) -> str:
    new_tokens = generated[:, prompt_len:]
    text = processor.batch_decode(new_tokens, skip_special_tokens=True)[0].strip()
    marker = "<asr_text>"
    if marker in text:
        text = text.split(marker, 1)[1].strip()
    return text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--adapter", type=Path, default=None)
    parser.add_argument("--language", default="Chinese")
    parser.add_argument("audio", nargs="+", type=Path)
    args = parser.parse_args()
    if not args.model.is_dir():
        print(f"Missing {args.model}", file=sys.stderr)
        return 2
    files = collect_audio(args.audio)
    if not files:
        print("No audio files.", file=sys.stderr)
        return 2

    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    os.environ["HF_DATASETS_OFFLINE"] = "1"

    import torch
    from peft import PeftModel
    try:
        from transformers import AutoProcessor
        from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration
    except ImportError:
        print(
            "Qwen3-ASR is not in this Transformers build. Use the Chinese environment from training\\scripts\\install_offline_zh.ps1.",
            file=sys.stderr,
        )
        return 2

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    processor = AutoProcessor.from_pretrained(args.model, local_files_only=True)
    model = Qwen3ASRForConditionalGeneration.from_pretrained(
        args.model,
        dtype=torch.bfloat16,
        local_files_only=True,
    )
    if args.adapter is not None:
        if not (args.adapter / "adapter_config.json").is_file():
            print(f"Missing {args.adapter / 'adapter_config.json'}", file=sys.stderr)
            return 2
        model = PeftModel.from_pretrained(model, args.adapter, local_files_only=True)
        print(f"model {args.model} adapter {args.adapter}", file=sys.stderr)
    else:
        print(f"model {args.model}", file=sys.stderr)
    model.eval()
    model.to("cuda")

    for audio in files:
        conversation = [[
            {"role": "user", "content": [{"type": "audio", "path": audio.resolve().as_posix()}]},
            {"role": "assistant", "content": [{"type": "text", "text": f"language {args.language}<asr_text>"}]},
        ]]
        inputs = processor.apply_chat_template(
            conversation,
            tokenize=True,
            return_dict=True,
            continue_final_message=True,
        )
        inputs = move_inputs(inputs, model.device, torch.bfloat16)
        prompt_len = inputs["input_ids"].shape[-1]
        with torch.no_grad():
            generated = model.generate(**inputs, max_new_tokens=256)
        print(audio)
        print(transcript_text(processor, generated, prompt_len))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
