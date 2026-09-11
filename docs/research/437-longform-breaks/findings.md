# Long-form paragraph breaks — measured (#437)

**Bars and plan:** `bars.md`, committed before the first candidate model call.
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/longform-fr.json` — the six
paired dictations of 2026-08-27, `raw` verbatim from the device export.
**Where:** Mac, macOS 26, Apple Intelligence on, `polish-harness`, 2026-09-11.
**Raw captures:** `raw/`. **Arms:** `prompts/`, `framings/`. **Scorer:** `harness/score.py`.

Everything below is Apple FM on a Mac. Nothing here was confirmed on a physical iPhone.

---

## The verdict

**The clause does not ship. Normal polish keeps its single block.**

Seven arms, 252 outputs on the six fixtures, across both prompt routes. The bar that
decides — *fixtures 3, 4, 5 and 6 each return at least one line break, on every run* —
is not approached by any arm. The best of them puts a break in **5 outputs of 18**, and
never once on fixtures 3 and 6.

That is the outcome the issue declares legitimate, and it closes it. What follows is
the number behind every bar, and the three findings that are worth more than the
verdict.

## Finding 1 — the system prompt is not the lever, at all

**132 outputs under five different system-prompt arms, and not one line break.**

| Arm | What it changes in the system prompt | Outputs | With a break |
|---|---|---|---|
| A | nothing — the shipping prompts, both routes | 60 | **0** |
| B | rule 5 gains the licence as prose (`You MAY insert…`) | 60 | **0** |
| C | B plus three worked examples, including a list counter-example | 30 | **0** |
| D | C with `MAY` turned into `MUST` | 18 | **0** |
| E | D asking for a real line break instead of the `<<NL>>` marker | 18 | **0** |
| F | C plus the licence restated in the GOAL line, at the top | 18 | **0** |

Every one of those is the edit the issue describes — *"one clause in one prompt"* —
written five different ways, including the two that should have settled it. A prompt
that says the model **MUST** break at a change of subject produces the same wall of
text as a prompt that forbids it. So does one that asks for an ordinary newline rather
than the pipeline's marker, which rules out the marker as the obstacle.

**The plumbing is not the obstacle either, and that was checked directly.** A 190-byte
system prompt whose only job is splitting —

```
You are a TEXT TRANSFORMATION FUNCTION. Output the input text with each sentence on
its own line, separated by a real line break. Add nothing, remove nothing, change no
word. Output only the text.
```

— returns a line break on the first fixture it is given, through the same
`PolishPipeline`, the same post-pass and the same guardrail. The capability is present.
It simply loses to a 6 KB prompt whose every other clause is about changing nothing.

## Finding 2 — the user turn is a lever, and a weak one

The one position none of the arms above touches is the **user turn** — the eleven words
`PolishTask.userInstruction` puts in front of the transcript. Moving the paragraphing
instruction there is the only change in this round that produces a break at all.

| Arm | Where the instruction lives | Outputs | With a break | Breaks total |
|---|---|---|---|---|
| G | user turn, permissive rule 5 | 18 | **5** | 21 |
| H | user turn (`and only there — never after every sentence`), bounded rule 5 | 30 | **5** | 7 |
| I | user turn (`break it into paragraphs.`), bounded rule 5 | 30 | 2 | 2 |
| J | G's user turn, bounded rule 5 | 30 | 3 | 9 |
| J-auto | J on the Auto route | 30 | 4 | 14 |
| K | G's user turn, GOAL line **and** bounded rule 5 | 30 | 2 | 11 |

Read straight: the rate tops out around **one output in four** and moves as much with
sampling as with wording. Stating the instruction at both ends (K) is not better than
stating it at one. Damping it (H, I) makes it rarer without making it better placed.

**And when it does fire, it often fires wrong.** Two of the fifteen firing outputs put
one line per sentence — ten breaks on fixture 4, which has three sections. That is the
failure the issue named in advance: *the risk is not too few breaks, it is too many*.

Per fixture, breaks per run, best arm on each route:

| Fixture | Bar | J (per-language) | J-auto (Auto) |
|---|---|---|---|
| 1 `1-free-form` | **0** | 0, 0, 0, 0, 0 — **holds** | 0, 0, 0, 0, 0 — **holds** |
| 2 `2-project-update` | none | 0, 0, 1, 0, 0 | 0, 0, 0, 0, 1 |
| 3 `3-message-draft` | ≥ 1 | 0, 0, 0, 0, 0 — **fails 5/5** | 0, 0, 0, 0, 0 — **fails 5/5** |
| 4 `4-explanation` | ≥ 1 | 0, 0, 0, 3, 0 — **fails 4/5** | 10, 3, 0, 0, 0 — **fails 3/5** |
| 5 `5-rambling` | ≥ 1 | 0, 5, 0, 0, 0 — **fails 4/5** | 0, 0, 1, 0, 0 — **fails 4/5** |
| 6 `6-unscripted` | ≥ 1 | 0, 0, 0, 0, 0 — **fails 5/5** | 0, 0, 0, 0, 0 — **fails 5/5** |

## Finding 3 — isolate the task and fidelity becomes free; judgement does not

The probe that follows from finding 1: hand the **already-polished** text back to the
engine in a second call whose only job is to add breaks (`prompts/L-second-pass.txt`,
`harness/probe-second-pass.json`, 30 outputs, 5 runs per fixture).

| Fixture | Chars | Breaks per run | Median ms | Whitespace-stripped text changed |
|---|---|---|---|---|
| 1 `1-free-form` | 403 | 3, 0, 3, 3, 0 | 1 600 | **0 / 5** |
| 2 `2-project-update` | 698 | 0, 0, 0, 0, 0 | 2 330 | **0 / 5** |
| 3 `3-message-draft` | 356 | 5, 0, 0, 0, 5 | 1 409 | **0 / 5** |
| 4 `4-explanation` | 838 | 10, 10, 10, 10, 10 | 2 974 | **0 / 5** |
| 5 `5-rambling` | 1 240 | 0, 0, 25, 0, 0 | 4 431 | **0 / 5** |
| 6 `6-unscripted` | 1 161 | 5, 5, 0, 5, 5 | 3 492 | **0 / 5** |

Two things, and they point opposite ways.

**The additive contract holds perfectly.** *Normal polish may add whitespace, it may
never remove words or change their grammar* — 30 outputs of 30, the whitespace-stripped
output is byte-identical to the whitespace-stripped input. Not one word added,
removed, reordered or respelled, and **no list syntax in any of them**. Take the task
away from the faithfulness prompt and the fidelity half of the contract costs nothing.

**The judgement is the part that is missing.** Fixture 4 comes back with one line per
sentence, 5 times out of 5. Fixture 1, the control that must return zero, is split in
3 runs of 5 — which is exactly what Typeless does to the same fixture, and exactly what
the 14:46 comment predicted would be the hard part. Fixture 2 never splits.

**So the defect is not fidelity and not plumbing. It is discourse-boundary detection,
and Apple FM does not have it.** That is the same shape as #439's result on homophone
repair, arrived at from a different direction: the model will do the operation, and
cannot tell where it belongs.

The second pass also costs 1.4 s to 5.2 s on top of the first, which is bar 8's whole
budget again, and it **cannot recover the word the first pass already dropped** — by
the time it runs, the boundary decision that deleted `en calcul` has happened.

## Every bar, scored

Occurrences over all arms unless a cell says otherwise.

| # | Bar | Result |
|---|---|---|
| 1 | Fixture 1 returns **0** breaks | **holds** — 0 in every output of every arm, 252 of 252 |
| 2 | Fixtures 3, 4, 5, 6 return **≥ 1** break, every run | **fails** — best arm 5 outputs in 18; fixtures 3 and 6 never break under any arm |
| 3 | **0** outputs carry list syntax | **holds** — 0 in 432 outputs, the probes included |
| 4 | Fixture 5's `ça m'échappe mais ça me reviendra` survives every run | **fails, and it fails on the baseline too** — dropped 1/30 on baseline Auto, 0/30 on baseline per-language, and 0 in every candidate arm. One occurrence, on `develop`, unchanged by this round |
| 5 | **0** invented content | **holds** — every length ratio inside the [0.92, 1.15] tripwire, 432 of 432, and no salutation, sign-off or invented fact read in the captures |
| 6a | Named spans survive (`en calcul`, the figures, the names) | **fails, as it does on the baseline** — `en calcul` deleted 5/5 on both baseline routes. See below |
| 6b | Unattributed word losses, per 30 outputs | baseline 28 (per-language) / 25 (Auto); best candidate arm **10–12**. Lower, but no arm reaches 0 |
| 7 | Fixture 4's boundary lands after `on découpe en paragraphes` | never reached — too few breaks on that fixture to read |
| 8 | Latency on the current curve | **holds** — 2.8 s at 395 chars and 7.1 s at 1 283 on the baseline, 3.3 s and 7.0 s on the heaviest candidate. The prompt edit is not visible in the latency |
| 9 | Guardrail rejections not above the baseline | **holds** — baseline 3/30 and 3/30, candidates 0/30 to 4/30, every rejection on fixture 6 except one. Same rate, same fixture |

