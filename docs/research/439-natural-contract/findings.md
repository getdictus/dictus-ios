# Natural contract, three violations — measured (#439)

**Bars and plan:** `bars.md`, committed before the first model call on this fixture set.
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/longform-fr.json` — the six
device dictations from #437, `raw` verbatim.
**Where:** Mac, macOS 26.5.1, Apple Intelligence on, `polish-harness`, 2026-08-27.
**Raw captures:** `raw/`. **Scorer:** `harness/score.py`. **Probe inputs:** `harness/*.json`.

Everything below is 5 samples per fixture per arm, per path, on Apple FM on a Mac.
Nothing here was confirmed on a physical iPhone.

---

## The headline

**Bar 1 does not clear, and the prompt is not the lever it fails on.** After the edit,
Apple FM repairs **1 of the 6** listed ASR errors on the per-language path and **0-1 of 6**
on the auto path — the same as before. Five of the six are never repaired, on any run, on
either path, under any prompt tested.

That is not a calibration miss. It was probed directly: **each broken segment was handed
to the model alone, in one short sentence, with the surrounding context that makes the
intended reading obvious** (`harness/probe-isolated.json`). Result, 5 runs each:

| Probe | Segment, in one sentence with its context | Repaired |
|---|---|---|
| P1 | `une visio depuis la salle à tante mais ce sera moyen` | **0/5** |
| P2 | `le découpe en petits morceaux. Le modèle prend ses morceaux` | **0/5** |
| P3 | `je répète le comptable … c'est l'assurance qu'il faut que je rappelle` | **0/5** |
| P4 | `l'intégration StoreKit … caler la partie Apple Store` | **0/5** |
| P5 | `une semaine et demie qu'il attend … si je les zappais` | **0/5** |

And with a **minimal prompt whose stated primary job is finding misheard words**, with a
three-step method in front of everything else and no long-form task competing for
attention (`prompts/C-minimal-repair-probe.txt`, 1.5 KB against the shipping prompt's
7.1 KB): still 0/5 on all five (`raw/probe-isolated-ab.txt`). That candidate also
introduced a fresh Preserve violation of its own, substituting `a fini` with `a terminé`.

**The capability #439 assumes is not present in this model.** ADR 0003 rule 8 works on
the shape it was written from — a whole-clause language switch, which fires 5/5 — and does
not generalise to a homophone that reads as fluent French. The issue's own sentence
*"So the capability is present"* is the inference this measurement falsifies: what is
present is off-language-fragment detection, which is a different and much easier signal.

## Bar 3 has a mechanism, and it is not a missing prohibition

`en calcul` is still deleted 4/5 on both paths after an explicit, named ban on deleting
meaningful words. So it was probed too (`harness/probe-length-ladder.json`, 5 runs each):

| Input | Chars | `en calcul` survives |
|---|---|---|
| The closing passage alone, as dictated (run-on, no boundaries) | 311 | 2/5 |
| …with the preceding section | 599 | 1/5 |
| …with two preceding sections | 727 | 1/5 |
| The whole fixture | 838 | 2/5 |
| **The same 311 characters with the sentence boundaries supplied** | 316 | **5/5** |

Length explains nothing — 6/20 across a 2.7x range. **Punctuation explains everything.**
The words that get dropped are the tail of a clause the model has to cut in two, and it
drops them while deciding where the cut goes. Feed it the same words already segmented
and it deletes nothing, 5 times out of 5.

This is the same defect #437 named from the other side: *"a pass that has to place a
break, and places it by comma rather than by discourse, produces a sentence that never
existed."* The two issues split fidelity from structure, and on this one defect the split
does not hold: **the deletion is a symptom of segmentation**, and no clause in a fidelity
prompt reaches it.

## Every bar, scored

5 runs per fixture, 30 outputs per arm per path. Occurrences, not rates.

| | FR before | FR after | Auto before | Auto after |
|---|---|---|---|---|
| **Bar 1** repairs per run (of 6) | 1,0,1,0,1 | 1,1,1,1,1 | 1,1,1,0,1 | 0,1,1,0,0 |
| runs clearing ≥4/6 | 0/5 | **0/5** | 0/5 | **0/5** |
| **Bar 2** `cela` for `ça` | 4 | **4** | 2 | **4** |
| `machin` → `machine` | 4 | **2** | 3 | **0** |
| hour format expanded (`11h` → `11 h`) | 2 | 1 | 0 | 2 |
| digits spelled back out | 0 | 0 | 2 | 0 |
| added `ne` | 0 | 0 | 0 | 0 |
| **Bar 3** `en calcul` deleted | 4 | **4** | 5 | **4** |
| other content deleted | 0 | **1** | 0 | 0 |
| **Bar 4** content invented | 0 | **0** | 0 | **0** |
| **Bar 5** outside `[0.92, 1.15]` | 0 | 0 | 0 | 0 |
| guardrail rejections | 0/30 | **0/30** | 0/30 | **0/30** |
| **Bar 6** line breaks · `<<NL>>` leaks | 0 · 0 | **0 · 0** | 0 · 0 | **0 · 0** |

Read straight:

- **Bar 1 — fails.** Unchanged. R4 (`honnêtement`) is the only repair that ever fires and
  it fired before the edit too. Its rate did move on the per-language path, 3/5 to 5/5.
- **Bar 2 — fails, and one item went backwards.** `machin` → `machine`, the one item
  taught by name in the Preserve list, dropped from 7 occurrences in 10 runs to 2 — the
  taught fix works. `cela` went from 6 to 8: the register clause, stated twice and
  demonstrated with a counter-example, did not take. The hour-format expansions
  (`11h` → `11 h`) are new on the auto path and are the same failure in a different
  costume.
- **Bar 3 — fails**, for the reason above. And one **new** deletion appeared that the
  baseline did not have: fixture 5's trailing `ça m'échappe mais ça me reviendra` was
  dropped once in 5 on the per-language path. That is #385's exact signature, at 1/30
  where the baseline had 0/30 — one occurrence, not a trend, and worth watching.
- **Bar 4 — holds.** No invention, 60/60 outputs.
- **Bar 5 — holds.** No guardrail rejection anywhere, all ratios inside the tripwire.
- **Bar 6 — holds.** Zero line breaks in 60 outputs, both arms, both paths. The scope
  fence with #437 is intact and #437's baseline is unchanged by this branch.

## Regressions on the fixture sets this round did not target

- `seed.json` (per-language polish): 3/3 passes clean before; **5/6 passes clean after**,
  the one miss being `2-bilingue` losing `push` in a single run. 1 fixture-failure in 84
  checks against 0 in 42 — sampling noise at this resolution, not a signal.
- `auto.json` (the anti-translation set, the one at risk from a new repair rule):
  **10/10, 9/10, 9/10 before, then 10/10 three times after.** The rule 8 this round
  added to `PolishAutoPrompt` **in the measured arm** did not cost the anti-translation
  contract, which was the main identified risk in `bars.md`. That arm did not ship: the
  widened rule 8 repaired none of the six segments, so it was cut from both prompts and
  `PolishAutoPrompt` carries no rule 8 at all — `testAutoPromptDoesNotCarryASRRepair`
  pins that. The number above says the risk was cleared, not that the rule is in the
  shipped prompt.

## What the prompt edit cost

The prompts grew: FR Natural 5 483 to 7 096 characters, `PolishAutoPrompt` similarly.
Instructions and input share one 4 096-token window (#270), so that is paid in maximum
dictation length: the French Natural ceiling moves from ~4 160 characters of input to
**~3 580**. `PolishContextBudgetTests` caught the first draft at 3 008, under the 3 500
floor #270 measured; the prompt was rewritten compact rather than the floor moved.

**~580 characters of maximum dictation length, for one Preserve item.** That is the trade
as measured, and it is the maintainer's call whether it is worth keeping.

## What this means for #439

The issue's three defects do not share the lever it proposes.

1. **A (rule 8 never fires) is not a prompt problem.** Apple FM cannot detect a homophone
   that reads as fluent French, in isolation or in context, under any instruction tested.
   Closing this needs a different mechanism — a lexicon or frequency check that flags
   improbable n-grams before the model sees them, a second pass, or a larger model — and
   that is an issue of its own, not a calibration round. The prompt rule is still worth
   keeping: it costs little, it protects the capability that *does* work, and it is what a
   future engine would need to find already written.
2. **C (deletion) is a segmentation problem** and belongs with #437, not here. A fidelity
   clause cannot reach it; supplying the boundary does, completely.
3. **B (register) is the only one of the three that is genuinely a prompt matter**, and
   even there the results split: the lexical item taught by name improved, the
   grammatical form stated as a rule did not.

The honest recommendation is that **#439 as written cannot be closed by this PR**, and
that its bar 1 should be re-cut against what the engine can actually do — with the six
probes above as the evidence, since they are cheap to re-run against any future engine.

---

# Addendum — the short version, measured (2026-08-27)

The maintainer read the above and cut the edit: **keep the two PRESERVE lines and the
explicit deletion ban, drop the rule-8 widening**, on both prompts. His reasoning, which
the numbers support: the measured return on the full edit is one Preserve item, the
product's central complaint is that *long* dictations come back as a wall of text, and
trading long-dictation headroom for a marginal fidelity win — on the free tier, while
#437 is about to make long dictations better — is backwards.

The auto arm supports dropping rule 8 rather than trimming it: it went 1,1,1,0,1 →
0,1,1,0,0 with the widening in, and fixture 3's off-language repair fired on the auto
path *before* any rule 8 existed there. The wording is not what buys that repair.

## The ceiling comes back

Measured with the same binary search `PolishContextBudgetTests` uses, on the resolved
French Natural prompt:

| | Prompt | Transcript ceiling |
|---|---|---|
| `develop` | 5 483 chars | **4 160** |
| Full edit (previous commits) | 7 096 chars | 3 580 |
| **Short edit (this branch)** | **6 009 chars** | **3 969** |

**The cost falls from 580 characters of maximum dictation length to 191** — about 31
words. `PolishContextBudgetTests` passes on both bounds, and the 3 500 floor #270 measured
was never moved. The Swift helper and an independent replica of the estimator agree on
3 969 to the character; the replica also reproduces `develop`'s 4 160 exactly, which is
the number #270 recorded.

## Same bars, same fixtures, same run count

Occurrences over 5 runs × 6 fixtures per arm per path. `before` is `develop`, `full` is
the rule-8 version, `short` is what ships.

| | FR before → full → short | Auto before → full → short |
|---|---|---|
| **Bar 1** runs clearing ≥4/6 | 0/5 → 0/5 → **0/5** | 0/5 → 0/5 → **0/5** |
| **Bar 2** `machin` → `machine` | 4 → 2 → **1** | 3 → 0 → **2** |
| `cela` for `ça` | 4 → 4 → **4** | 2 → 4 → **4** |
| hour format expanded | 2 → 1 → **0** | 0 → 2 → **0** |
| digits spelled back out | 0 → 0 → **0** | 2 → 0 → **0** |
| **Bar 3** `en calcul` deleted | 4 → 4 → **5** | 5 → 4 → **4** |
| trailing sentence deleted | 0 → 1 → **1** | 0 → 0 → **1** |
| **Bar 4** content invented | 0 → 0 → **0** | 0 → 0 → **0** |
| **Bar 5** guardrail rejections | 0/30 → 0/30 → **0/30** | 0/30 → 0/30 → **0/30** |
| **Bar 6** line breaks · `<<NL>>` | 0 · 0 → 0 · 0 → **0 · 0** | 0 · 0 → 0 · 0 → **0 · 0** |

- **The `machin` win survives the cut.** 7 occurrences in 10 runs on `develop`, 2 with the
  full edit, **3 with the short one**. The PRESERVE line is what was buying it, as
  expected — it is the only item in this PR that moves a number.
- **Bar 4 holds, 60/60.** No salutation, sign-off, bracket placeholder or invented fact
  in any output, on either path.
- **Bar 5 holds.** 60/60 `success`, zero guardrail rejections, every ratio inside the
  [0.92, 1.15] tripwire.
- **Bar 6 holds.** Zero line breaks and zero `<<NL>>` leaks in 60 outputs. The scope fence
  with #437 is intact.
- **Bars 1, 2 (`cela`) and 3 fail, unchanged**, for the reasons already measured above:
  the engine cannot do the repair, and the deletion is a segmentation defect. The `cela`
  PRESERVE line does not work in either version — 4/5 on both paths, against 4/5 and 2/5
  on `develop`. It is kept because it is one line and it is the correct statement of the
  contract, not because it was shown to help.
- **One thing to watch, not a proven regression.** Fixture 5's trailing
  `ça m'échappe mais ça me reviendra` — #385's exact signature — was dropped **twice in
  60 outputs**, against 0 in 10 baseline runs. Two occurrences is not a signal at this
  resolution, but it has now appeared in three separate arms and never on `develop`.

## Regression on the untargeted sets

- `seed.json`: **5 of 6 passes at 14/14** after the full edit, against `develop`'s 3/3.
  The miss is `2-bilingue` losing `push` in one pass — 1 fixture-failure in 84 checks
  against 0 in 42, which is sampling noise at this resolution. The capture is
  `raw/after-regression-eval-6seed-3auto.txt`, whose name used to say `3passes` while
  holding six seed passes and three auto ones.
- `auto.json`: **10/10, 9/10, 9/10** — identical to `develop`'s 10/10, 9/10, 9/10. The two
  misses are the `auto-verbal-*` fixtures dropping a `!`, the same sampling noise the
  baseline had.

---

# Part 2 — the bare `point` clause, measured (2026-09-11)

Bars in `bars.md` §5–§8, committed before the first model call. Amendments in §9.
Captures: `raw/point-pass{1,2}-{A,B}-*.txt`. Scorer: `harness/score-point.py`.
Arms: `prompts/D-natural-fr-point-kept.txt` against
`prompts/E-natural-fr-point-removed.txt`, which differ by **one line and fifteen
characters** — `diff` the two files, that is the whole experiment.

## The verdict: the clause stays, and it buys nothing

| | arm A, clause kept | arm B, clause removed |
|---|---|---|
| **P1/P2** noun class, `point` lost | **0 / 96 scored outputs** | 0 / 99 |
| **P4** command word removed | **66 / 100** | **66 / 100** |
| **P3** boundary mark supplied | 70 / 80 | 73 / 80 |
| **P5** non-success | 24 / 220 | 21 / 220 |

The decision rule declared in §7 was: *keep the clause only if the noun class is clean*.
It is clean, across seven noun fixtures and two passes, including `N7-noun-at-a-boundary`
— `point` as a noun sitting exactly where a sentence boundary belongs — which was added
after pass 1 precisely because pass 1 was clean. **The clause stays in FR and EN Natural.**

## What #185's open revisit turns out to say

The prepass doc-comment ends with *"Revisit once the LLM owns punctuation contextually"*,
and rests on a claim that was *observed on device, never counted*: that the model supplies
the terminal period at natural sentence boundaries on its own. Counted now, on the
boundary itself rather than anywhere in the output:

- **The claim holds.** 70/80 with the clause, 73/80 without it. The model closes the
  sentence at the command position whether or not rule 4 tells it to.
- **The fear does not materialise.** #185 ruled the substitution too dangerous for a regex
  because `point` is an ordinary French noun with no multi-word context to disambiguate.
  The model has that context and uses it: 96 outputs, 7 noun shapes, `un point final`
  included, and not one `point` converted to a mark or dropped. The distinction #185 drew
  between what a regex may do and what a model may do is confirmed, from the other side.

**So the clause is safe. It is also useless.** The command word is removed 66 times in 100
under both arms — the same number, arrived at from opposite directions in the two passes.
The between-pass swing within one arm (30→36 for A, 37→29 for B) is larger than any
difference between the arms, which is zero. Rule 4's bare-`point` entry does not change
what the model does with a bare `point`, in either direction.

It is kept because the decision rule said to keep it and because it is the correct
statement of the contract, not because it was shown to help. That is the same footing the
`cela` PRESERVE line was left on in the first half of this issue.

## A user-visible defect this round found and did not fix

**Thirty-four command-class outputs in a hundred leave a stray `Point,` in the text**, in
both arms:

```
raw     : je passe au bureau demain matin vers 9h point on se voit directement en salle de réunion
polished: Je passe au bureau demain matin vers 9 h. Point, on se voit directement en salle de réunion.
```

The model reliably puts the mark in and then keeps the word as well, which is the worst of
the two available failures: the user reads a sentence that is correctly punctuated and
carries one word nobody said. It is present on `develop` today, it is not caused by
anything in this round, and **neither arm reduces it** — 66/100 either way.

This is not #439's defect and it is not fixed here. It is the shape #185 left behind when
it took the bare period word out of the pre-pass: the regex no longer removes the word, and
the prompt turns out not to remove it either. Worth its own issue.

## An aside worth recording: Apple refuses a benign French sentence

`N2-point-de-vue` — *"de mon point de vue le plus gros risque c'est qu'on livre en retard
et que le client s'en aperçoive avant nous"* — is refused by Apple's safety guardrail
**39 times in 40** across the two arms and two passes, `reason=guardrailViolation`. `N6-point-de-vue-bis`,
the same shape in different words, is refused 6 times in 20. Nothing in either sentence is
sensitive. It is recorded here because it is the second time this campaign has had to
route around Apple refusing ordinary dictation, and because a 39/40 refusal rate on a
sentence a user could plausibly dictate is a product fact, not a harness artefact.
