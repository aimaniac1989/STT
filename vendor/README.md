# Vendor bundle

This PC downloads everything. The H100 has no network. Copy `vendor/h100/`, `vendor/checkpoints/`, `vendor/packs/`, `vendor/checksums.sha256`, `vendor/windows/vc_redist.x64.exe`, and `vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe`. The typed install is `docs/manual-training.md`.

Run `vendor/fetch-online.ps1` once while this PC is online. It skips any file that already has a `.complete` marker beside it. When it finishes it writes:

- `vendor/checksums.sha256` — SHA-256 of every archive and wheel in the bundle
- `vendor/h100/requirements-lock.txt` — wheel filenames installed on the H100
- `vendor/h100/torch-pin.txt` — the `cu130` PyTorch version downloaded for the CUDA 13.2 toolkit
- `packs/checksums.sha256` — hashes of the published speech packs

The H100 machine is Windows. CUDA toolkit 13.2 under driver 597.95. PyTorch publishes that line as Windows `cu130` wheels (`win_amd64`), not `cu132` and not Linux. If that wheel is missing, the script writes `vendor/h100/CUDA13_WHEEL_MISSING.txt` and stops. Do not downgrade driver 597.95.

## Which directory goes where

| Path | Machine | What it is |
| --- | --- | --- |
| `vendor/windows/jdk` | This PC | Eclipse Temurin JDK 17, expanded. `jdk-home.txt` is `JAVA_HOME` |
| `vendor/gradle/gradle-8.13-bin.zip` | This PC | Gradle distribution used by `stt-android/gradlew.bat` |
| `vendor/gradle-user-home` | This PC | Gradle cache from the first `assembleDebug`. Required for a later offline rebuild |
| `vendor/maven` | This PC | sherpa-onnx 1.13.6 AAR |
| `vendor/windows/vc_redist.x64.exe` | Windows H100 | Microsoft Visual C++ 2015-2022 x64. PyTorch needs it. Install this before Miniconda |
| `vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` | Windows H100 | Python 3.12 installer. Copy this file to the H100. Do not install `Miniconda3-latest-Windows-x86_64.exe` |
| `vendor/h100` | Windows H100 | `cu130` wheels for Windows (`win_amd64`, Python 3.12) and the lock file |
| `vendor/packs` | H100 and this PC | Published int8 packs and Silero VAD. Not training data |
| `vendor/checkpoints` | Windows H100 | Parakeet `.nemo` for the NeMo environment, and `Qwen3-ASR-0.6B-hf` for the Chinese environment (`transformers` 5.18). Both use the Windows cu130 wheel |

Datasets are not in this bundle. See `training/DATASETS.md`.

## Check a copy

On either machine, from the repo root in Command Prompt:

```
certutil -hashfile vendor\gradle\gradle-8.13-bin.zip SHA256
```

Compare the hash with the matching line in `vendor/checksums.sha256`. Letter case does not matter. The H100 weight files and the two installers are in that same file.
