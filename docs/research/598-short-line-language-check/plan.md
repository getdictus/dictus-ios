# The language check on a short line — plan and reading rules (#598)

**Issue:** [#598](https://github.com/getdictus/dictus-ios/issues/598) — *"The language check
refuses a correct output on a short line: es read as pt, da as nb"*. Its section **"What to
measure before any change"** is the contract; this note answers its three measurements and
nothing else.
**Date:** 2026-10-05. **Machine:** macOS 27.0 (26A428), Xcode 27.0. **Baseline:** `develop`
at `b1f15b4f`.

> Written and committed **before the first reading was taken**, the way every bench round
> under #587 committed its `bars.md` first. Nothing here calls a model: every number is the
> shipping `NLLanguageRecognizer` reading text that is already committed.

**Not in scope** (per the issue): what the user sees on a refusal (#580), the meaning
guardrail (#570). **No production code changes in this round.** Which fix ships, if any, is
the maintainer's call once the numbers exist.

---

## 1. The check, and everything that consumes it

`PolishGuardrail.detectedLanguageMatches` → private `matches(polished:expectedCode:thresholds:)`:

1. Output trimmed; under 12 characters passes.
2. **Whole pass**: the recogniser's top hypothesis on the whole output; refuses when it
   disagrees at **≥ 0.5**.
3. **Segment pass** (#413): `PolishSegmentation.segments(of:)` cuts on lines, strips one
   list marker; if more than one segment, every segment of **≥ 12 characters** whose top
   reading disagrees at **≥ 0.85** refuses the whole output.
4. "Disagrees" is `PolishGuardrail.matches(read:expected:)`: equal codes, or both inside
   `{da, nb, no, sv}` (#588's family exception). That one function serves **both** passes.

Its only production caller is `PolishPipeline.languageGuardrailPasses`, one branch per
contract:

| Contract | Who | Expected code |
|---|---|---|
| `.polishTarget` | free polish on the fr/en/es/de route | the prompt language |
| `.sameAsInput` | free polish on Auto, and `Liste`, `Structuré`, `Message`, `Résumé` | `PolishPipeline.detectLanguageCode(in: preprocessed)` — the **input's** reading, not the fixture language |
| `.fixed(target)` | `Traduction → X` (targets fr/en/es/de) | the target |

Consequence for any fix: a change inside `matches(read:expected:)` reaches all three
branches, **including `Traduction → ES`**, where a Portuguese dictation the model failed to
translate would read `pt` against an expected `es`. That branch has no committed corpus;
§5 says how it is reported.

Other readers: `PolishGuardrailCorpusReplayTests` (uses the check as the upstream lock in
its counting rule), and `polish-harness guardrail` (`GuardrailCorpus.scoreLanguage`).

## 2. Corpora

| Name | What | Labels |
|---|---|---|
| **K414** | `docs/research/413-414-guardrail/*.json`, 482 outputs — the corpus #413's thresholds and PR #588's replay were scored on | `language` ∈ `sameLanguage`/`bilingual`/`wrongLanguage`, by hand, committed |
| **C587** | every JSON capture under `docs/research/587-*/` and `docs/research/571-summary/{runs,step2}/` with `hasEngineOutput: true` | none: the labels this round needs are added by hand (§4) |

C587's records carry the **engine's** output (post-pass applied, before any guardrail), the
fixture id and the outcome, but not the transcript. The transcript is resolved from the
fixture id against `DictusCore/Sources/polish-harness/fixtures/*.json` and
`docs/research/571-summary/step2/fixtures-*.json` (251 ids, none conflicting, every capture
id resolves — checked before this note). The expected code is then computed exactly as
`.sameAsInput` does: `detectLanguageCode(in: VerbalPunctuationPrepass(raw))`. A transcript
the recogniser cannot read at 0.5 makes the pipeline pass through; such outputs are counted
and excluded. Captures under the free polish (`571-summary/runs/compare-polish.json`) are
read the same way; any output whose fixture language and input reading disagree is listed.

Several C587 arms are deliberately bad prompts (step 1 of #587's ladder, English examples)
that produced genuine wrong-language outputs. They stay in: they are the only committed
source of **genuine** catches outside K414, so they are what a cost is measured against.

The shipping arm of `587-structured-rewrite` is re-run in each of its three rounds; those
are independent model runs and count separately.

## 3. The instrument

A model-free `polish-harness langcheck` subcommand (bench code, test target side of the
house, no production change):

- reads K414 and C587 files, computes the expected code as above;
- records for each output the **shipping verdict**, straight from
  `PolishGuardrail.detectedLanguageMatches(polished:inputLanguageCode:)`;
- records the raw readings the verdict is made of: whole output top code + confidence, and
  each segment's text, length, top code + confidence;
- writes them to `readings.jsonl`, committed.

`summarise.py` then derives every variant **from the stored readings only**, and first
re-implements the shipping rule and asserts it reproduces the Swift verdict on **every**
output. A mismatch aborts the script. That is what makes the variants trustworthy without
editing `PolishGuardrail`.

Variants scored:

| Id | Rule |
|---|---|
| **V0** | shipping |
| **V1** | whole pass only — the segment pass removed (measurement 2) |
| **V2** | `es`/`pt` added as a family, **both passes** — what adding them to `matches(read:expected:)` would do (measurement 3) |
| **V3** | `es`/`pt` family in the **segment pass only**; the whole pass stays strict |
| **V4-n** | segment length floor raised to n ∈ {20, 25, 30, 40, 60} characters, everything else shipping |

## 4. Hand labels

Two label sets, written into `labels.json` with a one-line reason each:

- **Every segment** of C587 that refuses under V0 (disagrees at ≥ 0.85, ≥ 12 chars, outside
  the shipping family) is labelled `misread` (the line is in the expected language, the
  recogniser is wrong) or `foreign` (the line really is in another language). The output is
  a **false refusal** when every refusing segment is `misread`, and the whole pass agrees.
- **Every output** whose whole pass refuses under V0 and that is not obviously in another
  language is labelled the same way.

The labeller is an agent, not a native speaker of Spanish, Portuguese, Danish, Norwegian or
Swedish — the same limitation PR #588 and PR #597 declared on their hand reads. Labels are
committed so they can be disagreed with line by line.

## 5. How each measurement is read

**M1 — does the misreading survive on ordinary length, per pair.**
- Every V0 language refusal in C587, by (expected → read) pair, with refusing segment
  length, output length and confidence, and its label.
- Over every segment of ≥ 12 characters in C587 whose output is labelled correct-language
  (no `foreign` segment, whole pass agrees): the share read as another language at ≥ 0.85,
  by pair and by segment-length bucket (12–24, 25–49, 50–99, 100–199, 200+).
- Whole-pass false refusals (the whole output misread at ≥ 0.5), with output length.
- Answer, per pair: the longest segment ever misread at ≥ 0.85, and whether any misread
  survives at 100+ characters.

**M2 — read the whole output instead of a line.**
- K414: V1 against V0, **every one of the 18 catches named**, kept or lost, and false
  rejections on the `sameLanguage` population.
- C587: outputs V0 refuses and V1 accepts — split into false refusals avoided (labelled
  `misread`) and genuine catches lost (labelled `foreign`), by pair.

**M3 — the cost of an `es`/`pt` exception, the way PR #588 scored the Scandinavian one.**
- K414: V2 and V3 against V0, every catch named, kept or lost; false rejections. Also stated:
  how many K414 outputs involve `es` or `pt` at all, i.e. whether this replay can see the
  pair.
- C587: refusals avoided by V2 / V3 (named), genuine `es`↔`pt` outputs or lines the
  exception would let through (named), and every C587 output whose whole reading or any
  segment is `es`/`pt` against the other expected.
- `Traduction → ES`: not measurable from committed data (no Portuguese-input translation
  capture exists). Reported as a structural cost of V2, with what V3 or a contract-scoped
  rule would avoid.

## 6. Risks, written down before the readings

- **Platform.** `NLLanguageRecognizer` ships its model with the OS. Every reading here is
  macOS 27.0 (26A428). The phone runs iOS 27; the 0.91 and 0.993 readings in the issue are
  Mac readings too. No number here is claimed for iOS; the one check that would settle it is
  in the manual list.
- **The outputs are Mac outputs**, and most non-FR/EN fixtures are agent-translated clean
  text (PR #588, PR #597). They measure what the recogniser does on Apple FM's prose, not on
  a real Spanish or Danish speaker's dictation.
- **Small pair samples.** `es` and `pt` are a few hundred outputs each, mostly the same six
  translated dictations. A rate of 0 on them is a bound, not a proof.
- **The labels are judgements** (§4).
