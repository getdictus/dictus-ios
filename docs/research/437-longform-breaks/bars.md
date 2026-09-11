# Long-form paragraph breaks — bars and plan (#437)

**Issue:** [#437](https://github.com/getdictus/dictus-ios/issues/437)
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/longform-fr.json` — the six
paired dictations of 2026-08-27, `raw` verbatim from the device export.
**Date:** 2026-09-11

> **Everything in §1–§6 was written and committed BEFORE the first model call on a
> candidate prompt.** That is the discipline #439's round ran on, and the only reason
> the numbers in `findings.md` are worth reading: a bar that can still move is not a
> bar. §7 onward is written after.
>
> One model call precedes this file and is declared here rather than hidden: a single
> `show --runs 1` on the shipping prompts, run to confirm Apple Intelligence is
> available on this Mac before any clause was written. Its output is the first block of
> `raw/baseline-natural-fr-5runs.txt`'s subject matter and changes nothing below.

---

## 1. What is being changed, and what is not

Every shipping prompt carries, under **Forbidden**:

> Do NOT add `<<NL>>` markers where none existed. Do NOT split or alter existing markers.

The baseline measured on 2026-08-27 is **0 line breaks in 6 outputs of 6**, and the
2026-08-27 14:32 comment establishes why: this is not a missing capability, it is an
explicit prohibition honoured perfectly. The `<<NL>>` round-trip already works end to
end — pre-pass, `encodeForEngine`, prompt rule 5, `decodeFromEngine`.

**So the deliverable is one clause, in the prompts that serve long French dictation,
and the round that measures it.** No pipeline change, no post-pass change, no new
mechanism.

### The contract the clause has to fit inside

Decided on the issue, 2026-08-27 14:46:

> **Normal polish may add whitespace. It may never remove words or change their
> grammar.**

A paragraph break is **additive**: it inserts one `\n` and deletes nothing. A list is
**destructive**: `La première c'est la capture` cannot become `1. La capture` without
deleting `La première c'est`. That is the whole reason a break is in scope here and a
list is not, including for a speaker-announced enumeration — `il y a trois étapes`
renders as prose, never as `1. 2. 3.`. Not relitigated in this round.

### The side effect the clause has to protect against

Inherited from #439 (comment of 15:50), and the reason that issue handed this defect
over rather than fixing it:

| Input shape | `en calcul` survives |
|---|---|
| The unpunctuated run-on, as dictated | **6 / 20** |
| The same 311 characters, carrying their sentence boundaries | **5 / 5** |

Flat from 311 to 838 characters, so length explains nothing. **The words that get
dropped are the tail of the clause the model has to cut in two, dropped while it
decides where the cut goes.** Placing a break is exactly when words get deleted, so
the clause that authorises a break has to be written against its own side effect.

## 2. Which prompts the clause reaches, and which it must not

Eleven builders ship (`PolishPromptInventoryTests`). The clause is not a free
addition to all of them.

| Prompt | Clause? | Why |
|---|---|---|
| `PolishNaturalPromptFR` | **yes** | the per-language route these fixtures measure |
| `PolishAutoPrompt` | **yes** | the route a device on auto-detect takes — all six original captures came through it |
| `PolishNaturalPromptEN/ES/DE` | **yes, if FR holds** | propagated unmeasured, see below |
| `PolishRepairPromptFR/EN/ES/DE` | **no** | Repair carries no `<<NL>>` clause at all today; its contract (ADR 0002) is reconstruction, not presentation |
| `SmartModeTranslatePrompt` | **no** | a translation reproduces the source's structure; inventing a break there is drift, not formatting |
| `SmartModeNotesPrompt` | **no** | `Liste` already emits its own structure, and rule 10 tells it to consume input markers rather than reproduce them |

**EN/ES/DE are propagated only if the French round holds, and the propagation is
unmeasured.** Stated plainly because it is the same trade #439's PR #545 made on the
same four files: building three more fixture benches is a bigger job than this issue,
and leaving the three per-language prompts banned while the Auto prompt is not would
mean the same English speech formats or not depending on a settings toggle — which is
the drift `PolishPromptParityTests` exists to catch. A device pass on English is on
the manual list either way.

**The rule numbering does not move.** `PolishPromptParityTests` asserts that the
deletion ban cites rules 4, 6 and 7 and that rule 8 is the ASR-repair rule, reading
each file's own numbered lines. The licence therefore grows **inside rule 5**, which
already owns `<<NL>>`, rather than becoming a new rule 6.

## 3. The bars

Declared on the issue on 2026-08-27 before the first model call, restated here with
the predicate that scores each. Scored by `harness/score.py` over a
`polish-harness show --runs N` capture; the per-fixture ones are also in the fixture
`expect` block, so `eval` reports them.

| # | Bar | Threshold |
|---|---|---|
| 1 | Fixture 1 (`1-free-form`, one idea, no boundary) | **0** line breaks, every run |
| 2 | Fixtures 3, 4, 5, 6 | **≥ 1** line break, every run |
| 3 | List syntax (`1.`, `-`, `•`) the speaker did not dictate | **0** outputs |
| 4 | Fixture 5's trailing `ça m'échappe mais ça me reviendra` | survives **every** run |
| 5 | Content invented | **0** (holds 6/6 today, must not regress) |
| 6 | No word present in the input absent from the output | see §4 |
| 7 | Fixture 4's boundary lands after `on découpe en paragraphes` | reported per run |
| 8 | Engine latency | on the current curve: 2.2 s at 395 chars, 7.6 s at 1 283 |
| 9 | Guardrail rejections | not above the baseline measured in the same session |

**Fixture 2 carries no break threshold** and is reported without one. The 14:46 table
does not name it, and its shape — an update with a figures section — makes a break
defensible and its absence equally so.

**Bar 5 is not scored by `score.py`** and that is deliberate, for the reason #439
stated: there is no predicate for *"this sentence was not in the dictation"* that does
not either miss paraphrase or fire on it. It is carried by the `lengthRatioMax` of
1.15 in every fixture's `expect` block, which is what an invented clause breaks first,
and by reading the outputs. Nothing `score.py` prints is evidence for bar 5.

## 4. Bar 6, the one inherited from #439, and its declared allowances

The general form — *no word present in the input is absent from the
whitespace-stripped output* — needs a predicate, and the naive one scores every
contract-abiding run as a failure: ADR 0003 authorises removing stutters (rule 6),
gratuitous fillers (rule 7), spoken punctuation commands (rule 4), and changing a
word on an ASR repair (rule 8).

It is scored in two halves.

**6a — named spans, 0 tolerance, the decision rule.** `score.py`'s `KEEP` table:
#439's list carried over unchanged so the two rounds compare, plus the spans the
14:46 and 15:50 comments name. Any absence is a violation. `en calcul` and
`ça me reviendra` are in it.

**6b — the general form, comparative.** Every content word of the input absent from
the output, as a **set** so a stutter or a repeated filler can never register, minus a
closed allowance list written from the six `raw` fields and ADR 0003 before the first
candidate call. The remainder is printed per run and totalled.

The allowance list is in `score.py` and is complete: the rule 6/7 filler vocabulary,
the six ASR-repair sources #439 lists (R1–R6), the off-language clause in fixture 3
and the two mangled app names in fixture 6 — the two shapes rule 8 was measured
repairing reliably — and the rule-9 typo `l,'idée`.

**The candidate has to come in at or under the baseline on both halves.** The baseline
**fails** 6a today, on fixture 4, so matching it is not enough: this bar is the one
place where the round is asked to beat the measurement it starts from.

## 5. Plan

1. **Declare the bars.** This file and `harness/score.py`, committed before the first
   candidate call. *Verified:* the commit precedes every capture in `raw/`.
2. **Dump the two shipping prompts** as the baseline arm, byte-for-byte.
   *Verified:* the French dump is `cmp`-identical to `polish-harness prompt --out`;
   the Auto one comes from `harness/extract-prompt.py`, which refuses to print a
   literal carrying interpolation or escapes.
3. **Capture the baseline**, both routes, 5 runs × 6 fixtures. *Verified:* it
   reproduces the 0-breaks-in-6 invariant and the `en calcul` deletion. If it does not,
   the harness is not measuring what the device measured and the round stops.
4. **Re-run #439's committed probe** (`docs/research/439-natural-contract/harness/probe-isolated.json`)
   rather than rebuilding the 6/20 vs 5/5 comparison, as the issue asks.
5. **Write the candidate clause** in `prompts/`, as prompt files, so it is measured
   before it is compiled.
6. **Measure it**, both routes, same command, same run count. Iterate on the clause
   only, never on the bars.
7. **Confirm the winner at 10 runs** per fixture per route, because four of the nine
   bars are 0-tolerance and 5 samples is thin for one.
8. **Land it in the Swift builders** if it holds, with prompt-contract tests in
   `swift test`; or write the failure with its run counts and leave Normal polish its
   single block. Both close the issue.
9. **Regression-check the fixture sets this round does not target** — `seed.json`,
   `auto.json`, `nl-markers-fr.json` — before and after. `nl-markers-fr.json` is the
   one that matters: it holds the device captures of dictated markers, and a clause
   that lets the model add breaks is one wording away from letting it move the
   speaker's.
10. **Write `findings.md`** against these bars, whatever it says.

## 6. Risks

- **The clause becomes "reformat freely".** The failure mode the 14:46 comment names
  by hand: the risk is too many breaks, not too few, and fixture 1 is the control that
  sees it. Mitigated by scoping the licence to a position — *between two sentences* —
  rather than to a judgement, and by saying in the prompt that zero is the normal
  answer.
- **A break arrives as a list.** The model that has just been told it may structure
  reaches for `1.` next. Mitigated by an explicit refusal in FORBIDDEN with a worked
  counter-example, and measured by bar 3.
- **Teaching to the test.** The counter-example cannot use fixture 4's words, or bar 3
  measures the example rather than the rule. The examples added in this round use a
  different enumeration and a different topic change, and share no content with any of
  the six fixtures.
- **The deletion this round is supposed to fix, made worse.** Authorising a cut is
  authorising the exact operation that dropped `en calcul`. Mitigated by writing the
  licence as *copy every word on both sides of an inserted break*, and measured by
  bar 6.
- **Input headroom (#270).** Instructions and input share one 4 096-token window.
  `develop`'s French Natural prompt is 6 022 characters and buys a 3 969-character
  transcript ceiling; `PolishContextBudgetTests` fails under 3 500. Measured from the
  two points #439 recorded, a character of prompt costs ~0.36 characters of ceiling,
  so the clause has **~1 290 characters** of room. A candidate that needs more than
  that is refused on cost before it is measured on quality.
- **A single `\n`, not a blank line.** `PolishPostpass.decodeNewlines` collapses any
  run of newlines to one. A paragraph break therefore renders as a line break, not as
  a blank line, whatever the model emits. That is existing behaviour, it is not
  touched here, and whether Pierre wants blank lines is a product question for the
  device pass — not something this round changes quietly.
- **Mac ≈ iPhone, not identical**, and the maintainer's device pass on latency,
  context budget, thermal behaviour and keyboard-extension memory (step 8 of the
  issue's method) is not something an agent can run. It is on the manual list.
