# H100 offline setup

The training machine is Windows with one H100, driver 597.95, and CUDA toolkit 13.2. It has no network. Do not change the driver. Do not run `pip install` against the internet on that machine. If a step needs a download, stop and fix the bundle on the online PC.

## 1. What to copy

From the Windows repo, copy these directories to the server, keeping the same layout under a directory called `SR`:

- `training/`
- `inference/`
- `docs/`
- `data/en/librispeech-sample` and `data/zh/aishell-sample`
- `packs/PACK.md` and `packs/checksums.sha256`
- `vendor/h100/`
- `vendor/packs/`
- `vendor/checkpoints/`
- `vendor/checksums.sha256`
- `vendor/README.md`

Also copy `vendor/windows/vc_redist.x64.exe` and `vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe`. Those are the only two apps to install on the H100. Do not install `Miniconda3-latest-Windows-x86_64.exe`. Do not copy `vendor/gradle-user-home/`. That cache is for the Android build.

Wheels in `vendor/h100/wheels` are Windows `win_amd64` builds for Python 3.12. A Linux wheel will not install here.

On the H100, from the repo root in Anaconda Prompt or Command Prompt:

```
certutil -hashfile vendor\checkpoints\parakeet-tdt-0.6b-v2.nemo SHA256
certutil -hashfile vendor\checkpoints\Qwen3-ASR-0.6B-hf\model.safetensors SHA256
certutil -hashfile vendor\windows\vc_redist.x64.exe SHA256
certutil -hashfile vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe SHA256
```

Compare each hash with `vendor\checksums.sha256`. Letter case does not matter. If one does not match, copy that file again. Do not re-download it on the H100.

If `vendor/h100/CUDA13_WHEEL_MISSING.txt` exists, stop. The Windows fetch did not find a `cu130` wheel. PyTorch has no `cu132` build. The `cu130` wheel is the one that runs on CUDA toolkit 13.2. Do not install an older PyTorch and do not downgrade driver 597.95.

## 2. Confirm the GPU

```
nvidia-smi
```

You need one H100. `nvidia-smi` must show driver 597.95 and CUDA Version 13.2. Leave that toolkit in place. PyTorch wheels carry their own CUDA libraries, and the bundle uses the `cu130` wheel because that is the build which runs on toolkit 13.2. You do not install a second driver and you do not look for a `cu132` wheel.

## 3. Install the two apps

Double-click `vendor\windows\vc_redist.x64.exe` and choose Install. Then double-click `vendor\windows\Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` and install it for this user only. Open **Anaconda Prompt** from the Start menu and check:

```
python --version
```

The version line must say Python 3.12. The wheels were downloaded for cp312. If it does not, stop. Do not run `conda install` against the network.

## 4. Install wheels

Every install line and every train line, typed in that prompt, is `docs/manual-training.md`. The checksums and the reason the two environments stay separate are `training/OFFLINE.md`.

English and Chinese use two Python 3.12 environments. NeMo 2.7.3 stays on `transformers` 4.57.6. Qwen3-ASR loads only in `transformers` 5.18.0. Do not install both lists into one environment.

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

Chinese, after `conda activate sr-zh`:

```
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: torch torchvision torchaudio
python -m pip install --no-index --find-links vendor\h100\wheels --only-binary=:all: -r training\requirements-zh.txt
python -c "import torch; from transformers.models.qwen3_asr import Qwen3ASRForConditionalGeneration; print('torch', torch.__version__, 'qwen3_asr', Qwen3ASRForConditionalGeneration.__name__, 'cuda', torch.cuda.is_available())"
```

Both installs use `pip install --no-index --only-binary=:all:` and the Windows wheels. A missing wheel is a failure. Add the wheel on the online PC with `vendor\fetch-online.ps1` and copy `vendor\h100\wheels` again. Do not pass `--index-url` on the H100. The last line must print `available True`.

## 5. Train, then transcribe

```
python training\scripts\toy_gpu_step.py
```

Exit 0 prints the GPU name and a bfloat16 matmul shape. Exit 2 means this PyTorch build cannot see CUDA. Usual causes: the wheel is not the `cu130` build named in `vendor/h100/torch-pin.txt`, or `nvidia-smi` does not show CUDA 13.2. Do not switch to a CPU wheel.

The language commands, including the 20-step sample check and the Korean tokenizer, are `docs/manual-training.md`. English and Korean use `sr-en`. Chinese uses `sr-zh`. A finished English run writes `training\en\exp\parakeet-en-finetuned.nemo`. A finished Chinese run writes `training\zh\exp\adapter_config.json`. A finished Korean run writes `training\ko\exp\fastconformer-ko.nemo`.

Transcribe a clip with the Python commands in `docs/manual-inference.md`.

## 6. Data

The samples in `data/en/librispeech-sample` and `data/zh/aishell-sample` are the Allowed audio. `build_manifest.py` exits 2 when that audio folder is missing. The H100 does not fetch datasets. A Pending row in `training/DATASETS.md` stays unfetched. Korean audio is the project corpus at `D:\SR\data\ko`. Public Korean corpora are not used.

## 7. Packs

The published archives in `vendor/packs/` are the baseline weights. Their hashes are `packs/checksums.sha256`. Unpacking them into a directory with `pack.json` is a later export step. `export.sh` refuses to write a pack until the int8 transcripts match fp32 on 50 utterances.

Chinese re-export is the risky step, and it also runs on this Windows H100. Before any LoRA fine-tune, export the unmodified Qwen3-ASR weights with the sherpa-onnx export scripts and confirm the text matches the published pack. If that round trip fails, stop. The Chinese fine-tune target moves to Paraformer-large.
