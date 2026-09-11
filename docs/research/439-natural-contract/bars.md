# Natural contract, three violations — bars and plan (#439)

**Issue:** [#439](https://github.com/getdictus/dictus-ios/issues/439)
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/longform-fr.json` (the six #437
dictations, landed in the previous commit)
**Date:** 2026-08-27

> **Everything in §1–§4 was written and committed BEFORE the first model call on this
> fixture set.** That is PR #388's and PR #412's discipline, and it is the only reason
> the numbers in `findings.md` are worth reading: a threshold that can still move is not
> a threshold. §5 onward is written after.

---

## 1. What is being fixed

#439 measured three violations of [ADR 0003](../../adr/0003-natural-polish-contract.md) on
one device run, and argues they are one calibration problem:

- **A — rule 8 never fires.** Six incoherent ASR segments went through untouched, every
  one recoverable from the surrounding words.
- **B — the Preserve list is violated by the one repair that did fire.** `ça va déborder`
  came back `cela débordera`: written register, on a rule-8 repair.
- **C — the Forbidden list is violated twice.** `en calcul` was deleted mid-sentence, and
  `machin` was substituted with `machine`.

Raising repair aggressiveness without tightening the deletion ban makes C worse;
tightening C alone leaves A untouched. One round, one fixture set.

## 2. Which prompt actually serves which path

The issue is titled against `(.natural, fr)`, and **none of the six measured runs used
that prompt.** All six carry `mode: auto` / `detectedLanguage: fr`, because the device
had `transcriptionLanguageMode: autoDetect`, so
`AppleFoundationModelsPolishEngine.instructions(for:language:)` routed them to
`PolishAutoPrompt` — the language-agnostic prompt from #239.

That changes the diagnosis of A. **`PolishAutoPrompt` has no rule 8 at all**: its numbered
rules stop at *"Fix obvious one-letter typos"*. Rule 8 was not ignored on those six runs,
it was never sent. And the one repair that did fire — the English clause in fixture 3 —
fired *against* that prompt's own `PRESERVE` line (*"Mixed-language input keeps every part
in its original language"*) and its `FORBIDDEN` line (*"Do NOT translate. Not even
partially."*).

`PolishNaturalPromptFR` does carry rule 8, and it under-fires for a different reason: its
only demonstration of the rule is an off-language fragment that gets **deleted**, not
reconstructed. The prompt teaches the whole-clause shape and the deletion response, which
is exactly the pair the measurement found.

So both prompts are edited, as the issue's Scope section already asks, and both paths are
measured. EN/ES/DE are explicitly deferred by the issue until FR holds.

## 3. The bars

Declared here, before the first model call. Scored by
`harness/score.py` over a `polish-harness show --runs N` capture; the same properties are
also in the fixture `expect` blocks so `eval` reports them per fixture.

| # | Bar | Threshold |
|---|---|---|
| 1 | Incoherent ASR segments repaired | **≥ 4 of 6, per run** |
| 2 | Register preserved | **0** occurrences of `cela`, of an added `ne`, of `19h`-style forms expanded to `19 heures`, of `machin` → `machine` |
| 3 | Dictated content deleted | **0** occurrences (`en calcul`, every figure, name, date, and fixture 5's trailing sentence) |
| 4 | Content invented | **0** occurrences (holds 6/6 today, must not regress) — scored by `eval`, **not** by `score.py`, which has no invention predicate |
| 5 | Length ratio | inside **[0.92, 1.15]** per fixture, and guardrail rejections do not rise above the measured **0/6** |
| 6 | **Scope fence** | **0** line breaks in any output, and 0 `<<NL>>` leaks |

The six repairs of bar 1, from the issue body:

| | Fixture | Raw | Intended |
|---|---|---|---|
| R1 | 3 | `la salle à tante` | `la salle d'attente` |
| R2 | 5 | `il faut que je répète le comptable` | `je rappelle` |
| R3 | 5 | `si je les zappais` | `si je l'ai zappé` |
| R4 | 5 | `ce qui est un peu le cas honnête` | `honnêtement` |
| R5 | 4 | `Il prend ses morceaux` | `ces morceaux` |
| R6 | 2 | `on soumet la partie Apple Store` | `App Store` |

Two of these thresholds are mine rather than the issue's, and are declared as such:

- **Bar 5's band is [0.92, 1.15], not the guardrail's [0.5, 2.0].** The measured deltas on
  this run span -2.2 % to +1.5 %. A deletion the size of `en calcul` is invisible at
  `[0.5, 2.0]`, which is #439's own point about the guardrail, so the fixture carries a
  tripwire tight enough to see one. The guardrail band itself is unchanged and is what
  bar 5's second half tracks.
- **Bar 6 is the scope fence, not an improvement.** #437 owns line breaks and edits the
  same prompts. A break appearing in this round is a regression *for this round*, and the
  two must be measured separately or neither result attributes to anything.

### What is held out, and what is taught

Bar 1's six pairs appear **nowhere** in the prompt edits. Every ASR-repair example added
to a prompt uses a different instance of the same shape, so a pass measures the rule and
not the example.

Bar 2's `machin` is the opposite and is declared so: `machin` is added by name to the FR
`PRESERVE` list, which is the maintenance path ADR 0003 names for exactly this
(*"terms found unexpectedly translated can be added in PR"*). Its check verifies a taught
fix does not regress; it is not a held-out measurement. Bars 2 (`cela`, `ne`) and 3 are
stated as rules with generic examples, which is the fix, not teaching to the test.

## 4. Plan

Ordered, with what verifies each step.

1. **Land the fixtures.** Done in the previous commit — the prerequisite both #439 and
   #437 need. *Verified:* `polish-harness prompt` routes all six to `mode=natural`, and
   the six `raw` fields are byte-identical to the device export and to #437's comment.
2. **Declare the bars.** This file plus `harness/score.py`. *Verified:* committed before
   any model call on `longform-fr.json`.
3. **Teach the harness to replay a fixture set through the Auto path** (`--lang`). Without
   it the path that produced all six measured defects cannot be run off-device without
   duplicating the six transcripts into a second file. *Verified:* `--lang auto` on
   `longform-fr.json` prints `mode=auto` under `polish-harness prompt`.
4. **Capture the baseline**, both paths, 5 runs per fixture, shipping prompts, plus the
   shipping prompt bytes. *Verified:* the capture reproduces the device defects; if it
   does not, the harness is not measuring what the device measured and the round stops.
5. **Edit `PolishNaturalPromptFR`** — rule 8 widened to the plausible-but-incoherent class,
   repair required *in place* and *in the speaker's register*, `PRESERVE` gains the spoken
   forms the run lost, `FORBIDDEN` gains an explicit ban on deleting meaningful words.
6. **Edit `PolishAutoPrompt`** — the same three changes, language-agnostic, with the ASR
   rule worded so it cannot be read as a licence to translate. This is the prompt that
   took all six runs and the one carrying the most risk, because it also serves zh, it,
   pt and the rest of the long tail.
7. **Add prompt-contract tests** (`swift test`), in the shape of `PolishAutoPromptTests`:
   structural invariants only, since quality is the harness's job.
8. **Re-measure**, both paths, same command, same run count. Score with `score.py`.
9. **Regression-check the untouched fixture sets**: `eval seed.json` and `eval auto.json`,
   before and after. `auto.json` is the one that matters — it carries the anti-translation
   counter-examples the new rule could undermine.
10. **Write `findings.md`** against these bars, whatever it says.

### Risks

- **The new ASR rule reads as a licence to translate.** `PolishAutoPrompt`'s whole purpose
  is output language == input language, and "reconstruct an off-language fragment" is one
  clause away from "translate the input". Mitigated by wording (the trigger is
  *incoherence*, not *foreignness*), by an explicit carve-out for meaningful anglicisms and
  quoted speech, and by step 9's regression run over `auto.json`.
- **Repair and deletion pull against each other.** More repair aggressiveness is more
  licence to rewrite. Mitigated by making the repair *substitutional* — the reconstructed
  words replace the broken ones in place — and by the explicit deletion ban.
- **Over-repair.** A prompt told to fix incoherent segments can start "fixing" the
  speaker's deliberate oddities. Fixture 1 is the control: it carries no ASR defect, so any
  change beyond punctuation there is over-repair.
- **Apple FM is non-deterministic and the Mac is not the iPhone.** Everything here is a Mac
  measurement over 5 samples per fixture. It cannot replace a device pass, and the device
  pass is on the manual list.

### 4.1 One amendment, made at the baseline and before any prompt was touched

The baseline run showed the scorer classifying three things as **deleted content**
that are not deletions, and the classification is corrected rather than the threshold:

- `11h` → `11 h` and `11 heures`. The content survives; the *format* does not, which
  ADR 0003's Preserve list covers under *"number formats like `19h`, `25€`, `2k` stay"*.
  Moved to bar 2, where it is still a 0-tolerance check.
- `6 mois` → `six mois`, `15 trucs` → `quinze trucs`. Same shape, digits spelled back
  out against rule 3. New 0-tolerance check under bar 2.
- `dictus` left lowercase. That is a rule-2 capitalization miss, not a deletion, and
  #439 bars neither. The deletion check now matches case-insensitively and the
  capitalization behaviour is reported in the findings without being a bar.

**No threshold moved, and nothing was relaxed** — bar 2 gained two checks and bar 3
lost three false positives. The fixture `expect` blocks are untouched, so `eval` keeps
reporting `contains "11h"` and `contains "14h"` as the failures they are.

---

# Part 2 — the bare `point` clause in Natural rule 4

**Date:** 2026-09-11
**Fixtures:** `harness/point-fr.json` (10 French sentences, written for this round)
**Scorer:** `harness/score-point.py`

> **Everything in §5–§8 was written and committed BEFORE the first model call on
> `point-fr.json`.** Same discipline as §1–§4, same reason. §9 is written after.

## 5. The question

FR Natural rule 4 teaches bare `point` → `.`. EN Natural rule 4 teaches
`period` / `full stop` → `.`. `VerbalPunctuationPrepass` excludes the bare period word
on purpose (#185) and `PolishAutoPrompt` omits it on purpose.

**This is not the contradiction it looks like.** #185 ruled the substitution too dangerous
for a *regex*, which has no context, and its doc comment ends with *"Revisit once the LLM
owns punctuation contextually"*. The prompt rule is that revisit.

**What is at risk.** `point` is an extremely common French noun: `un point de vue`,
`faire le point`, `à quel point`, `un point final`. Applying rule 4 to one of those deletes
a content word and produces a broken sentence — which is the exact class the FORBIDDEN
block now bans, and rule 4 is named in that ban as one of only three licences to remove a
word. The clause is a licensed exception sitting on an ambiguous common noun.

There is a second cost the #185 comment does not mention. If the clause is removed, the
model has no licence to delete the word `point` at all: the deletion ban forbids it, and
rules 6 and 7 cover only stutters and fillers. The prepass comment's claim — *"the LLM
already supplies the terminal period at natural sentence boundaries on its own (observed
on device)"* — addresses the **mark**, never the **leftover word**. Both are counted here.

## 6. The bars

Two arms on `(.natural, fr)`, 10 fixtures × **10 runs** each, 100 outputs per arm:

- **Arm A** — the shipping prompt, dumped byte-for-byte with `polish-harness prompt`.
- **Arm B** — arm A with the six characters `` `point` → `.`, `` removed from rule 4, and
  nothing else. Committed as `prompts/` files so the diff is inspectable.

The French verbal-punctuation pre-pass runs before the engine in both arms, so by the time
the model sees the text every other rule-4 command has already been substituted in code.
**Bare `point` is the only live rule-4 clause on the French path**, which is what makes
this A/B clean.

| # | Bar | Threshold |
|---|---|---|
| P1 | **Noun class, arm A**: a `point` noun lost from the output | **0 occurrences.** Any occurrence at all decides the question against keeping the clause |
| P2 | **Noun class, arm B**: same count | reported, no threshold — the control that attributes any P1 loss to the clause |
| P3 | **Command class, both arms**: terminal mark present at the boundary | reported, no threshold — this is the prepass's uncounted claim, counted |
| P4 | **Command class, both arms**: the command word `point` removed | reported, no threshold — this is what the clause actually buys |
| P5 | **Health**: non-success outcomes | reported. A non-success is **excluded from P1–P4's denominator**: the free polish then inserts the deterministic floor, which still carries `point`, so scoring it would count a guardrail rejection as a clean run |

P1 is a **0-tolerance bar and it is the decision rule**, stated in the issue and repeated
here: the failure it catches is a silent content deletion the user cannot see, because the
output reads as a grammatical French sentence with one word missing.

### Fixture classes

**Noun class (5).** `point` as an ordinary noun, in shapes a person actually dictates.
`N1-point-final` is the worst case the prepass doc-comment names by hand.
`N5-deux-points-nommes` carries the word twice, once at a clause boundary where a mark
would read as plausible.

**Command class (5).** `point` dictated as a punctuation command at a natural sentence
boundary, in the **two shapes the device produces**:

- *bare* (C1–C3): the word alone between two clauses, no mark around it.
- *Parakeet-punctuated* (C4–C5): the STT surrounded the keyword with its own punctuation,
  which is the shape `VerbalPunctuationPrepass.normalize` exists for. Here the mark is
  already present and only the word is left to remove, so P3 is uninformative on these
  two and P4 is the whole measurement.

The fixtures are 85–115 characters so `NLLanguageRecognizer` is confident and the
gibberish gate does not skip them. None of them is in either prompt.

## 7. The decision rule, declared before the numbers

- **Noun class clean under arm A (P1 = 0)** → keep the clause in FR and EN Natural. Record
  P3 and P4 as the first count of the prepass's claim.
- **Noun class not clean (P1 > 0)** → remove the clause from FR Natural (`point`) and EN
  Natural (bare `period`; `full stop` stays, it is unambiguous and the pre-pass already
  does it in code). Record the numbers, which closes #185's open revisit with a
  measurement instead of a judgement.

Either outcome is a legitimate result and gets written up in `findings.md`.

## 8. Risks

- **Ten fixtures is a small set.** It is sized for a 0-tolerance bar, where one occurrence
  decides, not for estimating a rate. P3 and P4 are reported with their denominators and
  are not claimed as precise rates.
- **Mac ≈ iPhone, not identical** — the same caveat every round here carries. A device
  confirmation is on the manual list whichever way this goes.
- **The command class conflates two things on C4–C5.** Declared above rather than averaged
  away: on those two the mark is in the input, so only P4 measures anything.
- **Arm B removes a clause rather than adding one**, so it is the shorter prompt. Any
  difference in favour of B is therefore free of the headroom cost (#270) that decided the
  short-vs-full edit in Part 1.
