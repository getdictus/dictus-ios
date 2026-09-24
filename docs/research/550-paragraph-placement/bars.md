# Paragraph placement — bars and plan (#550)

**Issue:** [#550](https://github.com/getdictus/dictus-ios/issues/550)
**Brief:** the issue comment of 2026-09-11 19:16, *"The pause hypothesis is FALSIFIED"*.
The issue **body** proposed a silence-at-a-sentence-boundary rule; that comment kills it
on four controlled recordings, and it is the brief this round is built against.
**Date:** 2026-09-11

> **Everything in §1–§8 was written and committed BEFORE the first model call on an
> arm of this round.** That is the discipline #439 and #437 ran on, and the only
> reason numbers are worth reading afterwards.
>
> Two model calls precede this file and are declared here rather than hidden. One
> `swift run polish-harness show Sources/polish-harness/fixtures/longform-fr.json
> --runs 1` on the shipping prompts, run to confirm Apple Intelligence is available
> on this Mac before anything was written; it reproduced the invariant (6/6 success,
> 0 line breaks) and changes nothing below. The second is a Parakeet transcription
> (§8), which drives no Apple Foundation Model at all.

---

## 1. The question this round asks

Not *"can the shipping prompt be made to break paragraphs"*. #437 answered that: no,
over 432 outputs and twelve arms, and its `findings.md` records that `MAY`, `MUST`,
worked examples, a counter-example, the GOAL line and a real newline instead of the
`<<NL>>` marker all returned **0 breaks in 132 outputs**. Re-wording the shipping
prompt is a re-run, not an experiment, and `PolishPromptParityTests` pins the ban.

The question here is a **capability** question, asked with the lightest possible
prompts:

> Handed already-polished French text and the single job of splitting it, can Apple
> FM place paragraph breaks the way the reference does — at sentence boundaries, in
> roughly the right number, without touching a word?

#437's isolated second pass already established half of the answer: handed that job
alone, the model returned whitespace-stripped output byte-identical to its input
**30 times out of 30**, with no list syntax anywhere. Fidelity is free when the task
is isolated. What it did badly was *how many* breaks and *where* — one per sentence
on fixture 4 (5/5), none at all on fixture 2 (5/5).

**Nobody ever told it how many to place.** That is the untested variable, and it is
what this round exists to test.

## 2. What the reference is, and what it is not

The falsification comment's own conclusion:

> Typeless is not finding the right boundary. It is choosing a plausible one, and it
> always chooses.

Text A is the evidence: the same four sentences, dictated twice, split two different
ways, both defensible. So **placement agreement with Typeless is reported, never
barred.** Scoring against it as ground truth would repeat #437's mistake from the
other side — #437 required fixture 1 to return zero breaks and scored Typeless's
break there as over-formatting, and the maintainer's reading of 2026-09-11 is that
that break is correct.

One invariant does survive the falsification and it is the one hard bar below: over
seven breaks on five recordings, **no break ever lands inside a sentence.**

## 3. The input texts — already polished, not raw

The arms run on **polished** text, not on raw STT. Three reasons, all declared before
the round:

1. A paragrapher is a *presentation* pass. It sits after the words are settled.
   #437's second-pass probe is built the same way and its 30/30 fidelity number is
   the one this round must not regress; measuring on a different input would make the
   comparison meaningless.
2. Fidelity is only measurable against an input the pass is not allowed to change.
   Polish legitimately changes words (ADR 0003 rules 4, 6, 7, 8), so
   *whitespace-stripped output == whitespace-stripped input* is not a predicate that
   can be written against a raw transcript.
3. Fixture 7, the 89 s sample the maintainer recorded on 2026-09-11, is a
   Dictus **end-to-end** output — Parakeet v3 then Normal polish — so it is polished
   text by construction. Putting it next to six raw transcripts would mix two kinds
   of text in one fixture file.

**The probe set** is `DictusCore/Sources/polish-harness/fixtures/paragraph-fr.json`,
seven texts:

| id | Source | Chars |
|---|---|---|
| `P1-free-form` | #437 `probe-second-pass.json`, verbatim | 403 |
| `P2-project-update` | idem | 698 |
| `P3-message-draft` | idem | 356 |
| `P4-explanation` | idem | 838 |
| `P5-rambling` | idem | 1 240 |
| `P6-unscripted` | idem | 1 161 |
| `P7-89s` | fixture 7, Dictus side, from the #550 issue body | 1 150 |

P1–P6 are run 1 of #437's shipping-prompt baseline capture, committed there and
reused unchanged. Nothing is rebuilt.

**Texts A and B are not in the probe set.** They have a Typeless output per take and
**no Dictus transcription**. They serve as placement and count references only. No
Dictus side is invented for them.

## 4. N, the break count — fitted, not asserted

The falsification comment reports *"roughly one break per 250 to 380 characters,
growing slowly with length, never zero"* over five samples and says explicitly that
five samples is not a formula. Fitting it properly is this round's job.

**The reference set.** Every paired sample where the reference produced *prose
paragraphing*, with the character count of the text a paragrapher would be handed:

| Reference | Chars | Paragraphs | Breaks |
|---|---|---|---|
| Text A (both takes) | 246 | 2 | 1 |
| Text B (both takes) | 314 | 2 | 1 |
| Fixture 3, message draft | 356 | 3 | 2 |
| Fixture 1, free-form | 403 | 2 | 1 |
| Fixture 7, 89 s | 1 150 | 4 | 3 |

**Fixtures 2, 4, 5 and 6 are excluded, and the exclusion is the point.** On those
four the Typeless output carries numbered lists, bullets and invented headings
(#437, comment of 2026-08-27 14:39). Its line count there is *list structure*, not
paragraphing, and counting it as a break would fit N against a transformation this
contract forbids. Four of six is also why the reference cannot be a bar.

For A and B the character count is taken from the **Typeless** text, because no
Dictus side exists. Typeless rewrites, so those two counts carry an unknown error of
a few percent. Stated here rather than smoothed over.

**The fit.** Ordinary least squares on those five points:

```
breaks = 0.548 + chars / 470        R² = 0.78
```

Rounded, that predicts 1, 1, 1, 1, 3 against actuals 1, 1, 2, 1, 3 — **four of five
exact, one miss of one break**, on fixture 3.

**The rule this round supplies to the count-constrained arms** is the simpler form
with the same behaviour, because a shipping paragrapher needs a pure function of the
text and not a regression:

```
N = max(1, round(chars / 400))
```

It scores identically: 1, 1, 1, 1, 3. Both forms miss fixture 3 by one.

**This is a fit on five points and it is not settled.** Its uncertainty is ±1 break
over this range; it is untested above 1 150 characters and below 246; and two of the
five character counts come from a rewritten text. It is used here because the arms
need *some* N to obey, and because the untested variable is whether the model can
obey a count at all — not because 400 is a constant. A round that finds an arm
holding every bar makes the value of N a separate, cheaper question.

For the probe set, N is therefore:

| id | Chars | N |
|---|---|---|
| `P1-free-form` | 403 | 1 |
| `P2-project-update` | 698 | 2 |
| `P3-message-draft` | 356 | 1 |
| `P4-explanation` | 838 | 2 |
| `P5-rambling` | 1 240 | 3 |
| `P6-unscripted` | 1 161 | 3 |
| `P7-89s` | 1 150 | 3 |

## 5. The arms

Six, from least to most constrained, as the brief names them. Each is one JSON file
in `arms/`, holding a system prompt and a user turn, so it is committed before it is
run and re-runnable afterwards. `{{INPUT}}`, `{{SENTENCES}}` and `{{N}}` are the
placeholders the harness substitutes.

| # | id | Output | What it adds |
|---|---|---|---|
| 1 | `1-bare` | text | `Ajoute des paragraphes à ce texte.` and nothing else. The floor. |
| 2 | `2-boundary` | text | + breaks only between sentences, never inside one; change no word |
| 3 | `3-count` | text | + exactly `{{N}}` breaks |
| 4 | `4-both` | text | boundary **and** count. The candidate design on the text route. |
| 5 | `5-presegmented` | text | input is one numbered sentence per line; output is the text in paragraphs |
| 6 | `6-index` | integers | input numbered; output is the sentence numbers that start a paragraph |
| 6b | `6-index-count` | integers | arm 6 plus the count |

**Arm 6 is the one to reach for first if any arm holds**, and the reason is
structural rather than empirical: a model that returns only integers cannot delete a
word, cannot reorder, cannot invent and cannot emit a list. The text is reassembled
in code from `PolishSegmentation.sentences`, so the fidelity half of the contract
becomes impossible to violate rather than measured. It also emits a handful of tokens
instead of re-emitting 1 200 characters, which is where #437's second pass spent
1.4–5.2 s.

Arm 6b exists because the count is the untested variable and separating it from the
output shape costs one more capture.

### What the arms are NOT run through

**No `PolishPipeline`, no guardrail, no acceptance contract.** Declared, because it
changes what the numbers mean:

- Arm 6 returns integers. Every acceptance band necessarily rejects that, so routing
  it through the pipeline would measure the guardrail, not the model.
- The question is a capability question. A guardrail rejection and a model failure
  are different findings and must not be summed.
- The input texts carry no `<<NL>>` markers (they are single blocks), so the
  encode/decode round-trip is a no-op here and removing it removes no confound.

The consequence is stated plainly: **a design that holds these bars still has to be
re-measured inside the pipeline before it could ship.** This round does not clear
that step and does not claim to.

## 6. The bars

Declared in the brief, restated with the predicate that scores each. All are scored
by the harness itself, on the same sentence cut the arm was given, so a disagreement
between the prompt and the scorer is impossible by construction.

| # | Bar | Threshold |
|---|---|---|
| 1 | **Fidelity** — whitespace-stripped output identical to whitespace-stripped input | every run, every arm. Structurally satisfied by arms 6 and 6b |
| 2 | **Boundary discipline** — breaks inside a sentence | **0**, all arms, all runs |
| 3 | **Count obedience** — breaks returned equals N, on arms 3, 4 and 6b | per run; the **distribution** is reported, not only the mean |
| 4 | **List syntax** — `1.`, `-`, `•` the speaker did not dictate | **0** outputs. Held at 0 in 432 outputs under #437 and must stay there |

**Reported, never barred:**

- **Placement agreement** with the Typeless reference, where one exists in prose form
  (P1, P3, P7). A number, not a verdict — §2.
- **Latency**, per fixture per arm, against #437's curve (2.2 s at 395 chars, 7.6 s
  at 1 283). A second call is a second latency, and whether it is worth paying is the
  maintainer's decision, not this round's.

### Predicates, exactly

**Bar 1.** Remove every whitespace character from input and from output; compare as
strings. This is #437's second-pass predicate, unchanged, so the 30/30 it holds today
is directly comparable.

**Bar 2.** Only scorable when bar 1 holds for that run — if the words moved, "inside
a sentence" has no referent. A run that fails bar 1 is recorded `n/a` on bar 2 rather
than pass or fail. Where it is scorable: cut the input with
`PolishSegmentation.sentences`; compute the whitespace-stripped offset of each
sentence end; compute the whitespace-stripped offset of each break in the output;
every break offset must be in the set of sentence-end offsets.

**Bar 3.** Breaks are counted after collapsing runs of newlines to one, which is what
`PolishPostpass.decodeNewlines` does today. A model emitting a blank line between
paragraphs scores the same as one emitting a single newline, because that is what
would reach the document.

**Bar 4.** A leading ordinal or bullet on any line of the output:
`^\s*(?:\d+\s*[.)]|[-*•‣▪])\s+`. None of the seven inputs dictates a list, so any hit
is a violation. On the index arms the check runs on the reassembled text.

**Parse failures** on the index arms — an output that is not a list of integers, or
that names a sentence that does not exist — are counted and reported as their own
number. They are not folded into any bar.

## 7. Plan

1. Commit this file, the arms, the probe fixture set and the harness command
   **before the first arm call.** Verified by the commit order in `git log`.
2. Run every arm, 5 runs × 7 fixtures. Report per fixture, never pooled.
3. Confirm any arm that holds all four bars at 10 runs per fixture, because three of
   the four are 0-tolerance and 5 samples is thin for one.
4. Write `findings.md` against these bars, whatever it says, with run counts.
5. Either a design holds and ships with its latency cost stated, or the round records
   why no arm holds and Normal polish keeps its single block. Both close the issue.
   Stopping at a recommendation does not.

## 8. `tokenTimings`, settled separately

The issue body calls this the first technical step and gates its own route on it:
*"confirm `tokenTimings` is actually populated at runtime for Parakeet"*.
`DictusApp/Audio/ParakeetEngine.swift:169` keeps `result.text` and discards the rest.

The pause hypothesis is dead, so nothing in this round depends on the answer. It is
settled anyway, because it is cheap and it tells any future attempt whether acoustic
signal is available at all. Measured headlessly on this Mac against FluidAudio at the
pinned `0.12.3`, through the same `AsrManager.transcribe([Float])` call the app makes.
The number is in `findings.md` §Timings.

## 9. Risks

- **The fit becomes the finding.** N rests on five points, two of them measured on a
  rewritten text. If an arm holds its bars, the value of 400 is still open; if no arm
  holds, N was never the binding constraint. Either way the fit is reported with its
  residuals and never as a constant.
- **Arm 6 trades fidelity for a parse.** It cannot damage a word, but it can return
  nonsense integers, and a parse failure is a product failure too. Counted separately
  so it cannot hide inside a fidelity number that is true by construction.
- **The sentence cut is a dependency.** `NLTokenizer(unit: .sentence)` decides what a
  boundary is for arms 5, 6 and 6b, and for bar 2 on every arm. A cut that disagrees
  with the reader shifts every number. The cut is printed in the captures so it is
  auditable rather than assumed.
- **Seven fixtures, one language, one Mac.** Mac ≈ iPhone, not identical. No number
  here is a device number, and the device pass is on the manual list.
- **Judging placement by eye.** The blind rubric the brief calls the judgement of
  record is a human reading. This round produces the outputs and the agreement
  numbers; it does not claim to have performed a blind rubric on its own outputs.
