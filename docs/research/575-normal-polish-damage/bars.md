# Normal polish damages correct input — questions, bars and plan (#575)

**Issue:** [#575](https://github.com/getdictus/dictus-ios/issues/575)
**Fixtures:** `fixtures.json` (this folder) — 14 French dictations
**Arms:** `arms/`
**Date:** 2026-09-23
**Where:** Mac, macOS 27.0 (26A428), Apple Intelligence on, `polish-harness`.

> **Everything in this file was written and committed BEFORE the first model call on
> `fixtures.json`.** Same discipline as #439, #437 and #570: a threshold that can still
> move is not a threshold. Anything added after the first call goes in a dated
> amendment section at the bottom and says so.

This is a diagnosis round. No production prompt and no Swift source changes on this
branch. The arms under `arms/` are passed to the harness with `--instructions`; none of
them ships.

---

## 0. What the code says before any model is called

Two facts from reading the code and the device export. They decide how the round is set up.

**The device rows went through `PolishAutoPrompt`, not `PolishNaturalPromptFR`.** The
2026-09-17 capture was taken with transcription language on Auto-detect (#439's
comment of that day: *keyboard `fr`, auto-detect*). `PolishService` routes
`.autoDetected` to `polishAutoDetected`, and `AppleFoundationModelsPolishEngine`
resolves `(.auto, _)` to `PolishAutoPrompt`. The device output backs this up: in
`docs/research/572-message/corpus.json`, the `_normalPolish` of `2-message` has an ASCII
space before `?` and no U+00A0 anywhere. The French typography post-pass inserts an NBSP
there, and it only runs on the per-language route. So the device's rows 1, 2 and 4 ran
on the auto route. Rows 3 and 5 were harness runs with `lang: fr`, so they ran on
`PolishNaturalPromptFR`. Both routes are measured here.

**The code around the model cannot delete or substitute a word, with one exception
this round found.**
- `PolishPostpass.decodeFromEngine` changes only whitespace: marker → `\n`, blank-line
  cap, NBSP before `? ! ; :`, and sentence-initial `A` → `À`. No word can go missing
  there.
- `VerbalPunctuationPrepass.apply` is a no-op on 13 of the 14 fixtures. This was
  checked byte for byte with `polish-harness prompt --out`. The exception is
  `D1-selfcorrect`. Normalisation step 2 (`([,.])[ \t]*\1+` → `$1`) collapses Parakeet's
  ellipsis `dès que...` to `dès que.`, so the engine receives a sentence ending on a
  conjunction. That matches the hesitation #439's 2026-09-17 comment filed as *"a
  hesitation left broken"*. It is not one of #575's five rows. It is recorded because it
  is the one defect in this family that code causes, not the model.
- `engineOutput` in the harness and in the export is the decoded string, so it is
  logged *after* the post-pass (#523's lesson). Because the post-pass only touches
  whitespace, any word missing from `engineOutput` was missing from the model's own
  output. `show --engine-out` prints it on every success.

**One correction to the issue's table, from the transcript of the run it cites.** The
2026-09-17 harness run behind rows 3 and 5 was two arms: the shipping prompt, 2 runs,
and an emoji-palette arm, 3 runs. Row 3 was `reviendrai` 2/2 on shipping, and
`reviendrai`, `revoilà`, then intact on the palette arm, so **4 of 5**, not 3 of 3. Row 5
was lifted 2/2 on shipping and 1/3 on the palette arm, so **3 of 5**, not 2 of 6. The
shipping-prompt-only rate for both rows was 2 of 2.

## 1. Questions

- **Q1 — Reproduction.** How often does each of the five rows happen, on each route?
- **Q2 — Rate or shape.** Does the damage follow the *shape* (sign-offs, politeness
  formulas, idioms, slang, register markers) or does it land anywhere at a base rate?
  `C1-control` has none of those shapes. The `P*` probes carry the same shapes in
  different messages.
- **Q3 — Localisation.** For each damaged output: is it the model, the code around it,
  the prompt's examples, or the prompt's rules? The arms separate these:
  - `S-*`: the shipping prompts, byte for byte (`polish-harness prompt --out`).
  - `X-natural-fr-no-examples`: shipping FR with every worked example and
    counter-example removed, nothing else changed. If the damage drops, the examples
    teach it.
  - `M-minimal-punctuation-only`: a 451-character prompt that allows only punctuation
    and capitalisation and forbids changing any word. If the damage survives this, it is
    the model's prior and the prompt is not what triggers it.
  - `T-*-taught`: shipping plus **one** PRESERVE line naming the two classes, with one
    example each, both taken from the rows (`s'il te plaît` / `bisous`,
    `je suis preneur`). This is a candidate fix shape, measured so it has a cost and not
    just an estimate.
- **Q4 — Guardrails.** Would any of the five shipped checks (length, language,
  grounding, prefix alignment, segment overlap) refuse a damaged output? A damaged output
  whose outcome is `success` answers that directly: all five passed it.
- **Q5 — What a detector would cost.** A model-free check could refuse on "a word the
  speaker dictated is gone". How much damage would it catch, and how many faithful
  outputs would it refuse? #466 is the standing warning: its prefix check refused 10
  repairs in 10.

## 2. Fixtures

| id | What it carries | Rows | Held out from arm T? |
|---|---|---|---|
| `D1-selfcorrect` | device, self-correction | none (pre-pass ellipsis, §0) | n/a |
| `D2-bisous` | device | **1, 4** | taught (`s'il te plaît`, `bisous`) |
| `D3-petit-peu` | device, whose output lost `petit` | none | yes |
| `D4-preneur` | device | **2** | taught (`je suis preneur`) |
| `H1-thanks` | the 2026-09-17 harness fixture, verbatim | **3, 5** | yes |
| `P1-bisous-alone` | sign-off + politeness | shape of 1 | taught words |
| `P2-merci-avance` | politeness + two-part sign-off | shape of 1 | partly (`merci`) |
| `P3-bises-plus` | two short sign-offs | shape of 1 | **yes** |
| `P4-preneur-alone` | idiom | shape of 2 | taught |
| `P5-revaudrai-alone` | idiom | shape of 3 | **yes** |
| `P6-capte-alone` | slang verb | shape of 5 | **yes** |
| `P7-idioms` | three other idioms | shape of 2/3 | **yes** |
| `P8-register` | `comment tu vas`, `checker`, `le mail` | shape of 4 | **yes** |
| `C1-control` | nothing at risk | control | n/a |

Each fixture carries `_keep` (phrases that must survive) and `_forbid` (forms that
must not appear). `harness/score.py` reads them. The comparison lowercases both sides
and maps `’` to `'`.

## 3. Runs

| Arm | Route | Runs per fixture | Outputs |
|---|---|---|---|
| `S-natural-fr-shipping` | `lang: fr` → `PolishNaturalPromptFR` | 10 | 140 |
| `S-auto-shipping` | `--lang auto` → `PolishAutoPrompt` | 10 | 140 |
| `X-natural-fr-no-examples` | `lang: fr`, `--instructions` | 5 | 70 |
| `M-minimal-punctuation-only` | `lang: fr`, `--instructions` | 5 | 70 |
| `T-natural-fr-taught` | `lang: fr`, `--instructions` | 5 | 70 |
| `T-auto-taught` | `--lang auto`, `--instructions` | 5 | 70 |

Shipping arms run with no `--instructions`, so the harness sends exactly what the app
sends. Every capture is written with `--engine-out`.

## 4. Bars

Q1–Q3 are diagnostic, so most bars are *report*, with the counting rule fixed here:

| # | Bar | Rule |
|---|---|---|
| B1 | Row reproduced | A row counts on a run if its predicate fires: row 1 = `s'il te plaît` or `bisous` missing from `D2`; row 2 = `je suis preneur` missing from `D4`; row 3 = `revaudrai` missing from `H1`; row 4 = any of `vas-tu` / `vérifier` / `email` present in `D2`, each also counted alone; row 5 = `se capte` missing from `H1`. Reported as k/n per route. |
| B2 | Shape vs base rate | A fixture is *damaged* on a run if any `_keep` is lost or any `_forbid` appears. **Shape** means the `P*` probes are damaged at a rate at least 3× `C1-control`'s *and* at least 2 of the 8 probes are damaged at least once. Otherwise the defect is called a base rate. |
| B3 | Localisation | *Model prior*: arm M still damages at least one row fixture at least once in 5. *Taught by the examples*: arm X's damage count is at most half of `S-natural-fr`'s, on the same fixtures, per run. *Code*: a word missing from `engineOutput` that is present in the pre-passed input the engine got. Decided by §0's reading of the post-pass, and checked per output. |
| B4 | Guardrail blindness | Count damaged outputs whose outcome is `success`. Any count above 0 means the five checks are blind to that shape. |
| B5 | Taught-line effect | Arm T against S on the same route. It is **effective on taught items** if damage on the taught fixtures drops by at least half. It **generalises** if damage on the held-out probes (P3, P5, P6, P7, P8, H1) also drops by at least half. Reported with its character cost against the #270 input headroom. |
| B6 | Health | Outcomes other than `success` are reported per arm. A non-success inserts the floor, so it is excluded from B1/B2 denominators and counted separately. |

### Q5 — the detector, declared before it runs

Candidate **D-lost**, model-free. It is scored after the live runs, on three kinds of
pairs: this round's outputs, `docs/research/413-414-guardrail/freepolish.json` (free-polish
outputs already hand-labelled as accepted and faithful), and the #439 short-edit captures
(`docs/research/439-natural-contract/raw/short-*-show-5runs.txt`, 60 longform outputs).

- Tokenise both sides: lowercase, `’` → `'`, split on anything that is not a letter or
  digit, so apostrophes and hyphens split too. A word is *lost* when the input has more
  of it than the output.
- Not counted as lost: the fillers rule 7 licenses (`euh`, `hum`, `bah`, `heu`, `ben`),
  an immediate same-word repeat in the input (rule 6), the verbal-punctuation words
  `virgule` and `point`, and spelled-out number words when the output gained a digit
  (rule 3).
- **D-lost-1** refuses on ≥1 lost word outside a fixed French function-word list
  (`harness/detect.py`, `STOP`). **D-lost-2** refuses on ≥2.

Every output either variant flags is **read by a human** and labelled `damage` or
`faithful`. The count is a screen, not a verdict, as in #570 §2.

| # | Bar | Threshold |
|---|---|---|
| B7 | Catch | D-lost catches every B1 row occurrence in the deletion/substitution classes (rows 1, 2, 3, 5 and the `vérifier` / `email` parts of row 4). Reported per class. `comment vas-tu` is expected to be **missed** by construction, because the words survive and only their order changes. That is declared here, before the run. |
| B8 | False refusal | Faithful outputs refused / faithful outputs scored, per corpus. **Viable if ≤ 5 %** on the longform corpus *and* on this round's shipping arms. |
| B9 | What a false refusal costs | On the free polish, a refusal inserts the floor (pre-pass + typography), **not** nothing. Measured as the word-level difference between floor and accepted output over this round's successes. That difference is what a user loses on a false refusal. |

## 5. Risks, stated before the numbers

- **The Mac is not the phone.** #570 §9 measured macOS 27.0 as a different model from
  macOS 26.5.1, and still not the iPhone's. Anything the Mac does *not* reproduce says
  nothing about the device. The deletion row has only been seen on device.
- **Fourteen fixtures, 5–10 runs.** Sized to find a shape and localise it, not to
  estimate a rate to a percent.
- **Arm T teaches two of its targets by name.** Declared in §2. Only the held-out column
  can say whether a PRESERVE line generalises. #439 measured a taught item working
  (`machin`) and a stated rule not working (`cela`).
- **D-lost is bag-of-words.** It cannot see reordering, including `comment vas-tu`. It
  will read a legitimate rule-8 repair as a loss. That is #570's limit and #466's
  lesson, and it is named here so the number is not read as more than it is.

---

## Amendment A1 — 2026-09-23, made after reading D-lost's flags on the two legacy corpora, before scoring this round

Two defects in the **instrument**. Neither touches a threshold.

- **The detector compared the model's output against the raw, not against the pre-passed
  text.** On `freepolish.json` it flagged `interrogation`, `exclamation`, `retour` and
  `ligne` as lost on every verbal-punctuation fixture. The regex pre-pass had already
  replaced those, as the pipeline does, and the guardrails in production judge against
  the pre-passed text too. `detector_eval.py` now applies a Python mirror of
  `VerbalPunctuationPrepass`'s French rules first. That is 22 fewer flags, and every one
  of them was a false positive.
- **`oeuf` against `œuf` counted as a loss.** The ligatures now fold to two letters in
  `detect.tokens`. That is 5 fewer flags, all false positives.

The same corpora ran through the detector again after both fixes. Every flag left is
read by hand in `labels.json`.
