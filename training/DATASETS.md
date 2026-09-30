# Datasets and base models

Every corpus and every base model needs a row before it is used. Raw audio stays on the H100 after you copy it from this PC. The H100 does not download data.

License status `Pending` means: do not train on it yet. Fill the row after you read the license.

On this PC the only audio is an English sample and a Chinese sample. Korean training uses the project corpus, copied in by hand. Public Korean corpora are not downloaded.

| Language | Path | Split | Status |
| --- | --- | --- | --- |
| English | `data/en/librispeech-sample` | 6 train, 2 test | Allowed |
| Chinese | `data/zh/aishell-sample` | 6 train, 2 test | Allowed |

## Base models

| Name | Use | License | Redistribute derived weights | Status |
| --- | --- | --- | --- | --- |
| Parakeet TDT 0.6B v2 | English baseline and fine-tune | CC-BY-4.0 | Yes, with attribution | Allowed |
| Qwen3-ASR-0.6B | Chinese baseline and LoRA fine-tune | Apache-2.0 | Yes | Allowed |
| SenseVoice-small int8 | Korean interim pack | See the FunASR / sherpa-onnx model card | Not confirmed | Not used |
| sherpa-onnx 1.13.6 AAR | Android runtime | Apache-2.0 | Yes | Allowed |
| Public icefall Korean Zipformer | Korean evaluation baseline | Check the model card before any use beyond scoring | Not confirmed | Not used |

## English

| Corpus | Role | License | Hours | Status |
| --- | --- | --- | --- | --- |
| GigaSpeech, podcast and interview portions | Conversational fine-tune | Agreement required | Pending | Pending |
| People's Speech, conversational subset | Conversational fine-tune | CC BY or CC BY-SA, per file | Pending | Pending |
| Common Voice English | Microphone and speaker diversity only. These are read prompts, not conversation | CC0 | Pending | Pending |
| LibriSpeech | Read-speech sample in `data/en/librispeech-sample`. The 960-hour archive is not downloaded | CC BY 4.0 | 8 clips | Allowed |
| Project voice messages, English | Product test set. Hold out a portion | Recorded by this project | Pending | Not downloaded. Record on a phone |

## Chinese

| Corpus | Role | License | Hours | Status |
| --- | --- | --- | --- | --- |
| WenetSpeech, talk and interview subsets | Conversational fine-tune | Agreement required | Pending | Pending |
| MagicData-RAMC | Conversational fine-tune | Check before use | Pending | Pending |
| Common Voice Chinese | Microphone diversity only | CC0 | Pending | Pending |
| AISHELL-1 | Read-speech sample in `data/zh/aishell-sample`. The 178-hour archive is not downloaded | Apache-2.0 | 8 clips | Allowed |
| Other open read-speech sets (MagicData, Primewords, aidatatang, THCHS-30, ST-CMDS) | Small replay set only | Check each card | Pending | Pending |

## Korean

Korean training is from scratch. The architecture is NeMo FastConformer-Transducer. The corpus is this project's own audio, with the same layout as the English and Chinese samples. Do not download KsponSpeech, AI Hub, Zeroth-Korean, Common Voice Korean, or FLEURS Korean.

| Corpus | Role | License | Hours | Status |
| --- | --- | --- | --- | --- |
| Project Korean corpus | From-scratch training. Place it at `data/ko` with `train/` and `test/` plus transcripts | Recorded by this project | Project set | Allowed. Not stored in this bundle. Copy it to the H100 |

## Not in the first bundle

`vendor/fetch-online.ps1` does not download corpora. The only audio copied from this PC is the English sample and the Chinese sample above. A later fetch on this PC may download another English or Chinese corpus only after its row says Allowed. Do not fetch corpora on the H100. The train commands are `docs/manual-training.md`.
