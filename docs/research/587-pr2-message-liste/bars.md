# `Message` and `Liste` — the language fix (#587, PR 2)

**Issue:** [#587](https://github.com/getdictus/dictus-ios/issues/587) decision 9: *"PR 2,
after PR 1 — language fix only on `Message` and `Liste`, reusing the rule PR 1 measured.
Nothing else moves in `Message`. `Liste`'s full rebuild stays #573."*
**Date:** 2026-09-23. **Machine:** macOS 27.0 (26A428), Xcode 26.4.1, Apple Intelligence on.
**Baseline:** `develop` at `3fb161e`, i.e. the prompts PR 1 left untouched.

> Written and committed **before the first model call of this round**, as PR 1's three
> rounds were. The only model calls that precede it are PR 1's, in
> `docs/research/587-structured-rewrite/`.

---

## 1. What this round changes, and what it must not

**Changed, and only this:** the worked examples of both prompts become one set per Apple
FM language, through the mechanism PR 1 and #571 shipped (`SmartModePrompt.localizedInstructions`,
resolved by the pipeline from the transcript's language). Plus one clause: each prompt's
existing language line gains *"never in the language of the examples below"*, which is the
rule PR 1 measured.

**Not changed:**

- **No rule of either mode.** `Message`'s seven rules, its `0.2…1.1` band, its user turn
  and its short-block pass are untouched; `Liste` keeps every rule and its counter-example
  block. #573 is where `Liste`'s prompt is rebuilt.
- **No guardrail, no contract, no pipeline code.**
- **`Message`'s French prompt.** Its French set is the shipping pair **byte for byte**, so
  a French dictation sends what it sent before, minus the one language clause. Verified by
  diffing the composed prompt against `develop`'s rendered text: the only line that differs
  is that clause.
- `Liste`'s French set keeps its three French blocks byte for byte; its fourth block, the
  build example, was English and is now French, which is the whole point of the round.

## 2. The candidate, and the baseline

| Arm | What it is |
|---|---|
| **shipping** | the prompts as wired in this branch: one example set per language |
| **develop** | `arms/message-develop.txt` and `arms/notes-develop.txt`, the exact strings `develop` sends today, run as a single-file arm |

The candidate is the code, not a file, because the mechanism is already shipped and
resolving it per fixture is what has to be measured. The baseline is a file because
`develop`'s prompt no longer exists in this branch.

## 3. Fixtures

| Set | File | Modes | Valid for |
|---|---|---|---|
| **M-fr** | `fixtures/message-fr.json` (new, 4) | `Message` | the French regression bar: the four device messages of `docs/research/572-message/corpus.json`, raw verbatim |
| **L-fr** | `fixtures/notes-fr.json` (6, unchanged) | `Liste` | French bullets, and the one English fixture it already holds |
| **T** | `fixtures/translated-structured.json` (90, unchanged) | both | **output language only**: 6 of Pierre's French dictations machine-translated into English and the 14 other Apple FM languages, 6 distinct dictations per language |

`T` is clean written text and is reused from PR 1 deliberately: it is the set the language
bars were measured on there, so the two rounds are comparable. It says nothing about
fidelity, register or shape, and no bar below reads it for those.

3 runs per fixture, both arms, every round.

## 4. The bars, per mode

Read on the engine's output, as in PR 1. A run with no engine output is in no denominator.

| Bar | How it is read |
|---|---|
| **B1a — 0 wrong-language output accepted**, per mode, per language | an accepted output whose whole-text `NLLanguageRecognizer` reading is not the fixture's language, or which carries a sentence of ≥ 20 characters read as another language at ≥ 0.85 that the speaker did not say in it. Flagged by code, adjudicated by hand, every flag printed |
| **B1b — ≤ 10 % refused on `check=language`**, per mode, per language | `rejectedCheck == language`. **A failure stops the round**: it is reported, and step 3 of the ladder is not attempted — PR 1 stopped at step 2 and nothing here justifies going further |
| **B1c — English input, English output**, both modes | every engine output on the `en` rows of `T` reads as English, accepted or refused |
| **B2 — `Liste` still makes bullets** | on `L-fr` and on `T`, every accepted `Liste` output carries at least one line opening on `- `. #393 is why this is a bar: a translated example that came back as prose would have turned the bullet mode into prose |
| **B3 — `Message` unchanged in French** | on `M-fr`: the same accept rate or better than `develop`'s arm, the same block shape (outputs carrying a blank line), and no new refusal check. Pierre uses this mode daily and is satisfied with it |

Reported, never barred: length ratios, refusals by check, prompt sizes, and the per-language
bullet counts for `Message` (it has no bullet bar either way).

## 5. What is run

```sh
cd DictusCore
H=.build/debug/polish-harness; O=../docs/research/587-pr2-message-liste; F=Sources/polish-harness/fixtures
$H fidelity $F/message-fr.json  --mode message --runs 3 --arm $O/arms/message-develop.txt --json $O/capture-message-fr.json
$H fidelity $F/notes-fr.json    --mode notes   --runs 3 --arm $O/arms/notes-develop.txt   --json $O/capture-notes-fr.json
$H fidelity $F/translated-structured.json --mode message --runs 3 --arm $O/arms/message-develop.txt --json $O/capture-message-i18n.json
$H fidelity $F/translated-structured.json --mode notes   --runs 3 --arm $O/arms/notes-develop.txt   --json $O/capture-notes-i18n.json
python3 $O/summarise.py
```

The `fidelity` command is used for its observables (output language, list lines, refusal
check, length), not for its four fidelity axes: those are `Structuré`'s contract, and
neither mode here is judged on them. Axis numbers in the captures are ignored, and
`summarise.py` prints none.

## 6. Risks, declared in advance

1. **The Mac is not the phone.** Every number is a Mac number; PR 1's device rounds are the
   precedent for how far that goes.
2. **`T` is agent-translated and clean**, so it exercises the output language and nothing
   else. In particular it cannot say whether `Message` still cuts on device.
3. **The example sets for 13 of the 15 languages are agent translations**, never read by a
   native speaker. That is the same limitation the two shipped modes carry.
4. **`Liste` has no French corpus beyond `notes-fr.json`'s six fixtures**, so B2's French
   half is measured on a small set.
5. **A `Message` regression that only shows on device** — the relational layer, the cut
   rate — is invisible here by construction. B3 is a Mac-side no-change check, not a
   revalidation of the mode.
