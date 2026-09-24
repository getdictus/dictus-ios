# The language clause, reworded — bars and plan (#587 follow-up)

**Why:** CodeRabbit on PR #597. All four localized Smart Modes tell the model to write in
the transcript's language **and** "never in the language of the examples below", while
those examples are now in the transcript's own language. Read literally, the clause
forbids the language the output must be in.
**Scope:** the clause's wording, in `Message`, `Liste`, `Structuré` and `Résumé`. No rule
renumbered, no example changed, no guardrail, no contract, no pipeline code.
**Date:** 2026-09-24. **Machine:** macOS 27.0 (26A428), Apple Intelligence on.
**Baseline:** `develop` at `127fed3`, the four prompts as merged.

> Committed before the first model call of this round. The reword is **not landed on
> argument**: PR 1 measured the clause as part of what works, so removing it is measured
> too.

---

## 1. The change, in full

| Mode | Before | After |
|---|---|---|
| `Structuré`, rule 1 | *"…whatever it is, and never in the language of the examples below."* | *"…whatever it is. Read it, then write in that language and no other."* |
| `Message`, language line | *"…whatever it is, never in the language of the examples below."* | *"…whatever it is. Read it, then write in that language and no other."* |
| `Résumé`, language line | *"The examples below may be in another language: never write in theirs."* | *"That language alone decides the output's; nothing else does."* |
| `Résumé`, rule 1 | *"…never in the language of the examples below."* | *"…Read it, then write in that language and no other."* |
| `Liste`, examples header | *"…the output language always matches it, never the examples'."* | *"…the output language always matches the input's."* |

Everything else in the five strings is byte-identical, and every example set is untouched.

## 2. Arms and baselines

| Mode | Candidate | Baseline |
|---|---|---|
| `Message` | the code on this branch | PR 2's committed `shipping` capture (`docs/research/587-pr2-message-liste/capture-message-i18n.json`), which **is** `develop`'s prompt on this very fixture file, 3 runs, same Mac |
| `Liste` | the code | PR 2's `capture-notes-i18n.json`, same reason |
| `Structuré` | the code | PR 1 round 3's `C3` arm (`docs/research/587-structured-rewrite/round3/capture-r4.json`), which is the prompt that then landed |
| `Résumé` | the code | `arms/develop-summary/`, a directory arm rebuilt from the candidate's own strings with the two clause lines reverted, run in this round |

Reusing three committed baselines rather than re-running them is deliberate: they were
taken on the same fixture file, the same run count and the same machine, and re-running
them would spend two hours to re-measure prompts nothing has changed. `Résumé` has no
comparable capture, so its baseline runs here.

## 3. Fixtures

`fixtures/translated-structured.json`, unchanged: 6 of Pierre's French dictations
machine-translated into English and the 14 other Apple FM languages, 90 fixtures, 3 runs
each per mode. **Valid for output language only** — it says nothing about register, shape
or fidelity, and no bar below reads it for those.

## 4. The bars, per mode

Unchanged from PR 2 §4, because the question is the same one:

