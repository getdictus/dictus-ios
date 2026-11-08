# Normal polish damages correct input — measured (#575)

**Bars and plan:** `bars.md`, committed before the first model call (commit `f920d07`),
with two dated amendments: A1 before the round was scored, A2 after the first capture.
**Fixtures:** `fixtures.json`: four device dictations of 2026-09-17, the 2026-09-17
harness fixture behind rows 3 and 5, eight shape probes and one control.
**Arms:** `arms/`. **Captures:** `raw/`, 560 model calls. **Scorers:** `harness/`.
**Where:** Mac, **macOS 27.0 (26A428)**, Apple Intelligence on, `polish-harness`,
2026-09-23. Nothing here ran on an iPhone.

Recompute every table:

```sh
cd docs/research/575-normal-polish-damage/harness
python3 summarise.py            # per-arm and per-fixture damage, D-lost on this round
python3 detector_eval.py score  # D-lost on the two legacy corpora, and B9
python3 protected.py            # the narrow check, on the legacy corpora
python3 score.py ../fixtures.json ../raw/S-natural-fr-10runs.txt   # one capture in detail
```

---

## The verdict

1. **It is the model, not our code.** Every damaged word is already missing from
   `engineOutput`. The only thing the post-pass does is whitespace (`bars.md` §0).
   Measured the other way round, a **451-character prompt that forbids changing any
   word** damages *more* than the shipping prompts do: 27 of 70 outputs. It produces
   row 4's `comment vas-tu` 4/5 and row 3's `revoilà` 3/5, which the shipping prompts
   never produced here. The defect is Apple FM's prior toward standard written French.
   The prompt holds it back. It is not what causes it.
2. **The prompt is not the lever either, measured in both directions.** Removing the
   worked examples makes it worse (15/68 against 12/131). One added PRESERVE line naming
   the classes by example also makes it worse on the items it names. It deleted
   `s'il te plaît` 2/5, the phrase it teaches by name, where the shipping prompt did it
   0/10. It moved `comment tu vas` → `comment vas-tu` from 0/10 to 4/5 on the auto
   route. This prompt family punishes additions, as #414 and #570 already found.
3. **No shipped guardrail can see any of it.** 86 damaged outputs across the six arms
   were all `success`. The checks refused only whole-sentence drift: `P8` translated
   into English (language check, 10/10 on auto) and `Hello` → `Bonjour` (grounding
   check, 9/10 on FR, see §4).
4. **The Mac reproduces the class, not the rows.** Rows 1, 2, 3 and 5 are **0/20** on
   the shipping prompts. Row 4 is 2/20, `vérifier` only. But the same shape of damage
   shows up on other words of the same dictations: `settings` → `paramètres`,
   `je vois pas` → `je ne vois pas`, `pourrais` → `peux`, `t'as` → `tu as`. It lands on
   12/131 FR and 17/130 auto accepted outputs.
5. **A narrow code check could enforce the part of the Preserve list that is listable,
   at almost no false-refusal cost.** A generic "a dictated word is gone" check cannot,
   because it refuses 21 % of faithful long outputs. §5 and §6.

## 1. Q1 — the five rows, on the shipping prompts

10 runs per fixture per route, accepted outputs only (bars B1, B6).

| Row | Predicate | FR Natural | Auto (the device route) | 2026-09-17 |
|---|---|---|---|---|
| 1 | `s'il te plaît` or `bisous` gone from `D2` | **0/10** | **0/10** | device 1/1 |
| 2 | `je suis preneur` gone from `D4` | **0/10** | **0/10** | device 1/1 |
| 3 | `revaudrai` gone from `H1` | **0/10** | **0/10** | harness 2/2 on shipping |
| 4 | `vas-tu` / `vérifier` / `email` in `D2` | 0 / 0 / 0 of 10 | 0 / **2** / 0 of 10 | device 1/1, all three |
| 5 | `se capte` gone from `H1` | **0/10** | **0/10** | harness 2/2 on shipping |

**Which route the device was on.** It was the auto route (`bars.md` §0): Auto-detect
sends `PolishAutoPrompt`, and the device output has no NBSP, which only the per-language
post-pass inserts.

