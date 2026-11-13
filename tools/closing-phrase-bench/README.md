# Closing-phrase bench (#932)

Measures how often a speech engine writes words after the last spoken word of a
dictation ("Vielen Dank.", "Merci.", "you", "*Ruhige Musik*"), and the word error rate
on the whole dictus-test-voices corpus, per engine, language and recording tail.

## Run

```bash
cd tools/closing-phrase-bench
swift build -c release --scratch-path ../../build/closing-phrase-bench/spm
cd ../..
B=build/closing-phrase-bench/spm/release/closing-phrase-bench
$B --corpus ~/dev/dictus-test-voices --engine openai_whisper-large-v3-v20240930_turbo_632MB --out before.tsv
$B --corpus ~/dev/dictus-test-voices --engine openai_whisper-large-v3-v20240930_turbo_632MB --trim --out after.tsv
python3 -I tools/closing-phrase-bench/score.py ~/dev/dictus-test-voices before.tsv after.tsv > report.md
```

`--engine` takes a WhisperKit variant (downloaded once into
`build/closing-phrase-bench/models`) or `parakeet-v3` (FluidAudio's cache). About six
minutes per engine on an M-series Mac. Runs on macOS, so speed numbers say nothing
about an iPhone; the text does, since the model weights and decoding options are the
ones the app ships.

## What it runs

- WhisperKit 0.18.0 and FluidAudio 0.15.8, the versions DictusApp resolves.
- Whisper: the `DecodingOptions` of `WhisperKitEngine.transcribe`, language forced to the
  clip's. Parakeet: the first pass of `ParakeetEngine.transcribe`; the drift retry
  (#623) is not run.
- Every result goes through `NonSpeechMarkers.spokenText`, as in `TranscriptionService`.
- `--trim` sends `TrailingSilence.trimmed(samples)` instead of the samples, which is what
  the app does since #932.

Each of the 20 clips is decoded six ways:

| tail | what the microphone recorded |
|---|---|
| `clean` | the clip as is |
| `zero-3s` | the clip, then 3 s of digital silence |
| `quiet-3s`, `quiet-8s` | room noise at -65 dBFS under the clip, then 3 or 8 s of it |
| `noisy-3s`, `noisy-8s` | room noise at -45 dBFS under the clip, then 3 or 8 s of it |

The levels bracket the pauses of iPhone recordings in dictus-asr-audio (-76 to -44
dBFS). The noise is seeded white noise, the same on every run.

## Scoring

`score.py` lowercases and strips punctuation as `WHISPER_CHECK.md` does, aligns words
(characters for Mandarin), and reports the WER plus the share of decodes with at least
one word inserted after the last expected word: an invented ending. Numbers are not
normalized, so `9h30` against `9 heures 30` counts as errors on both sides of a
comparison alike.

## Limits

- TTS voices, no real room: white noise is not a café. A room within 20 dB of the voice
  is not trimmed at all, by design.
- Greedy decoding at temperature 0 is deterministic, but each tail is one sample.
- The corpus is not modified; the bench reads it.
