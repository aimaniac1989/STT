# Training

This folder runs on the Windows H100. It does not link into the Android app. The machine has no network. Type the Python commands in `docs/manual-training.md`. Checksums, sample paths, and why the two environments stay separate are in `OFFLINE.md`.

Driver 597.95 and CUDA toolkit 13.2 stay as they are. PyTorch is the Windows `cu130` wheel in `vendor/h100/wheels`. Do not install a `cu132` wheel and do not downgrade the driver.

English and Chinese use different environments because they need different Transformers builds:

| Environment | Requirements file | Transformers | What it trains |
| --- | --- | --- | --- |
| `sr-en` | `requirements-h100.txt` | 4.57.6 | Parakeet TDT 0.6B v2 fine-tune from `vendor/checkpoints/parakeet-tdt-0.6b-v2.nemo` |
| `sr-zh` | `requirements-zh.txt` | 5.18.0 | Qwen3-ASR-0.6B LoRA from `vendor/checkpoints/Qwen3-ASR-0.6B-hf` |

Do not install both requirement files into one environment. NeMo 2.7.3 cannot load the Qwen3-ASR classes, and Transformers 5.18 is not the NeMo pin.

Audio in this bundle is the samples listed in `DATASETS.md`: `data/en/librispeech-sample` and `data/zh/aishell-sample`, 6 train clips and 2 test clips each. On the H100 those live under `D:\SR\data\en` and `D:\SR\data\zh`. Korean training uses the same NeMo environment and your own corpus at `D:\SR\data\ko`, in that same transcript layout. It trains a FastConformer-Transducer from scratch. The Korean procedure is `ko/README.md`. Public Korean corpora are not used.

`scripts/build_manifest.py` writes `train_manifest.jsonl` and `val_manifest.jsonl` from local audio. It does not download corpora. `scripts/toy_gpu_step.py` checks that PyTorch sees the H100. `eval/` holds WER and CER notes after a run.

After a checkpoint exists, transcribe a clip from Anaconda Prompt with the Python commands in `docs/manual-inference.md`. English and Korean use the NeMo environment. Chinese uses the Chinese environment.

Pack export is a later step. English `export.py` writes `pack.json` only after the int8 transcripts match fp32 on at least 50 lines. Chinese and Korean `export.sh` exit 2.
