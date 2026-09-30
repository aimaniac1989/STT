---
name: Offline Setup Manuals
overview: "Before any model work, this Windows PC collects every dependency for both subprojects into a vendor bundle, plus two English manuals: one to build the Android app here, and one to install and train on the offline H100."
todos:
  - id: scaffold-dirs
    content: Create training/{en,zh,ko}, stt-android Gradle shell, packs/PACK.md, and training/DATASETS.md in English only.
    status: in_progress
  - id: vendor-fetch
    content: Add vendor/README.md and vendor/fetch-online.ps1 that downloads the Windows JDK, Maven mirror, H100 wheels, and the three published int8 packs, and writes checksums.
    status: pending
  - id: manual-windows
    content: Write docs/manual-windows.md for a from-scratch Android build using the existing SDK and the vendored JDK and Maven artifacts.
    status: pending
  - id: manual-h100
    content: Write docs/manual-h100-offline.md for copying the bundle to the air-gapped H100 and installing it with no network, including the CUDA 13 wheel stop condition.
    status: pending
isProject: false
---

# Offline setup: vendor bundle and manuals

The H100 server has no network. This Windows PC is where everything is downloaded, then copied across. Nothing in [training/](training/) may assume `pip install` or `git clone` works on the server.

This PC today: Git 2.47 is installed. Android SDK is at `%LOCALAPPDATA%\Android\Sdk` with platform `android-37.0` and build-tools `36.0.0`. There is no JDK on PATH and no Python on PATH. Both manuals start from that state.

## What gets added

- [docs/manual-windows.md](docs/manual-windows.md) — install JDK 17, point Gradle at the existing SDK, build [stt-android/](stt-android/) with no further downloads.
- [docs/manual-h100-offline.md](docs/manual-h100-offline.md) — copy the bundle onto the Windows H100 (driver 597.95, CUDA 13.2 already installed; do not change the driver), install from local files only, run one GPU step.
- [vendor/README.md](vendor/README.md) — exact list of files, versions, checksums, and which machine each file is for.
- [vendor/fetch-online.ps1](vendor/fetch-online.ps1) — run once on this PC while it has internet. Downloads into `vendor/` and writes checksums. Re-running skips files that already match.

`vendor/` is gitignored except `README.md` and the checksum list. The bundle is copied to the H100 by disk or internal transfer, not by cloning.

## Windows bundle (this PC)

- Eclipse Temurin JDK 17 (the Android Gradle build needs it; the SDK alone is not enough).
- Gradle wrapper jar committed inside [stt-android/](stt-android/), so Gradle itself is not a separate install.
- Android Gradle Plugin and sherpa-onnx Maven artifacts mirrored under `vendor/maven/` so the app build works if this PC is later offline too.
- The manual uses the SDK already on disk (`android-37.0`, build-tools `36.0.0`). It does not download another SDK.

## H100 bundle (copied from this PC)

Pinned in `vendor/README.md` after the fetch script records the real filenames:

- Python 3.12 Windows Miniconda installer, plus a `requirements-lock.txt` of wheels built for Windows win_amd64 and CUDA 13 (`cu130`).
- PyTorch wheel for CUDA 13 (bf16 on H100). If the CUDA 13 wheel index has no matching file, the manual says so and stops. It does not tell you to downgrade driver 597.95.
- NeMo, lhotse, transformers, peft, sentencepiece, and the sherpa-onnx export scripts as wheels or source tarballs.
- k2 is not in the default bundle. It is added only if Korean falls back to the icefall Zipformer recipe, and the manual says to build it from the vendored source against the vendored PyTorch.
- Published model packs used before any training: Parakeet TDT 0.6B v2 int8, Qwen3-ASR-0.6B int8, SenseVoice-small int8, Silero VAD. Checksums go in [packs/](packs/).

Datasets are not in the first bundle. [training/DATASETS.md](training/DATASETS.md) lists them, and a later fetch step downloads each corpus on this PC only after its license row is filled in. The H100 never fetches data itself.

## Manual contents

Windows manual: install JDK, set `JAVA_HOME` and `ANDROID_HOME`, open [stt-android/](stt-android/), `gradlew.bat assembleDebug`, where the APK is written, and what to do if the SDK path differs.

H100 manual: copy `vendor/h100/` to the server, create the environment from local wheels only, confirm `nvidia-smi` shows the H100 and CUDA 13.2, import torch and run one matmul on GPU, then run the toy step in [training/](training/). Any step that needs the network is marked as a failure, not as a workaround.

## Order

This lands before the Android UI and before any training recipe. Scaffold of [training/](training/), [stt-android/](stt-android/), and [packs/PACK.md](packs/PACK.md) still comes first so the manuals have real paths to point at. The fetch script and both manuals are the next commit after that scaffold.