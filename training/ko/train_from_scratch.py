"""Train a Korean FastConformer-Transducer from scratch. No network.

The corpus is the project set under the manifest paths. Public Korean corpora are not used.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def manifest_rows(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train-manifest", type=Path, required=True)
    parser.add_argument("--val-manifest", type=Path, required=True)
    parser.add_argument("--tokenizer-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--max-epochs", type=int, default=100)
    args = parser.parse_args()

    for path in (args.train_manifest, args.val_manifest, args.tokenizer_dir / "tokenizer.model"):
        if not path.is_file():
            print(f"Missing {path}", file=sys.stderr)
            return 2

    import lightning.pytorch as pl
    import torch
    from nemo.collections.asr.models import EncDecRNNTBPEModel
    from omegaconf import OmegaConf

    if not torch.cuda.is_available():
        print("CUDA is not available to this PyTorch build.", file=sys.stderr)
        return 2

    cfg = OmegaConf.load(Path(__file__).with_name("fastconformer_transducer_bpe.yaml"))
    workers = 0 if sys.platform == "win32" else 8
    batch = min(args.batch_size, manifest_rows(args.train_manifest), manifest_rows(args.val_manifest))
    if batch < 1:
        print("Manifests need at least one train row and one val row.", file=sys.stderr)
        return 2
    if batch != args.batch_size:
        print(f"batch_size {batch}")
    cfg.model.train_ds.manifest_filepath = str(args.train_manifest)
    cfg.model.train_ds.batch_size = batch
    cfg.model.train_ds.num_workers = workers
    cfg.model.validation_ds.manifest_filepath = str(args.val_manifest)
    cfg.model.validation_ds.batch_size = batch
    cfg.model.validation_ds.num_workers = workers
    cfg.model.tokenizer.dir = str(args.tokenizer_dir)
    cfg.trainer.devices = 1
    cfg.trainer.accelerator = "gpu"
    cfg.trainer.precision = "bf16-mixed"
    cfg.trainer.max_epochs = args.max_epochs
    cfg.trainer.strategy = "auto"
    cfg.trainer.enable_checkpointing = True
    cfg.trainer.logger = False

    args.output.mkdir(parents=True, exist_ok=True)
    trainer = pl.Trainer(**OmegaConf.to_container(cfg.trainer, resolve=True))
    model = EncDecRNNTBPEModel(cfg=cfg.model, trainer=trainer)
    trainer.fit(model)
    saved = args.output / "fastconformer-ko.nemo"
    model.save_to(str(saved))
    print(f"saved {saved}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
