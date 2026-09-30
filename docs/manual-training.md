# Training by hand

This page is the command-prompt procedure for `training/`. Type the lines in **Anaconda Prompt** (a Command Prompt window where `conda` works). You do not run the `.ps1` files.

The machine is the Windows H100. It has no network. Driver 597.95 and CUDA toolkit 13.2 stay as they are. Do not downgrade the driver. Do not run `pip install` against the internet. If a step needs a download, stop and fix the bundle on the online PC.

Copy the bundle as listed in `training/OFFLINE.md`, including `inference/` and `docs/`. The examples below use `D:\SR`. Change that letter and folder if your copy lives somewhere else.

```
cd /d D:\SR
```

English and Korean use the NeMo environment `sr-en`. Chinese uses the Chinese environment `sr-zh`. Do not install both requirement files into one environment. NeMo 2.7.3 stays on Transformers 4.57.6, which cannot load Qwen3-ASR. Chinese uses Transformers 5.18.0.

`set` lines last only for that window. Type them again if you open a new prompt.

## 1. Check the copy and the GPU

```
nvidia-smi
certutil -hashfile vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo SHA256
certutil -hashfile vendor\checkpoints\Qwen3-ASR-0.6B-hf\model.safetensors SHA256
```

`nvidia-smi` must show one H100, driver 597.95, and CUDA Version 13.2. The two hashes must match these lines in `vendor\checksums.sha256` (letter case does not matter):

```
d99e39955c9d3d0350d8fb7c75e40c64a2b2eaeb003883d7c941fd2e8747b28c  vendor/checkpoints/parakeet-tdt-0.6b-v2.nemo
d3f212dd20abecd315d830bc54ae3865e56ebfc3276484e57b771288ba27fd35  vendor/checkpoints/Qwen3-ASR-0.6B-hf/model.safetensors
```

If a hash does not match, copy that file again. Do not download it on the H100. If `vendor\h100\CUDA13_WHEEL_MISSING.txt` exists, stop.

## 2. Apps on the H100

The H100 already has the NVIDIA driver 597.95 and CUDA toolkit 13.2. Leave both as they are. Do not install another driver, another CUDA toolkit, Git, Visual Studio, or the JDK. The JDK and Gradle in `vendor\windows` and `vendor\gradle` are for the Android build on the online PC.

`sr-en` and `sr-zh` are not installers. They are two Python environments you create after the two apps below. The Python packages themselves are the wheel files in `vendor\h100\wheels`, already in the copy.

Install these two programs, in this order, by double-clicking them. Both live under `vendor\windows` in the copy.

1. `vc_redist.x64.exe` — Microsoft Visual C++ 2015-2022 (x64), 25635768 bytes. PyTorch will not load without it. Choose Install. Hash `cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b`.
2. `Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` — Python 3.12, 93706080 bytes. Choose install for this user only (Just Me). Hash `97a750503cf1ef57c8a7cc79e7cff04b3d4a566091c631f665eb91eae3a6fde0`.

Do not run `Miniconda3-latest-Windows-x86_64.exe`. That file is a different Python, and the wheels will not install into it.

Check both hashes from the repo root before you install:

```
certutil -hashfile vendor\windows\vc_redist.x64.exe SHA256
certutil -hashfile vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe SHA256
```

After Miniconda finishes, open **Anaconda Prompt** from the Start menu. That window is where every later command in this page is typed. This line must say Python 3.12:

```
python --version
```

Create both environments from that install. This needs no network:

```
conda create -n sr-en --clone base -y
conda create -n sr-zh --clone base -y
```

English environment. These two `pip` lines install the `cu130` PyTorch wheel, then NeMo 2.7.3, from `vendor\h100\wheels` only:

```
conda activate sr-en
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: torch torchvision torchaudio
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: -r training\requirements-h100.txt
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda, 'available', torch.cuda.is_available())"
```

The last line must print `available True`.

Chinese environment. Open the same kind of prompt, or run `conda activate sr-zh` in a window that is not still inside `sr-en`:

```
conda activate sr-zh
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: torch torchvision torchaudio
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: -r training\requirements-zh.txt
python -c "import torch; from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration; print('torch', torch.__version__, 'qwen3_asr', Qwen3ASRForConditionalGeneration.__name__, 'cuda', torch.cuda.is_available())"
```

The last line must print `qwen3_asr Qwen3ASRForConditionalGeneration` and `available True`. If the import fails, this window is still the NeMo environment.

A missing wheel is a failure. Add the wheel on the online PC and copy `vendor\h100\wheels` again. Do not pass `--index-url` on the H100.

## 3. Confirm the GPU from Python

In whichever environment you are about to train with:

```
python training\scripts\toy_gpu_step.py
```