**Rows 3 and 5 reproduced on this same Mac on 2026-09-17 and do not today.** #570 §9
records that the Mac was on macOS 26.5.1 that day and moved to 27.0 on 2026-09-18.
Same fixture, same prompt: 2/2 then, 0/10 now. That is an engine change. It is not
sampling. **So a Mac pass says nothing about whether a fix works on the phone for these
rows.** The same reservation #570 reached from its own data.

The issue's table overstates row 3's rate and understates row 5's. The session
transcript shows two arms: shipping 2 runs, an emoji-palette arm 3 runs. Row 3 was 4
of 5, not 3 of 3. Row 5 was 3 of 5, not 2 of 6. See `bars.md` §0.

## 2. Q2 — shape or base rate

Damaged / accepted, per fixture. The label is the union of both screens (amendment A2).
The per-class split is in `summarise.py`'s output.

| fixture | FR shipping | Auto shipping | FR, no examples | minimal | FR + taught | Auto + taught |
|---|---|---|---|---|---|---|
| `D1-selfcorrect` | 0/10 | 1/10 | 0/5 | 5/5 | 0/5 | 0/5 |
| `D2-bisous` (rows 1, 4) | 0/10 | 2/10 | 0/5 | 4/5 | 0/5 | 4/5 |
| `D3-petit-peu` | 0/10 | 0/10 | 0/5 | 0/5 | 0/5 | 0/5 |
| `D4-preneur` (row 2) | **8/10** | **6/10** | 5/5 | 5/5 | 1/5 | 5/5 |
| `H1-thanks` (rows 3, 5) | 0/10 | 0/10 | 2/5 | 3/5 | 1/5 | 0/5 |
| `P1-bisous-alone` | 3/10 | 0/10 | 3/5 | 4/5 | 5/5 | 0/5 |
| `P2-merci-avance` | 0/10 | **8/10** | 5/5 | 0/5 | 2/5 | 1/5 |
| `P3`–`P7` (held-out shapes) | 0/50 | 0/50 | 0/25 | 5/25 | 0/25 | 0/25 |
| `P8-register` | 0/1 (9 refused) | – (10 refused) | 0/3 | 0/5 | – | – |
| `C1-control` | 1/10 | 0/10 | 0/5 | 1/5 | 0/5 | 0/5 |

**By the declared rule (B2), it is not a shape.** On the shipping prompts the probes are
damaged 3/71 (FR) and 8/70 (auto), in one probe each. The control is damaged 1/10 on FR:
`18h30` → `18 h 30`, a format lift. The shapes the issue names hold on the Mac every
time: sign-offs, politeness formulas, the three idioms, the slang verb. So the rule's
"at least 2 probes damaged" test fails.

**What the damage does follow is one direction, not one shape.** Every damaged word on
the shipping prompts moves *toward standard written French*:

| from (dictated) | to | where |
|---|---|---|
| `settings` | `paramètres` | D4, both routes |
| `je vois pas` | `je ne vois pas` | D4, both routes; D1 auto |
| `usage` | `utilisation` | D4 |
| `t'as` | `tu as` | P1, FR |
| `pourrais` | `peux` | P2, auto 8/10 |
| `checker` | `vérifier` | D2, auto 2/10 (row 4) |
| `Hello` | `Bonjour` | P8, FR 9/10, refused |
| `18h30` | `18 h 30` | C1, FR 1/10 |

Every one of these is on ADR 0003's Preserve list by name or by class: anglicisms, oral
negation, contractions, number formats, word choice. The deletions and idiom
substitutions (rows 1, 2, 3, 5) are the same drift carried further. The phone does it
and the Mac on macOS 27 mostly does not. That makes it an **engine-dependent
normalisation prior**, not a list of fragile phrases. It explains why the device rows
look random across fixtures: the prior fires on whichever word it can normalise in that
input.

## 3. Q3 — localisation

| Candidate | Test | Result |
|---|---|---|
| **Code (pre-pass / post-pass)** | Is the word missing from `engineOutput`, and present in what the engine was given? | **Model, every time.** The post-pass only changes whitespace. The pre-pass leaves 13/14 fixtures byte-identical (checked with `prompt --out`). |
| **The model's prior** | Arm M: 451 characters, "you may NOT change, add, remove, or reorder any word" | **Yes. 27/70 damaged**, the most of any arm: `vas-tu` 4/5, `revoilà` 3/5, `+ne` on D1 5/5 and on D4 5/5, `t'as` → `tu as` 9/10 |
| **The worked examples teach it** | Arm X: shipping FR minus every example and counter-example | **No. The opposite.** 15/68 against 12/131. The examples *protect*: without them `s'il te plaît` is deleted from P2 5/5 and `revaudrai` goes 2/5 |
| **The Forbidden/Preserve rules are ignored** | Shipping arms | **Partly.** They suppress most of the prior (27/70 → 12/131), and what leaks is what the prior pushes hardest (`settings`, oral negation) |

