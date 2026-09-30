# Korean training

Korean is a FastConformer-Transducer trained from scratch on this project's own audio. There is no pretrained Korean checkpoint. Public corpora are not used: do not download KsponSpeech, AI Hub, Zeroth-Korean, Common Voice Korean, or FLEURS Korean.

Training runs on the Windows H100 in the NeMo environment, the same `sr-en` environment as English. It does not use the Chinese environment. The machine has no network. The commands to type are in `docs/manual-training.md`. Install that environment before the steps below.

## Architecture

`fastconformer_transducer_bpe.yaml` is the NeMo large FastConformer-Transducer recipe, about 120M parameters. `train_from_scratch.py` loads that file and builds `EncDecRNNTBPEModel` with random initial weights.

The audio front end is 80-dim mel features at 16 kHz, 25 ms window, 10 ms stride. The encoder is a Conformer: 17 layers, hidden size 512, 8 attention heads, convolution kernel 9, depthwise-strided subsampling by 8. The prediction network is a one-layer RNN with hidden size 640. The joint network is also hidden size 640. The loss is RNN-T. The vocabulary is the SentencePiece model described below, not a fixed character list.

`train_from_scratch.py` overrides the recipe for this machine:

| Setting | Value used for training |
| --- | --- |
| GPU | 1 |
| Precision | bf16 |
| Epochs | 100 |
| Strategy | `auto` (one GPU, so no multi-GPU process group) |
| Batch size | 64, lowered to the smaller of the train count and the val count |
| Data workers | 0 on Windows |
| Optimizer | AdamW, learning rate `5e-3`, from the yaml. The script does not change it |
| Scheduler | Cosine annealing, 15000 warmup steps, minimum learning rate `5e-4` |

A finished run writes `training/ko/exp/fastconformer-ko.nemo`.

Clips shorter than 0.1 s or longer than 16.7 s are left out by the yaml. The product records about 2–60 s, so a clip longer than 16.7 s is not in this run unless `max_duration` in the yaml is raised first.

## Corpus layout

Copy the project corpus to `D:\SR\data\ko`. That `data` directory is the one that contains `en`, `zh`, and `ko`.

Use the same pairing as the English and Chinese samples. One of these three layouts is enough.

A transcript file named `*.trans.txt` sits next to the audio. Each line is the utterance id, a space, then the text. The audio file has that same id and an extension `.wav`, `.flac`, `.mp3`, or `.ogg`.

```
ko/train/spk/utt0001.wav
ko/train/spk/train.trans.txt
ko/test/spk/utt0901.wav
ko/test/spk/test.trans.txt
```

`train.trans.txt` contains lines like:

```
utt0001 the meeting ends here
utt0002 we will talk again tomorrow
```

Or put a text file beside each clip, with the same stem: `utt0001.wav` and `utt0001.txt`. The text file is the transcript only.

Or use an AISHELL-style list named `aishell_transcript*.txt`, first field the wav stem, then the text. The wav files can live anywhere under `ko`.

Anything whose path contains `/test` or `/dev` is validation. Everything else is train. If you have train audio and no `test` or `dev` directory, prepare holds out 1 of every 50 train rows for validation.

## Manifests

`build_manifest.py` does not download audio. It writes two JSONL files next to the corpus:

- `D:\SR\data\ko\train_manifest.jsonl`
- `D:\SR\data\ko\val_manifest.jsonl`

Each line is one utterance:

```json
{"audio_filepath": "D:\\SR\\data\\ko\\train\\spk\\utt0001.wav", "duration": 3.5, "text": "the meeting ends here"}
```

`audio_filepath` is an absolute path. `duration` is seconds. `text` is the transcript with the whitespace collapsed to single spaces. Both files must contain at least one row. A path under `test` lands in the val file, as in this line:

```json
{"audio_filepath": "D:\\SR\\data\\ko\\test\\spk\\utt0901.wav", "duration": 2.8, "text": "yes I understand"}
```

## Tokenizer

The tokenizer is SentencePiece byte-pair encoding, trained from the train-manifest text only. Audio is not read. English and Chinese do not use this step. They keep the tokenizers shipped inside Parakeet and Qwen3-ASR.

`prepare_tokenizer.py` runs after the manifests exist. The script requires at least 100 non-empty train transcripts. Fewer than that and it exits 2 with `Need at least 100 transcript lines to train the tokenizer.` It writes `D:\SR\data\ko\tokenizer\`:

| File | Contents |
| --- | --- |
| `corpus.txt` | One transcript per line, in manifest order |
| `tokenizer.model` | SentencePiece model. This is the file training loads |
| `tokenizer.vocab` | The piece list written beside that model |

The trainer settings are vocab size 5000, model type `bpe`, character coverage 0.9995, and no beginning-of-string or end-of-string ids. The FastConformer config sets `tokenizer.type` to `bpe` and `train_from_scratch.py` sets `tokenizer.dir` to this directory.

Run `prepare_tokenizer.py` again after the transcripts change. An old `tokenizer.model` does not match new text.

## Commands

From the repo root, in the NeMo environment. The three `set` lines keep Hugging Face off the network for that window:

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

`toy_gpu_step.py` must print the H100 name and exit 0. Exit 2 means this PyTorch build cannot see CUDA.

The epoch count is the `--max-epochs` default of 100 inside `train_from_scratch.py`. The batch-size default there is 64.

When training ends, the script prints `saved` and the path `training\ko\exp\fastconformer-ko.nemo`.

## What exits 2

- `D:\SR\data\ko` has no audio and transcript pairs
- The train manifest has fewer than 100 lines, so the tokenizer is not written
- `tokenizer.model` is missing when training starts
- Either manifest is empty
- CUDA is not available in the `sr-en` environment

`training/ko/export.sh` exits 2 on purpose. Pack export stays off until this model has been scored on the project held-out set. SenseVoice and the public icefall Zipformer are not part of this training run.
