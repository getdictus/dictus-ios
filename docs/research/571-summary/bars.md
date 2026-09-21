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