**One code defect in the family, and it is not a #575 row.** The pre-pass's
normalisation step 2 (`([,.])[ \t]*\1+` → `$1`) turns Parakeet's ellipsis
`dès que... dès que` into `dès que. dès que`. So the engine gets a sentence that ends on a
conjunction. That is the *"hesitation left broken"* #439 filed on 2026-09-17, and the
device output shows it verbatim. On the Mac the model folds the repeat back together
11 times in 20 on the shipping arms, and 26 in 40 across every arm except the minimal
one. The minimal arm is told to touch nothing, and it passes the break through 5/5. A one-line regex exclusion for `...` would remove the cause. Not done
here, per the brief.

## 4. Q4 — the guardrails

All **86** damaged outputs that were accepted across the six arms were `success`.
Deletion, substitution, register and format all pass all five checks, as the checks are
written:

- **length** `[0.5, 2.0]`: one word never moves the ratio.
- **language**: fires on language, not register.
- **grounding**: fires on a *named entity* absent from the input.
- **prefix alignment**: compares the opening window, and one substitution inside eight
  words passes the 0.70 floor.
- **segment overlap**: one content word of eight in a segment clears it. That is #570's
  finding: nothing in the pipeline refuses a replaced token.

The checks did refuse two things. Both were larger than any #575 row:

- `P8` on auto came back **in English** 10/10. Refused by the language check, which is
  working as designed.
- `P8` on FR came back `Bonjour Julie, …` for `Hello Julie, …` 9/10. Refused by
  **grounding**. The check most plausibly read `Bonjour Julie` as a new name span. That
  was not investigated further. It caught a real substitution, but that was luck, not
  design: the same swap without a name next to it would pass.

## 5. Q5 — what a detector would cost

### D-lost, declared in `bars.md` before the round

