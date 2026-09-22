# `Structuré` rewritten short — bars and plan (#587, PR 1)

**Issue:** [#587](https://github.com/getdictus/dictus-ios/issues/587), the Smart Mode prompt
campaign, grilled with Pierre on 2026-09-21. **Its body is the brief**; #570, #581, #585
and #523's 2026-09-20 verdict are context and point to it.
**Scope of this round:** decision 8's PR 1 only — `Structuré`'s prompt rewritten short on
`Message`'s skeleton, step 1 of the language ladder (decision 5.1), the example rules
(decision 4), the list rule (decision 7) and the narrow fabrication check (decision 6).
**Out:** PR 2 (`Message` and `Liste`), #570's guardrail half (decision 10), steps 2 and 3
of the ladder.
**Date:** 2026-09-21. **Machine:** macOS 27.0 (26A428), Xcode 26.4.1, Apple Intelligence on.

> **Everything in this file was written and committed before the first candidate call.**
> That is the discipline #439, #437, #550 and #570 ran on. No model call of any kind
> precedes it in this round: the Apple FM language list in §2 was read from
> `SystemLanguageModel.default.supportedLanguages`, which generates nothing.

---

## 1. What the round decides

One question per bar of decision 11, asked of **one** candidate prompt against the prompt
that ships today:

> Does a ~3 000-character `Structuré` prompt, built on `Message`'s skeleton, with rule 1
> naming the transcript's language, two worked examples in two languages and no
> counter-example block, hold the output language in every Apple FM language, stop
> fabricating the speaker-state closing line, stop turning prose into one bullet per
> sentence, and stay no worse than today on #583's fidelity axes?

**The Mac is not the gate.** PR #583's macOS 27 comment: the Mac reproduces the prompt
leaks and not the phone's rewriting. Decision 12's device round is the gate; this bench
decides only whether the candidate is worth putting on a phone.

### The language ladder's stop rule, fixed here

Decision 5: **any Apple FM language above 10 % wrong-language outputs** fails step 1. If
the candidate fails that, the round **stops and reports**. Step 2 (examples in the
transcript's language) and the `<TRANSCRIPT>`-tag variant are not tried in this PR — the
brief reserves the climb to Pierre's reading of the numbers.

A language-bar failure is also not answered by rewording rule 1 and re-running: that is a
search over wordings until one passes, and its pass would mean nothing.

### What may be iterated

A failure on bars B2–B4 (§4) may be answered by **at most two further candidates**, each
re-run on the **whole** bench, never on the fixture that failed alone. Every candidate is
committed as a file under `arms/` and reported, including the ones that lose.

## 2. The Apple FM languages, read from this Mac

```swift
// swiftc langs.swift && ./langs     (macOS 27.0, 2026-09-21)
import FoundationModels
for l in SystemLanguageModel.default.supportedLanguages { print(l.languageCode!, l.script!, l.region!) }
```

24 locales, **16 languages once regions are folded**:

| Code | Locales |
|---|---|
| `da` | da-DK |
| `de` | de-DE |
| `en` | en-AU, en-GB, en-IN, en-US |
| `es` | es-419, es-ES, es-US |
| `fr` | fr-CA, fr-FR |
| `it` | it-IT |
| `ja` | ja-JP |
| `ko` | ko-KR |
| `nb` | nb-NO |
| `nl` | nl-NL |
| `pt` | pt-BR, pt-PT |
| `sv` | sv-SE |
| `tr` | tr-TR |
| `vi` | vi-VN |
| `zh-Hans` | zh-Hans-CN |
| `zh-Hant` | zh-Hant-HK, zh-Hant-TW |

Chinese is benched as **two** languages, Simplified and Traditional: the language guardrail
compares `NLLanguageRecognizer` codes and those two are different codes, so a Traditional
dictation answered in Simplified is a wrong-language output for this bench.

## 3. Fixtures

| Set | File | What it is | Valid for |
|---|---|---|---|
| **R1** fidelity | `fixtures/device-structured-fr.json` (9) + `fixtures/longform-fr.json` (6) | #583's two sets, unchanged: Pierre's voice, French | all four fidelity axes, rule 7, the enumeration, prose bullets |
| **R2** new French device | `fixtures/device-structured-0918-fr.json` (new, 9) | Every `Structuré` French dictation of the exports of 2026-09-18 → 2026-09-20 that the bench needs: the three accepted fabrications, the bullet-per-sentence one, the person drift, one mid-text `autre chose` that is not an incompleteness | language, fabrication, prose bullets, fidelity |
| **R3** English device | `fixtures/device-structured-en.json` (new, 5) | Pierre's five English `Structuré` dictations of 2026-09-19/20 — **the #585 set**, all five refused on `check=language` on device | English 100 % English |
| **R4** translated | `fixtures/translated-structured.json` (new, 6 × 15) | Six of Pierre's French dictations, **machine-translated by the agent running this round** into English and the 14 other Apple FM languages | **output language only** |

R4 is clean written text: no hesitation, no Parakeet drift. The brief says so and this
file repeats it — **R4 measures which language comes back and nothing else**, never
fidelity. Its six sources, chosen to span length and shape before any call:

| id | Source | Chars (fr) | Shape |
|---|---|---|---|
| `T1-last-transcription` | `D8-last-transcription` | 65 | prose, short |
| `T2-no-error` | 2026-09-18T20:55:22Z | 152 | prose, short |
| `T3-plan-mode` | `D3-plan-mode` | 192 | prose, a request |
| `T4-structured-since` | 2026-09-19T06:56:01Z | 284 | prose — on device its output closed on the rule-7 example line verbatim |
| `T5-long-test` | 2026-09-20T14:29:19Z | 407 | prose — on device, one bullet per sentence |
| `T6-project-update` | `2-project-update` | 698 | **enumerates** two remaining items |

Routing: `fr`, `en`, `es`, `de` run the per-language path (the harness's fixture `lang`),
every other code runs the auto path — exactly what a user of that language reaches with
auto-detect, since explicit transcription exists only for the four.

### Prose, enumerating, and neither — declared before any output exists

Bar B3 needs a list of prose fixtures that the outputs cannot be allowed to redraw.

- **The enumerating fixture** (B3's "≥ 2 of 3"): **`2-project-update`** — *"Il reste deux
  trucs. Le premier c'est… Et le deuxième c'est…"*. The speaker counts off distinct items
  themselves; that is decision 7's licence exactly.
- **Excluded from the prose bar, as enumerating or arguably so:** `4-explanation`, `D1`,
  `D2` (three numbered steps), `5-rambling` (a spoken task list), `D9` (feedback points
  counted off with *enfin*), `2-project-update`, `R2`'s `F9-summary-and-stats` (*"et aussi,
  autre chose"*), `T6` in every language.
- **Prose — B3's zero applies:** every other fixture of R1–R4.

## 4. The bars (decision 11), each with its measurement

Every bar reads the **engine's** output (`engineOutput`), for the reason #583 §3 gives: a
refused output is still what the prompt produced. Where a bar says *accepted*, it means
`outcome = success`. A run with no engine output is in no denominator.

### B1 — output language (decision 5, step 1)

Per language, over every run of the candidate on R1–R4 whose fixture is in that language:

| Bar | Measured as |
|---|---|
| **B1a — 0 wrong-language output accepted** | an accepted output whose whole-text `NLLanguageRecognizer` reading is not the fixture's language, or which carries a sentence of ≥ 20 characters read as another language at ≥ 0.85 that is **not** a fragment the speaker said in that language. Flagged by code, adjudicated by hand, every flag listed by text in findings |
| **B1b — ≤ 10 % refused on `check=language`** per language | `rejectedCheck == language` over runs with engine output. **This is the ladder's stop rule** (§1) |
| **B1c — English 100 % English** | every engine output of R3 and of R4's `en` rows reads as English — accepted **or refused** |

B1b is read on the raw refusal count, as the brief states it. If a refusal turns out to be
the recogniser misreading a right-language output (the Scandinavian trio is the obvious
risk), findings reports it as such — but the bar is still read raw, and a failure still
stops the round.

### B2 — fabrication (decision 6, rule 7)

| Bar | Measured as |
|---|---|
| **B2a — 0 fabricated incompleteness sentence accepted** | three screens over every accepted output: #583's axis 4 (`PolishSpeakerState`, FR/EN), the new shipping check (`PolishIncompleteness`, §5), and **a hand read** of every accepted output against its transcript for a sentence about the speaker's memory or an unfinished point — #583 §9.1 found the scorer catches 4 of 9 and the hand read is what found the other five |
| **B2b — rule 7 kept 3/3 on `5-rambling`** | axis 4 verdict `preserved` on all three candidate runs |

### B3 — lists (decision 7)

| Bar | Measured as |
|---|---|
| **B3a — 0 bullets on prose fixtures** | an engine output with **any** line opening on a list marker (`-`, `*`, `•`, `–`, or `1.` / `1)`), on a fixture §3 declares prose |
| **B3b — a list on the enumerating fixture in ≥ 2 of 3 runs** | `2-project-update`: ≥ 2 list lines in the engine output |

### B4 — not worse than shipping on #583's fidelity axes

R1, three runs per fixture, both arms, scored with `polish-harness fidelity` — the
unchanged `PolishFidelity` scorers, so the numbers read against PR #583's.

| Axis | Bar |
|---|---|
| 1 — proposition recall (`unrecalled`) | candidate's count of outputs flagged ≤ shipping's **+ 2** |
| 2 — person and stance (`personLost`, `hedgeLost`, `stanceHardened`) | same, per sub-axis |
| 3 — order | **observable, never a bar** — #583 §1; the contradiction it sits on is still Pierre's |
| 4 — speaker-state (`fabricated`, `dropped`) | same, and B2 is the stricter half |

**+ 2 is the declared noise margin**, from #570's bars.md §9 item 4: on ~45 outputs per arm
a difference of one or two is sampling. Anything past it fails the bar, whatever a
significance test would say about it.

Plus **the §9.1 hand read**: every accepted candidate output on R1 read against its
transcript for content the speaker never said; the candidate may carry no more such
outputs than the shipping arm.

### Reported, never barred

Length ratio, refusals by check, outputs with a paragraph break, inversions, dropped
negations, the prompt's resolved size and the largest dictation that still fits under
`PolishContextBudget`.

## 5. The fabrication check (decision 6), specified before it is built

- **What it refuses:** an output carrying a sentence in which the speaker reports their
  own recall failing, when the transcript carries none. New `PolishGuardrail.Check`
  case, its own slug, so a seven-day export counts it apart from `segmentOverlap`.
- **Narrow on purpose (#466).** Only phrasings of **recall failing** — *ça m'échappe*,
  *je ne me souviens pas*, *j'ai oublié un truc*, *I can't remember*… Not *il y a autre
  chose*, not *je reviendrai là-dessus*: a rewrite of *il y a aussi autre chose* into
  *il y a autre chose* is ordinary, and that phrase in the list would refuse it.
- **Asymmetric by construction.** The output side matches the strict list; the input side
  also accepts the spoken forms that list does not (*je m'en souviens plus*, *je sais
  plus*). So a speaker who said it one way and got it back in written form is never
  refused — the rewrite licence would otherwise make this check refuse rule 7 doing its
  job. The 2026-09-19 07:03:42 dictation carries exactly that shape and is in R2.
- **Languages:** French, English, Spanish, German, Italian, Portuguese. Every other
  language passes untested, and that hole is written in the type's doc comment.
- **Contract field, off by default.** Only `Structuré` turns it on in this PR — decision 9
  keeps `Message` and `Liste` out of PR 1, and #571's `Résumé` gets the default.
- **Unit-tested before the bench runs:** the three device fabrications refused, rule 7 kept
  on `5-rambling`, the spoken-form input kept, one fabricated and one said sentence in
  each of the six languages.

Since #580 a guardrail refusal on `Structuré` inserts the speaker's own words, so a false
refusal here costs the structure, never the dictation.

## 6. The arms

| Arm | What it is |
|---|---|
| **shipping** | `SmartModeStructuredPrompt.instructions()` as on `develop` at `b09d517`, 5 556 characters |
| **C1** | the candidate, `arms/C1.txt`: written short on `Message`'s skeleton; seven one-line rules, rule 1 the language rule; two worked examples, one French and one English, one prose that stays prose and one genuine enumeration that becomes a short list inside a paragraph; no heading, no incompleteness line and no counter-example anywhere |

Both arms run with the same user turn (`userInstruction` and `outputMarker` are not
touched: #523's arm table measured that string as the only lever for a paragraph break)
and **the same contract**, fabrication check included — so the check does not separate the
arms on any bar, and fidelity axes read the engine output whether the check refused it or
not.

If C1 passes, it lands in `SmartModeStructuredPrompt.swift` byte for byte, and a
**confirmation round** re-runs R1 and R3 on the landed code with no `--arm`, to prove the
landed string is the benched one.

## 7. What is run

```sh
cd DictusCore
H="swift run polish-harness fidelity"
A=../docs/research/587-structured-rewrite/arms/C1.txt
O=../docs/research/587-structured-rewrite
$H Sources/polish-harness/fixtures/device-structured-fr.json \
   --mode structured --runs 3 --arm $A --json $O/capture-r1.json      > $O/raw/r1.txt
$H Sources/polish-harness/fixtures/device-structured-0918-fr.json \
   --mode structured --runs 3 --arm $A --json $O/capture-r2.json      > $O/raw/r2.txt
$H Sources/polish-harness/fixtures/device-structured-en.json \
   --mode structured --runs 3 --arm $A --json $O/capture-r3.json      > $O/raw/r3.txt
$H Sources/polish-harness/fixtures/translated-structured.json \
   --mode structured --runs 3 --arm $A --json $O/capture-r4.json      > $O/raw/r4.txt
python3 $O/summarise.py $O/capture-r*.json
```

Shipping runs on R4 too: 540 of R4's 1 080 calls are the baseline, because B1 has no
meaning without knowing whether the shipping prompt fails the same languages.

## 8. Risks, declared in advance

1. **The Mac is not the phone** (#583 §9). A Mac pass is a reason to go to the device,
   never a ship verdict. The device round is decision 12's and is Pierre's.
2. **R4 is translated by the agent that also writes the candidate.** It is clean text in
   every language, which is why it is valid for language alone. A human translator would
   produce something different; the language question does not depend on the difference.
3. **Three runs per fixture** leaves ±1 as noise on every per-fixture cell. The 10 % bar
   on 18 outputs per R4 language means **two** refusals already fail it (2/18 = 11 %).
   That is strict, and it is the brief's number.
4. **`NLLanguageRecognizer` is the judge of B1** and it has known confusions (the
   Scandinavian trio, Simplified/Traditional). §4 B1b says how those are reported.
5. **The fidelity scorers are FR/EN** (#570 bars.md §9 item 3); B4 is therefore read on R1
   alone, which is French.
6. **One speaker, one domain.** Every real fixture is Pierre talking about Dictus.

## 9. Amendments made after §1–§8 were committed, and still before the first model call

1. **R1 runs as two invocations, not one.** `fidelity` reads one fixture file; §7's R1 line
   passing two would have run only the first. Captures: `capture-r1-device.json` and
   `capture-r1-longform.json`. Nothing else about R1 changes.
2. **The observables of §4 are recorded by the harness**, not recomputed afterwards:
   `FidelityShape` stores the expected language, the output's reading, the foreign
   sentences, the list lines and the shipping check's verdict on every run, and the
   harness prints a per-language table. The definitions are §4's, unchanged.
3. **C1 is committed as `arms/C1.txt`, 2 966 characters**, before its first call.

## 10. Round 2 — step 2 of the ladder (2026-09-22), declared before its first call

**Why a round 2.** Round 1 stopped at §1's rule: C1 failed B1b in Danish (`T3-plan-mode.da`
translated into English 3 of 3). Pierre approved climbing to decision 5's step 2 on
2026-09-22. Everything in this section is committed before the first C2 call.

**The candidate, C2** — `arms/C2/`, one file per `NLLanguage` code plus `fallback.txt`:

- **Rules byte-identical to C1.** Only the two worked examples change.
- **Examples in the transcript's language**, the same two examples as C1 (bike prose that
  stays prose; trip enumeration that becomes a short list), machine-translated by the
  agent into all 16 Apple FM language codes. Decisions 4 and 7 unchanged: no
  incompleteness line, no heading, no person named.
- **`fallback.txt` is C1, byte for byte** (`cmp` checked), sent when the transcript's
  language is unknown or has no set.
- The files are dumped from `SmartModeStructuredPrompt.shortInstructions(examples:)`, so
  if C2 lands, the landed strings are the benched strings.
- The harness resolves a directory arm per fixture with the app's own rule
  (`SmartModePrompt.instructions(forTranscriptLanguage:)`: exact code, then base subtag,
  then fallback), off the language the pipeline is given: the fixture's `lang` on the
  per-language path, the detected language on the auto path.

**What changed in the pipeline since round 1, for both arms:** a trailing ```` ``` ```` or
`---` line is now stripped before the guardrails (`PolishPostpass.stripTrailingFenceLines`),
and the transcript language reaches the job. `engineOutput` is recorded after the strip, so
the stray-line count in round 2 measures what is left, not what the model emitted.

**Fixtures, unchanged:** R1–R4. Every Apple FM language other than French and English has
**6 distinct translated dictations × 3 runs = 18 outputs**; French has 24 fixtures (R1, R2),
English 11 (R3 plus six translated). No language is judged on one dictation.

**Arms:** `shipping` (re-run the same day, as the baseline) and `C2`.

**Bars: §4, unchanged. The 10 % threshold stays.** If any language exceeds it on
`check=language`, the round stops and reports, and step 3 is not attempted.

**One reading declared now, after seeing round 1, and flagged as such.** B3b (a list on
`2-project-update` in ≥ 2 of 3) failed on **both** arms in round 1, 0 of 3 each, which
matches #523's measured inability of the Mac model to list a spoken enumeration. If round 2
repeats that on both arms, B3b is reported as failed and as a Mac capability limit, and it
alone does not block landing C2; the device round is where it is judged. Every other bar
blocks. This is the one place the pre-registration is loosened, it is loosened before the
round-2 numbers exist, and the PR says so.

**If the blocking bars hold:** C2 lands in `SmartModeStructuredPrompt` and the catalogue,
and a **confirmation round** runs R4 once per fixture with no `--arm` (the landed prompt as
`shipping`), to prove the pipeline resolves the right language's examples on its own. Its
B1b is reported; it is a wiring check, not a second vote.
