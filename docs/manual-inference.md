# Inference by hand

This page is the command-prompt procedure for `inference/`. Type the lines in **Anaconda Prompt** (a Command Prompt window where `conda` works). You do not run the `.ps1` files.

The machine is the same Windows H100 used for training. It has no network. Setup for that machine is `docs/manual-h100-offline.md`. Copy the `inference/` folder onto the H100 with the rest of the bundle, then open a prompt in the repo root. The examples below use `D:\SR`. Change that letter and folder if your copy lives somewhere else.

```
cd /d D:\SR
```

Each Python script turns the network off itself, loads one checkpoint onto the GPU, and prints text. The first lines go to the error stream and name the file it loaded. Then, for every clip, it prints the audio path and the transcript. You can pass one file, several files, or a folder. A folder is searched for `.wav`, `.flac`, `.mp3`, and `.ogg`.

Exit code 0 means every file was transcribed. Exit code 2 means a checkpoint is missing, the audio path is missing, or this PyTorch build cannot see the GPU. Do not switch to a CPU wheel.

## English

Use the NeMo environment. That is the same environment that fine-tuned Parakeet.

```
conda activate sr-en
```

After the English commands in `docs/manual-training.md` have finished, the fine-tuned file is `training\en\exp\parakeet-en-finetuned.nemo`:

```
python inference\en\transcribe.py --checkpoint training\en\exp\parakeet-en-finetuned.nemo D:\SR\data\en\librispeech-sample\test
```

Before that file exists, the published checkpoint is already in the bundle:

```
python inference\en\transcribe.py --checkpoint vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo D:\SR\data\en\librispeech-sample\test
```

One clip instead of the whole test folder:

```
python inference\en\transcribe.py --checkpoint vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo D:\SR\data\en\librispeech-sample\test\6930-75918-0006.flac
```

The error stream should contain a line that starts with `model` and the checkpoint path you passed. The standard output is the audio path, then the transcript, then the next audio path.

## Chinese

Use the Chinese environment. The NeMo environment cannot load Qwen3-ASR.

```
conda activate sr-zh
```

The base weights are the folder `vendor\checkpoints\Qwen3-ASR-0.6B-hf`. This command runs that base model, with no LoRA adapter:

```
python inference\zh\transcribe.py --model vendor\checkpoints\Qwen3-ASR-0.6B-hf D:\SR\data\zh\aishell-sample\test
```

After the Chinese commands in `docs/manual-training.md` have finished, `training\zh\exp\adapter_config.json` is the LoRA adapter. Pass that folder with `--adapter`. The base folder stays the same. The adapter does not replace the base weights.

```
python inference\zh\transcribe.py --model vendor\checkpoints\Qwen3-ASR-0.6B-hf --adapter training\zh\exp D:\SR\data\zh\aishell-sample\test
```

The error stream prints `model` plus `adapter` when the adapter loaded. If you leave `--adapter` off, it prints only `model`.

`--language` defaults to `Chinese`. Leave it at that value for these clips.

## Korean

Use the NeMo environment again.

```
conda activate sr-en
```

Korean has no published checkpoint in this bundle. The file appears only after the Korean commands in `docs/manual-training.md` write `training\ko\exp\fastconformer-ko.nemo`. Point `--checkpoint` at that file and point the last argument at a folder of your own test clips:

```
python inference\ko\transcribe.py --checkpoint training\ko\exp\fastconformer-ko.nemo D:\SR\data\ko\test
```

If that `.nemo` file is not there yet, the script prints `Missing` and exits 2. Train first, then run the same command again.
