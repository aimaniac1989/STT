"""Fine-tune a local Parakeet checkpoint. This script does not use the network."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def manifest_rows(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--train-manifest", type=Path, required=True)
    parser.add_argument("--val-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--max-steps", type=int, default=10000)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--batch-size", type=int, default=16)
    args = parser.parse_args()

    for path in (args.checkpoint, args.train_manifest, args.val_manifest):
        if not path.is_file():
            print(f"Missing {path}", file=sys.stderr)
            return 2

    import torch

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    import lightning.pytorch as pl
    from nemo.collections.asr.models import ASRModel
    from omegaconf import open_dict

    model = ASRModel.restore_from(str(args.checkpoint))
    workers = 0 if sys.platform == "win32" else 4
    batch = min(args.batch_size, manifest_rows(args.train_manifest), manifest_rows(args.val_manifest))
    if batch < 1:
        print("Manifests need at least one train row and one val row.", file=sys.stderr)
        return 2
    if batch != args.batch_size:
        print(f"batch_size {batch}")
    with open_dict(model.cfg):
        model.cfg.train_ds.manifest_filepath = str(args.train_manifest)
        model.cfg.train_ds.is_tarred = False
        model.cfg.train_ds.batch_size = batch
        model.cfg.train_ds.num_workers = workers
        model.cfg.validation_ds.manifest_filepath = str(args.val_manifest)
        model.cfg.validation_ds.is_tarred = False
        model.cfg.validation_ds.batch_size = batch
        model.cfg.validation_ds.num_workers = workers
        if "optim" in model.cfg and "lr" in model.cfg.optim:
            model.cfg.optim.lr = args.lr
    model.setup_training_data(model.cfg.train_ds)
    model.setup_validation_data(model.cfg.validation_ds)
    if hasattr(model, "setup_optimization"):
        model.setup_optimization()

    args.output.mkdir(parents=True, exist_ok=True)
    trainer = pl.Trainer(
        accelerator="gpu",
        devices=1,
        precision="bf16-mixed",
        max_steps=args.max_steps,
        default_root_dir=str(args.output),
        enable_checkpointing=True,
        logger=False,
    )
    trainer.fit(model)
    saved = args.output / "parakeet-en-finetuned.nemo"
    model.save_to(str(saved))
    print(f"saved {saved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