Exit 0 prints the GPU name and a bfloat16 matmul shape. Exit 2 means this PyTorch build cannot see CUDA. Do not switch to a CPU wheel.

## 4. English

Stay in `sr-en`. The sample audio is already at `D:\SR\data\en`. A path that contains `\test` or `\dev` goes into the validation manifest. Everything else goes into the train manifest.

```
conda activate sr-en
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\en --out D:\SR\data\en
```

That writes `D:\SR\data\en\train_manifest.jsonl` and `D:\SR\data\en\val_manifest.jsonl`. The sample has 6 train clips and 2 test clips.

First check, 20 steps. The script asks for batch size 16 and lowers it to 2 for this sample. It prints `batch_size 2` when that happens.

```
python training\scripts\toy_gpu_step.py
python training\en\finetune.py --checkpoint vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo --train-manifest D:\SR\data\en\train_manifest.jsonl --val-manifest D:\SR\data\en\val_manifest.jsonl --max-steps 20 --output training\en\exp
```

A finished run prints `saved` and writes `training\en\exp\parakeet-en-finetuned.nemo`.

A real run uses `--max-steps 10000` after a larger Allowed corpus is in `D:\SR\data\en` and you have run `build_manifest.py` again. The 8-clip sample only checks that the offline loop starts. Learning rate stays `1e-4`. One GPU, bf16.

## 5. Chinese

Switch to `sr-zh`. The NeMo environment cannot load this checkpoint.

```
conda activate sr-zh
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\zh --out D:\SR\data\zh
```

That writes `D:\SR\data\zh\train_manifest.jsonl` and `val_manifest.jsonl`. LoRA trains on the train manifest only. The sample has 6 train clips and 2 test clips.

First check, 20 steps. The default for a real run is `--max-steps 2000`.

```
python training\scripts\toy_gpu_step.py
python training\zh\finetune_lora.py --model vendor\checkpoints\Qwen3-ASR-0.6B-hf --train-manifest D:\SR\data\zh\train_manifest.jsonl --max-steps 20 --output training\zh\exp
```

Every 10 steps the script prints `step` and `loss`. A finished run prints `saved` and writes the LoRA adapter into `training\zh\exp`, including `adapter_config.json`. The base weights stay in `vendor\checkpoints\Qwen3-ASR-0.6B-hf`.

`--language` defaults to `Chinese`. Leave it at that value.

If Python raises `ImportError` on `Qwen3ASRForConditionalGeneration`, activate `sr-zh` and repeat the Chinese install in section 2.

## 6. Korean

Use `sr-en` again. There is no Korean audio in the bundle and no published Korean checkpoint. Copy the project corpus to `D:\SR\data\ko` with a `train` folder and a `test` folder, in the same layout as the English sample. Public Korean corpora are not used. The architecture notes are `training/ko/README.md`.

The tokenizer needs at least 100 non-empty lines in the train manifest. Fewer than that prints `Need at least 100 transcript lines to train the tokenizer.` and exits 2.

```
conda activate sr-en
set HF_HUB_OFFLINE=1
set TRANSFORMERS_OFFLINE=1
set HF_DATASETS_OFFLINE=1
python training\scripts\build_manifest.py --root D:\SR\data\ko --out D:\SR\data\ko
python training\ko\prepare_tokenizer.py --manifest D:\SR\data\ko\train_manifest.jsonl --out D:\SR\data\ko\tokenizer
```

The second command writes `D:\SR\data\ko\tokenizer\tokenizer.model`. Run it again if the transcripts change.

Then train from scratch. The default is 100 epochs. Batch size starts at 64 and is lowered when a split has fewer rows than that. Clips shorter than 0.1 s or longer than 16.7 s are skipped.

```
python training\scripts\toy_gpu_step.py
python training\ko\train_from_scratch.py --train-manifest D:\SR\data\ko\train_manifest.jsonl --val-manifest D:\SR\data\ko\val_manifest.jsonl --tokenizer-dir D:\SR\data\ko\tokenizer --output training\ko\exp
```

A finished run writes `training\ko\exp\fastconformer-ko.nemo`.

## 7. After training

Transcribe a clip with the Python commands in `docs/manual-inference.md`.

Pack export is a later step. Chinese and Korean export scripts exit 2 until their checks pass. Those checks are not required before the commands above.

## Stop

Stop instead of working around the failure when any of these happen:

- `python --version` is not 3.12
- `nvidia-smi` does not show driver 597.95 and CUDA 13.2
- A checkpoint hash does not match `vendor\checksums.sha256`
- `vendor\h100\CUDA13_WHEEL_MISSING.txt` exists
- `pip` tries to reach the internet, or a wheel is missing
- `toy_gpu_step.py` exits 2
- English and Chinese were installed into the same environment
- A corpus row in `training\DATASETS.md` is Pending, Not downloaded, or Not used
