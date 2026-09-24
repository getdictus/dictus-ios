# `Structuré` fidelity — what the licence to rewrite costs (#570, #581)

**Where:** Mac, Apple Intelligence on, `polish-harness`. **Two OS generations, and every
number says which:** rounds 1-4 and the calibration ran on **macOS 26.5.1** on
2026-09-17; rounds 1 and 3 were re-run unchanged on **macOS 27.0 (26A428)** on
2026-09-18, after Pierre upgraded the Mac specifically to test §6's first caveat. §9 is
that re-run. Sections 1-8 are macOS 26.5.1 throughout unless they say otherwise.
**Brief:** #570's comment of 2026-09-17 16:40, *"The bench this issue needs, specified"*.
**Bars:** `bars.md`, committed before the first arm ran, with its two calibration
amendments recorded in §6.1.
**Fixtures:** `DictusCore/Sources/polish-harness/fixtures/device-structured-fr.json`
(the nine device `Structuré` runs of 2026-09-17) and `…/longform-fr.json` (the six of
2026-08-27, every #523 number's corpus).
**Captures:** `raw/`, four rounds. **JSON:** `capture-*.json`. **Aggregation:**
`summarise.py`. **Hand labels:** `device-corpus.json`.

> Everything below is Apple FM **on a Mac**. Nothing here was confirmed on a physical
> iPhone, and §6 is about why that matters more in this round than in any before it.

---

## The verdict in four lines

1. **The bench works.** Replayed against the nine device outputs, it flags a defect on
   a scored axis in **8 of 9**, including every deletion, every person loss and the
   fabrication Pierre found by hand — and it stays silent on rule 7 doing its job.
2. **Neither Mac reproduces the device's rewriting damage.** On macOS 26.5.1 (714
   scored outputs) the shipping prompt fabricates 2 times in 239 and loses the speaker's
   person on no fixture the phone broke. macOS 27.0 is a different model — it reproduces
   the device's **counter-example leak** on `D5` 3 of 3 — and it still does not delete
   `D1`'s proposition, move `D4` out of the first person, or refuse `D6`. Mac 27 is not
   iPhone 27 either. §9.
3. **No prompt variant is recommended, on either OS, for any round.** #581's proposed fix
   (V1) does not lower the fabrication rate on macOS 26 (p = 0.21, direction against) and
   on macOS 27 it produces the defect #581 is about **and gets it accepted**: `D1`,
   838 → 854, closing on `Et puis, il y avait un dernier machin, mais ça m'échappe.`,
   passed by every guardrail. §5, §7, §9.
4. **On macOS 27, nine accepted outputs carry content the speaker never said**,
   hand-labelled — one on the shipping prompt, and one (V2) carrying the prompt's own
   plumber-and-firewood example inserted into a real project update as the speaker's
   tasks. **The scorer caught 4 of the 9.** Every earlier count of accepted fabrications
   in this document was the scorer's and undercounted. §9.1.

---

## 1. What was measured, and on what

