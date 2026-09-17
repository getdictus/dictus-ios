# `Structuré` fidelity — bars and plan (#570, #581)

**Issues:** [#570](https://github.com/getdictus/dictus-ios/issues/570) (damage inside
accepted outputs) and [#581](https://github.com/getdictus/dictus-ios/issues/581) (a
fabricated closing sentence lifted from the prompt's own example).
**Brief:** the #570 comment of 2026-09-17 16:40, *"The bench this issue needs,
specified"*. The issue bodies are context; **the brief wins where they disagree**.
**Date:** 2026-09-17

> **Everything in §1–§9 was written and committed BEFORE the first model call of this
> round.** That is the discipline #439, #437 and #550 ran on, and the only reason the
> numbers afterwards are worth reading.
>
> Two model calls precede this file and are declared here rather than hidden. Both are
> a one-fixture availability probe (`show --mode structured --runs 1` on a synthetic
> 67-character French sentence), run to confirm Apple Intelligence is enabled on this
> Mac before anything was written. The second reproduced, on the first call, the exact
> defect #581 reports from the device: the output carried the shipping prompt's entire
> first worked example, closing on `Il y avait un autre truc, mais ça m'échappe.` That
> observation is what §4's axis 4 is shaped to count; it is **not** a measurement, and
> it is not counted anywhere below.

---

## 1. What this round is, and what it is not

It is **not** a fix. No prompt change and no guardrail change lands out of this
campaign. #466 is the precedent the brief names: widening a check blind refused 10 of
10 legitimate repairs at every threshold swept. So a number comes first, and what
ships is Pierre's call on reading it.

The question:

> On `Structuré` outputs, how often — and on which axis — does the model damage the
> speaker's meaning **inside** the licence #523 granted it, where every guardrail we
> ship is blind by construction?

### What is locked and not reopened

- **#523's twelve decisions.** The licence to rewrite stays. This bench measures
  fidelity *inside* it. Decision 11 (`Structuré` in the default pins) is untouched.
- **#414's result.** Deleting the prompt's examples makes copying *worse* — 9 of 30
  against 1 of 29. Any prompt variant here is **benched, not landed**.
- **Axis 3 scores nothing.** Decision 3 licenses *"reorder within a topic"*; the
  prompt's rule 2 says *"an idea never moves elsewhere in the text"*. They disagree,
  and which governs is Pierre's call, not a measurement. Axis 3 reports a count and
  calls nothing a defect. The bench must not pre-empt that decision.

## 2. The fixture hole this round closes first

`fixtures/longform-fr.json` holds six fixtures of **353 to 1 283 characters**. Every
device defect of 2026-09-17 but one is on input **shorter than the shortest fixture**:
65, 192, 246, 578. Short input is where the model has least to restructure and most
room to fill, and it was unrepresented in every number #523 published.

`fixtures/device-structured-fr.json` closes it: the **nine** `Structuré` dictations of
the two debug exports of 2026-09-17, `raw` verbatim, three refused and six accepted on
device.

**Why the file is not called `shortform-fr.json`**, which is what the brief calls it.
Four of the nine are under 250 characters and are the hole. The other five are not
short, and dropping them would throw away three things the round needs: the
1 337-character refusal that is #581's **positive control**, the two runs of the *same
dictation* 35 minutes apart that are the evidence for §5, and the 433-character
refusal. The set is "the nine device runs", so the file is named for what it is.

| id | Device timestamp | Chars | Device outcome |
|---|---|---|---|
| `D1-three-steps` | 2026-09-16 19:52 | 838 | success |
| `D2-three-steps-drift` | 2026-09-16 20:27 | 795 | success |
| `D3-plan-mode` | 2026-09-17 07:03 | 192 | success |
| `D4-logs-polish` | 2026-09-17 12:10 | 578 | success |
| `D5-lets-go` | 2026-09-17 12:14 | 15 | rejectedGuardrail |
| `D6-issues-check` | 2026-09-17 14:45 | 433 | rejectedGuardrail |
| `D7-mod-rejects` | 2026-09-17 14:47 | 246 | success |
| `D8-last-transcription` | 2026-09-17 14:47 | 65 | success |
| `D9-suggestion-bar` | 2026-09-17 15:29 | 1337 | rejectedGuardrail |

`longform-fr.json` runs too, unchanged, so the short set is read against the set every
#523 number was taken on rather than on its own.

## 3. What is scored, and on which text

**The engine's output, not the inserted text.** A Smart Mode that fails its contract
inserts nothing, so scoring what reached the document would score three of the nine
device runs as having no defects at all — and one of those three is #581's positive
control, whose only defect is *in the refused output*. The guardrail verdict is
reported **beside** each run, never folded into it. A refusal and a fidelity defect are
different findings and this round does not sum them, for the reason #550's round gives
about parse failures.

Concretely: every axis reads `engineOutput` from `PolishPipeline`, which since #523
round 8 is recorded after the post-pass — good enough here, because no axis below reads
whitespace.

## 4. The four axes

All four are **deterministic and model-free**: `NLTokenizer` cuts, `PolishLexicon`
folds, `PolishGrounding`'s content-word list filters, and the rest is set arithmetic
and a committed lexicon. That is deliberate and it is the same reason `guardrail` drives
no model: a number that decides a prompt must be re-runnable by anyone, including on a
machine with Apple Intelligence off.

### The alignment every axis but 4 is built on

A **proposition** is a clause, not a sentence: `Je te laisserai regarder, il s'agit de
la dernière transcription.` is one sentence carrying two, and the device defect on it
is *between* them. So:

1. Cut the text into sentences (`PolishSegmentation.sentences`).
2. Cut each sentence further at `,` `;` `:` — and only where **both** sides carry at
   least `minimumContentWords` content words, which is 3, the same number
   `PolishSegmentOverlapThresholds.default` uses for the same reason: below it a unit
   can only score 0, 0.5 or 1 and a single unmatched word decides everything.

For each input proposition, against the output's propositions:

- `bestRecall` — the highest share of the input proposition's **content words** found
  in any single output proposition, and the index of that proposition.
- `wholeRecall` — the share found anywhere in the whole output.

### Axis 1 — proposition recall (SCORED)

An input proposition is **unrecalled** when `wholeRecall < floor`. That is the axis
that sees a deleted sentence, and the brief is right that no current check approximates
it: deleting raises no length ratio, invents no name, and lowers no per-segment overlap
on the segments that remain. It is **#414's check run backwards** — #414 asks whether
each *output* segment is supported by the input (precision, anti-fabrication); this
asks whether each *input* proposition is supported by the output (recall,
anti-deletion).

An input proposition is **dispersed** when `wholeRecall ≥ floor` but `bestRecall <
floor`: its words survive, no single output clause carries it. Reported, not scored.

**The floor is calibrated, not asserted.** §6.

**What this axis cannot do, stated before it produces a number.** Decision 4 licenses
dropping *dead weight*, and rule 1 licenses reformulating — so a low recall is
"the model dropped an idea" *or* "the model said it in other words" *or* "the model
correctly cut a filler", and content-word overlap cannot tell the three apart. The
bench therefore prints **every** unrecalled proposition with its text, and findings.md
classifies them by hand. The number is a screen, not a verdict. Claiming otherwise
would repeat the mistake #570 was opened to correct.

### Axis 2 — person and stance (SCORED)

Per aligned pair (input proposition, its best-matching output proposition), and only
where `bestRecall ≥ floor` — an unaligned proposition is axis 1's finding, not this
one's:

- **person lost** — the input proposition carries a first-person marker and the output
  proposition carries none. This is the device defect `j'en ai fait une dizaine` →
  `il y a une dizaine qui ont été créées`, and #523's decision 5 measured 28/28 on the
  Mac corpus while the phone broke it. A document-level count cannot see it: the rest
  of that output is full of `je`.
- **hedge lost** — the input carries a hedge and the output carries none.
- **stance hardened** — the output carries a booster the input does not. `il coupe
  quand même pas mal de mots` → `il enlève effectivement beaucoup de mots`: concessive
  to confirmatory, which is the pair that motivates having two lexicons rather than one.

Lexicons are committed in `PolishStanceLexicon.swift` in French and English, the two
languages the corpus is in. A language the lexicon does not cover simply scores zero on
this axis, which is visible rather than wrong.

**Negation balance is reported here as an observable, and it is an addition to the
brief.** #570's body opens on `c'est pas naturel` → `ce qui est naturel`, a dropped
negation that reverses a sentence, and the brief's four axes do not name polarity. It is
cheap to count and it is the defect the issue is titled after, so it is measured — as a
**count, not a bar**, alongside axis 2. Flagged here so nobody reads it as a fifth bar
that was smuggled in.

### Axis 3 — order (OBSERVABLE, NEVER A DEFECT)

Over the propositions with an alignment index, the number of **inversions**: pairs
`(i < j)` of input propositions whose aligned output indices run backwards. The
65-character device run scores 1 and that is the whole of what this axis says about it.

Nothing here is called a defect. §1.

### Axis 4 — speaker-state fabrication (SCORED, #581)

A **speaker-state sentence** is one in which the speaker reports their own recall
failing: `je ne me souviens pas`, `ça m'échappe`, `j'ai oublié un truc`, `il y avait
autre chose`, `ça me reviendra`, `I don't remember`, `there was something else`. The
patterns are committed in `PolishSpeakerState.swift` against folded text, so an
apostrophe or an accent cannot decide the answer.

Four outcomes, and three of them matter:

| Verdict | Output's **last** sentence | Input, anywhere | Meaning |
|---|---|---|---|
| **fabricated** | matches | no match | #581. The bar is **zero**. |
| **preserved** | matches | matches | Rule 7 doing its job. #523's decision 7. |
| **dropped** | no match anywhere | matches | Rule 7 violated. #523's decision 7 bar, from the other side. |
| absent | no match | no match | Nothing to say. |

`preserved` and `fabricated` are the same regex on the output and are told apart
entirely by the input. That is the point: rule 7 exists to keep such a sentence, so a
check that flagged every one of them would refuse the rule doing its job.

**Two controls, both committed, both model-free:**

- **Positive:** `D9-suggestion-bar`'s device output ends on `Il y a un autre truc, mais
  je ne me souviens pas.` and its raw contains no speaker-state sentence → must score
  `fabricated`.
- **Negative:** `longform-fr.json`'s fixture 5 ends on `ça m'échappe mais ça me
  reviendra`, and #523 measured its preservation 5/5 → its committed outputs must score
  `preserved`, never `fabricated`.

Both are unit tests in `swift test`, so the scorer is pinned before it is trusted.

## 5. Three runs per fixture, never one

`D1-three-steps` and `D2-three-steps-drift` are the same content dictated 35 minutes
apart. Run 1 deleted the proposition that carries the passage's point; run 2 kept it and
substituted a technical term instead. **Two runs, two different defects.** A single run
per fixture cannot see this class, and every per-fixture table below is therefore
`runs = 3`, printed per run and never averaged into a single cell.

## 6. The floor, calibrated on hand-labelled device outputs

The recall floor decides axes 1 and 2, so it is not picked by taste.

`docs/research/570-structured-fidelity/device-corpus.json` holds the nine device runs
with their **actual device outputs** and the defect labels taken from #570's two
comments of 2026-09-17 — Pierre's own reading, transcribed, not the bench's. The round
sweeps the floor over `0.10 … 0.60` in steps of `0.05` on that corpus, model-free, and
reports:

- how many labelled deletions the floor catches (`D1` has one, `D7` has two);
- how many propositions it calls unrecalled on outputs labelled faithful.

The floor that ships in the bench is chosen off that table and the table is printed in
findings.md, with the false positives named. If no floor separates the two, **that is
the finding** and it is reported as one rather than worked around — the same rule #414
followed when its own floor did not separate cleanly.

## 7. The arms

| Arm | What it is | Why |
|---|---|---|
| **shipping** | `SmartModeStructuredPrompt.instructions()`, unchanged | the baseline every number is read against |
| **V1-rule7-property** | #581's two changes: rule 7 stated by its property rather than by four liftable sentences, and the first worked example no longer ends on the rule-7 clause | #581's "what to change", 1 and 2 |
| **V2-fidelity** | V1 plus one FORBIDDEN line naming deletion of a proposition and change of the speaker's person as forbidden | #570's axes 1 and 2 have no line in the prompt today that names them as failures |

Arms are full system prompts, committed as files under `arms/`, run through
`--instructions`, exactly as #523's rounds 5–10 ran theirs. **None of them lands.**
#414 is the reason: the last campaign that reasoned its way to a prompt edit made
copying worse by a factor of nine.

## 8. What is run, and what is committed

```sh
cd DictusCore
swift run polish-harness fidelity Sources/polish-harness/fixtures/device-structured-fr.json \
  --mode structured --runs 3 \
  --arm ../docs/research/570-structured-fidelity/arms/V1-rule7-property.txt \
  --arm ../docs/research/570-structured-fidelity/arms/V2-fidelity.txt \
  --json ../docs/research/570-structured-fidelity/capture-device.json
```

Committed: the console capture under `raw/`, the JSON sidecar, the corpus, the arms, and
`findings.md` in the shape of `docs/research/523-structured/findings.md` — every bar with
its number, every rejection reported rather than worked around, and one recommended
variant with the measurement that justifies it.

## 9. Risks, declared in advance

1. **The Mac is not the phone.** macOS 26.5.1's Apple FM against iOS 27.0's. #523's
   round 9 measured the phone as the better writer on the same input, so a defect rate
   here **overstates** the device and a capability ceiling here understates it. Every
   number below is a Mac number.
2. **Content-word overlap is not meaning.** §4, axis 1. The screen/verdict distinction
   is the mitigation and it is only as good as the hand classification that follows it.
3. **The lexicons are French and English.** A Spanish or German `Structuré` dictation
   scores 0 on axis 2 and that is not the same as passing it.
4. **Nine fixtures × 3 runs × 3 arms is 81 outputs per fixture set.** That is a rate
   with wide error bars, not a precision instrument. A difference of one or two between
   arms is sampling noise and is reported as such.
5. **The corpus is one speaker, in one language, on one domain** — Pierre, French, his
   own work. #523's corpus has the same shape. Nothing here generalises past it and
   findings.md says so.