It refuses when a word the speaker dictated is gone, apart from the licensed removals
(`detect.py`). Every flag was read by hand (`label_legacy.py` holds the reads as
auditable rules, `summarise.py` holds this round's).

| corpus | outputs | damage refused | **faithful refused** (D-lost-1) | D-lost-2 |
|---|---|---|---|---|
| this round, two shipping arms | 261 | – | **10/232 (4.3 %)** | – |
| #439 longform, short edit | 60 | 27 | **7/33 (21.2 %)** | 6/33 (18.2 %) |
| `freepolish.json` (#466) | 72 | 8 | **5/64 (7.8 %)** | 5/64 (7.8 %) |

The faithful denominator is every output not labelled damage, so it is an upper bound on
the faithful count and a lower bound on the rate.

Catch rate on this round, every arm: **deletion 7/7, substitution 44/44, format 2/2,
register 25/61.** The register misses are expected by construction (B7): `vas-tu`,
`tu as` and `ne` keep every word or add one.

**B8 fails.** The bar was ≤ 5 % on the longform corpus. What D-lost refuses there
is legitimate:

- rule-8 repairs: `honnête` → `honnêtement`, `type less` → `TypeLess`, the English
  clauses of #439 fixture 3 and of `5-erreur-parakeet`;
- spelling variants: `essaye` → `essaie`, `paye` → `paie`;
- repeated phrases collapsed: `le comptable le comptable`, `un grand un grand`.

On short input all 10 false refusals are one shape: `D1`'s hesitation fold.
**This is #466 again**: a bag-of-words check cannot tell a repair from a loss.

### D-protected, sketched after the round (`protected.py`)

It refuses when the output adds `ne`/`n'`, or when a phrase from a short lexicon is in
the input and missing from the output. The lexicon: `s'il te plaît`, `bisous`, `bises`,
`merci`, `t'as`, `t'es`, `checker`, `check`, `mail`, `settings`, `today`, `push`,
`deadline`, `review`.

| corpus | faithful refused | damage refused |
|---|---|---|
| #439 longform (never seen) | **0/33** | 3. All `+ne`, all *missed by the first hand read*: `les autres c'est pas` → `les autres ne sont pas` |
| `freepolish.json` (never seen) | **0/64** | 5: `today`, `push`, `deadline` translated; one Apple refusal sentence accepted by the old pipeline |
| this round (**fitted**) | 0/439 | deletion 7/7, register 54/61, substitution 29/44 |

Its false-refusal numbers are the only ones measured on data it never saw. Its catch
numbers are fitted to this round and **are not a measurement.** It cannot see an idiom
it does not list: `revaudrai`, `preneur`, `pourrais` → `peux`, `usage` → `utilisation`.

### B9 — what a refusal costs the user

On the free polish, a refusal inserts the **floor**: the pre-pass text, plus
typography on the per-language route. It does not insert nothing. Words that differ
between the floor and the accepted output:

- this round's shipping arms, short Parakeet messages: **zero on 216 of 261**, median 0,
  max 14;
- #439 longform: zero on 24/60, median 5, max 15.

Parakeet already punctuates (#439, 2026-09-11 device session). On a short message, a
false refusal usually costs a comma or a capital. On a long dictation it costs the
filler cleanup.

## 6. Candidate fix shapes, ranked

No decision is taken here. Costs are the measurements above unless marked *estimated*.

### A — enforce the listable part of the Preserve list in code (recommended)

A sixth output check on Natural and Auto, not Repair, shaped like `protected.py`.
When it fails, the result is `rejectedGuardrail` and the free polish falls back to the
floor.

- **What it buys:** it catches every deletion of a named politeness formula or sign-off,
  every added `ne`, and every translated listed anglicism, whichever engine the phone
  runs. That last point is the reason to prefer it. The prompt's effect changed with one
  OS update (§1), and a code check does not.
- **Measured cost:** 0 false refusals in 97 faithful outputs it never saw. A refusal
  costs about nothing on short Parakeet input (B9).
- **What it does not buy:** idiom substitutions (rows 2, 3, 5) and any register word
  missing from the lexicon. The lexicon is the Preserve list the prompts already carry,
  moved into code. It grows by PR, exactly as ADR 0003 says the prompt list does.
- **Risk, estimated:** a speaker who dictates `merci` and means it as filler loses the
  polish on that message. The legacy corpora do not contain that case.

### B — the generic "no dictated word may vanish" check, gated to short input

D-lost, only below a length where the floor is nearly the output, around 300
characters (*estimated* from B9).

- **What it buys:** it is the only shape that catches rows 2, 3 and 5: 44/44
  substitutions and 7/7 deletions on this round.
- **Measured cost:** 4.3 % false refusals on short input. All were one licensed
  hesitation fold, and it would refuse any rule-8 repair on a short message. 21 % on
  long input is why it must not run there.
- **Why it ranks second:** it trades a silent wrong word for a visible *un*-polished
  message about 1 time in 25, on the free path everyone uses. Whether that trade is
  right is a product call. It is #466's shape, and #466's number is why it is gated.

### C — a prompt change (not recommended, measured)

- The taught line cost 272 characters (FR) and 286 (auto) of #270 headroom. It made
  taught items worse: `s'il te plaît` deleted 0/10 → 2/5, `t'as` → `tu as` 3/10 → 5/5,
  `vas-tu` 0/10 → 4/5 on auto.
- Removing the examples is worse still.
- The one gain was `D4`, 8/10 → 1/5 on FR, and it reversed on auto (5/5).

A prompt round can only be judged on device, because the Mac's engine changed under
this very fixture set a week ago.

### Independent of A–C

- **The pre-pass ellipsis collapse** (§3) is a code defect with a one-line cause. It
  is fixable on its own.
- **Accepting the register lift as out of scope for the free path** is the remaining
  option the issue lists. Nothing here argues for it: every class measured is on the
  Preserve list by name.

## 7. What this round did not establish

- **Nothing about the phone.** The four device-only rows did not reproduce here. The
  one bench that can validate A or B against rows 1–5 is a device replay of the same
  fixtures. It goes on the manual validation list.
- **D-protected's catch rate on unseen data.** Its lexicon was written after reading
  this round. Only its false-refusal count is out-of-sample.
- **Whether the grounding refusal of `Bonjour Julie` is by design.** It was not
  investigated.
- **Whether the lexicon generalises to EN/ES/DE.** This round is French only, like
  #439.
