# Inference

This folder runs a trained or fine-tuned checkpoint on the Windows H100 and prints text for an audio file. It does not train, and it does not link into the Android app. The machine has no network.

English and Korean use the NeMo environment `sr-en`. Chinese uses the Chinese environment `sr-zh`. Install those environments with `docs/manual-training.md`.

The command-prompt procedure, with the Python lines typed by hand, is `docs/manual-inference.md`. The `.ps1` files are optional wrappers around those same Python scripts.

Each script prints the checkpoint path on the error stream, then one audio path and its transcript on the standard output. Pass one file, several files, or a folder of `.wav`, `.flac`, `.mp3`, or `.ogg` clips.

## English

Fine-tuned Parakeet, when `training\en\exp\parakeet-en-finetuned.nemo` exists. Otherwise pass the published checkpoint `vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo`.

```
conda activate sr-en
python inference\en\transcribe.py --checkpoint training\en\exp\parakeet-en-finetuned.nemo D:\SR\data\en\librispeech-sample\test
```

## Chinese

Base weights are `vendor\checkpoints\Qwen3-ASR-0.6B-hf`. After LoRA training, pass `training\zh\exp` with `--adapter`. Leave `--adapter` off to run the base model alone. The error stream prints `adapter` only when that folder was loaded.

```
conda activate sr-zh
python inference\zh\transcribe.py --model vendor\checkpoints\Qwen3-ASR-0.6B-hf --adapter training\zh\exp D:\SR\data\zh\aishell-sample\test
```

Leave `--adapter` off to run the base model alone. The full choices are in `docs/manual-inference.md`.

## Korean

The from-scratch model `training\ko\exp\fastconformer-ko.nemo`. There is no published Korean checkpoint in this bundle, so the script exits 2 until that file exists. Pass another `.nemo` file with `--checkpoint` when you have one.

```
conda activate sr-en
python inference\ko\transcribe.py --checkpoint training\ko\exp\fastconformer-ko.nemo D:\SR\data\ko\test
```
