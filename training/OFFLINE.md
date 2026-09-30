# Offline training on the Windows H100

This folder trains on a Windows machine with one H100. That machine has no network. Driver 597.95 and CUDA toolkit 13.2 stay as they are. Do not downgrade the driver. Do not run `pip install` against the internet there. If a step needs a download, stop and fix the bundle on the online PC.

Speech for the product is one language per model. English fine-tunes Parakeet. Chinese runs Qwen3-ASR LoRA. Korean trains a FastConformer-Transducer from scratch on this project's own corpus. The Android app is a separate folder and is not part of this procedure.

The same steps, typed in Anaconda Prompt without the `.ps1` files, are `docs/manual-training.md`.

## What is already on the online PC

Copy these paths to the H100 and keep the same layout under a directory called `SR`.

| Path | Why it is copied |
| --- | --- |
| `training/` | Scripts, this document, and `DATASETS.md` |
| `inference/` | Transcribe a clip after a checkpoint exists |
| `docs/` | `manual-training.md` and `manual-inference.md` |
| `data/en/librispeech-sample` | 8 English clips. 6 are train, 2 are test |
| `data/zh/aishell-sample` | 8 Chinese clips. 6 are train, 2 are test |
| `vendor/h100/` | Windows `win_amd64` wheels for Python 3.12, including the `cu130` PyTorch wheel |
| `vendor/checkpoints/parakeet-tdt-0.6b-v2.nemo` | English starting weights. 2472222720 bytes |
| `vendor/checkpoints/Qwen3-ASR-0.6B-hf/` | Chinese starting weights. `model.safetensors` is 1564928088 bytes |
| `vendor/checksums.sha256` | Hashes for those two weight files |
| `vendor/windows/vc_redist.x64.exe` | Visual C++ 2015-2022 x64. Install this before Miniconda. 25635768 bytes |
| `vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` | Python 3.12 installer. The wheels are cp312. 93706080 bytes. Do not install `Miniconda3-latest-Windows-x86_64.exe` |
| `vendor/README.md` | What each vendor directory is |

Do not copy `vendor/gradle-user-home/`. That cache is for the Android build. Do not copy a Linux wheel or a Linux Miniconda installer. A Linux wheel will not install on this machine.

PyTorch in the bundle is `torch==2.14.0+cu130` from `vendor/h100/torch-pin.txt`. The wheel file is `torch-2.14.0+cu130-cp312-cp312-win_amd64.whl` (1990604486 bytes). PyTorch has no `cu132` build. The `cu130` wheel is the one that runs on CUDA toolkit 13.2. If `vendor/h100/CUDA13_WHEEL_MISSING.txt` exists, stop and fix the bundle on the online PC.

## Check the copies

On the H100, from the repo root in Anaconda Prompt or Command Prompt:

```
certutil -hashfile vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo SHA256
certutil -hashfile vendor\checkpoints\Qwen3-ASR-0.6B-hf\model.safetensors SHA256
certutil -hashfile vendor\windows\vc_redist.x64.exe SHA256
certutil -hashfile vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe SHA256
```

`vendor\checksums.sha256` must match:

```
d99e39955c9d3d0350d8fb7c75e40c64a2b2eaeb003883d7c941fd2e8747b28c  vendor/checkpoints/parakeet-tdt-0.6b-v2.nemo
d3f212dd20abecd315d830bc54ae3865e56ebfc3276484e57b771288ba27fd35  vendor/checkpoints/Qwen3-ASR-0.6B-hf/model.safetensors
97a750503cf1ef57c8a7cc79e7cff04b3d4a566091c631f665eb91eae3a6fde0  vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe
cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b  vendor/windows/vc_redist.x64.exe
```

Compare the hex. Letter case does not matter. If it does not match, copy that file again. Do not download it on the H100.

Then confirm the GPU:

```
nvidia-smi
```

You need one H100. The driver line must show 597.95 and the CUDA version line must show 13.2. Leave that toolkit in place. The PyTorch wheel carries its own CUDA libraries.

## Two Python environments

English and Chinese do not share one Python environment.

NeMo 2.7.3, which fine-tunes Parakeet, requires `transformers` 4.57.6. That build has no Qwen3-ASR classes. The local `Qwen3-ASR-0.6B-hf` checkpoint was saved for Transformers 5, and this bundle uses `transformers` 5.18.0 for Chinese. Installing both package lists into one environment breaks one of the two trainings.

Install `vendor\windows\vc_redist.x64.exe` first, then Miniconda from `vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` for this user only. Open **Anaconda Prompt**. `python --version` must say Python 3.12. If it does not, stop. Do not run `conda install` against the network.

