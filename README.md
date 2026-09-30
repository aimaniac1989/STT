# Speech to text

Three projects. Training and the Android app meet only at `packs/PACK.md`. Inference reads the checkpoints training writes.

- `stt-android/` is the Android app. Build it on this PC. Read `docs/manual-windows.md`.
- `training/` runs on the offline H100. Type the Python commands in `docs/manual-training.md`.
- `inference/` transcribes audio with a trained or fine-tuned checkpoint on that same H100. Type the Python commands in `docs/manual-inference.md`.

Download dependencies once, on this PC, with `vendor/fetch-online.ps1`. The H100 does not download anything. On that machine, install `vendor/windows/vc_redist.x64.exe` and then `vendor/windows/Miniconda3-py312_25.7.0-2-Windows-x86_64.exe` before the commands in `docs/manual-training.md`.
