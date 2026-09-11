# Paragraph placement — measured (#550)

**Bars and plan:** `bars.md`, committed before the first arm call (`249ea37`).
**Instrument:** `swift run polish-harness paragraph`, committed before the first arm
call (`f5aafda`).
**Arms:** `arms/`, one JSON file each. **Raw captures:** `raw/`. **Machine capture:**
`captures/`. **Reported, never barred:** `score.py`.
**Where:** Mac, macOS 26, Apple Intelligence on, 2026-09-11.

Everything below is Apple FM on a Mac. Nothing here was confirmed on a physical
iPhone, and nothing here ran through `PolishPipeline` — see §Limits.

---

<!-- VERDICT -->

## What this round was for

#437 asked whether Normal polish could be licensed to break paragraphs **at a change
of subject**, measured it over 432 outputs and twelve arms, and closed with no. The
maintainer's reading on 2026-09-11 is that the criterion was wrong, not the capability:

> Les paragraphes, moi je le fais naturellement. Comme je sais que Dictus fait des
> gros pavés, je m'arrête de parler, je termine la transcription, puis je recommence.
> […] C'est pas vraiment un changement de sujet, c'est quand même dans le sujet
> global, mais il y a un changement de contexte.

The issue opened on the hypothesis that followed — a silence at a sentence boundary
opens a paragraph — and **the maintainer's own four controlled recordings falsified
it** before this round started (`align.py`, `run.py`, and the comment of 19:16). Text B
breaks at the boundary carrying the least silence in one take and none at all in the
other, which no threshold produces.

What survived the falsification is what this round is built on:

1. **No break ever lands inside a sentence.** Seven breaks, five recordings.
2. **The reference is not finding a correct boundary.** It is choosing a plausible one,
   and it always chooses. Text A is the same four sentences split two different ways on
   two takes, both defensible.
3. **Nobody ever told the model how many breaks to place.** #437's isolated second pass
   held fidelity 30/30 and then put one break per sentence on one fixture and none on
   another. That is the untested variable.

So this round asks a **capability** question with the lightest possible prompts, and it
is explicitly not a prompt round: the shipping prompt is exhausted,
`PolishPromptParityTests` pins the ban, and re-wording rule 5 is a re-run.

<!-- ROUND -->

<!-- LIMITS -->

## Timings — the issue body's first technical step, settled

The issue body gates its own acoustic route on one question and calls it the first
technical step: *is `ASRResult.tokenTimings` actually populated at runtime for
Parakeet, or merely declared optional in the type?* `DictusApp/Audio/ParakeetEngine.swift:169`
keeps `result.text` and drops the rest.

The pause hypothesis is dead, so nothing in this round depends on the answer. It is
settled anyway, because it is cheap and it tells any future attempt whether there is a
signal to work with. Measured headlessly on this Mac, against FluidAudio at the pinned
`0.12.3`, through the same `AsrManager.transcribe([Float])` the app calls.
`timings-probe/` is the package; it drives no Apple Foundation Model.

**It is populated. Never nil, one entry per subword token, on both code paths.**

| Clip | Seconds | Path | `tokenTimings` | Entries | Coverage |
|---|---|---|---|---|---|
| no deliberate pauses | 14.0 | single window (≤ 240 000 samples) | non-nil | **91** | 0.00 → 13.92 s |
| one 1.5 s pause | 8.8 | single window | non-nil | **45** | 0.00 → 8.72 s |
| two 1.2 s pauses | 22.1 | `ChunkProcessor` | non-nil | **130** | 0.00 → 22.08 s |
| two 1.5 s pauses | 22.7 | `ChunkProcessor` | non-nil | **133** | 0.00 → 22.64 s |

**And a deliberate silence does reach the field, as an inter-token gap.** On the 8.8 s
clip the single inserted 1.5 s pause is the **only** gap of 0.15 s or more in the
recording, at 0.80 s. On the 22.7 s clip the two inserted 1.5 s pauses are the two
largest gaps, 0.56 s and 0.72 s, both immediately after a sentence-final full stop.

Three caveats, and they matter more than the headline:

- **The gap under-reports the silence by roughly half.** 1.5 s of inserted silence
  reads as 0.56–0.80 s, because the token durations either side absorb part of it and
  the encoder frame is 80 ms. A threshold fitted on wall-clock silence would not
  transfer to this field unchanged.
- **It is noisy.** The 22.7 s clip also shows a 0.40 s gap **inside a word**
  (`ch|antiers`) and 0.16 s gaps mid-phrase. The largest gaps are the real pauses here,
  but a bare threshold would fire on neither cleanly.
- **This is `say`, not a person.** Synthetic speech settles whether the field carries
  data and whether a silence reaches it. It says nothing about how a human voice
  distributes pauses, and the acoustic route is falsified on human recordings anyway.

So: the signal exists and is thrown away on one line. That is a fact about the code,
not an argument for using it — the hypothesis that wanted it is dead.

<!-- MANUAL -->
