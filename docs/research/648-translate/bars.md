# Translate renders the spoken draft word by word (#648) — plan and bars

**Issue:** [#648](https://github.com/getdictus/dictus-ios/issues/648). The contract is the two
maintainer comments of 2026-10-05 (13:29: six fixtures, bar (e), N ≥ 3; 14:14: arms A to E, the
cleaning pass as an internal step of Translate). This file covers **step 1 of the "Order of work"
only**: the harness bench. Step 2 (device probe) and step 3 (ship the winner) are out of scope.
**Date:** 2026-10-05. **Machine:** macOS 27.0 (26A428), Xcode 27.0 SDK, Apple Intelligence on.
**Baseline:** `develop` at `66b1f85f`, `SmartModeTranslatePrompt` untouched since #587.

> Written and committed **before the first model call on a fixture**. The commit that adds this
> file adds no Swift.

**Disclosed, because the commit order is the evidence:** before writing these bars I ran a
throwaway feasibility probe (a SwiftPM executable in `/tmp`, not committed) to answer the brief's
stop condition, "can the Translation framework run headless from a SwiftPM executable on this
Mac". It made **two Translation-framework calls on one synthetic sentence, not a fixture**:
`Salut, je viens de faire le rendez-vous avec Bernard, ça s'est bien passé. Il faut passer à la
phase de marketing.` `.lowLatency` threw `notInstalled`; `.highFidelity` returned `Hi, I just made
the appointment with Bernard, it went well. We need to move to the marketing phase.` (1 670 ms).
The sentence borrows two spans the 13:29 comment already lists as errors, so it told me nothing
the bars below did not already contain. No Apple FM call and no fixture call has been made.

## 1. What the probe established (measured, this Mac)

| Question | Answer |
|---|---|
| `LanguageAvailability(preferredStrategy: .highFidelity).status(fr → en)` | `installed` (also `it → en`) |
| `LanguageAvailability(preferredStrategy: .lowLatency).status(fr → en)` | `supported`, **not installed**; `translate` throws `TranslationError.notInstalled` |
| `TranslationSession.canRequestDownloads` from a CLI process | `false`, both strategies |
| `en → en` | `unsupported` (the framework refuses a same-language pair) |
| A session built for `fr` handed Italian or English | returns the input **untranslated**, no error |
| A newline in the input | comes back as a blank line (`\n` → `\n\n`) |

Consequences for the plan:

- **Arm B cannot run headless.** Installing the classic fr ↔ en model needs System Settings, and
  the brief forbids triggering a download UI. Arm B goes on the manual list with the exact steps
  and one command to run it; the harness supports it, and a B run on this Mac is committed anyway
  so the `notInstalled` failure is on record rather than asserted.
- **The translator needs the source language.** A wrong source fails silently (untranslated text,
  no error), so the engine passes the language the pipeline already measures (`PolishLanguageMix`
  dominant code) and, when source equals target, returns the input unchanged, which is what rule 8
  of the shipped prompt asks for an input already in the target.
- **Line breaks are carried by splitting on `<<NL>>`**, translating each segment, and re-joining
  with the marker, so the doubled newline never reaches the pipeline.

## 2. What changes, and every consumer of it

Nothing that ships changes. Step 3 ships the winner; this PR measures.

| Change | Where | Consumers |
|---|---|---|
| A `translate` command: runs one arm over a fixture file, scores bars (a) to (e) | new `polish-harness/TranslateRound.swift`, dispatched in `main.swift` | none outside the harness; the harness is macOS-only, excluded from every app target and from CI |
| A Translation-framework engine (`PolishEngineProtocol`) | same file | the `translate` command only |
| A two-pass engine: Apple FM cleaning pass → translator | same file, reusing `FramedAppleFMPolishEngine` for pass 1 | the `translate` command only |
| The cleaning-pass prompt | `docs/research/648-translate/prompts/clean-v1{,-framing}.txt` | passed by path (`--clean`); **not** in DictusCore, **not** a Smart Mode, no catalogue entry |
| README of the harness | `polish-harness/README.md` | readers |

`SmartModeTranslatePrompt`, `SmartModeCatalogue.translate(to:)`, `PolishPipeline`, the contract and
every app target are read, never written. `swift test` and `swiftlint --strict` still have to stay
green because the harness compiles inside the `DictusCore` package.

## 3. The arms (the 14:14 comment's table)

Every arm runs through the **real `PolishPipeline`** under the shipped `translate.en` mode: same
pre-pass, same `<<NL>>` encoding, same gates, and the shipped Translate contract
(`0.40–3.00`, output = English) judging the final output. Only the engine differs.

| Arm | Pass 1 | Translator | Command flags |
|---|---|---|---|
| A (baseline) | none | Apple FM, shipped prompt | `--translator apple-fm` |
| B | none | Translation `.lowLatency` | `--translator translation-framework --strategy lowLatency` — **blocked here, §1** |
| C | none | Translation `.highFidelity` | `--translator translation-framework --strategy highFidelity` |
| D | Apple FM clean (`clean-v1`) | Translation `.highFidelity` | C + `--clean … --clean-framing …` |
| E | Apple FM clean (`clean-v1`) | Apple FM, shipped prompt | A + `--clean … --clean-framing …` |

**6 fixtures × 3 runs = 18 calls per arm** (the 13:29 comment: N ≥ 3). Fixtures:
`.local-corpus/648-translate/fixtures.json`, the six device raws, read in place and never copied
into the repo. Latency is recorded **per pass** (cleaning ms, translator ms) and in total.

The fixture file says `lang: "fr"`; the device export says `transcriptionMode: autoDetect`. The
per-language route is used as the file declares. For a Smart Mode the two routes differ only in
the verbal-punctuation pre-pass, and none of the six raws dictates punctuation.

## 4. The bars

Per fixture, by hand, in `bars.json` (one entry per fixture, plus `*` for every fixture). The
fixture `translate-fr-05` is a personal opinion: its public entry carries only the spans the 13:29
comment already quotes, and its full lists are in
`.local-corpus/648-translate/bench/bars-private.json`,
**SHA-256 `3f2a19f06e0c5f976a87842dae19e0dbb763749dfef7e53fd08b4a85bbe4b623`**, so this commit
binds them without publishing them.

| Bar | Question | Mechanical check | Where judgement is needed |
|---|---|---|---|
| **(a)** | No self-correction, false start, restart or verbal tic survives | `drop[].forbid`: the literal English renderings of each disfluency in the raw | A disfluency rendered with a word the regex did not foresee. Every output is read. |
| **(b)** | No information from the intended message is lost | `keep[].require`: one pattern per fact the speaker meant | A pattern can match a sentence that lost the fact around it; every output is read |
| **(c)** | Nothing is added | `add[].forbid` (`*` + per fixture): placeholders, sign-offs, the device inventions (`a tool`, `keypad`) | Any other invention. Read. |
| **(d)** | Output language and register hold | Language: the pipeline's own contract check (`fixed(.english)`) plus `NLLanguageRecognizer` on the engine output | Register is read against `register` in `bars.json`; no regex measures it |
| **(e)** | No meaning inversion, no wrong word sense | `critical[]`: a `forbid` for the device error and, where one exists, a `require` for the right sense | A third rendering that is neither; read |

A run is scored on the **engine's output**, like `summary` and `fidelity` do, and its pipeline
outcome is reported beside it: a refused run inserts nothing, which is a failure of the arm on its
own count (refusals), not a pass of bars it never reached.

**Mechanical flags are candidates, not verdicts.** Every output is read; where the reading
overturns a flag (a false positive) or adds one the regexes missed, the README says so per run and
says it is judgement.

### 4.1 Thresholds, written before the numbers

An arm is **shippable** only if, over its 18 runs:

| Bar | Threshold |
|---|---|
| (c) additions | **0/18** |
| (d) not English, or register lifted | **0/18** |
| (e) inversion or wrong sense | **0/18** on the inversions (`skip`, `no longer`); wrong-sense rate reported |
| refused by the pipeline | **≤ 1/18** |
| #412 regression (§4.2) | no bar worse than #412 measured |

Among shippable arms the recommendation goes to the one with the fewest (a)+(b)+(e) failures.
Latency is a gate for step 3, not here: a Mac number is not a device number (#412 §4.5), so an arm
whose Mac latency more than doubles arm A's is flagged for the step-2 probe to price against
`PolishTimeBudget` (15 s floor, 40 ms per character), not rejected.

No arm is expected to clear (a) and (e) everywhere. If none is shippable, that is the result.

### 4.2 #412's 30/30 bars must not regress

Re-run on `fixtures/translate-en.json` (6 fixtures × 5 runs = 30, as #412 did), on every arm the
§4.1 thresholds leave shippable, plus arm A as the control:

| Bar | #412 measured | Checked by |
|---|---|---|
| A1 accepted output not English | 0/30 | the contract |
| A2 refuses a translation it should have made | 0/30 | outcome |
| A3 invents greeting / sign-off / name | 0/30 | fixture `expect` + `*` additions + reading |
| A4 proper noun lost | 0/30 | fixture `expect` (`Sophie`, `deadline`, `dentist`, `friday`) |
| A5 `<<NL>>` leak or lost line break | 0/30 | fixture `expect` on T5 (`\n` present, no marker) |

T3/T4 (Italian) and T6 (already English) matter more for the Translation framework than for Apple
FM, because of §1: the framework needs the right source and refuses `en → en`.

## 5. Order of work

1. This file, `bars.json`, the cleaning prompt. No Swift. **Commit.**
2. The harness command and the two engines. Lint, `swift test`. **Commit.**
3. Arms A, C, D, E on the six fixtures; arm B once to record `notInstalled`. Captures: full text
   private, redacted copy committed. **Commit.**
4. #412's bars on the shippable arms. **Commit.**
5. README: method, table, latency, verdict, recommendation for step 3, the step-2 probe procedure.

## 6. Risks

- **One cleaning prompt, one round.** A bad pass-1 result says `clean-v1` is not good enough, not
  that a cleaning pass cannot work. Reported as such.
- **The Mac's Apple FM and Translation models are not the device's.** Quality transfers, latency
  does not (#412). The iOS 27.0.1 device and macOS 27.0 here are the same OS generation, which is
  the best available match.
- **The bars are mine.** The 13:29 comment's table is the seed of (e); the rest is my reading of
  six French raws. A reader who disagrees with a list can re-read every output: the capture
  stores them all, with the flags each one raised.
- **n = 3.** A rate of 1/18 is a discovery, not a measurement, as #412 said of its own samples.

## 7. Round 2 — `clean-v2`, added after round 1 and committed before it ran

Round 1 (arms A to E, `runs/arm-*.txt`) showed `clean-v1` barely cleaning: it removed a
self-correction only when `enfin` marked it, kept an unmarked false start, kept every opener tic,
repaired no speech-to-text slip, and added the `ne` of a negation in fixture 05 (3/3) and 06
(1/3), against its own rule 7. `prompts/clean-v2.txt` targets those four failure classes and
nothing else: false starts without a marker (rule 2), opener tics (rule 3), the sound-alike /
dropped-short-word repair (rule 5), and a counter-example for the added `ne` (rule 7).

**v2 is in-sample.** It was written after reading v1's outputs on these six fixtures, and its
lists name tics that occur in them (`aussi`, `écoute`, `concrètement`, `à ce moment-là`) and a
short word one of them dropped (`à`). Its examples and counter-examples share no sentence with the
fixtures. A gain measured here is an upper bound on what v2 would do on unseen dictations, and is
reported as such.

Arms D2 and E2 are D and E with `clean-v2`; the bars, thresholds and fixtures are unchanged.
