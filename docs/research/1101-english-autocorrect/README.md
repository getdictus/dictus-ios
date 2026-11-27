# English autocorrect against Apple's keyboard, then Hex (#1101)

Study only: no app code changes. Several US users found Dictus's English autocorrect
"weird". Pierre cannot judge English typing, so this page measures it: 58 English
sentences with the mistakes US typists make, typed with the same taps on Apple's
keyboard and on four Dictus builds, every Dictus miss explained from the keyboard's own
decision log, then how Hex handles what still fails, and five follow-up issues.

Measured 2026-11-27 and 28 on an iPhone 17 simulator, iOS 26.5, Xcode 27.2, with the
#954 bench (`tools/keyboard-bench/`, protocol in
[`docs/keyboard-measurement.md`](../../keyboard-measurement.md)) and AXe 2.2.0.

## Verdict

**Better since the reports, by a lot, and still behind Apple.** Between v2.0.2 (the App
Store build US users had, before #993 and #995) and develop, wrong words fall from 50 to
26 of 417, and words the keyboard wrongly changed (the "weird" ones) from 29 to 9. Apple
leaves 7 wrong words and wrongly changes 3. With the spatial decoder on, develop is at 19
and 8.

| 58 sentences, 417 words, 73 typed wrong | Apple | build 43 (v2.0.2) | build 47 | develop, switches off | develop, spatial on |
|---|---:|---:|---:|---:|---:|
| **Sentences exactly right** (case ignored) | **51** | 18 | 35 | 35 | 42 |
| **Typed wrong, fixed** | **68** | 32 | 54 | 54 | 61 |
| Typed wrong, left as typed | 4 | 21 | 17 | 17 | 11 |
| **Wrongly changed** (broken + miscorrected) | **3** | 29 | 9 | 9 | 8 |
| …broken: typed right, changed | 2 | 9 | 7 | 7 | 7 |
| …miscorrected: typed wrong, changed to another wrong word | 1 | 20 | 2 | 2 | 1 |
| **Wrong words in the final text** | **7** | 50 | 26 | 26 | 19 |
| …of which right after a user typo (counted apart) | 0 | 3 | 2 | 2 | 2 |
| Casing: `i`, `i'm`, `i'll` lowercase mid-sentence (of 9) | **0** | 9 | 8 | 8 | 8 |
| Casing: names and brands with their capital (of 22) | **14** | 1 | 1 | 1 | 1 |

- **Build 47 is not "before the fixes".** Tag `build/47` is `9bfa9203` (2026-11-26),
  which contains #997 (#993) and #999 (#995), both merged on 2026-11-21. Its output is
  byte-identical to develop's with the switches off: nothing has changed English
  autocorrect since. The "before" column is therefore **build 43** (`fef8360c`, v2.0.2,
  the App Store build from 2026-11-17 to 2026-11-25, and the last tag before #997 and
  #999). The US review of 2026-11-11 was written on v2.0.0; between v2.0.0 and build 43
  the only autocorrect change is #943 (never correct inside an e-mail address or a URL),
  which no sentence here reaches. v2.0.0 itself was not replayed.
- **What #993 and #995 did:** miscorrections 20 → 2. Build 43 turned swapped letters
  into other words (`siad` → `size`, `hvae` → `hvac`, `whne` → `wine`, `moive` → `move`,
  `tbh` → `thu`); develop fixes 18 of 21 swaps.
- **What the "weird" words are now:** 7 correct words changed (`venmo` → `venom`,
  `hulu` → `july`, `texted` → `tested`, `coworker` → `coworkers`, `jaxon` → `jax on`,
  `idk` → `idl`, `priya` → `prima`), and on screen, a lowercase `i` and `i'm` in nearly
  every message. Apple's three: `is ill` → `is I’ll`, `hwy` → `Hey`, `priya` → `Oriya`.

Sentence by sentence, with every wrong word and the risk family of each word:
[`results.md`](results.md).

## Method

### (a) Apple's keyboard on the simulator really runs en_US autocorrect

- The simulator is mine (`study-1101-english-autocorrect`, deleted at the end), set to
  `AppleLanguages = (en-US)`, `AppleLocale = en_US` and one keyboard,
  `en_US@sw=QWERTY;hw=Automatic` (`AppleKeyboardsExpanded = 1`), slimmed with
  `simslim on --keep com.apple.remindd`.
- The runtime holds the US English language data: `RequiredAssets_en.bundle` (97 MB)
  with `en_US.lm`, `Delta-en_US`, `Phrases-en_US`, `Unigrams-en`; French, Spanish and
  German are empty there (4 KB each), as #954 found.
- The keyboard in Reminders is QWERTY (top row starts with Q, accessibility tree), and
  it autocorrects: typed on the key centres, `teh adn i dont recieve its raining ill call `
  became `The and I don’t receive it’s raining I’ll call `.

So no device protocol is needed to get Apple's numbers. What the simulator lacks is a
person's phone: no contacts, no learned words, no real thumbs. The device check belongs
to each fix (#1105 asks for one before changing a default).

### The sentences

58 sentences, 417 words, in [`corpus/sentences.tsv`](corpus/sentences.tsv): what the
typist means, what they type, and the category of each slip.

- **Sentences 1 to 56 are invented** for this study (Claude, writing US texting
  English). No sentence corpus has the slang, brands and names needed; the typo sources
  of #978 are word pairs, not sentences. Nothing was tuned on them.
- **Sentences 57 and 58 come from Pierre's typing journal** (English keyboard, device,
  2026-11-20): his own test sentences, with his real slips letter for letter (`thzg`,
  `tgis`, `doidn`, `ftiend`). They were typed on AZERTY; here they are replayed on QWERTY
  key centres. His other English slips of that session (`weemeef` for `we meet`, `ly` and
  `le` for `my` and `me`, AZERTY neighbours) do not fit a QWERTY run. No other text from
  the journal is used.
- **Where each slip comes from** (column `slips`): `T`, a pair of
  [`typos-en.tsv`](../multilingual-autocorrect/typos-en.tsv) (TOEFL-Spell, Wikipedia,
  CC BY-SA 4.0); `A`, a contraction without its apostrophe, the largest real category of
  [`typo-sources.md`](../multilingual-autocorrect/typo-sources.md) (MultiLexNorm counts);
  `X` swapped letters, `O` a missed letter, `D` a doubled letter, `N` a neighbour key:
  **invented**, by those categories; `P`, Pierre's journal.
- **What they hold**: 23 contractions without apostrophe (13 of them real words: `ill`,
  `its`, `were`, `well`, `id`, `wont`, `lets`, `cant`), 8 real words that look like one
  (`ill` meaning sick, possessive `its`, verb `lets`, `well`, `were`), 22 names and brands
  (`venmo`, `hulu`, `chipotle`, `jaxon`, `priya`...), 13 slang words (`gonna`, `lol`,
  `tbh`, `idk`, `ngl`, `u`, `ur`, `k`...), 21 swaps, 12 neighbour keys, 3 doubled and 3
  missed letters, 19 short words with a slip (`ro`, `st`, `jn`, `mon`, `hwy`), every
  sentence start, and words right after a name.

[`make_run.py`](make_run.py) writes the bench's files: `corpus/en-us.txt`,
`corpus/en-us.keys`, `runs/en-us.tsv` (2,033 taps). Taps land on the centre of the key
typed, as in the bench's typo runs, except a neighbour slip: its wrong letter lands 0.3
of the way towards the key meant, inside the wrong key, where a thumb that misses lands.
Rhythm 170 ± 40 ms, fixed seed.

### The keyboards

| Column | Commit | How |
|---|---|---|
| Apple | iOS 26.5 | `sim_replay.py --keyboard apple` on my simulator, same taps and rhythm. One change to a local copy of the script: it taps `New Reminder` (English UI) where the committed one taps `Rappel`, and takes the `axe` path from `AXE`. |
| build 43 | `fef8360c` (`build/43`, v2.0.2) | the bench of that commit in a scratch worktree, the corpus copied in as `en` (that bench reads only its own `corpus/` and `runs/`) |
| build 47 | `9bfa9203` (`build/47`) | that commit's bench, `--corpus`/`--runs` |
| develop, off | `a5ef8a71` | `run.sh --langs en-us --corpus … --runs …`: every Experiments switch at its default, off (spatial, adaptive touch, bilingual, swipe) |
| develop, spatial | `a5ef8a71` | the same with `--spatial`, as the Experiments switch does |

Each Dictus column is the in-process replay of the shipping engine code of its commit
(#954: on the French run it typed what the real keyboard typed, 20 of 20).

### Scoring

[`score_1101.py`](score_1101.py) gives each intended word one outcome, case ignored and
`’` read as `'`: kept, **broken** (typed right, changed), fixed, missed, **miscorrected**
(typed wrong, changed to another wrong word). **(c)** A word whose previous word the
typist got wrong is counted apart: its context was the typist's error. **(e)** Broken
words are failures whatever the totals: a fix that adds one is not a fix. Casing is
scored separately, never as a wrong word.

## What still fails, and why

Per family: words right of the family's words (wrongly changed in brackets). Full table
in [`results.md`](results.md).

| family | words | Apple | build 43 | develop, off | develop, spatial |
|---|---:|---|---|---|---|
| contraction, real word typed (`its`, `ill`, `were`, `lets`, `id`, `well`, `wont`) | 13 | **13** (0) | 2 (0) | 5 (0) | 5 (0) |
| real word that looks like a contraction | 8 | 7 (**1**) | 8 (0) | 8 (0) | 8 (0) |
| contraction, plain (`dont`, `im`, `youre`...) | 14 | 14 (0) | 14 (0) | 14 (0) | 14 (0) |
| name or brand | 22 | 21 (1) | 17 (5) | 18 (**4**) | 18 (**4**) |
| slang / shorthand | 13 | 13 (0) | 10 (3) | 12 (1) | 12 (1) |
| swapped letters | 21 | 19 (1) | 3 (15) | 18 (1) | 18 (1) |
| neighbour key | 12 | 12 (0) | 7 (1) | 8 (0) | **12** (0) |
| short word with a slip | 19 | 18 (1) | 6 (2) | 11 (0) | 15 (0) |
| missed / doubled letter | 6 | 3 (0) | 2 (3) | 3 (1) | **6** (0) |
| single letter (`i`, `u`, `k`, `a`) | 18 | 18 (0) | 18 (0) | 18 (0) | 18 (0) |
| after a name or brand | 14 | 14 (0) | 13 (1) | 14 (0) | 14 (0) |
| sentence start | 58 | 56 (1) | 46 (5) | 51 (1) | 52 (1) |
| Pierre's journal | 4 | 4 (0) | 3 (1) | 3 (0) | 3 (0) |

**(d)** Every gap read in the keyboard's decision log: a DEBUG replay with the typing
journal (`run.sh --journal`, #1001), whose text is byte-identical to the Release
replay's. The lines are in [`out/decisions.md`](out/decisions.md).

1. **Correct words outside the 39,944-word list are corrected** (the 7 broken words).
   `TextPredictionEngine.checkWord` protects a word only if the trie has it
   (`TextPredictionEngine.swift:455`, `reason=already-valid`); anything else goes to the
   trie, which takes the nearest frequent word: `venmo` → `venom` (cost 0.70, nothing
   else under 1.65), `hulu` → `july` (0.80), `texted` → `tested` (0.45), `coworker` →
   `coworkers` (1.00), `idk` → `idl` (0.40; `idl` is itself a junk entry of the list),
   `priya` → `prima`; `jaxon` is split as `jax on` (`branch=split-bigram`). On every one
   the bigram context is 0 (`ctx=0`). Spatial on changes none of them: the trie decided
   first. Apple's own dictionary knows 6 of the 7 (below).
2. **Real-word contractions stay as typed** (8 words: `its` ×2, `lets`, `wont`, `id`,
   `well`, `were` ×2). All `already-valid`. Only `ill`, sentence-start `its`, `its`
   before a curated list of words, and `were` after `afraid`/`glad`/`hope`... have rules
   (`ContextualContraction`, `English.swift:59-111`); develop's 5 right answers come
   from those rules. Apple fixes 8 of 8, and breaks one correct `ill`.
3. **Typos that land on a word the list holds stay** (`ro`, `st`, `jn`, `mon`, `hwy`,
   `strat`). All `already-valid`; several are junk entries (`jn` rank 18,202, `ro`
   8,467, `strat` 27,278). The spatial decoder fixes 4 of the 6 (`ro` → to, `st` → at,
   `jn` → in, `mon` → mom) from the taps and the word pairs (`branch=spatial`). Apple:
   `hwy` → `Hey`, `strat` kept.
4. **The trie picks the cheaper edit with no context**: `than expectd` → `expects` (cost
   0.40 against `expected` 1.00), `he wnats` → `whats` (0.45 against `wants` 0.70);
   `wher`, `goood` and `doidn` are kept as `ambiguous-candidates` (`when`/`her`/`where`
   all at 1.00). Spatial fixes `expectd`, `wher`, `goood`.
5. **Casing.** `englishProfile.overrides` writes `"im": "i'm"` (`English.swift:20`),
   `applyOverride` capitalises only a word typed with a capital
   (`OverrideLookup.swift:26-31`, asserted by `OverrideLookupTests.swift:71`), and
   nothing turns `i` into `I`. Names stay lowercase: no rule, and most are not in the
   list.
6. **After a user typo** (counted apart): 2 words, both `its` after a slip the keyboard
   had fixed; the cause is family 2, not the context.

## Measured for the fixes

- **Apple's dictionary** (`UITextChecker`, en_US, same runtime, a probe spawned on the
  simulator; [`textchecker_probe.swift`](textchecker_probe.swift),
  [`out/textchecker.md`](out/textchecker.md)), all 295 distinct words of the run:
  - valid: `coworker`, `texted`, `idk`, `tbh`, `instagram`, `chipotle`;
  - misspelled, but the first guess is the word with a capital: `venmo` → `Venmo`,
    `hulu` → `Hulu`, `iphone` → `iPhone`, `coachella` → `Coachella`, `kayla`,
    `brandon`; `jaxon` → `Jason`, then `Jaxon`; `priya`: no;
  - it rejects junk entries Dictus accepts: `st` (→ at), `jn` (→ in), `ro` (→ or, to),
    `strat` (→ start);
  - the one risk on the run: `hime` (meant `home`) is a word for it;
  - one call: p50 5 µs, p95 96 µs, max 0.76 ms (the first).
- **Hex's context choice** for same-letter words, restated offline over `en.hextm`
  ([`context_choice.py`](context_choice.py), [`out/context-choice.md`](out/context-choice.md)):
  18 group words of the run, **8 of 8 to change chosen right, 10 of 10 to keep kept**,
  identical with Dictus's model and Hex's current one. An estimate of the rule, not of
  the keyboard.
- **The word pairs already in the bundle** (`en.hextm`) rank the trie's own candidates
  right where the trie had no context: −ln P after the previous word, `expected` 6.25 vs
  `expects` 12.67, `wants` 6.0 vs `whats` 16.17, `good` 5.6 vs `blood` 9.7. They would
  not save `texted` (`tested` 11.0 is likelier after `just`) or `coworker`.
- **Hex's current English model** (`en.hextm` `98c8da8f`, after Hex #2408 and #2973;
  Dictus ships the earlier `14370569`, which Hex's README names as the model before
  #2408) swapped into the spatial replay for `en`, `en-typos` and this run:
  **byte-identical texts and commits** ([`out/model-swap/`](out/model-swap/)). Its gains
  are in Hex's own branches (context choice, names), not in what Dictus ported.

### Time and memory (simulator, compare runs with each other only)

| | letter p50 / p95 (ms) | space p50 / p95 (ms) | bench footprint |
|---|---:|---:|---:|
| build 43 | 1.42 / 2.38 | 0.08 / 1.09 | n/a (older bench) |
| build 47 | 1.40 / 2.41 | 0.07 / 0.97 | 10.19 MB |
| develop, off | 1.41 / 2.40 | 0.07 / 0.98 | 9.44 MB |
| develop, spatial | 1.41 / 2.42 | 0.34 / 1.46 | 9.54 MB |
| develop, spatial, Hex's current `en.hextm` | 1.43 / 2.46 | 0.36 / 1.47 | 9.75 MB ¹ |

¹ Measured in a three-run replay (`en`, `en-typos`, `en-us`), where the same build with
Dictus's model reads 9.60 MB: the swap costs about 0.15 MB of touched pages, the file
being the same size (3,599,997 against 3,600,000 bytes).

None of the five fixes below touches the letter path. Their space-bar costs: one
`UITextChecker` call for words the list lacks (5 µs p50); a few binary searches in the
mapped pair table for the context choice and the reranking; the spatial decoder's
+0.27 ms p50 is measured. `en.hextm` is mapped on first use only
(`SpatialAutocorrect.swift:44-56`), so the fixes that read it with the switches off map
3.6 MB of read-only pages, of which only the rows looked up become resident: about
+0.1 MB of footprint with the decoder on.

## Hex

How Hex (github.com/anomalyco/hex, `dev` at `2f8c3b70`, 2026-11-27, MIT, Copyright (c)
2026 Christopher Langton) handles English, file by file with lines, and the licence of
every word list it ships or builds from: [`hex-english.md`](hex-english.md). In short,
per failure family:

| Family that still fails here | Hex | Where (Hex `2f8c3b70`) | Dictus today |
|---|---|---|---|
| Correct words outside the list | Ships **no** English validity list on iOS: asks `UITextChecker`; a word known only capitalised gets its capital | `ios/HEXShared/FullKeyboard/Autocorrect/AutocorrectEngine.swift:1215-1217`, `:1243-1264`; `ios/docs/keyboard.md:253-254` | 39,944-word list decides (`TextPredictionEngine.swift:455`) |
| Real-word contractions | Context choice over the model's word pairs, previous word on space, next word as a revision; `were` deliberately left out | `AutocorrectEngine.swift:1266-1383` | 3 hand rules (`English.swift:59-111`) |
| `wont`, `im`, lone `i` | Table of ~125 unambiguous fixes, `i` → `I`, `im` → `I'm` | `AutocorrectEngine+Dictionaries.swift:37-164`, `:207-218`; applied `AutocorrectEngine.swift:1078-1081` | `im` → `i'm`, no `wont`, no `i` |
| Slang | ~70 never-rewrite tokens (`tbh`, `idk`, `ngl`, `brb`...) | `AutocorrectEngine+Dictionaries.swift:27-34` | none; `idk`, `tbh`, `ngl` absent from the list |
| Neighbour slips onto list words, two-letter slips | Spatial decoder on by default; two-letter neighbour fix to a common word | `ios/HEXShared/FullKeyboard/TypingDecoder.swift:342-598`; `AutocorrectEngine.swift:1112-1115`, `KeyboardLanguage.swift:808-812` | decoder ported, off in Release |
| Names, brands, casing | `UILexicon`, `en.spellings` (299 spellings: `ChatGPT`, `GitHub`), names in the model | `AutocorrectEngine+Spellings.swift:11-25`, `ios/HEXKeyboard/TypingModel/en.spellings` | `ProperNounGuard`, 17 curated names |

What could be taken, with the licence of each source checked on its own page
([`hex-english.md`](hex-english.md) §12 has the quotes):

| What | Source data | Licence | URL | Size per language |
|---|---|---|---|---|
| Rule tables (fixes, shorthand, context groups, two-letter words) and the context choice logic | written for Hex | MIT | <https://github.com/anomalyco/hex/blob/dev/LICENSE> | a few KB of code |
| `en.hextm` (Hex current) | Google Books Ngram v3, 1980–2019 | CC BY 3.0 | <https://creativecommons.org/licenses/by/3.0/> | 3.6 MB, replaces Dictus's 3.6 MB: 0 net (measured: no gain on its own) |
| …its vocabulary filter, names, spellings | SCOWL 2020.12.07, sizes ≤ 70 | SCOWL permission notice (copy the notice) | <http://wordlist.aspell.net/scowl_v1-readme/> | inside the model; `en.spellings` 4.6 KB |
| …its newer words (ChatGPT, TikTok) | Leipzig Corpora Collection, English news 2023–2025 | CC BY for downloads (version not stated on the page; Hex says 4.0); website and API CC BY-NC, not to be used | <https://wortschatz.uni-leipzig.de/en/usage> | inside the model |
| …its chat words (`en-extra-words.tsv`, 166) | written by Hex's developers | MIT | (Hex licence) | inside the model |
| Never-suggest list (slurs) | LDNOOBW | CC BY 4.0 | <http://creativecommons.org/licenses/by/4.0/> | 11.5 KB |
| Validity and capitals | Apple `UITextChecker` | system API, no data shipped | — | 0 MB |

All attribution-only; none is non-commercial or share-alike for what would ship. Not
verified: the Leipzig licence version, and the source of SCOWL's name and abbreviation
lists. Dictus's own `en_ngrams.dict` uses OpenSubtitles sentences, whose OPUS terms this
study did not check.

## Fixes, ranked

Gains are on this run against develop with the switches off (26 wrong words, 9 wrongly
changed). They are estimates from the probes above unless marked measured, and they
overlap: do not add them up.

| # | Fix | Issue | Gain on the 58 sentences | Effort | Risk | Latency, memory |
|---:|---|---|---|---|---|---|
| 1 | Keep a word Apple's dictionary knows; take its capital for names | [#1102](https://github.com/getdictus/dictus-ios/issues/1102) | **6 of 7 broken words** (−6 wrongly changed), names capitalised; −1 fix (`hime`) | small | low: one typo kept on the run | +5 µs p50 on space, words the list lacks only; 0 MB |
| 2 | `I`, `I'm`, `I'll` capitalised mid-sentence | [#1103](https://github.com/getdictus/dictus-ios/issues/1103) | casing 8 → 0 of 9 (no word count change) | tiny | low | none |
| 3 | Hex's context choice for `its`/`it's`, `id`/`I'd`, `lets`/`let's`, `well`/`we'll`, and `wont` | [#1104](https://github.com/getdictus/dictus-ios/issues/1104) | **+6 words**, 0 broken (estimate: 8 of 8, 10 of 10 kept) | medium (~100 lines, port) | low; check on a held-out run | pair lookups on space; maps `en.hextm` (+0.1 MB) |
| 4 | Spatial decoder on by default for English, after a device run | [#1105](https://github.com/getdictus/dictus-ios/issues/1105) | **measured: +7 fixed, −1 miscorrected, 0 broken** (26 → 19); `en` 8 → 2 | small (a default), device test first | medium until a device run | **measured**: space +0.27 ms p50, letters unchanged, +0.1 MB |
| 5 | Rank trie candidates with `en.hextm`'s word pairs when the n-grams have no context | [#1106](https://github.com/getdictus/dictus-ios/issues/1106) | +2 off (`expected`, `wants`), +1 with spatial | medium | low–medium | ≤ 5 pair lookups on space |

All five keep the letter path untouched. #3 and #5 are a small local language model
choosing between readings, which is what this study prefers over per-word rules, and
the cheap first step of #996. With 1, 3 and 4 together, the words left wrong on this run
would be about `priya`, `were` ×2, `strat`, `hwy`, `doidn` and `hime`: near Apple's 7,
with its own different misses. That total is an estimate, not a measurement.

## Limits

- **Invented sentences.** 56 of 58 were written for this study, by a model, not by US
  typists; the slips follow measured categories but are placed by hand. They show
  families and causes; the counts are not a typing study.
- **Key-centre taps.** Only neighbour slips land off centre. A thumb's real scatter
  (the #954 touch run) is not in this run; `en` (#954) is quoted beside it.
- **One Apple keyboard state.** No learned words, no contacts, no history; a real phone
  knows its owner's names (`priya`, `jaxon`) and Apple would keep them.
- **build 43's bench** is that commit's own, with the grid of that time; the run's taps
  are on key centres, where the grid change does not matter.
- **Not replayed:** v2.0.0, the build the US review was written on.
- Simulator timings are not device timings (#591).

## Files

| Path | What |
|---|---|
| `corpus/sentences.tsv` | the 58 sentences: intended, typed, slip categories |
| `corpus/en-us.txt`, `corpus/en-us.keys`, `runs/en-us.tsv` | the bench's files, written by `make_run.py` |
| `make_run.py`, `score_1101.py` | the run and the scorer |
| `results.md` | totals, families, sentence by sentence, every wrong word |
| `out/<keyboard>/texts.tsv` | what each keyboard wrote; `commits.tsv` and `report.md` (the bench's own report) for Dictus |
| `out/decisions.md` | the decision log lines of every wrong Dictus word, off and spatial |
| `out/textchecker.md`, `textchecker_probe.swift` | the `UITextChecker` probe |
| `out/context-choice.md`, `context_choice.py` | Hex's context choice, offline |
| `out/model-swap/` | the spatial replay with Dictus's and Hex's current `en.hextm` |
| `hex-english.md` | Hex's English autocorrect file by file, and the licences |

Reproduce a Dictus column (own booted simulator):

```bash
tools/keyboard-bench/run.sh --udid <udid> --langs en-us \
    --corpus docs/research/1101-english-autocorrect/corpus \
    --runs docs/research/1101-english-autocorrect/runs [--spatial] > report.md
python3 -I docs/research/1101-english-autocorrect/score_1101.py \
    --corpus docs/research/1101-english-autocorrect/corpus/sentences.tsv \
    --run "develop"=build/keyboard-bench/out/texts.tsv
```