| Bar | Read as |
|---|---|
| **B1a — 0 wrong-language output accepted**, per mode, per language | an accepted output whose whole-text reading is not the fixture's language, or which carries a sentence of ≥ 20 characters read as another language at ≥ 0.85 that the speaker did not say in it; flagged by code, adjudicated by hand |
| **B1b — ≤ 10 % refused on `check=language`**, per mode, per language | **a regression above the bar stops the round**: keeping today's wording is an acceptable outcome, since it ships and measures clean |
| **B1c — English in, English out**, every mode | every engine output on the `en` rows reads as English |
| **B2 — `Liste` still makes bullets** (#393) | every accepted `Liste` output carries a `- ` line |

The Spanish short-bullet refusals recorded on PR #597 (#598) are expected to recur: they
are the language check reading one short line, independent of any prompt wording. They are
counted, and read against the baseline rather than against zero.

## 5. What is run

```sh
cd DictusCore
H=.build/debug/polish-harness; O=../docs/research/587-language-clause; F=Sources/polish-harness/fixtures
for m in message notes structured; do
  $H fidelity $F/translated-structured.json --mode $m --runs 3 --json $O/capture-$m.json > $O/raw/$m.txt
done
$H fidelity $F/translated-structured.json --mode summary --runs 3 \
   --arm $O/arms/develop-summary --json $O/capture-summary.json > $O/raw/summary.txt
python3 $O/summarise.py
```

## 6. Risks, declared in advance

1. **The Mac is not the phone.** PR 1's device rounds are the precedent for how far these
   numbers go.
2. **Three of the four baselines are from an earlier day**, on the same machine and
   fixtures. Apple FM samples, so a difference of one or two runs in 18 is noise, and the
   bar is read accordingly.
3. **The fixture set is agent-translated clean text.** It exercises the output language
   and nothing else.
4. **A clause that measures the same either way is a wording decision, not a measured
   improvement.** If the numbers are level, what this round buys is coherence — and the
   PR will say exactly that rather than claim a gain.

## 7. Outcome, 2026-09-24: the clause STAYS

The round ran as declared, four modes, 16 languages, 3 runs per fixture: **2 160 runs
loaded, 2 155 scored.** The five that are in no denominator produced no engine output at
all — four on the candidate side (one `Structuré`, two `Résumé`) and one on the reused
`Résumé` baseline — and a run the engine never answered has violated nothing, which is the
rule every round of this campaign has filtered on.

**The reword regressed `Liste` above the bar, so today's wording ships.**

| Mode | Language refusals, `develop` | Language refusals, reworded | Flagged by the detector, accepted | **Adjudicated wrong-language, accepted** |
|---|---|---|---|---|
| `Message` | 0 / 270 | 0 / 270 | 3 and 3 | **0 and 0** |
| **`Liste`** | **2 / 270** | **5 / 270** | 4 and 4 | **0 and 0** |
| `Structuré` | 0 / 269 | 0 / 269 | 3 and 3 | **0 and 0** |
| `Résumé` | 0 / 269 | 0 / 268 | 0 and 0 | **0 and 0** |

The two flag columns read `develop` and `reworded` in that order. **They are not the same
measurement**, and B1a is the second one:

- **Flagged by the detector** is what the code prints: an accepted output whose whole-text
  reading, or one of whose sentences of 20 characters or more, is read as another language
  at 0.85 or above. It is a screen, and it fires on things that are not defects.
- **Adjudicated** is B1a: the flags read one by one against the output. All 20 of them, on
  both arms, are cross-readings **inside** the Scandinavian set — `Jeg tror, jeg kan
  eksportere loggene, som de er.` read as Norwegian, a Norwegian bullet read as Danish —
  on outputs whose whole text reads as the language asked for. None is an output in a
  language the speaker did not dictate.

So the campaign's headline number is the second column: **0 wrong-language outputs
accepted**, on either wording, in all 16 languages, for all four modes. The first column
is kept beside it because a screen that is never shown is a screen nobody can check.

Per language, the two that moved, both on `Liste`:

- **Traditional Chinese: 0 of 18 refused → 2 of 18 (11.1 %)**, and these are **genuine**:
  the output came back **in English** (`- Prepare for issue integration`) on a Chinese
  dictation, twice of three runs, where the clause-carrying prompt answered in Chinese
  3 of 3. Over the bar, and the exact failure the bar exists for.
- **Spanish: 2 of 18 → 3 of 18 (16.7 %)**, the short-bullet misreading of #598, one run
  worse.

Everything else is level: English in, English out 18/18 for all four modes on both arms;
`Liste` keeps bullets on every accepted output (257/257 reworded, 263/263 baseline);
`Message` and `Résumé` unchanged.

**So the rule declared in §4 applies: keeping today's wording is the outcome.** The clause
is incoherent to read and measured better to ship, in the one place it matters. The
finding is not dismissed — it is written into `SmartModeStructuredPrompt`'s doc comment
and pinned by the two tests that assert the wording, so the next reader meets the
measurement rather than the contradiction alone.