| Round | Fixtures | Arms | Runs each | Outputs | Capture |
|---|---|---|---|---|---|
| calibration | 9 device **outputs**, hand-labelled | — (model-free) | — | 9 | `raw/replay-device-corpus.txt` |
| 1 | 9 device dictations | shipping, V1, V2 | 3 | 81 | `raw/round1-device-3arms-3runs.txt` |
| 2 | 4 short device + 1 synthetic | shipping, V1, V2 | 15 | 225 | `raw/round2-shortprobe-3arms-15runs.txt` |
| 3 | 6 longform (#523's corpus) | shipping, V1, V2 | 3 | 54 | `raw/round3-longform-3arms-3runs.txt` |
| 4 | the 2 shortest, leak-prone | shipping, V1, V2 | 60 | 360 | `raw/round4-leakprobe-3arms-60runs.txt` |

**720 outputs, 714 scored** (six Apple FM engine failures are in no denominator).
Rounds 1 and 3 are the brief's three-runs-per-fixture round on the two fixture sets;
rounds 2 and 4 exist because the event #581 is about turned out to be a ~1 % event.

Three runs per fixture is the brief's floor and rounds 2 and 4 go far past it, for the
reason §5 gives: the event #581 is about happens about once in a hundred outputs, and
three runs cannot see a 1 % event at all.

## 2. The calibration: does the bench see what Pierre saw?

Model-free, re-runnable with Apple Intelligence off:

```sh
cd DictusCore
swift run polish-harness fidelity ../docs/research/570-structured-fidelity/device-corpus.json --replay --sweep
```

### The floor

| floor | labelled deletions caught | other flags | outputs flagged |
|---|---|---|---|
| 0.10 – 0.20 | 2/2 | 5 | D1×1, D3×1, D5×1, D6×1, D7×1, D9×2 |
| 0.25 | 2/2 | 6 | + D6×1 |
| 0.30 | 2/2 | 7 | + D6×1 |
| **0.35 — ships** | **2/2** | **9** | + D1×1, D2×1 |
| 0.40 – 0.50 | 2/2 | 9 | unchanged |
| 0.55 | 2/2 | 15 | + D4×1, D6×1, D7×2, D9×4 |
| 0.60 | 2/2 | 19 | + D1×1, D2×1, D4×2, D9×1 |

`caught` is 2/2 everywhere, so **the deletion label does not discriminate** and the floor
cannot be chosen off that column. What chooses it is *which text* gets flagged:

- Below 0.35, the only flag on `D1-three-steps` is `Le truc important à comprendre,` at
  recall 0.00 — the four-word run-up. The proposition that actually carries the
  passage's point, `c'est que ces trois étapes ne coûtent pas du tout le même prix en
  calcul`, scores **0.33** and is invisible. `caught 2/2` is satisfied by the wrong text.
- At 0.35 it is flagged by name. **That is the whole argument for the number.**
- What it costs is named rather than hidden: 0.35 also flags
  `He prends his morceaux and essays of devine quels have been prononced,` on
  `D2-three-steps-drift` — a Parakeet English-drift segment the model **repaired**. A
  legitimate rewrite, flagged as a possible deletion, because content-word overlap
  cannot tell a repair from a loss. `bars.md` §4 declared that limit before the number
  existed and this is it in the flesh.
- 0.55 and above start flagging `D4-logs-polish`, whose output is faithful at clause
  level, so the top of the grid is measuring the instrument rather than the model.

### The bench against the hand labels

| Fixture | Pierre's labels (#570's two comments) | The bench |
|---|---|---|
| `D1-three-steps` | propositionDeleted | unrecalled×2, personLost×1, hedgeLost×1 |
| `D2-three-steps-drift` | termSubstituted | unrecalled×1, personLost×1, hedgeLost×1 |
| `D3-plan-mode` | registerDropped | unrecalled×1 — and it is `s'il te plaît.`, at recall 0.00 |
| `D4-logs-polish` | intentionInvented, factFabricated, personLost, stanceHardened, misspelled | personLost×1, hedgeLost×2, negDropped×1 |
| `D5-lets-go` | exampleLeaked, refusedByGuardrail | unrecalled×1 |
| `D6-issues-check` | refusedByGuardrail | unrecalled×4, personLost×1, negDropped×1 |
| `D7-mod-rejects` | reordered, propositionDeleted | unrecalled×1, personLost×1, **inversions=1** |
| `D8-last-transcription` | reordered | **inversions=1**, nothing else |
| `D9-suggestion-bar` | speakerStateFabricated, refusedByGuardrail | unrecalled×2, personLost×3, hedgeLost×1, **speakerState=fabricated** |

**Totals: 7/9 unrecalled, 6/9 person lost, 4/9 hedge lost, 1/9 fabricated, 0/9 dropped,
1/9 clean.** Observables: 8 inversions, 5 dispersed, 3/9 negation dropped, 0/9 rule-7
preserved.

Four things in that table are worth naming.

**It finds the two defects the brief names by example, by name.** `j'en ai fait une
dizaine` → `il y a une dizaine qui ont été créées` is `personLost` on `D4`; `je suis
assez surpris` → `je suis surpris` is `hedgeLost` on the same output. Both are pinned
by a test.

**It finds a defect no axis was built for.** `D3-plan-mode`'s only hand label is a
dropped `s'il te plaît`, which is register rather than proposition — and axis 1 flags it
anyway, because politeness that is dropped whole is a proposition that is dropped whole.

**It finds three person losses on `D9` that the hand read did not.** `Pour moi, il y a
tout un design à revoir` → `Il y a tout un design à revoir`, twice, and `Je crois qu'on
a une issue` → `Il paraît qu'il y a une issue`. The speaker's ownership of his own
opinion, removed. That is decision 5's territory and it was in neither comment.

**It misses `D2`'s term substitution.** `le même prix en calcul` → `le même temps de
calcul` changes one content word in a clause that keeps the rest, so recall stays high
and no axis reads it. **Term substitution is not one of the brief's four axes and the
bench does not measure it.** It is the same class as the `dictus` → `dictée` defect
#570's body opens on, and it remains unmeasured.

**It misses `D4`'s hardened stance, and the reason is alignment, not the booster rule.**
Pierre labelled `effectivement, il coupe quand même pas mal de mots` → `il enlève
effectivement beaucoup de mots` as hardened. The `effectivement` is the speaker's own
and its clause pairs correctly with the output clause carrying it. What was lost is the
hedge — `quand même`, `pas mal` — and the clause that carried it keeps one content word of
three (`coupe` → `enlève`, `pas mal` → `beaucoup`), so it aligns with nothing and axis 2
is never asked. That is term substitution again. Pinned by
`testAxis2CannotSeeD4sHardeningAndSaysWhy`.

**`D8` is the only `clean` output and that is the contradiction, not a pass.** Its one
finding is an inversion, and axis 3 calls nothing a defect because #523's decision 3 and
the prompt's rule 2 disagree. Under rule 2 that output is damaged; under decision 3 it
may be licensed. **The bench refuses to answer and that refusal is deliberate.**

## 3. The live rounds: the Mac barely damages anything

Recomputed from the JSON with engine failures excluded
(`python3 summarise.py capture-*.json`):

### Round 1 — the nine device dictations, 3 runs each

| arm | outputs | unrecalled | personLost | hedgeLost | hardened | **fabricated** | dropped | clean |
|---|---|---|---|---|---|---|---|---|
| shipping | 27 | 6/27 | 1/27 | 3/27 | 0/27 | **0/27** | 0/27 | 19/27 |
| V1-rule7-property | 27 | 4/27 | 0/27 | 2/27 | 0/27 | **0/27** | 0/27 | 21/27 |
| V2-fidelity | 27 | 3/27 | 1/27 | 2/27 | 0/27 | **0/27** | 0/27 | 21/27 |

Every one of the 81 was accepted by the pipeline except one (V2, refused on `length`).
On device, **three of these same nine were refused and six of six accepted were damaged.**

Held against the phone on the same input, fixture by fixture:

| Fixture | Phone, one run | Mac, shipping, 3 runs |
|---|---|---|
| `D1-three-steps` | a proposition deleted | 17/17 recall, 3/3 |
| `D4-logs-polish` | five defects, incl. person and stance | no defect, 3/3 |
| `D7-mod-rejects` | reordered + 2 deletions | no defect, 3/3 |
| `D8-last-transcription` | two clauses swapped | 0 inversions, 3/3 |
| `D9-suggestion-bar` | refused; fabricated closing sentence | accepted 3/3, no fabrication |

**This is the most important comparison in the document.** The Mac's Apple FM, given
the same prompt and the same transcripts, returns the speaker's sentences with the
punctuation fixed. The phone rewrites, and the damage arrives with the rewriting. #523's
round 9 recorded the same gap from the other side — *"the phone is the better writer"* —
and this is its cost: the phone is the better writer **and** the more dangerous one, and
the harness cannot see the dangerous half.

### Round 3 — the six longform fixtures, 3 runs each

| arm | outputs | unrecalled | personLost | hedgeLost | fabricated | clean | rule 7 preserved |
|---|---|---|---|---|---|---|---|
| shipping | 18 | 1/18 | 3/18 | 0/18 | 0/18 | 14/18 | **3/18** |
| V1-rule7-property | 18 | 1/18 | 2/18 | 0/18 | 0/18 | 15/18 | **3/18** |
| V2-fidelity | 18 | 2/18 | 1/18 | 0/18 | 0/18 | 15/18 | **3/18** |

*Rescored (§10): `hedgeLost` for V1 and V2 was 1/18 each and is 0/18. Both were false
positives. `Alors je vais quand même faire un sixième test parce que les autres c'est
pas vraiment ma voix` was read as one clause, and both outputs keep `quand même` in their
previous sentence.*

The `3/18` column is the same fixture on every arm: `5-rambling`, whose raw ends on *"il
y avait un dernier truc ça m'échappe mais ça me reviendra"*. **3 of 3 on all three arms.**
This is #523's decision 7 holding, and it is the check that matters most for #581's
variant: rewording rule 7 by its property, and taking its clause off the worked example,
does **not** stop rule 7 from firing when the speaker actually says one. That was the
risk of the change, and it did not materialise here.

## 4. Axis 3, reported and nothing else

| Round | shipping | V1 | V2 |
|---|---|---|---|
| device fixtures (81) | 32 | 23 | 30 |
| longform (54) | 9 | 8 | 5 |
| short probe (225) | 0 | 0 | 0 |

An inversion is counted, printed with both clauses, and called nothing. **The bench
takes no position on whether reordering is damage**, because #523's decision 3 licenses
*"reorder within a topic"*, the prompt's rule 2 forbids an idea moving, and which
governs is Pierre's to settle. `D8-last-transcription` is the 65-character dictation
that lands exactly on the disagreement: its two clauses come back swapped, at a length
ratio of 1.01, and every guardrail we ship is blind to it by construction.

Worth noting for whoever settles it: on the Mac, short input produces **zero**
inversions in 225 outputs, and the reordering all happens on input over 500 characters.

## 5. Axis 4: the leak, and why it needs 300 runs rather than 3

Across rounds 1-3 (360 outputs, 3 arms), prompt content reached an output **twice**:

| | Arm | Fixture | What leaked | Ends on rule 7's clause? |
|---|---|---|---|---|
| 1 | **shipping** | `D5-lets-go` (15 chars) | example 1, whole | **yes** — `Il y avait un autre truc, mais ça m'échappe.` |
| 2 | V2-fidelity | `D5-lets-go` (15 chars) | example 1, whole | **no** — ends on `Voici c'est tout.` |

Both were refused by the length check, so neither would have reached a user. Both are
trap 1 of `SmartModeStructuredPrompt`'s doc comment, firing on the shortest input in the
corpus, exactly as that comment predicts.

**The difference between the two rows is precisely what #581 asked to change, and it is
a mechanism rather than a rate.** The shipping arm's leak carried a sentence about the
speaker's own memory, which fits onto the end of any dictation and which a reader has no
way to identify as not theirs. The variant's leak carried a plumber and a garage:
obviously not the speaker's, which is the off-domain defence working. The variant did
not stop the copying — #414 already measured that nothing does — it **changed what gets
copied**, which is the only thing #581 claimed was available.

Two events in 360 cannot separate two rates. Round 4 exists to try, and it answers
something other than the question it was asked.

### Round 4 — the two shortest fixtures, 60 runs per arm, 360 outputs

`D5-lets-go` (15 characters) and `S1-synthetic-short` (68 characters, the availability
probe of `bars.md`'s preamble, marked synthetic because it is). Both are leak magnets:
short input is where the model has least to restructure and most room to fill.

| arm | outputs | **speaker-state fabricated** | any prompt content copied | refused (all on `length`) |
|---|---|---|---|---|
| shipping | 119 | **1** | 1 | 6 |
| V1-rule7-property | 118 | **4** | 5 | 16 |
| V2-fidelity | 119 | **1** | 4 | 17 |

Two-sided Fisher exact against shipping:

| Comparison | p |
|---|---|
| fabrication, V1 | 0.21 |
| fabrication, V2 | 1.0 |
| any content copied, V1 | 0.12 |
| any content copied, V2 | 0.37 |
| **refused, V1** | **0.042** |
| **refused, V2** | **0.027** |

**On the question it was built to answer, this is a null result and it is stated as
one. 360 outputs do not separate the fabrication rates.** The direction is against the
variant rather than for it, and the count is too small to call that anything.

**What round 4 does establish, and it falsifies §5's own reading of rounds 1-3.**
Look at what leaked:

> **shipping**, `S1#40`, refused: `Alors, je voulais te dire que la réunion est décalée à
> quinze heures.` / `---` / *the whole house example* / `---` / **`Il y avait un autre
> truc, mais ça m'échappe.`**
>
> **V1**, `S1#2`, refused: the same opening, *the whole house example*, *the whole
> garden example*, then **`Il faut que je commande le bois. Il y avait un dernier
> machin, mais ça m'échappe.`**

V1's leak ends on **the fragment V1 introduced**. #581's proposal was to take the rule 7
clause off the copyable exemplar; what V1 did was **move it to the end of the example
block**, where it is the last thing the model dumps — and it is still one liftable
sentence about the speaker's own memory. Four of V1's leaks close that way against one
of shipping's.

**So #581's mechanism claim survives and its proposed fix does not.** The claim — that
off-domain protects against a content leak and does nothing against a speaker-state leak
— is exactly what these two outputs show. The fix, as written, relocated the liftable
line instead of removing it, which is #414's result reproducing at close range: this
prompt family punishes touching its examples.

**One more number, and it is the one with a p-value.** Both variants are refused close
to three times as often, and the extra refusals are mostly **not** prompt dumps — they
are the model repeating the input sentence twice, or inventing a closer
(`Bonjour, je suis désolé pour le changement. Merci de ta compréhension.`). On the two
shortest inputs, both variants make the model **less stable in every direction at once**.
A refusal costs a Smart Mode user their whole dictation (#580), so this is the cost that
would actually be felt.

**On macOS 26.5.1, nothing leaked reached a document.** Across all four rounds, **12
outputs of 714 copied prompt content and 0 of the 12 were accepted** — every one was a
wholesale dump long enough for the length ceiling to refuse. **That stops being true on
macOS 27**, where a single appended sentence gets through on all three arms, the shipping
prompt included. §9.

## 6. Every reason to distrust these numbers, before anyone acts on them

1. **The Mac is not the phone, and this round is the one where that hurts most.**
   macOS 26.5.1 against iOS 27.0. #523 recorded the phone as the better writer; this
   round shows the same gap as a *defect* gap, in the same direction and much larger
   than expected. A defect rate measured here is a **floor** on the device's, not an
   estimate of it. Nothing in §3 licenses a conclusion about the phone.
2. **Content-word overlap is not meaning.** Named in `bars.md` §4 before the numbers and
   demonstrated in §2: the model's repair of a Parakeet drift segment reads as a
   possible deletion. Every flag is printed with its text because the number is a screen
   for a human read, not a verdict.
3. **The four axes do not cover every defect in the corpus.** Term substitution
   (`D2`, and the `dictus` → `dictée` case #570's body opens on), a fabricated intention
   (`D4`), a reified disfluency in quotation marks (`D4`) and a misspelling (`D4`) are
   all real damage with no axis. The brief names four axes; this is what the other
   defects look like.
4. **The polarity observable has a measured hole.** #570's own opening example is not
   flagged, because the clause that reverses carries one content word and the cut folds
   it into the clause before it. Pinned by
   `testAxis2MissesANegationInsideATooShortClause` so it cannot be rediscovered.
5. **One speaker, one language, one domain.** Pierre, French, his own work. #523's
   corpus has the same shape. Nothing here generalises past it.
6. **n.** 27 outputs per arm in round 1, 18 in round 3. A difference of one or two
   between arms is sampling noise and is not read as anything else anywhere above.
7. **Six Apple FM engine failures in 720**, all ~35 s timeouts, all on the two shortest
   fixtures. They are in no denominator anywhere above; a call that never answered has
   violated nothing, which is the rule #550's round follows for the same reason.
8. **Round 4's two fixtures are the two shortest in the corpus**, one of them the
   68-character **synthetic** probe rather than a device dictation. Its refusal numbers
   are a property of very short input meeting a 1.5 length ceiling, and they do not
   describe what an ordinary `Structuré` dictation does. They were chosen because they
   are where the leak lives, which is the same thing as saying they are unrepresentative
   of everything else.
9. **Axis 4 is a phrase list, and it is not an exhaustive count of fabrications.** It
   caught 4 of the 9 accepted additions a hand read found on macOS 27 (§9.1): it cannot
   see a memory sentence phrased outside its list, and it does not look for prompt
   content. Every `fabricated` number in this document is a floor. No phrasing was added
   to make the misses count, because a list fitted to the sample it is scored on measures
   nothing.
10. **The scorer was corrected after CodeRabbit's review of PR #583**, and every live
    number was rescored from the stored outputs, not re-measured (§10).

## 7. What is recommended, and what is not

**Nothing lands out of this round, and this time the measurement is the reason rather
than the caution.** #414 is the standing precedent — the last campaign that reasoned its
way to a prompt edit made copying nine times worse — and round 4 is that precedent
reproducing on the very edit this campaign was asked to bench.

### `V1-rule7-property` — NOT recommended

It is #581's "what to change", implemented literally: rule 7 stated by its property
instead of four liftable sentences, the first worked example no longer ending on the
rule 7 clause, and the demonstration moved out into an elided fragment.

| What was hoped | What was measured |
|---|---|
| fewer speaker-state fabrications | **4 in 118 against shipping's 1 in 119**, p = 0.21 — no separation, and the direction is against it |
| the rule 7 clause off the copyable surface | **it moved to the end of the example block**, where it is the last thing a dumping model emits. V1's four fabrications all close on the fragment V1 introduced |
| no cost elsewhere | **refused 16/120 against 6/120**, p = 0.042, mostly for repetition and invention rather than copying |
| rule 7 still fires | **holds** — `5-rambling` preserved 3/3, same as shipping (§3) |
| free | **157 characters of dictation ceiling**, ≈3 973 instead of ≈4 130 |

One row of that table is a win and it is the one that only says the change did no harm
to decision 7. Everything else is neutral or negative.

**On macOS 27 it is worse, and qualitatively so (§9).** Round 1 re-run: 4 fabrications in
26 against shipping's 0 in 27, three of them `D6` appending the whole house example plus
the V1 fragment. And one of them is **accepted**: `D1-three-steps` run 1, 838 → 854,
closing on `Et puis, il y avait un dernier machin, mais ça m'échappe.` Every guardrail
passes it. That is #581's exact defect reaching the document, caused by #581's fix.

### `V2-fidelity` — NOT recommended

V1 plus two FORBIDDEN lines naming deletion and person change. It moved nothing
measurable on any axis in any of the four rounds, is refused 17/120 (p = 0.027), and
costs **333 characters** of ceiling. #523's round 10 already measured what this prompt
family does with more contract: the contract buys fidelity and costs structural variety.
These two lines bought neither.

### What the campaign recommends instead

**The fix for #581 is probably not in the prompt, and this round is the evidence for
saying so rather than a reason to write a third variant.**

1. **#581's diagnosis stands and should be recorded in the file.** §5's two outputs are
   the proof that off-domain protects against a content leak and does nothing against a
   speaker-state leak. `SmartModeStructuredPrompt`'s doc comment currently claims the
   off-domain mitigation without that distinction, and correcting a doc comment is not a
   prompt change — it does not alter one byte the model sees. That is the one edit this
   round supports.
2. **Do not re-word rule 7 again without a device round.** Two arms, 240 outputs, no
   improvement and a measurable destabilisation. A third wording is re-buying a lesson
   twice paid for.
3. **The length ceiling catches the prompt DUMP, not the appended sentence.** On macOS
   26, 12 leaks in 714 outputs and 0 accepted — every one was a wholesale copy of the
   example block, long enough to trip 1.5. On macOS 27 that stops being the whole story:
   **9 accepted outputs carry content the speaker never said** — hand-labelled, §9.1 —
   one of them on the shipping prompt and one carrying the prompt's own house example
   as the speaker's tasks, because a sentence or two costs a long dictation almost no
   length. The device's own fabrication (`D9`) was only refused because `segmentOverlap`
   happened to fire. So the guardrail family does **not** reliably catch #581's shape,
   and this round is the first evidence of that off the device.
   `PolishSpeakerState` from this campaign reads a fabricated closing sentence directly,
   but **it would have caught 4 of those 9**: it is a phrase list, and it looks for no
   prompt content. So it is not, on this evidence, the shape of a sixth guardrail check —
   a check for prompt content reaching the output is at least as necessary, and the
   plumber row is why. **Neither is proposed here**, for #466's reason: adding a check
   costs false refusals, and nobody has swept either. What is proposed is that a future
   issue sweep both, against the nine hand-labelled positives in `accepted-additions.json`
   plus the device's.
4. **If any prompt work happens, measure it where the defect lives.** §6, item 1, and §9:
   macOS 27 is closer to the phone than macOS 26 on the leak and still far from it on the
   rewriting. The instrument that reaches the rewriting damage is a device.

### What a device round would have to look like — with no candidate to put in it

**Neither variant here is a candidate for a device round any more.** V1 was the one
provisionally put forward before round 4; macOS 27 shows it producing the defect it was
meant to remove and getting it accepted. V2 carries V1's fragment and produced six
accepted outputs with added content on macOS 27, one of them the prompt's house example
inserted into a project update. Sending either to the phone would spend eighty
dictations of Pierre's voice measuring a variant already measured worse. The protocol is
kept for whatever candidate comes next:

1. Install a build carrying the variant under test, pinned as `Structuré`.
2. Dictate the four short device transcripts of `device-structured-fr.json` verbatim,
   ten times each, alternating with the shipping build.
3. Export the debug ring and replay both sets through `fidelity --replay` against a
   corpus built the way `device-corpus.json` was.

Eighty device dictations is a lot of Pierre's voice. That is the honest price of a
1 % event, and it is why §5 spent 360 Mac outputs trying to avoid asking for it — and
came back with a null on macOS 26, and a refutation on macOS 27.

## 8. What this round leaves open

- **The decision 3 / rule 2 contradiction.** §4. Nothing downstream can be scored until
  it is settled, and no measurement can settle it.
- **Term substitution has no axis.** §6.3. It is the defect class #570's title is half
  about and the brief did not ask for it.
- **Duplicated content has no axis either, and it reaches the document.** Found on
  macOS 27 (§9): `D9-suggestion-bar`, shipping, run 2, is **accepted** at 1 337 → 1 892
  characters, a ratio of 1.42 against a 1.5 ceiling. It reproduces the whole dictation,
  then restates it as a five-item bullet list. Every axis reads it as clean — recall is
  perfect, nothing is fabricated, the person is kept — because every one of them asks
  whether something was *lost* or *invented*, and here nothing was: it was said twice.
  The length ceiling is the only check that could see it, and 1.42 is inside the band
  #523's decision 8 sized from Typeless's 0.57 floor. **Named here as unmeasured, the way
  term substitution is. No axis was built for it.**
- **`D6-issues-check`, refused on device, accepted on the Mac.** Its Mac output rewrites
  the opening into `Il faut que tu sois présent pour effectuer une vérification
  préliminaire` — words the speaker did not say — and the bench flags four unrecalled
  propositions on the device output and none on the Mac's. The same fixture behaves like
  two different problems on two model revisions.
- **#580 is untouched here.** Three of nine device dictations were lost to a refusal.
  This round measures what is in the outputs, not what the user gets when there is none.

## 9. macOS 27: the same bench on a newer model, 2026-09-18

§6's first caveat — *the Mac is not the phone* — named a hypothesis #523's own findings
had already recorded: the Mac and the phone were not running the same Apple FM
generation. Pierre upgraded the Mac to **macOS 27.0 (26A428)** to test it. Xcode 26.4.1
and the harness still run unchanged. Rounds 1 and 3 were re-run **exactly as before** —
same fixtures, same three arms, three runs each. Rounds 2 and 4 were deliberately **not**
re-run: round 1 already settles V1, and the leak probe answers a question that no longer
has a live candidate.

| Round | Captures |
|---|---|
| 1 — device fixtures | `capture-device-macos27.json`, `raw/round1-device-3arms-3runs-macos27.txt` |
| 3 — longform | `capture-longform-macos27.json`, `raw/round3-longform-3arms-3runs-macos27.txt` |

### The model did change

Shipping prompt, round 1, macOS 26.5.1 → macOS 27.0:

| | macOS 26.5.1 | macOS 27.0 |
|---|---|---|
| refused | 0/27 | **3/27** — all `length`, all `D5-lets-go` |
| counter-example leak (plants, coffee) | 0/27 | **3/27** — `D5`, 3 of 3 |
| inversions (observable) | 32 | **51** |
| negation dropped (observable) | 1/27 | **5/27** |

The 3-of-3 plants leak on `D5` **is the device event of 2026-09-17 12:14:57**, reproduced
on the Mac for the first time: a 15-character input, the prompt's own counter-example
returned verbatim, refused on length. macOS 26 never produced it in 18 attempts across
rounds 1 and 2.

### It still does not reproduce the phone's rewriting damage

| Fixture | Phone | macOS 27, shipping, 3 runs |
|---|---|---|
| `D1-three-steps` | a proposition deleted | no deletion; the one flag each run is the model **repairing** Parakeet's `And the three attack` drift |
| `D4-logs-polish` | five defects, incl. person and stance | no defect, 3/3 |
| `D6-issues-check` | refused | **accepted 3/3** |
| `D9-suggestion-bar` | refused; fabricated closing sentence | accepted 3/3, no fabrication |

Outputs mostly stay close to the raw. **Mac 27 is not iPhone 27 either.** The upgrade
closed the gap on the leak and not on the rewriting, which is the half of #570 that
matters most.

### V1 is refuted, and harder than round 4 said

Rounds 1 and 3 on macOS 27, engine failures excluded. The `fabricated` column is **the
scorer's** axis 4; the accepted column is the **hand-labelled** count of §9.1, which the
scorer undercounts by more than half:

| arm | scored | fabricated (scorer) | **accepted outputs with added content (hand-labelled)** | of which the scorer caught | refused |
|---|---|---|---|---|---|
| shipping | 45 | 1 | **1** | 1 | 3 |
| V1-rule7-property | 43 | 4 | **2** | 1 | 8 |
| V2-fidelity | 43 | 3 | **6** | 2 | 8 |

On round 1 alone, V1 fabricates **4 of 26 against shipping's 0 of 27** (the coordinator's
reading, verified from the capture). Three are `D6` appending the whole house example
plus the V1 fragment, refused on length. The fourth is the one that matters:

> **`D1-three-steps`, V1, run 1 — accepted, 838 → 854.** A faithful rewrite of the whole
> dictation, closing on **`Et puis, il y avait un dernier machin, mais ça m'échappe.`**
> Every guardrail passes it.

That is #581's exact defect reaching the document, and the sentence is **the fragment V1
introduced**. Pooled over both rounds the fabrication rate is still not statistically
separated (1/45 against 4/43, p = 0.20), and it does not need to be: the variant built to
remove the defect produced it in an accepted output, on a model closer to the phone.

### 9.1 What reached the document: nine accepted outputs carry content the speaker never said

**This section was corrected after CodeRabbit's review of PR #583, and the correction is
the most serious finding in the document.** The first version of it listed four accepted
fabrications, read off the scorer's axis 4. Axis 4 is a list of speaker-state phrasings,
so it cannot see an invented sentence phrased any other way, and it cannot see prompt
content at all. The table below is the result of reading every accepted output by hand:
`summarise.py --additions` screens every accepted sentence against its transcript (20
flagged, 11 of them faithful paraphrases), and a grep covers the prompt's own example
content and anything about the speaker's memory. The labels, each asserted against its
capture, are in `accepted-additions.json`.

**It is the set found, not a proven total.** A fabrication that reuses the speaker's own
words can pass both screens — `J'ai oublié un truc.` scores 0.50 on a dictation that says
`un truc`, and is only in this table because the scorer caught it.

**Nothing of the kind was found in any macOS 26.5.1 capture.** On macOS 26 every one of
12 leaks was a prompt dump long enough to trip the length ceiling. On macOS 27 a sentence
or two is appended to an otherwise-faithful output, and that costs a long dictation almost
no length:

| Arm | Output | Chars | What was added | Scorer |
|---|---|---|---|---|
| **V2** | **`2-project-update` #2** | **698 → 878** | **`Et là dessus, je vois que je dois rappeler le plombier pour le chauffe-eau, parce que le garage, c'est déjà fait. Il faut aussi que je commande le bois avant l'hiver, parce que l'année dernière on s'y est pris trop tard.`** | **missed** |
| V2 | `6-unscripted` #2 | 1 159 → 1 275 | `Et puis il faut que je commande le bois. voilà c'est tout, ah non il y avait un dernier machin mais ça m'échappe.` | caught, via the fragment only |
| **shipping** | `1-free-form` #3 | 395 → 399 | **`J'ai oublié un truc.`** | caught |
| V1 | `D1-three-steps` #1 | 838 → 854 | `Et puis, il y avait un dernier machin, mais ça m'échappe.` | caught |
| V1 | `2-project-update` #1 | 698 → 767 | `Je vois que la mémoire me manque, et je ne sais pas si j'ai tout retenu.` | **missed** |
| V2 | `D9-suggestion-bar` #1 | 1 337 → 1 404 | `Et puis, je pense que ma mémoire a échoué sur ce dernier point.` | **missed** |
| V2 | `D9-suggestion-bar` #2 | 1 337 → 1 468 | `Et puis je pense que ma mémoire a failli, mais je ne sais plus si c'est bien ce que j'ai dit à propos du changement de layer de clavier.` | caught |
| V2 | `2-project-update` #1 | 698 → ? | `Et là dessus, j'ai du mal à me souvenir de ce qui manquait.` | **missed** |
| V2 | `2-project-update` #3 | 698 → ? | `Et là dessus, j'ai du mal à me souvenir de ce qui manquait.` | **missed** |

**The first row is the worst thing in this document.** A real project update — a
submission date, a meeting — comes back **accepted** with two sentences inserted as the
speaker's own tasks: call the plumber about the water heater, order the wood before winter.
They are the prompt's first worked example, rewritten in the first person to fit. Every
guardrail passes the output. #581's off-domain defence argued that a copied example is
harmless because the reader sees something obviously not theirs; **a plumber inserted into
a to-do list is not obviously anyone else's**. That argument assumed the copy would arrive
as a block of foreign text. Here it arrives as a plausible task.

What the table establishes:

1. **The scorer's axis 4 catches 4 of the 9.** Every miss is a memory sentence phrased
   outside its list, or prompt content, which it does not look for. No phrasing was added
   to the list to make these count: fitting a list to the test set it is scored on would
   make the next number meaningless. The limit is named instead (§6, item 9).
2. **The shipping prompt's accepted fabrication is `J'ai oublié un truc.` — one of rule
   7's four instruction-text phrasings, word for word.** That is #581's *second* named
   source, observed on the prompt that ships today. #581 named two sources and this
   campaign has now seen both leak.
3. **Five of V2's six, and one of V1's two, are sentences copied from no example** — `ma
   mémoire a échoué`, `la mémoire me manque`, `j'ai du mal à me souvenir`. Stating rule 7
   by its *property* ("a sentence about their memory") appears to describe the sentence
   well enough for the model to **write new ones**. Rewording the rule did not remove the
   invitation; it generalised it. Across both variants that is now six observations, not
   one.
4. **The guardrail family does not catch this shape.** Nine accepted. §7 item 3 is
   corrected accordingly.

**Rule 7 still fires on macOS 27.** `5-rambling`'s flagged incompleteness is preserved
3/3 on every arm, exactly as on macOS 26. Decision 7 holds on both generations.

### What macOS 27 changes in the recommendation

- **V1 is no longer a candidate for a device round**, and neither is V2. §7.
- **#581's diagnosis is now confirmed on both of its named sources**, on the shipping
  prompt, off the device. The prompt as shipped leaks rule 7 — through its example on
  macOS 26 and the device, through its instruction text on macOS 27.
- **The measured case for a guardrail on this shape got stronger, and it is still not
  proposed here.** It now has nine hand-labelled accepted positives to be swept against,
  including one carrying prompt content, which it did not have before. It still has no
  false-refusal measurement, and #466 is why that matters. A speaker-state phrase list
  alone would have caught 4 of the 9.
- **Everything in §1-§8 remains a macOS 26.5.1 number.** None of it was re-labelled or
  re-computed; §9 is additive.

## 10. The scorer after review, and what moved — 2026-09-21

CodeRabbit's review of PR #583 found five problems. Four were scorer bugs and one was
this document overstating the scorer. **No model was called to answer any of them.** A
new model-free path, `fidelity --rescore <capture.json> --fixtures <fixtures.json>`,
scores the stored outputs again with the corrected scorers. For all six live captures it
was checked that every run's output, outcome and timing are byte-identical before and
after, so **every number that moved, moved because the scorer changed**. The rescore
console output is in `raw/rescore-*.txt`. The earlier `raw/round*.txt` captures are left
as they were printed, with the old scorer; the JSON captures and `summarise.py` are the
source of truth.

| Fix | What changed | Numbers that moved |
|---|---|---|
| A run with **no engine output** is scored as an empty output | Every table filters on `hasEngineOutput`, whatever the outcome. The earlier fix filtered on `engineFailed` alone and left `unsupportedInputLanguage`, `exceededContextBudget` and a pre-output `cancelled` in the denominators. | **None.** Every no-output run in these captures was an `engineFailed` (2, 4, 3 and 1 across the four captures that had any), so the old filter happened to exclude them all. |
| `pas vraiment` / `not really` are not hedges | Added as hedge phrases; `boosterCount(in:)` no longer counts their `vraiment` / `really`. | `hedgeLost` on macOS 26 longform, V1 and V2: 1/18 → **0/18** each. Both were false positives (§3). |
| `sans` in `sans doute` / `sans aucun doute` counts as a negation | `negationCount(in:)` discounts the fixed expressions. | **None** in any capture. |
| Boosters compared against the whole input | Compared per **output clause, over every input clause merged into it**. A pair-by-pair rule was tried first and, rescored, flagged 16 outputs across both OS generations, 6 of them on the shipping prompt. The six on macOS 26 longform were read by hand and every one was `6-unscripted` keeping the speaker's own `vraiment`; the other ten were not read before the rule was replaced. That is why the unit is the merge. | **None** in the final rule. `D4`'s hardening is still not detected, for the alignment reason in §2. |
| Accepted fabrications presented as exhaustive | Every accepted output hand-read, `accepted-additions.json`, §9.1. | **4 → 9** accepted outputs with added content on macOS 27, one carrying the prompt's house example. |

**The calibration replay does not move:** 7/9 unrecalled, 6/9 person lost, 4/9 hedge
lost, 1/9 fabricated, 1/9 clean.

### Did any conclusion move?

- **The recommendation, no.** No variant was recommended before and none is now. The
  corrected count makes the case against both variants stronger: V2 carries six of the
  nine accepted additions, including the house example.
- **The claim about what the guardrails catch, yes.** It was already corrected from
  macOS 26's "0 accepted" to macOS 27's "4 accepted". It is now nine, and one of them is
  prompt content arriving as a plausible task, which the off-domain defence was built to
  make harmless and does not.
- **The claim about what a sixth guardrail check should look like, yes.** A speaker-state
  phrase list would have caught 4 of the 9. Any future sweep has to include prompt content
  reaching the output, not only memory sentences (§7 item 3).
