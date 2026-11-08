# `Liste` rebuilt as a summary in bullets (#573) — plan and bars

**Issue:** [#573](https://github.com/getdictus/dictus-ios/issues/573), spec grilled with Pierre on
2026-09-30 (eight decisions, the issue body is the contract).
**Date:** 2026-10-01. **Machine:** macOS 27.0 (26A428), Xcode 27.0, Apple Intelligence on.
**Baseline:** `develop` at `b040427`: `Liste` as #587 PR 2 left it, one example set per Apple FM
language, rules untouched since #79.

> Written and committed **before the first model call of this round**. No candidate prompt has
> been run when this file lands; the commit that adds it touches no Swift.

---

## 1. What changes, and every consumer of it

| Behaviour | Where it lives today | Who reads it |
|---|---|---|
| The rules, the language block, the counter-example | `SmartModeNotesPrompt.instructions(examples:)` | `SmartModeCatalogue.notes` (fallback + per-language table), `PolishPromptInventoryTests`, `SmartModeCatalogueTests` (the measured clause `never the examples'`, the rule-1 text), `PolishContextBudget` (prices the resolved prompt at run time, no constant to move) |
| The worked examples, 15 languages | `SmartModeNotesExamples.byLanguage`, shape `SmartModeNotesPrompt.ExampleSet` | `SmartModeNotesPrompt.localizedInstructions()`, `defaultExamples` (`fr`), `SmartModeCatalogueTests` (15 keys, bullet shape, same keys as `Message`) |
| User turn and marker | `SmartModeNotesPrompt.userInstruction` / `outputMarker` | `PolishTask.userTurn`, `PolishTaskTests.testTheUserTurnCarriesTheTasksOwnImperativeAndMarker`, the #518 no-label test |
| Contract `0.1…2.0`, grounded, unaligned | `SmartModeCatalogue.notes.contract` | `PolishGuardrail`, `SmartModeCatalogueTests`, `SmartModeSummaryTests` (Summary's floor equals List's) |
| Short-input floor | `SmartMode.minimumInputCharacters` (nil for `notes`), read by `PolishService.skipForShortInput` | `SmartModeShortInputSkipTests` (asserts only Structuré has one: **must change**), the metrics event `smartModeSkippedShortInput` + `smartModeLengthSkip.mode`, `PolishDebugExporter.smartModesSkippedForLength` (already per mode), `PolishDebugView` |
| The notice | `KeyboardPolishCoordinator.message(for:degraded:)`, one generic sentence for every mode | `DictusKeyboard/Localizable.xcstrings`. The app path (`DictationHandoff`) shows no non-fatal notice and is not changed |
| "List = actions" descriptions | `SmartModeCatalogue` header and `summary` doc, `structured` doc, `SmartModeSummaryPrompt` doc table, `SmartModeNotesPrompt` doc | doc comments only; no user-facing copy describes `Liste` (checked both catalogs) |

**Decision 5's "own export event".** The skip already emits a `smartModeSkippedShortInput` metrics
event carrying `smartModeLengthSkip.mode`, a `smartModeSkipped` persistent-log line with the mode
id, and a per-mode count in the export (`smartModesSkippedForLength: {"notes": n}`). Arming the
floor on `notes` gives `Liste` that event under its own identifier, distinguishable from
`Structuré`'s. No new outcome is added: a second outcome for the same event would split one count
in two for every reader of the export.

## 2. Ordered changes

1. This file and the two fixture files (`liste-statements.json`, `liste-mixed.json`). No Swift.
2. **Baseline round** on `develop`'s prompt (§5), before any candidate exists.
3. Candidate C1 in code: rules, user turn, marker, all 15 example sets (§3). Bench §5.
4. If a bar fails, the next candidate, its predecessor kept as a committed arm. Stop at the first
   candidate that holds every bar; report every failure, never work around one.
5. Threshold measurement on the landed prompt (§6), then the floor on `SmartModeCatalogue.notes`.
6. The notice: a `Liste`-specific sentence in the keyboard, FR + EN in its catalog.
7. Doc comments that describe `Liste` as an action extractor, tests, lint, build.

## 3. The candidate, as specified before it is written

- **Shape (decision 2):** first line a title made of the transcript's own words, a colon in the
  language's typography (`Titre :` in French, `Title:` in English, `标题：` in Chinese and
  Japanese), then `- ` lines. Plain text, no emphasis.
- **Points (decisions 1, 3):** one line per distinct point, actions in the infinitive, statements
  kept as statements; repetitions and self-corrections merged; nothing dropped.