Create the two environments from the base install, which needs no network:

```
cd /d D:\SR
conda create -n sr-en --clone base -y
conda create -n sr-zh --clone base -y
```

English, after `conda activate sr-en`:

```
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: torch torchvision torchaudio
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: -r training\requirements-h100.txt
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'available', torch.cuda.is_available())"
```

That installs `torch`, `torchvision`, and `torchaudio` from the `cu130` wheels, then `training/requirements-h100.txt` (`nemo_toolkit[asr]==2.7.3` and `transformers` 4.57). The last line prints the torch version, the CUDA version inside the wheel, and whether CUDA is visible.

Chinese, after `conda activate sr-zh`:

```
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: torch torchvision torchaudio
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: -r training\requirements-zh.txt
python -c "import torch; from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration; print('torch', torch.__version__, 'qwen3_asr', Qwen3ASRForConditionalGeneration.__name__, 'cuda', torch.cuda.is_available())"
```

That installs the same `cu130` PyTorch wheels, then `training/requirements-zh.txt` (`transformers==5.18.0` and the LoRA packages). The last line imports `Qwen3ASRForConditionalGeneration`. If that import fails, this environment is the NeMo one. Activate `sr-zh` and run the Chinese install again.

Both installers use `pip install --no-index --only-binary=:all:`. A missing wheel is a failure. Add the wheel on the online PC and copy `vendor\h100\wheels` again. Do not pass `--index-url` on the H100.

## Data that is allowed to train

`training/DATASETS.md` is the license gate. A row that says Pending or Not downloaded is not training data. The H100 does not fetch corpora.

The only audio in this bundle is the two samples:

| Language | Files | How prepare splits them |
| --- | --- | --- |
| English | `data/en/librispeech-sample` | 6 clips under `train/`, 2 clips under `test/` |
| Chinese | `data/zh/aishell-sample` | 6 clips under `train/`, 2 clips under `test/` |

`training/scripts/build_manifest.py` writes JSONL. It does not download audio. A path containing `/test` or `/dev` goes to `val_manifest.jsonl`. Everything else goes to `train_manifest.jsonl`. Each line is:

```
{"audio_filepath": "...", "duration": 1.2, "text": "..."}
```

Korean does not use KsponSpeech, AI Hub, Zeroth-Korean, Common Voice Korean, or FLEURS Korean. Copy the project corpus to `D:\SR\data\ko` in the same layout as the samples: `train/` and `test/` directories, audio files, and a transcript next to them. `build_manifest.py` accepts any of these:

- A `*.trans.txt` file whose lines are `utt_id transcript`, with `utt_id.flac` or `utt_id.wav` in the same folder
- One `.txt` file beside each audio file, with the same stem
- An AISHELL-style `aishell_transcript*.txt` whose first field is the wav stem

A path containing `/test` or `/dev` becomes the validation manifest. The tokenizer needs at least 100 transcript lines in the train manifest.

Other English and Chinese corpora in `DATASETS.md` stay Pending until that row is changed to Allowed on the online PC. Pending rows are not fetched.

On a copy whose root is `D:\SR`, the audio root passed to `build_manifest.py` is `D:\SR\data\en`, `D:\SR\data\zh`, or `D:\SR\data\ko`. The script exits 2 when that folder has no audio and transcript pairs.

These 8-clip sets check that the offline loop starts. They are not a quality training set. A real run waits until a larger Allowed corpus is copied into `D:\SR\data\en` or `D:\SR\data\zh` and `build_manifest.py` is run again.

## English

Use the NeMo environment. The three `set` lines keep Hugging Face off the network for that window:

```
conda activate sr-en
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\en --out D:\SR\data\en
python training\scripts\toy_gpu_step.py
python training\en\finetune.py --checkpoint vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo --train-manifest D:\SR\data\en\train_manifest.jsonl --val-manifest D:\SR\data\en\val_manifest.jsonl --max-steps 20 --output training\en\exp
```

`build_manifest.py` writes `D:\SR\data\en\train_manifest.jsonl` and `val_manifest.jsonl`.

`toy_gpu_step.py` must exit 0. It prints the GPU name and a bfloat16 matmul shape. Exit 2 means this PyTorch build cannot see CUDA. Do not switch to a CPU wheel.

The fine-tune restores `vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo` from disk. Pass another file with `--checkpoint` only when the weights really are somewhere else. Training uses one GPU, bf16, learning rate `1e-4`, and Windows `num_workers` 0. The default step count is 10000. The command above uses `--max-steps 20` for a first check on the 8-clip sample. A real run uses `--max-steps 10000`.

