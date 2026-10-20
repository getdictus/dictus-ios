# `Résumé` — plan and bars (#571)

**Issue:** [#571](https://github.com/getdictus/dictus-ios/issues/571), decisions locked
2026-09-16, plus the 2026-09-21 comment carrying #587's output-language decision.
**Binding from #587:** decision 4 (two worked examples, two languages, no example acting
out a risky rule) and decision 5 step 1 (rules in English, rule 1 = write in the
transcript's language, never the examples'), with the examples structured so step 2
(examples in the transcript's language) can swap them in without rewriting the mode.
**Date:** 2026-09-21. **Mac:** macOS 27.0 (26A428), Apple Intelligence enabled.

> **This file was written and committed before the first model call of this round.**
> Same discipline as #439, #437, #550 and #570. Nothing below §5 was edited after a
> number came in, except the results section appended at the end.

## 1. What is being built

A fifth Smart Mode row, identifier `summary`, displayed `Summary` / `Résumé`. It
returns the gist of a dictation in prose. It is wired exactly the way `Message` was in
PR #576:

| Site | Change |
|---|---|
| `Polish/Prompts/SmartModeSummaryPrompt.swift` | new: system prompt, user turn, output marker, and the two worked examples **as data** |
| `Polish/SmartModeCatalogue.swift` | `summaryIdentifier` and the `summary` row appended to `builtIns` after `message`. No other row moves, no reformatting (#587 edits this file in parallel) |
| `DictusApp/SmartModeDisplayName.swift`, `DictusKeyboard/SmartModeDisplayName.swift` | the localised name, keyed on the identifier |
| both `Localizable.xcstrings` | `Summary` → fr `Résumé` |
| `Tests/…/SmartModeSummaryTests.swift` | new file (not appended to `SmartModeCatalogueTests`, to keep #587's merge clean). Only the catalogue row count and the prompt inventory count move in existing files |
| `polish-harness` | a `summary` command that runs a mode and scores the bars below, and the fixtures |

What does **not** move, and why:

- **The fan, the list, the recording overlay, the paywall.** Every one of them reads
  `SmartModeCatalogue.builtIns` / `pinnedModes` and draws any row. PR #576 touched none
  of them for `Message`. The paywall's Smart Mode card names no mode.
- **`defaultPinnedIdentifiers`.** The fan holds three and the seed is full, the same
  reason `Message` is not in it. A user reaches `Résumé` by pinning it in the app.
- **The icon is `text.quote`, not `text.line.3.summary`.** The second is an SF Symbols
  2025 glyph (iOS 26 only, per `name_availability.plist`), and the mode list is not
  gated on device capability, so a Pro user on iOS 17–25 would see an empty slot.

## 2. The contract (the issue's proposal, unchanged)

```
minimumLengthRatio: 0.1
maximumLengthRatio: 0.6
outputLanguage: .sameAsInput
requiresGroundedNames: true
requiresAlignedPrefix: false
floorBehaviour: .insertRawText   // `overflowBehaviour` in the issue, renamed since
segmentOverlapThresholds: .default
```

## 3. The prompt

`SmartModeMessagePrompt`'s skeleton: ~3 000 characters, a framing line, the no-reply
paragraph, seven one-line rules, two worked examples, no counter-example block.

- **Rule 1 is the language rule** (#587 decision 5, step 1), and it names the examples:
  write in the language of the text given, never in the examples' language.
- **The mode's name never reaches the model.** `summary`, `summarise`, `résumé`: none
  appears in the system prompt or the user turn. PolishTask's genre-prior finding (PR
  #388) is that naming a written genre pulls in its furniture, and a summary's furniture
  is exactly what the bars forbid — a `Summary:` heading, and the third person
  (`The speaker explains…`). What is named is the transformation: *condense to the gist*.
- **Examples as data.** `SmartModeSummaryPrompt.Example` pairs, a default set of two
  (one French, one English, both off-domain, no person named, both first person, no
  list, no incompleteness line), and `instructions(examples:)` builds the prompt
  around whatever set it is given. Step 2 of the ladder is then a per-language example
  table passed in, with no rule text touched. The step-2 table is **not** built: the
  ladder says climb only when the bench shows step 1 fails.
- **Nothing about a speaker-flagged incompleteness.** Decision 4 says it MAY be
  dropped, which is what a summary does anyway; a rule or an example about it is the
  #581 fabrication route.

## 4. Fixtures

| File | What | Origin |
|---|---|---|
| `fixtures/summary-fr.json` | 7 French dictations, 73 to 1 283 characters | verbatim from `longform-fr.json`, `notes-fr.json`, `device-structured-fr.json` — real Parakeet output |
| `fixtures/summary-en.json` | 4 English: 1 native (`N5-en-ramble`) + 3 translated from the French set | translated by the agent, keeping the spoken style |
| `fixtures/summary-i18n.json` | 2 dictations × the 13 other Apple FM languages | the same two French dictations, translated by the agent |

The two translated dictations are chosen for pressure, not for comfort: `1-free-form`
(a thought, 395 characters, `on` and `je`) and `N2-reunion-vrac` (585 characters, an
**enumeration of first-person to-dos** — the input on which `Résumé` would collapse into
`Liste`, and where the person rule and the prose rule both bite).

**What the translated fixtures can and cannot prove** (#587 decision 11): they are
cleaner than real speech in those languages. They are valid for **output language**,
**bullets** and **length**. They say nothing about fidelity on real non-French speech.

**Apple FM languages on this Mac**, read from `SystemLanguageModel.default.supportedLanguages`
on 2026-09-21 (24 locales, 15 languages): `da de en es fr it ja ko nb nl pt sv tr vi zh`.
Regional variants (`en-GB`, `es-419`, `pt-PT`, `zh-TW`, …) are not run separately:
the prompt and the check are language-level, and `zh` is run in Simplified.

## 5. Bars — declared before the first candidate call

Runs: **5 per fixture** (FR 35, EN 20, each other language 10). Every bar is read on
the **engine output** — what the model wrote — not on the inserted text, because a
refusal inserts the raw transcript and would score as a perfect "same language, no
bullet" output. The guardrail verdict is reported beside it.

| # | Bar | Threshold | Scored how |
|---|---|---|---|
| **L1** | Output in the input's language, every Apple FM language | **0 wrong-language engine outputs accepted**; **≤ 10 % refused on `check=language`** per language; **English 100 % English** | `NLLanguageRecognizer` dominant language of the engine output against the fixture's language |
| **B** | No bullets | **0** engine outputs with a bullet, dash, numbered item or heading line, across every language, including the enumerating fixture | line regex `^\s*([-*•–]\|\d+[.)])\s` and a line ending in `:` |
| **R** | Length inside the band | **≥ 90 %** of engine outputs within `0.1 … 0.6`, overall and on FR and EN separately. `N4-une-idee` (73 characters) is **excluded** from this bar and reported: a gist of one short sentence cannot be 60 % of it without losing a fact, so a refusal there is the contract working, and the raw is inserted | ratio = engine output characters / pre-passed input characters, the guardrail's own ratio |
| **P** | Speaker's person kept | FR and EN: **0** engine outputs framed as a report (`le locuteur`, `l'orateur`, `il explique`, `the speaker`, `he says`, `the user`…) and **0** opening on a bare infinitive task; a first-person marker present whenever the input has one. Other languages: report-framing terms per language, plus a hand read | regex, then hand read of every FR/EN output flagged |
| **D** | Visibly different from `Liste` and from Normal polish (#393 bar B) | On **5 of 5** FR/EN dictations, same input, 3 runs each: `Résumé` has 0 bullets where `Liste` has bullets, **and** `Résumé`'s median ratio is at most **half** of Normal's | `ab --mode-a notes --mode-b summary` and `ab --mode-b summary` over the same five |
| **F** | No invented fact, figure, date or name; no example copied | **0** accepted outputs carrying a figure or name absent from the input, and **0** carrying example content (`garagiste`, `plaquettes`, `grincement`, `station`, `cupboard`, `150`…) | digit and capitalised-token diff against the input, flagged runs hand-read; example-marker list |
| **A** | Never answers, comments or concludes | **0** outputs opening on a preamble (`Voici`, `Here is`, `En résumé`, `In short`, `Summary`…) and **0** answers to `D6-issues-check`, a dictation addressed to an assistant that asks for a list | regex, plus a hand read of every `D6` output |

**Reported, never barred:** refusals by check (`length`, `grounding`, `language`,
`prefix`), engine milliseconds, whether `5-rambling`'s closing *"il y avait un dernier
truc ça m'échappe"* is kept or dropped (decision 4 allows both).

**If a bar fails:** the prompt is revised and the whole bench is re-run on the revision,
each run committed under `runs/`. A language failing L1 above 10 % after revision is
**not** chased with step 2 in this PR: it is reported, because the ladder is climbed
for every mode at once (#587 decision 5), not by one mode alone.

**The Mac understates the phone** (#523 round 10, PR #576's device round). A bar that
holds here is a floor for the device, not a verdict. The device round is Pierre's.

---

## 6. Results (appended after the runs; §1–§5 unchanged)

Shipping prompt = arm `G-D-plus-closing-language` (byte-identical to
`SmartModeSummaryPrompt.instructions()`, checked with `polish-harness prompt`). FR and EN
numbers come from that arm in `runs/arms-DFG-{fr,en}.*`; the 13 other languages from
`runs/shipping-i18n.*`. One deviation from §5, declared: bar L1's "≤ 10 % refused on
`check=language`" is read as **≤ 10 % wrong-language engine outputs**, which is stricter,
because a wrong-language output is often refused by `length` first (CJK → English
roughly doubles the character count) and would otherwise not be counted.

### How the shipping prompt was reached

| Candidate | FR wrong language | EN wrong language | FR in band | Kept? |
|---|---|---|---|---|
| `v1` (French example first, English last) | 11/35 | — | 17/35 | no |
| `A` + a language line above the rules | 8/35 | — | 16/35 | no |
| `C` = `A` with the examples swapped (French last) | 1/35 | — | 15/35 | no |
| `D` = `C` + rule 3 "cut hard" | 6/35 | 0/20 | 19/35 | no |
| `F` = `A` + cut hard + closing line "in its own language" | 10/35 | 0/20 | 18/35 | no |
| **`G` = `D` + the closing line** | **0/35** | **0/20** | 15/35 | **yes** |
| `G` + user turn "to about a quarter of its length" | 5/35 | 0/20 | 21/35 | no |
| `G` + user turn "far shorter than it is" | 5/35 | 0/20 | 20/35 | no |
| `H` = `G` + "never in English unless the text is English" (13 langs) | 35/77 in the 13 languages | | | no |

### Bars, shipping prompt

| Bar | Result | Verdict |
|---|---|---|
| **L1** FR | 0/35 wrong language | holds |
| **L1** EN | 20/20 English | holds |
| **L1** 13 other languages | **55/130 wrong language (English), 0 accepted**. Over 10 %: de 10/10, ja 10/10, es 5/10, it 5/10, ko 5/10, pt 5/10, vi 5/10, zh 5/10, tr 4/10. Under: da 1/10, nb 0, nl 0, sv 0 | **fails on 9 languages** |
| **B** no bullets | 0/318 engine outputs across every run of the shipping prompt | holds |
| **R** in band (`S6-one-line` excluded) | FR 15/30 (50 %), EN 13/20 (65 %). Out of band = long dense dictations the Mac keeps at 0.6 to 0.85 | **fails on the Mac** |
| **P** person | 0 report framing, 0 infinitive opening. EN flags 6: 5 are `E1`, whose input speaks in the generic "you" the output keeps (hand read: kept); 1 is `E4` written as note fragments, the first person gone (hand read: lost, accepted) | holds with 1 exception |
| **D** vs `Liste` | 5/5: `Résumé` 0 bullets in 15, `Liste` bullets in 15/15 | holds |
| **D** vs Normal | median ratio ≤ half of Normal's on 2/5 (S1 0.49, S3 0.24; S5 0.60, E3 0.50, E4 0.70 against Normal ≈ 1.0) | **fails on the Mac** |
| **F** invented facts | 0 example content, 0 novel figure in an accepted output (the 10 figure flags are thousands separators and one `1500`, all refused). **Meaning damage, accepted**: `dictus` → `dictées` in 5/5 `S7`, and `qu'on n'utilise plus depuis février` → `utilisé depuis février` in 2/5 `S3` | holds on invention; **2 accepted distortions** |
| **A** never answers | 0 preamble in 318; `S7` (a request addressed to an assistant) condensed 5/5, never answered | holds |

Reported: decision 4, `S3`'s closing *"il y avait un dernier truc ça m'échappe"* was
dropped in 5/5 — which the decision allows. `S6-one-line` (73 characters) came back at
0.95 in 5/5 and was refused by the ceiling: the raw goes in, as §5 predicted.

### Step 2, probed and not landed (`step2/`)

Same rules, only the two examples translated into the transcript's language:

| Language | Step 1 wrong language | Step 2 wrong language | Step 1 accepted | Step 2 accepted |
|---|---|---|---|---|
| de | 10/10 | 0/10 | 0/10 | 8/10 |
| es | 5/10 | 0/10 | 0/10 | 6/10 |
| ja | 10/10 | 0/10 | 0/10 | 8/10 |
| zh | 3/10 | 0/10 | 5/10 | 3/10 |

Per #587 decision 5, a language above 10 % climbs **every** mode to step 2. That is
#587's call, not this mode's alone; the seam is `SmartModeSummaryPrompt.instructions(examples:)`.

### Context: `Message` on the same 13-language fixtures

`runs/baseline-message-i18n.*`: 0/78 wrong language. But on the Mac `Message` barely
rewrites (PR #576's own finding), so an echo keeps its language trivially. This is not
evidence that step 1 holds for a mode that rewrites.

---

## 7. Round 2 — amendments, declared before the first round-2 candidate call (2026-09-22)

**Why a round 2.** Pierre's device round of 2026-09-22 (iPhone16,2, iOS 27.0, commit
`13ea392`, 8 `Résumé` dictations, FR/EN, Parakeet v3):

| What | Device result |
|---|---|
| Language | 6/6 correct (FR and EN) |
| Bullets / answers | 0 / 0 |
| Condensing | long dictations at **0.36 and 0.44**: the phone condenses far more than the Mac |
| Meaning changed | **3 of 6 accepted**: a date word (`pour demain` → `Aujourd'hui`) on a to-do list; a product name Parakeet misrendered (`hue dictus iOS`) turned into `les dictionnaires iOS`; an invented qualifier (`réinstallation coûteuse` where the speaker only said he did not want to lose his setup) |
| Person lost | **2 of 6**: a telegraphic noun-phrase output with no `je`; `j'aimerais qu'on fasse un point` → `Nous devons aborder` |
| Ceiling | a good 263-character, three-sentence dictation with two negations came back at ~0.72, both negations kept, **refused by the 0.6 ceiling**. A 38-character line refused as intended; a 73-character English line accepted at 0.47 |

Pierre approved three changes. Each amends §2, §3 or §5, and says so.

### 7.1 Amendments

| # | Amends | Change |
|---|---|---|
| A1 | §3, "The step-2 table is not built" | **Step 2 of #587 decision 5.** Worked examples in the transcript's language, for all 15 Apple FM languages (agent-translated from the two step-1 examples, same content, same shape). Rules stay in English, rule 1 stays the language rule. The language is the forced transcription language if set, else the transcript's detected language (#587 decision 5). Wired through #587's shared seam (`SmartModePrompt.localizedInstructions`), cherry-picked as an identical commit. Unknown language → the step-1 set. |
| A2 | §3, rule 5 | **The speaker's person is a hard rule**: first person stays first person (`je` / `on` / `I` / `we` as spoken), no telegraphic noun-phrase summary, no switch to a collective obligation (`nous devons`, `we must`) the speaker did not use. |
| A3 | §2, `maximumLengthRatio: 0.6` | **Ceiling 0.75.** Decision 1 still holds (a band, never a sentence count); only its top moves. |

**Explicitly not done:** no meaning or fidelity guardrail. That is being grilled with
Pierre separately (#570, extended to every rewriting mode). The three device
distortions become **observables**, not bars.

### 7.2 Round-2 bars

Runs: 5 per fixture on FR, EN and the new device-shaped set; 5 per fixture on the 13
other languages. Engine outputs, as in §5.

| # | Bar | Threshold |
|---|---|---|
| **L1** (unchanged in substance) | Output language, every Apple FM language | **≤ 10 % wrong-language engine outputs per language** (the reading §6 declared), 0 accepted, English 100 % English |
| **B** (unchanged) | No bullets | 0 |
| **R** (amended by A3) | In band `0.1 … 0.75` | ≥ 90 % of engine outputs, FR and EN separately, one-line fixtures excluded. **Reported against the Mac's known under-condensing**: the device condensed to 0.36–0.44 where the Mac gave 0.6–0.85, so a miss here is read beside the device numbers, not alone |
| **P2** (new, from A2) | Speaker's person, hard | FR and EN, **0 accepted outputs** that (a) lose a first-person marker the input had, (b) introduce `nous` / collective `we must/need/have to` the input did not use, or (c) open on a bare infinitive or report framing. Scored by `PolishSummaryShape`, every flag hand-read |
| **D** (re-checked under A3) | Visibly different from Normal polish (#393 bar B) and from `Liste` | Same five dictations as §6: Résumé 0 bullets where `Liste` bullets; Résumé median ratio ≤ half of Normal's. **Also reported:** how many accepted outputs sit between 0.6 and 0.75, i.e. the ones the old ceiling refused, each with its ratio to Normal's |
| **A** (unchanged) | Never answers | 0 |

### 7.3 Observables (reported, never barred): the device distortions, rephrased

`fixtures/summary-device-r1.json`. The device texts are private; each fixture keeps
the **linguistic structure** of one device failure and none of its topic.

| Fixture | Keeps the structure of | Observable |
|---|---|---|
| `R1-date-word` | a to-do list said "pour demain" | output keeps `demain`, never `aujourd'hui` |
| `R2-misrendered-product` | Parakeet's `hue dictus iOS` | output keeps `dictus`, no `dictionnaire` / `dictée` |
| `R3-no-qualifier` | "je veux pas perdre ma config" before a reinstall | no evaluative qualifier the speaker did not say (`coûteu`, `longue`, `pénible`, `risqué`, `compliqu`) |
| `R4-on-not-nous` | "j'aimerais qu'on fasse un point" | P2: no `nous devons`, first person kept |
| `R5-telegraphic` | a week of phone trouble, told in `je` | P2: first person kept, not a noun-phrase list |
| `R6-two-negations` | 3 sentences, two negations, ~260 characters | both negations kept; accepted under 0.75 |
| `R4-en`, `R5-en` | English versions of R4 and R5 | P2 in English |

---

## 8. Round-2 results (appended after the runs; §7 unchanged)

Shipping prompt = round-2 code on `feature/571-resume-mode` (step-2 table through
#587's seam `adafb69` and harness commit `4fe1c6c`, both cherry-picked unchanged).
Runs: `runs/r2-*`, reproducible with `run-round2.sh`. macOS 27.0. `Liste` and Normal
comparison runs are round 1's (`compare-notes.*`, `compare-polish.*`): neither prompt
moved.

### Bars

| Bar | Round 1 | Round 2 | Verdict |
|---|---|---|---|
| **L1** FR | 0/35 wrong language | **0/35** | holds |
| **L1** EN | 20/20 English | **20/20** | holds |
| **L1** 13 other languages | 55/130 wrong (English) | **0/130** | **holds in every language** (step 2) |
| **B** bullets | 0/318 | **0/240** (FR, EN, device-shaped, 13 languages, compare) | holds |
| **R** in band, FR (one-line excluded) | 15/30 in `0.1…0.6` | **21/30** in `0.1…0.75` | fails ≥ 90 % on the Mac |
| **R** in band, EN | 13/20 | **15/20** | fails ≥ 90 % on the Mac |
| **R** in band, 13 languages | 48/130 | **105/130** (81 %) | — |
| **P2** person, FR and EN accepted | 1 lost (EN notes) | **0 flags** in 36 accepted + hand read of every accepted output: first person kept, no `nous devons`, no noun-phrase string | holds |
| **D** vs `Liste` | 5/5 | **5/5** (0/15 bullets vs 15/15) | holds |
| **D** vs Normal (median ≤ half of Normal's) | 2/5 | **1/5** (S3 0.25; S1 0.62, S5 0.54, E3 0.54, E4 0.82 against Normal ≈ 1.0) | **fails on the Mac** |
| **A** never answers | 0 | **0** | holds |

**Bar D under the new ceiling, stated plainly.** 19 of the 36 accepted FR/EN outputs
sit between 0.6 and 0.75, i.e. they were refused under 0.6 and are accepted now
(`S1`, `S4`, `S7`, `E1`, `E2`). Each is 60 to 75 % of its input where Normal is about
100 %: shorter, but not "half". On the Mac, 0.75 lets through outputs that read closer
to Normal than to a gist. The device condensed long dictations to 0.36 and 0.44 on
2026-09-22, which is well inside "half of Normal"; whether short, dense dictations
stay visibly different on the phone under 0.75 is the device round's question.

### What 0.75 now lets through that 0.6 refused

`S7` (a request addressed to an assistant, `issues dictus iOS`) was refused 5/5 in
round 1 at 0.69 to 0.88. In round 2 it is **accepted 4/5 at 0.69 to 0.74, and all 4
turn `dictus` into `dictées`**: the #570 meaning distortion, which the old ceiling
happened to hide. Likewise `E2` is accepted 5/5 at 0.72 to 0.74 with proper names
lowercased (`thomas`, `storekit`).

### Observables: the device distortions (`summary-device-r1.json`, 40 runs)

On the Mac **all 40 were refused on `length`** (0.76 to 1.03): the Mac barely
condenses ~250-character inputs, where the phone reached 0.72. So these read the
engine output only:

| Fixture | Observable | Mac |
|---|---|---|
| `R1-date-word` | `demain` kept, never `aujourd'hui` | `aujourd'hui` 0/5; `demain` **dropped** 3/5 |
| `R2-misrendered-product` | `dictus` kept | 5/5 kept (output ≈ input) |
| `R3-no-qualifier` | no invented qualifier | 0/5 |
| `R4-on-not-nous`, `R4-en` | no `nous devons` / `we must` | 0/10 |
| `R5-telegraphic`, `R5-en` | first person kept | 10/10 |
| `R6-two-negations` | both negations kept | 5/5 (hand read) |

These cannot show the device's distortions because the Mac leaves the text almost
untouched. They are the fixtures the next fidelity check (#570) can measure against.

### Other things the round showed

- **Japanese, a figure changed and accepted** 2/10: `15000` → `1500` (`ja-todo-enumeration`).
- **Italian, the grounding check refused 5/5** `it-todo-enumeration` outputs that read
  correctly by hand: a guardrail false refusal candidate, not investigated here.
- Korean and Turkish sit at 5/10 in band: under-condensing, not language.
