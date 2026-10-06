# The language check on a short line — results (#598)

**Issue:** [#598](https://github.com/getdictus/dictus-ios/issues/598) — *"The language check
refuses a correct output on a short line: es read as pt, da as nb"*.
**Plan and reading rules:** [`plan.md`](plan.md), committed before the first reading.
**Date:** 2026-10-05. **Machine:** macOS 27.0 (26A428). **Baseline:** `develop` at `b1f15b4f`.
**No model was called and no production code changed.**

Everything below is reproduced by:

```sh
docs/research/598-short-line-language-check/run-readings.sh        # re-takes readings.jsonl (macOS)
python3 docs/research/598-short-line-language-check/summarise.py   # prints summary.txt
docs/research/598-short-line-language-check/compare-ios-simulator.sh  # optional, headless
```

| File | What |
|---|---|
| `readings.jsonl` | 6 292 outputs: whole-output and per-segment `NLLanguageRecognizer` readings, and the shipping verdict, from `polish-harness langcheck` |
| `labels.json` | the hand labels: 139 refusing segments, 406 whole-pass refusals |
| `summarise.py` | re-implements the check, **refuses to run unless it reproduces the shipping verdict on all 6 274 readable outputs**, then scores the variants |
| `summary.txt` | its output, as committed |

Corpora: **K414** = the 482 hand-labelled outputs of `docs/research/413-414-guardrail/`, the
corpus #413's thresholds and PR #588's replay were scored on. **C587** = every capture under
`docs/research/587-*/` and `docs/research/571-summary/`, 5 792 outputs with an engine output
(18 more are a 15-character dictation the recogniser cannot read, so the pipeline passes
them through; excluded).

---

## The answer in four lines

1. **The misreading does not survive on ordinary length.** Across 5 792 bench outputs it
   appears on **one Spanish line** (`Parece bastante correcto`, 24–25 characters) and on
   **short Danish lines** (28–51 characters), 29 of 31 of them variants of one sentence;
   all but two come from one translated dictation (`T4-structured-since`). No line of 52
   characters or more is misread in any language, and **the whole-output pass refused 406
   outputs, none of them wrongly**.
2. **Reading the whole output instead of a line is not the cheaper fix.** It avoids the 9
   Spanish refusals and loses **114 genuine catches** in C587 and **1 of K414's 18**
   (`N3-projet-fleuve#3`, a bilingual list: the case #413 was built for).
3. **An `es`/`pt` exception costs nothing measurable**: 9 of 9 false refusals avoided, 0 of
   520 genuine catches lost, K414 18/18 kept with 0/464 false rejections. **But K414 cannot
   see this pair** — it holds 9 Spanish outputs, no Portuguese one and no `es`/`pt` drift —
   so "every catch preserved" is true and proves nothing here.
4. **Recommendation, if anything ships:** the exception on the **segment pass only**, and
   only on `.sameAsInput` (V3, scoped). Same measured benefit as the wide version, and it
   keeps refusing a wholly Portuguese output on a Spanish dictation, which the bench shows
   Apple FM producing on other languages. Doing nothing is also defensible; the cost of
   nothing is below.

---

## M1 — How often it fires on real length

**Measured.** Every refusal of C587 under the shipping check, labelled by hand:

| | refusals | false (every reason a misreading) |
|---|---|---|
| whole-output pass | 406 | **0** |
| segment pass | 123 | **9**, all `es→pt`, all the line `Parece bastante correcto` |

The 9 are `Liste` (6) and `Structuré` (3) outputs on the Spanish `T4-structured-since`
fixture, 129 to 370 characters long, whose whole reading is Spanish at 0.999–1.000. The
refusing line is 24 or 25 characters, read Portuguese at 0.910. 9 of the 45 outputs on that
fixture were refused this way.

Every misreading in the corpus, including the ones the Scandinavian rule already accepts:

| pair | lines | distinct strings | length | fixtures |
|---|---|---|---|---|
| `da→nb` | 31 in 30 outputs | 9: eight variants of *"Jeg tror, jeg kan eksportere loggene, som de er"* (29 lines, `T4-structured-since.da`) and `Jeg kan ikke skrive det selv` (2 lines, `T3-plan-mode.da`) | 28–51 ch | two |
| `es→pt` | 9 in 9 outputs | 2 (`Parece bastante correcto`, with and without a full stop) | 24–25 ch | `T4-structured-since.es` |

Rate of confident misreading (≥ 0.85) by segment length, over the 2 983 correct-language
outputs (of 5 272) that have more than one segment — a single-segment output is never
segment-tested (`summary.txt`, M1):

| lang | 12–24 | 25–49 | 50–99 | 100–199 | 200+ |
|---|---|---|---|---|---|
| es | **6/14** | 3/150 | 0/253 | 0/139 | 0/43 |
| pt | 0/20 | 0/160 | 0/282 | 0/128 | 0/39 |
| da | 0/19 | **29/190** | 1/270 | 0/93 | 0/45 |
| nb, sv, fr, en, it, de | 0 | 0 | 0 | 0 | 0 |

Across all 636 Spanish and Portuguese outputs, **the only `es`/`pt` cross-reading at any
confidence** — whole or segment — is that one Spanish line. The Portuguese
`T4-structured-since.pt` dictation says the same thing differently (*"parece estar bem
correto"*) and is never misread.

**Why these lines, read off the data:** the two the issue names are text that legitimately belongs to the
other language. `Parece bastante correcto` is well-formed Portuguese in its pre-1990 European
spelling (Brazilian *correto*). The Norwegian translation of the same fixture writes the
Danish sentence as *"Så jeg tror jeg kan eksportere loggene som de er"* — identical but for a
comma. No reading of these lines alone can tell the two languages apart. One word
more settles it: the same fixture once produced `Parece bastante correcto para mí.` (33 ch),
read Spanish at 0.72, below the floor, and accepted.

**Per pair, the answer:** `es→pt` fires at 24–25 characters only; `da→nb` at 28–51 only.
Neither survives at 52 characters or more, and the whole-output pass never misreads either
language.

## M2 — Read the whole output instead of a line (V1)

**K414**, every catch named (`summary.txt`, M2): **17/18**, 0/464 false rejections. The one
lost is `round1-notes-show-5runs.txt:N3-projet-fleuve#3`, a French note with English bullets
that #413's labels call `bilingual` — the shape the per-segment pass exists for.

**C587:** false refusals 9 → 0, **genuine catches 520 → 406: 114 lost**. They are lines in
another language inside an output whose bulk is right, mostly a French worked-example line
(`Il faut que je…`, `J'ai oublié un truc, mais ça m'échappe.`) inside an Italian, English,
Spanish, Danish, Turkish, Dutch… output (it→fr 24, en→fr 15, es→fr 14, da→fr 10, tr→fr 10,
…), plus an English line inside Portuguese or Danish outputs. Each of those would have been
accepted as the user's text.

**Verdict:** whole-output reading trades 9 false refusals for 114 genuine catches on the
bench and reopens #413 on its own corpus. Not cheaper.

## M3 — The cost of an `es`/`pt` exception

Scored the way PR #588 scored the Scandinavian one: K414 replayed, every catch named.

| Variant | K414 catches | K414 false rejections | C587 false refusals | C587 genuine catches |
|---|---|---|---|---|
| V0 shipping | 18/18 | 0/464 | 9 | 520 |
| **V2** — `es`/`pt` family, both passes (adding them to `matches(read:expected:)`) | 18/18, all kept | 0/464 | **0** | 520, **0 lost** |
| **V3** — `es`/`pt` family, segment pass only | 18/18, all kept | 0/464 | **0** | 520, **0 lost** |

**What K414 can and cannot say.** Only 9 of its 482 outputs touch `es` or `pt` at all, all
`sameLanguage` Spanish (`X4-es-liste`, `6-repair-es` ×5, `auto-verbal-es-prompt-layer` ×3).
None is Portuguese, none drifts between the two. The replay is therefore blind to the one
thing the exception risks; "18/18 kept" holds by construction. PR #588's replay had the same
blindness for Scandinavian drift, and said so.

**What C587 adds.** No output in C587 is a genuine `es`↔`pt` drift, so the exception's cost
is 0 measured. But the bench does show Apple FM writing those languages where it should not:
7 `Liste` outputs on `develop`'s old French-example prompt came back **wholly Spanish or
Portuguese on English, Japanese and Korean dictations**, and the same Korean dictation came
back Portuguese twice and Spanish once. Both V2 and V3 refuse all 7 (the expected language is
not `es`/`pt`). The difference between V2 and V3 is the case that did not occur: **a wholly
Portuguese output on a Spanish dictation** is accepted by V2 and still refused by V3, whose
whole-output pass stays strict.

**Unmeasured, structural.** `matches(read:expected:)` serves all three contract branches. V2
placed there reaches `Traduction → ES` (`.fixed(.spanish)`), where a Portuguese dictation the
model failed to translate reads `pt` against an expected `es` and would be accepted. V3 still
refuses that whole output, but would accept one untranslated Portuguese line inside a
translation. No committed capture has a Portuguese input to a translation, so neither is
measured. Scoping the exception to `.sameAsInput` closes both by construction.

## Also scored — a longer segment floor (V4)

| floor | K414 | C587 false refusals | C587 genuine catches |
|---|---|---|---|
| 12 (shipping) | 18/18, 0/464 | 9 | 520 |
| 20 | 18/18, 0/464 | 9 | 520 |
| 25 | 18/18, 0/464 | 3 | 519 |
| 30 | 18/18, 0/464 | 0 | 519 |
| 40 | 18/18, 0/464 | 0 | 505 |
| 60 | 18/18, 0/464 | 0 | 489 |

A floor of 26–30 avoids all 9 and loses one refusal (a JSON line the model appended,
`"title": "Plan-Modus",` — not a language catch, but a refusal worth keeping). It is not
recommended: the margin is **one string wide** (misread at 24–25, the shortest genuine
foreign line refused is 26: `Cela me semble très juste.` in a Turkish output), it moves the
boundary for every language rather than for the pair, and it would not have covered #588's
Danish sentence (48 characters) without the family rule.

---

## Recommendation, with its measured cost

**If a fix ships: V3 scoped to `.sameAsInput`** — add `es`/`pt` as a family to the segment
pass only, and only when the expected language is the input's own (the four Smart Modes and
free polish on Auto).

- **Refusals avoided:** 9 of 9 on the bench (9 of the 45 `T4-structured-since.es` outputs).
- **Catches lost:** 0 of 520 on C587; K414 18/18 kept by name, 0/464 — with K414 blind to the
  pair (above).
- **What it keeps that V2 does not:** a wholly Portuguese output on a Spanish dictation stays
  refused; `Traduction → ES` stays strict.
- **What it gives up, unmeasured:** a single Portuguese line inside an otherwise Spanish
  output would be accepted. Not observed in 636 Spanish/Portuguese outputs.

**Not recommended:** whole-output reading (M2: −114 genuine catches, reopens #413), a longer
segment floor (one-string margin, every language), V2 (same benefit as V3, wider exposure).

**Doing nothing is defensible.** The cost of nothing, measured: 9 refusals in 328 Spanish
outputs (2.7 %), every one from one translated dictation, on a Mac. Since #580 the user gets
their raw text and a notice, never a wrong-language text. Every false refusal measured here
rests on one string.

**An observation, not a recommendation:** #588's Scandinavian rule also sits in both passes,
and the whole pass never needed it here — no Danish, Norwegian or Swedish output was misread
as a whole (all 31 `da→nb` misreadings are lines). Moving that rule to the segment pass too
would cost 0 measured refusals. That is a change to a shipped rule and a separate decision.

---

## Measured, assumed, and not verified

**Measured** (macOS 27.0, 26A428): every reading in `readings.jsonl`; the reproduction of
the shipping verdict on 6 274 of 6 274 outputs; every number above.

**Measured on the iOS 27.0 simulator** (24A434): all 5 460 distinct segment strings re-read
with the simulator's `NaturalLanguage` — **identical top code on 5 460 of 5 460, and identical
confidence** (largest difference 0.000000). `compare-ios-simulator.sh` re-runs it headless.
Whole-output readings were not compared (the readings file stores segments, not whole
outputs). **A physical iPhone was not checked**; the simulator ships an iOS build of the
framework, but that is an inference, not a measurement of the device.

**Assumed / judgement:**

- **The labels.** Written by an agent, not a native speaker of Spanish, Portuguese or the
  Scandinavian languages. 127 of the 139 segment labels are French or English lines inside
  other-language outputs, which leave little room for doubt; the 11 `misread` labels (the two
  Spanish strings, the nine Danish ones) are the ones worth a second reader. The 406
  whole-pass refusals were all read and are all genuine; 390 of them are read English or
  French at ≥ 0.95, 16 were read line by line (`zh-Hant` outputs written in Simplified
  characters, `ko`/`ja` outputs written in Spanish or Portuguese, mixed outputs).
- **A third label, `markup`,** was added for the one JSON line; `plan.md` named only two.
- **The outputs are Mac outputs** on mostly agent-translated fixtures, as PR #588 and PR #597
  declared. They measure the recogniser on Apple FM's prose, not on a real speaker's dictation.
- **The expected code is computed from the fixture transcript** with the verbal-punctuation
  pre-pass applied in the fixture's language, as `GuardrailCase.preprocessed` does. It
  matches the fixture language on every output (`zh` reads `zh-Hans`).
- **Small samples.** One string (with and without its full stop) carries every false refusal. A zero is a bound on this corpus,
  not a property of the pair.

## What contradicted the issue

- The issue reads the two instances as the detector failing on a short line. Measured, it is
  narrower: both lines the issue quotes are text the two languages **share**; no reading of the line alone
  could separate them. This is why any fix based on a better reading of the line (a higher
  floor, another detector call) cannot be the answer, and why the fix that works is one that
  stops judging such a line between those two languages.
- `CLAUDE.md` says the iOS Simulator destination of the DictusCore package builds since #301.
  It does not on `develop` today: `polish-harness/LostWordReplay.swift` (#575) uses
  `corpusPaths` and `args` outside the `#if os(macOS)` guard, and `xcodebuild test -scheme
  DictusCore-Package -destination <iOS simulator>` fails on it. Not fixed here (out of scope);
  the iOS comparison above was taken with a standalone binary instead.