### Bar 6, and the one number that supports #439's mechanism

`en calcul` is deleted from fixture 4 on **5 runs of 5, on both baseline routes** — the
defect #439 handed to this issue. Across every arm in this round, split by whether the
output carried a break at all:

| Fixture 4 output | `en calcul` survives |
|---|---|
| carries at least one line break | **4 / 7** |
| carries none | **6 / 55** |

Seven outputs is a thin denominator and it is reported as one. But it points the same
way as #439's 6/20 against 5/5, from the other side: **the word survives when the
boundary has been placed, and disappears while the boundary is being decided.** The
mechanism in the 15:50 comment is not contradicted by anything measured here. What this
round adds is that Apple FM cannot be made to place that boundary reliably, so the
mechanism has no lever on it.

## What it would have cost, since the arithmetic was done before the measurement

Instructions and input share one 4 096-token window (#270), so a clause is paid for in
maximum dictation length — on the free tier, on exactly the long dictations this round
exists to improve.

| | Prompt | Transcript ceiling |
|---|---|---|
| `develop`, French Natural | 5 926 chars | **3 998** |
| B, the licence as prose | 6 422 | 3 822 |
| C, prose plus worked examples | 6 943 | 3 635 |
| K, both ends plus examples | 7 115 | 3 568 |

Computed with a replica of `PolishContextBudget`'s estimator, which reproduces the two
points #439 recorded (5 483 → 4 160, 7 096 → 3 581) to the character. Every arm clears
the 3 500 floor `PolishContextBudgetTests` enforces, so cost is not why this fails —
but it is why the round measured the prose arm before the example arm, and it is what a
future attempt is spending.

## What this means for #437

**The issue closes on the second of its two declared outcomes.** The clause was
written, five ways, measured over 252 outputs on both prompt routes, and it does not
hold the bars. Normal polish keeps its single block, and nothing in
`DictusCore/Sources/DictusCore/Polish/` changes except a test that pins the ban so the
next round has to be deliberate rather than accidental.

**What a future attempt should not repeat.** The system prompt is exhausted: `MAY`,
`MUST`, worked examples, a counter-example, the GOAL line, and a real newline instead
of the marker all produce zero. Re-wording rule 5 is not an experiment any more, it is
a re-run.

**What is left, with its cost stated.**

1. **A second pass** — proven to hold the fidelity contract 30/30 and to cost 1.4–5.2 s
   and the ceiling of a second call. Its boundary judgement is worse than useless today
   (fixture 4 split every sentence, 5/5; fixture 1 split when it must not, 3/5), so it
   needs the judgement solved first, not the architecture.
2. **A deterministic paragrapher in code** — `PolishSegmentation.sentences` already cuts
   the text; what is missing is the topic-change signal, and no cheap local primitive in
   this repo produces one. That is a research question, not a prompt round.
3. **A different engine.** The two capability probes this campaign now owns —
   `439-natural-contract/harness/probe-isolated.json` for homophone repair and
   `437-longform-breaks/harness/probe-second-pass.json` for boundary judgement — are
   both cheap to re-run against any future backend, and both are currently answered no.
4. **#523**, the armed long-vocal mode, is unaffected. It is allowed to transform, so it
   is not bound by the additive contract that makes this problem hard, and the six
   fixtures and the Typeless half of the pair are committed for it.

**One thing this round did not find, and it is worth saying.** The fear that motivated
the whole careful framing — that lifting the ban would produce lists, headings and a
restructured document, the way Typeless does on four of these six — **did not
materialise once.** Zero list markers in 432 outputs, under prompts that told the model
it could structure and under a second pass whose only job was structure. The contract
decided on 2026-08-27 was never under pressure. The capability was.
