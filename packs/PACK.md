# Language pack contract

`training/` writes a pack. `stt-android/` loads a pack. `inference/` reads the checkpoint training just wrote and does not write a pack. The three projects do not share code. This file is the only interface between training and the app.

A pack is a directory plus `pack.json` in that directory. Model weights are not committed. `vendor/fetch-online.ps1` downloads the published baseline packs into `vendor/packs/` and writes their SHA-256 hashes to `packs/checksums.sha256`.

## pack.json

```json
{
  "language": "en",
  "model_type": "nemo_transducer",
  "version": "parakeet-tdt-0.6b-v2-int8",
  "emits_punctuation": false,
  "min_free_ram_mb": 2048,
  "min_sherpa_onnx_version": "1.12.0",
  "files": [
    {"name": "encoder.int8.onnx", "sha256": "<64 hex chars>", "size_bytes": 0}
  ]
}
```

Fields:

- `language`: `en`, `zh`, or `ko`
- `model_type`: `nemo_transducer`, `qwen3_asr`, `paraformer`, `sense_voice`, or `transducer`
- `version`: pack version string, unique per language
- `emits_punctuation`: `true` when the model already writes punctuation (Qwen3-ASR, SenseVoice). `false` for the transducers, which need the punctuation model shipped in the APK
- `min_free_ram_mb`: the app refuses the pack when free RAM is below this
- `min_sherpa_onnx_version`: the app refuses the pack when the bundled sherpa-onnx AAR is older. Qwen3-ASR needs a recent build
- `files`: every file the recognizer loads, relative to the pack directory. `sha256` is lowercase hex. `size_bytes` is the file size

The app checks every hash before load and refuses an unknown `model_type`.

## Baseline packs

| Language | model_type | Published archive | Notes |
| --- | --- | --- | --- |
| en | nemo_transducer | sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8.tar.bz2 | CC-BY-4.0. About 640 MB unpacked. `min_free_ram_mb` 2048 |
| zh | qwen3_asr | sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25.tar.bz2 | Apache-2.0. About 1.9 GB unpacked. `min_free_ram_mb` 4096. `min_sherpa_onnx_version` 1.12.15 |
| ko | sense_voice | sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2 | Not used. `training/DATASETS.md` keeps this pack off the phone until that row says Allowed |

`transducer` is reserved for an icefall Zipformer export. `paraformer` is reserved if the Chinese phone-speed check rejects Qwen3-ASR.

## Files that are not packs

Silero VAD (`silero_vad.onnx`) and the sherpa-onnx punctuation models ship inside the APK. They are small and shared by every language. The fetch script still downloads Silero VAD into `vendor/packs/` so the app build can copy it later.

## Export

`training/<lang>/export.sh` writes a directory that matches this file. It must refuse to write a pack whose int8 transcripts differ from fp32 on the 50-utterance check described in `docs/manual-h100-offline.md`.