The requested batch size is 16. The script lowers it to the smaller of the train row count and the val row count, so the sample uses batch size 2. It prints `batch_size 2` when that happens.

A finished run writes `training\en\exp\parakeet-en-finetuned.nemo` and prints `saved` plus that path.

`training/en/export.py` writes an ONNX file from that checkpoint. It writes `pack.json` only when you also pass fp32 and int8 transcript files, each with at least 50 non-empty lines, and the mean character error between them is at most 0.003. Until that check exists, the export script exits 2 after writing the ONNX file.

## Chinese

Use the Chinese environment. The NeMo environment cannot load this checkpoint.

```
conda activate sr-zh
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\zh --out D:\SR\data\zh
python training\scripts\toy_gpu_step.py
python training\zh\finetune_lora.py --model vendor\checkpoints\Qwen3-ASR-0.6B-hf --train-manifest D:\SR\data\zh\train_manifest.jsonl --max-steps 20 --output training\zh\exp
```

`build_manifest.py` writes `D:\SR\data\zh\train_manifest.jsonl` and `val_manifest.jsonl`. The LoRA script trains on the train manifest. The assistant target is `language Chinese<asr_text>` plus the transcript.

The command loads `vendor\checkpoints\Qwen3-ASR-0.6B-hf` with `local_files_only=True`. Pass another directory with `--model` only when the checkpoint really is somewhere else. Audio paths are passed as a normal Windows path with forward slashes so `D:` is not read as a URL scheme.

LoRA uses rank 32, alpha 64, and dropout 0.05 on `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, and `down_proj`. Any parameter whose name contains `audio` is frozen. Learning rate is `1e-4`. Gradients accumulate for 8 examples, then one optimizer step is counted. The default step count is 2000. The command above uses `--max-steps 20` for a first check on the sample. A real run uses `--max-steps 2000`.

Every 10 steps the script prints `step` and `loss`. A finished run writes the adapter and processor into `training\zh\exp` and prints `saved` plus that directory.

If Python raises `ImportError` on `Qwen3ASRForConditionalGeneration`, the active environment is still the NeMo one. Activate `sr-zh`.

`training/zh/export.sh` exits 2. Chinese pack export stays off until an ONNX round trip of the unmodified Qwen3-ASR weights matches the published pack in `vendor/packs/`. That check is not a second export path. If the round trip fails, stop. The Chinese fine-tune target moves to Paraformer-large, and that model is not in this bundle yet.

## Korean

The full Korean procedure is `training/ko/README.md`. Korean uses the NeMo environment, the same one as English. There is no pretrained Korean checkpoint. `training/ko/fastconformer_transducer_bpe.yaml` is the large FastConformer-Transducer, about 120M parameters, with transducer loss and a 5000-piece SentencePiece model trained from the project transcripts.

```
conda activate sr-en
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\ko --out D:\SR\data\ko
python training\ko\prepare_tokenizer.py --manifest D:\SR\data\ko\train_manifest.jsonl --out D:\SR\data\ko\tokenizer
python training\scripts\toy_gpu_step.py
python training\ko\train_from_scratch.py --train-manifest D:\SR\data\ko\train_manifest.jsonl --val-manifest D:\SR\data\ko\val_manifest.jsonl --tokenizer-dir D:\SR\data\ko\tokenizer --output training\ko\exp
```

Those commands write `D:\SR\data\ko\train_manifest.jsonl`, `val_manifest.jsonl`, and `D:\SR\data\ko\tokenizer\tokenizer.model`, then fit the model from scratch for 100 epochs on one GPU in bf16. Windows `num_workers` is 0. The batch size starts at 64 and is lowered when a split has fewer rows than that. A finished run writes `training\ko\exp\fastconformer-ko.nemo`.

## After training

Transcribe a clip from the same prompt with the Python commands in `docs/manual-inference.md`. English and Korean stay in `sr-en`. Chinese uses `sr-zh`.

`training/ko/export.sh` exits 2 until that model has been scored on the project held-out set. SenseVoice and the public icefall Zipformer stay unused.

## Stop conditions

Stop instead of working around the failure when any of these happen:

- `python --version` is not 3.12
- `nvidia-smi` does not show driver 597.95 and CUDA 13.2
- A checkpoint hash does not match `vendor\checksums.sha256`
- `vendor/h100/CUDA13_WHEEL_MISSING.txt` exists
- `pip` tries to reach the internet, or a wheel is missing
- `toy_gpu_step.py` exits 2
- English and Chinese were installed into the same environment
- A corpus row in `DATASETS.md` is Pending, Not downloaded, or Not used
