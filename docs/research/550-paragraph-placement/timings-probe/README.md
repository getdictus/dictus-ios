# Does Parakeet hand us token timings? (#550 §8)

A standalone SPM package, deliberately outside `DictusCore` so it cannot drift into
a shipping target. It depends on FluidAudio at the same pin the app uses
(`.upToNextMinor(from: "0.12.3")`) and calls the same
`AsrManager.transcribe([Float])` that `DictusApp/Audio/ParakeetEngine.swift:169`
calls — the line that keeps `result.text` and drops everything else.

It prints, per audio file: whether `tokenTimings` is nil, how many entries it holds,
the coverage window, and every inter-token gap of 0.15 s or more with the words on
each side.

## Run it

```sh
# French speech with deliberate silences, headless, no microphone:
say -v Jacques -o /tmp/probe.aiff \
  "Première phrase. [[slnc 1500]] Deuxième phrase, plus longue, avec une suite."
afconvert -f WAVE -d LEF32@16000 -c 1 /tmp/probe.aiff /tmp/probe.wav

cd docs/research/550-paragraph-placement/timings-probe
swift run probe /tmp/probe.wav
```

The first run downloads `parakeet-tdt-0.6b-v3-coreml` into
`~/Library/Application Support/FluidAudio/Models/` and compiles it, which takes a
few minutes. Later runs load from that cache.

`say` is synthetic speech. It settles whether the field carries data and whether a
silence reaches it; it says nothing about how a human voice distributes pauses.

The numbers this produced are in `findings.md`.
