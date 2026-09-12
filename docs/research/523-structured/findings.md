# `Structuré` — the round that ships with the mode (#523)

**Where:** Mac, macOS 26, Apple Intelligence on, `polish-harness`, 2026-09-12.
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/longform-fr.json` — the six
French dictations of 2026-08-27, `raw` verbatim from the device export.
**Captures:** `raw/`. **Prompt arms:** `prompts/`. **Labelled outputs:** `corpus.json`.
**Side by side with `List` and Typeless:** `comparison.md`.

Everything below is Apple FM on a Mac. Nothing here was confirmed on a physical iPhone;
decision 12 makes that the maintainer's, and it is the definition of done.

---

## The verdict in one line

**The mode holds every bar #523 set, and under-delivers the want it was asked for.**
Nothing is invented, nothing the speaker flagged is dropped, the person is the
speaker's in 28 outputs of 28 — and the paragraphs the mode exists to produce appear in
**8 accepted outputs of 28**. The licence to rewrite was granted, and the model largely
declines to use it.

## The bars, each with its number

| Bar | Result |
|---|---|
| 30 outputs committed | `raw/round6-structured-shipping-5runs.txt`, 28 accepted, 2 refused |
| Zero invented facts, figures, dates or names **reaching the document** | **0 of 28.** No number, and no capitalised token absent from the input, in any accepted output |
| Zero speaker-flagged incompleteness dropped; fixture 5's trailing sentence in 5/5 | **5 of 5.** `ça m'échappe, mais ça me reviendra` present in every run |
| First person preserved; no infinitive task list | **28 of 28.** `il faut que je …` four times per fixture-5 output; no bullet or numbered shape in any accepted output |
| No guardrail rejection of a legitimate output | **1 of 29 refused.** Reported below, not worked around |

## The one legitimate output the guardrail refuses, and why

Re-runnable, model-free, from the `DictusCore` directory:

```sh
swift run polish-harness guardrail ../docs/research/523-structured/corpus.json --anchors
```

```
── #413 per-segment language check          caught 0/0   false rejections 0/30
── #414 grounding check                     caught 0/1   false rejections 1/29
   FALSE REJECTION: 6-unscripted#4 — TypeLess
── #414 worst-segment overlap               caught 1/1   false rejections 0/29
── #414 anchors OR overlap (the pipeline)   caught 1/1   false rejections 1/29
```

The refused output writes **`TypeLess`** where the transcript says `type less` in one
place and `Type Laiss` in another. `PolishGrounding.isGrounded` matches a name as a
contiguous run of input words, so one token cannot be grounded by two, and the anchor is
called invented. The output is legitimate: the model normalised a product name the STT
rendered three ways inside one dictation.

**It is not a property of this mode.** Any contract with `requiresGroundedNames` —
Normal polish, Auto, `List` — refuses the same rewrite, and it is the same
multi-rendering problem #80 measured when Parakeet spelled `Claude Code` five ways
across six dictations. Nothing was widened to make the number go away, per decision 9.
The user-visible cost is one dictation in twenty-nine inserting nothing, on input
carrying a product name the transcript cannot spell consistently.

**The other refusal is the guardrail working.** `1-free-form#3` ran away: it returned
the dictation, then two paragraphs of generic advice (*"Il faut donc être très vigilant
et bien planifier…"*), then the same two paragraphs again. The length ceiling of 1.5
refused it before anything reached the document. That is the only fabrication in 30
outputs, and the band caught it — worth recording, since PR #388 measured a band
rejecting nothing in 240 calls.

## The gap: paragraphs

Breaks per run, shipping prompt:

| Fixture | run 1 | run 2 | run 3 | run 4 | run 5 |
|---|---|---|---|---|---|
| 1 `free-form` (control: 0 is right) | 0 | 0 | refused | 0 | 0 |
| 2 `project-update` | 0 | 0 | **2** | 0 | 0 |
| 3 `message-draft` | 0 | **5** | **1** | 0 | 0 |
| 4 `explanation` | 0 | 0 | **3** | **3** | **2** |
| 5 `rambling` | 0 | **6** | **3** | 0 | 0 |
| 6 `unscripted` | 0 | 0 | 0 | refused | 0 |

**8 of 28.** Fixture 6 — a real 90-second dictation, the closest thing in the set to the
use case — never breaks. Fixture 3 breaks once per *sentence* when it breaks at all,
which is the failure #437 named in advance.

This reproduces #437 exactly, under the one condition #437 said it lacked. That issue
measured 144 outputs across five system-prompt arms and got **zero** breaks, and
concluded the obstacle was the contract forbidding rewriting. #523 grants the licence to
rewrite, and the first round of this mode returned **0 breaks in 27 accepted outputs**
(`raw/round1-structured-show-5runs.txt`). The licence is not what was missing.

What moves the needle is what #437's finding 2 already said: the **user turn**, and only
weakly. Four user turns, same six fixtures:

| Arm | User turn | Outputs | With a break |
|---|---|---|---|
| A | `Rewrite this text as clear paragraphs.` | 27 | **0** |
| B | `… : start a new line each time the speaker moves to a different subject, and only there.` | 18 | 4 |
| **C — ships** | `… and break it into paragraphs, one per subject, separated by a blank line.` | 18 | **7** |
| D | C plus `— never one per sentence.` | 18 | 8, but it splits the control fixture one line per sentence |

C ships because it places breaks best and never split fixture 1, the one that must stay
one block. D's extra bound made the model noisier rather than better bounded. A fifth
arm, on the **system** prompt — an explicit `DO NOT COPY THE INPUT` clause above the
rules (`prompts/B-structured-anticopy.txt`, `raw/round7-armB-anticopy-3runs.txt`) —
moved neither copying nor breaks outside sampling noise, and does not ship.

## The second gap, which nobody asked about: it barely rewrites

Similarity between the accepted output and the raw transcript is **1.00 on five of six
fixtures** in the arm-B round. The mode returns the speaker's sentences with the
punctuation repaired, which is Normal polish. It does not repair `salle à tante` (0 of
5, where Typeless does), it does not resolve fixture 5's self-correction, and on fixture
1 four runs of five are the transcript verbatim.

Where it does use the licence it uses it well — fixture 5's ramble comes back in whole
sentences, in the first person, with the open loop kept — but that is the exception, not
the rule.

Read `comparison.md` with this in mind: the `Structuré` column there is the run with the
most breaks of five, so it shows the mode at its best per fixture, not its median.

## What this leaves for the maintainer to decide

Three answers are open, and none of them is an agent's to pick:

1. **Ship it as the better polish it currently is**, and let the paragraph half arrive
   from #550's deterministic route, which places breaks from `tokenTimings` rather than
   from the model's judgement. That issue is open and already owns this problem.
2. **Keep iterating on the prompt.** #437 spent 372 outputs on this dial and moved it
   from 0 to 5 of 18; this round moved it to 8 of 28 with the same lever. The measured
   ceiling of the prompt route is low.
3. **Cut it**, per #393's precedent, if a mode that reads like a cleaner polish is not
   worth a fourth row in a 46 pt fan.

Decision 12 makes the verdict his after living with it, which is why the mode ships
installable and pinned rather than held back for another round here.