- **Flat, speaker's order (decision 4).**
- **Examples:** the issue's execution notes and #587's ladder step 2: one set per Apple FM
  language. The one-idea-one-bullet example goes (it teaches the lone dash-line Pierre named);
  a statements-only example comes in; the off-domain counter-example (plants) and the language
  block stay (#414, #585), the counter-example rewritten to the new shape. No example names a
  person (#414). The prompt never quotes a forbidden title formula: PR #388's `[Votre Nom]` is what
  quoting a ban costs.
- **User turn and marker** describe the new shape, never name a genre, and put no label before the
  transcript (#518).

## 4. Fixtures

| Set | File | n | Valid for |
|---|---|---|---|
| **N** | `fixtures/notes-fr.json` (unchanged) | 6 | the no-regression bar (decision 6) |
| **S** | `fixtures/liste-statements.json` (new) | 8 (5 FR, 3 EN) | **statements only, no action**: bar B3 |
| **M** | `fixtures/liste-mixed.json` (new) | 5 (3 written, 2 device) | decisions 1-2: actions and statements interleaved |
| **L** | `fixtures/longform-fr.json` (unchanged) | 6 | decision 3, long input; fixture 5 is #437's Typeless loss |
| **T** | `fixtures/translated-structured.json` (unchanged) | 90 | **output language only**, 15 languages; agent-translated clean text, says nothing about fidelity |

3 runs per fixture. Baseline arm on N, S, M, L; candidates on all five sets.

## 5. The bars, read on the engine's output

A run with no engine output is in no denominator. Every flag a script raises is printed and
adjudicated by hand before a bar is called.

| Bar | How it is read | Holds when |
|---|---|---|
| **B1 — 0 invented facts or names, title included** (decision 6) | Screens: (a) the pipeline's own `grounding` / `segmentOverlap` refusals; (b) a number in the output absent from the input; (c) a title content word (4+ letters, not a stopword) whose 5-letter prefix appears nowhere in the input. Then a hand read of every flag. | 0 accepted outputs carrying an invented fact, figure, date or name, on every set |
| **B2 — output language = input language** (decision 6) | #587's reading: `NLLanguageRecognizer` on the whole output plus every sentence ≥ 20 characters at ≥ 0.85 | per language: 0 wrong-language outputs **accepted**; ≤ 10 % refused on `check=language`; English input answered in English 100 % |
| **B3 — 0 tasks fabricated from a statement** (decision 6, new) | Set S, every engine output read by hand, line by line: does a line turn something the speaker stated into something to do (an infinitive or imperative they never voiced)? | 0 accepted outputs on S carrying such a line |
| **B4 — no regression on N1-N6** (decision 6) | Against the baseline arm, same 18 runs: accepted count; every `contains` expectation of `notes-fr.json` held in each accepted output; 0 wrong language | candidate accepted ≥ baseline accepted, no expectation lost that the baseline kept, 0 wrong language |
| **B5 — the shape** (decisions 2, 4) | First non-empty line not a list line and ending on `:` / `：`, followed by ≥ 1 `- ` line; no indented or numbered list line; no second non-list line after the title | every accepted output on N, S, M, L; ≥ 95 % on T (reported per language) |
| **B6 — nothing dropped** (decision 3) | `polish-harness fidelity` axis 1 (outputs with ≥ 1 unrecalled proposition) on N + L + M, against the baseline; L5's trailing `ça m'échappe … ça me reviendra` kept, counted | candidate not worse than baseline on axis 1; L5's trailing line reported, not barred |
| **B7 — the band fits a titled list** (execution note) | refusals on `check=length` | 0 on N, S, M, L; length ratios reported |

**The ladder (#587 decision 5) applies to B2:** a language above 10 % refused on `check=language`
or any wrong-language output accepted stops the candidate and moves to the next one. Step 3, a
native prompt per language, is not attempted in this round; if step 2 fails it is reported.

Reported, never barred: refusals by check, prompt sizes, infinitive-line counts on M.

## 6. The short-input floor, measured (decision 5)

**Question:** below how many characters does `Liste` stop producing a list? Pierre named the
defect: a lone dash-line on a short dictation.

**Corpus C:** every distinct dictation in the maintainer's 24 polish debug exports of 2026-09-13
to 2026-09-30, of **300 characters or fewer** (all modes, deduplicated on `raw`). It is his real
speech at real lengths, which no written fixture is. **It is not committed**: these are private
messages (to family, to colleagues) and the tracker is public. What is committed is the
extraction script, the per-dictation numbers (a hash of the text, its length, its bullet counts)
and the curve below, so Pierre can rebuild the measurement from his own exports.

**Measured:** the landed prompt, `lang auto`, 2 runs per dictation, through `polish-harness
fidelity`. Per run, `bullets` = lines opening on `- ` after the title.

**Decision rule, fixed now:** for each candidate floor F in {50, 75, 100, …, 300}:
- A(F) = runs with **≤ 1 bullet** on dictations of **≥ F** characters (the lone dash-line still
  reaches the user);
- B(F) = runs with **≥ 2 bullets** on dictations of **< F** characters (a list the floor takes away).

The floor is the F minimising A(F) + B(F); on a tie, the lower F (the user armed the mode, so the
mode runs when in doubt). The whole curve is reported, and the dictations on either side of the
chosen F are read by hand before it ships, to check that ≥ 2 bullets there means distinct points
rather than one sentence cut in two.

## 7. Risks, declared in advance

1. **The Mac is not the phone** (macOS 27.0 here, iOS 27.0 there). Decision 7: the device round
   is mandatory and it is Pierre's.
2. **T is agent-translated and clean**, so it measures the output language and nothing else; so
   are 13 of the 15 example sets, never read by a native speaker.
3. **B3 is a hand read** by the agent that wrote the prompt. Every line is committed in the raw
   captures so the reading can be disagreed with.
4. **The title check (B1c) is lexical.** A title that paraphrases the speaker with words they did
   not use is flagged; one built from their words but misleading is not. The hand read covers it.
5. **Corpus C was dictated under other modes**, mostly messages and instructions to an agent. Its
   lengths are real; whether the same lengths carry lists when the user arms `Liste` is a device
   question.
6. **A character floor misfires both ways**: a short enumeration loses its list (Structuré's known
   cost at 149 characters), a long single idea still gets one bullet. The curve says how often.

---

## 8. Round 2: after device round 1 (2026-10-01), two decisions amended

> Written and committed **before the first model call of round 2**. Context: the comment of
> 2026-10-01 21:19 on #573. C3 (shipped in PR #629 at `a03da9d`) failed on device on the
> title: an announcement *sentence* opener ("Je te fais un petit récap de ce qu'on a fait ce
> soir") made the model promote the first point to title and leave its bullet truncated
> (`- J'ai fait`); past facts became tasks; a 64-character four-item list was skipped by the
> 100-character floor.

**Amended by Pierre:**
- **Decision 2:** the title is a short summary of what the list is about, chosen by the model
  from the whole transcript, in its own words when needed. Hard: no fact absent from the
  transcript (day, time, name, number, place), never a generic label, never one of the points,
  a bullet never loses words to the title.
- **Decision 5:** the floor is replaced by a **post-check**. `Liste` always runs; an output with
  fewer than two bullets is replaced by Normal polish with the same notice and export event.
- **Decision 1, restated:** a past fact stays past (`- On a gardé les petits`, never `- Garder…`).

**Fixtures:** `fixtures/liste-round2.json` (set **R**, 10, synthetic, written to reproduce the
device shapes without their content, which is private). Pierre's device dictations are not
committed.

**Arms:** C3 (shipping in the branch) as baseline on R; candidate C4 onward on R, N, S, M, L, T.
3 runs per fixture.

| Bar | How it is read | Holds when |
|---|---|---|
| **T1 — the title is never one of the points** | Screen: the title's content words (4+ letters) are ≥ 70 % contained in one bullet, or a bullet starts with the title's words. Hand read of every flag. | 0 accepted outputs on R, N, S, M, L |
| **T2 — no invented fact in the title** | Screen: a number, a day or month name, or a capitalised word in the title absent from the input. Hand read. | 0 accepted outputs on every set |
| **T3 — never a generic label** | The title, colon stripped, is one of: Notes, Note, Résumé, Summary, Liste, List, Points, Récap, Récapitulatif, À faire, To do, Tâches, Tasks, Status, Current status, État actuel, Estado actual, Stato attuale, Status atual. Plus hand read for the other languages. | 0 accepted outputs on every set |
| **T4 — no bullet truncated by the title** | Screen: a bullet of ≤ 2 words. Hand read: is it a fragment whose rest went into the title? | 0 on R, N, S, M, L |
| **P1 — past facts stay past** | R1-R5 (recaps of past facts), every line read by hand: a past fact written as an infinitive task is a failure. | 0 accepted outputs |
| **P2 — post-check inputs** | R6, R7 (four items, < 100 characters): ≥ 2 bullets, i.e. they pass the post-check. R10 (one idea): reported. | R6, R7: every run ≥ 2 bullets |
| **Regression** | §5's B2 (language, 16), B3 (S, 0 tasks from statements), B4 (N1-N6), B5 (shape), B7 (band) on the candidate | as in §5 |

**Not barred, reported:** filler (`uh`, `euh`) left in a bullet on R3, R9; a duplicated bullet
on R9; title readings per language on T.

**Decision rule:** the first candidate that holds every bar ships. A bar that no candidate holds
after three is reported, not worked around.
