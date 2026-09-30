"""LoRA fine-tune of local Qwen3-ASR-0.6B weights on the Windows H100. No network.

Run this from the Chinese environment installed by training/scripts/install_offline_zh.ps1.
That environment has transformers 5.18. The NeMo environment stays on transformers 4.57.6
and cannot load this checkpoint.

Manifest lines use the same JSON as English: audio_filepath, duration, text.
The assistant target keeps the pretrained prefix `language Chinese<asr_text>`.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


DECODER_TARGETS = ["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"]


def read_manifest(path: Path) -> list[dict]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        if not Path(row["audio_filepath"]).is_file():
            raise FileNotFoundError(row["audio_filepath"])
        rows.append(row)
    if not rows:
        raise ValueError(f"empty manifest {path}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--train-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--language", default="Chinese")
    parser.add_argument("--max-steps", type=int, default=2000)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--grad-accum", type=int, default=8)
    args = parser.parse_args()
    for path in (args.model, args.train_manifest):
        if not path.exists():
            print(f"Missing {path}", file=sys.stderr)
            return 2

    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"

    import torch
    from peft import LoraConfig, get_peft_model
    try:
        from transformers import AutoProcessor
        from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration
    except ImportError:
        print(
            "Qwen3-ASR is not in this Transformers build. Install the Chinese environment with training\\scripts\\install_offline_zh.ps1.",
            file=sys.stderr,
        )
        return 2

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    rows = read_manifest(args.train_manifest)
    processor = AutoProcessor.from_pretrained(args.model, local_files_only=True)
    model = Qwen3ASRForConditionalGeneration.from_pretrained(
        args.model,
        dtype=torch.bfloat16,
        local_files_only=True,
    )
    model = get_peft_model(
        model,
        LoraConfig(
            r=32,
            lora_alpha=64,
            lora_dropout=0.05,
            target_modules=DECODER_TARGETS,
            bias="none",
        ),
    )
    for name, param in model.named_parameters():
        if "audio" in name:
            param.requires_grad = False
    model.to("cuda")
    model.train()
    optimizer = torch.optim.AdamW((param for param in model.parameters() if param.requires_grad), lr=args.lr)
    optimizer.zero_grad(set_to_none=True)

    step = 0
    seen = 0
    while step < args.max_steps:
        row = rows[seen % len(rows)]
        seen += 1
        audio = Path(row["audio_filepath"]).resolve().as_posix()
        conversation = [[
            {"role": "user", "content": [{"type": "audio", "path": audio}]},
            {
                "role": "assistant",
                "content": [{"type": "text", "text": f"language {args.language}<asr_text>{row['text']}"}],
            },
        ]]
        inputs = processor.apply_chat_template(
            conversation,
            tokenize=True,
            return_dict=True,
            processor_kwargs={"output_labels": True},
        )
        inputs = inputs.to(model.device)
        loss = model(**inputs).loss / args.grad_accum
        loss.backward()
        if seen % args.grad_accum == 0:
            optimizer.step()
            optimizer.zero_grad(set_to_none=True)
            step += 1
            if step % 10 == 0:
                print(f"step {step} loss {loss.item() * args.grad_accum:.4f}")

    args.output.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(args.output)
    processor.save_pretrained(args.output)
    print(f"saved {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
