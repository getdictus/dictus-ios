# Multilingual autocorrect: first numbers and a plan

Goal (2026-11-19): typing on Dictus as good as Apple's keyboard in every language, not
only French. This page holds the first measurement of the Dictus keyboard in English,
Spanish and German next to French, Apple's keyboard on the same taps where the
simulator can run it, the realistic typo runs, the real cases we have, and the order
proposed for the work.

Research and tooling only: no app code changes. The keyboard code measured is develop
at `13c134a1`, on an iPhone 17 simulator, iOS 26.5, Xcode 27.2. The tool is
`tools/keyboard-bench/` and the protocol is
[`docs/keyboard-measurement.md`](../../keyboard-measurement.md).

## Files

| Path | What |
|---|---|
| [`corpus.md`](corpus.md) | Where the Spanish, German and typo-run sentences come from (Tatoeba, native authors) and how they were checked. |
| [`typo-sources.md`](typo-sources.md) | The public typo corpora checked per language, their licences, and the frequent real mistakes they show. |
| `typos-en.tsv`, `typos-es.tsv`, `typos-de.tsv` | The typo pairs (`typo`, `correct`, `category`, `source`), CC BY-SA 4.0 (attribution in `typo-sources.md`). |
| [`real-cases.md`](real-cases.md) | The register of real cases per language: App Store reviews, TestFlight, in-app feedback, the tracker. |
| `dictus-replay/` | `run.sh --langs fr,en,es,de`: the report and every tap, word and sentence. |
| `dictus-replay-typos/` | `run.sh --langs en-typos,es-typos,de-typos`. |
| `apple-simulator/` | `sim_replay.py --keyboard apple` for es, de and en-typos. Apple fr and en are the #954 baseline runs ([`954-keyboard-baseline/apple-simulator/`](../954-keyboard-baseline/apple-simulator/)), same taps, same simulator and iOS version. |

## The numbers

Same seeded touch model in every language (Gaussian offsets, sigma 0.22 key widths
across, 0.18 rows down), 20 everyday sentences per language, typed fast: lowercase, no
accent and no tilde typed, German umlauts typed on their keys, `ss` for `ß`.

### Dictus against Apple, per language

| | fr | en | es | de |
|---|---:|---:|---:|---:|
| Words | 152 | 157 | 141 | 141 |
| **Dictus: wrong words, final text** | 9 (5.9%) | 9 (5.7%) | **29 (20.6%)** | 7 (5.0%) |
| Apple: wrong words, final text | 33 ¹ | **0** | 48 ¹ | 30 ¹ |
| Dictus: wrong-key characters before autocorrect (accents ignored) | 13 of 801 | 28 of 766 | 25 of 729 | 26 of 752 |
| Apple: wrong-key characters, final text (accents ignored) | 17 ¹ | 0 | 29 ¹ | 33 ¹ |
| Dictus: wrong-key characters after autocorrect | 4 | 17 | 11 | 8 |
| Dictus: wrong letter taps (key geometry) | 13 of 669 | 21 of 629 | 23 of 608 | 21 of 634 |
| Dictus: typed wrong, fixed | 22 | 11 | 15 | 17 |
| Dictus: **broken** (typed right, changed) | 0 | 0 | 0 | 0 |
| Dictus: **miscorrected** | 4 | 4 | 3 | 2 |
| Dictus: missed (typed wrong, kept) | 5 | 3 | **23** | 5 |
| …of which only a missing accent | 5 | 0 | **18** | 0 |
| Dictus: next word in the prediction bar (top 3) | 16.7% | 20.0% | 21.7% | 18.0% |
| Dictus: engine time per letter, p50 / p95 (ms, simulator) | 0.12 / 0.53 | **1.13 / 2.08** | 0.11 / 0.83 | 0.09 / 0.69 |

¹ **Apple's autocorrect does not run on the simulator in French, Spanish or German.**
The iOS 26.5, 27.0 and 27.2 simulator runtimes ship English language data
(`RequiredAssets_en.bundle`, 97 MB) and empty `es`, `de` and `fr` bundles (4 KB each);
typed slowly, `la estacion esta cerca y tegno que ir ` stayed as typed on Apple's
Spanish keyboard. In those three columns Apple's numbers are its **key choice only**:
compare them with the Dictus row "before autocorrect", not with the Dictus final text.
English is the only language where the simulator compares the two keyboards end to end.
On key choice alone, Dictus's plain hit test types fewer wrong keys than Apple's in the
three languages where both can be read (fr 13 against 17, es 25 against 29, de 26
against 33). Apple's Spanish page has ten keys in its second row (`ñ`) where Dictus has
nine, so part of the Spanish difference is key width.

### Realistic typo runs

20 other native sentences per language, typed with the language's frequent real
mistakes and no touch noise (taps on the key centres), so the run measures what
autocorrect does with the mistake alone. Pairs from TOEFL-Spell, COWS-L2H, Tweet-Norm_es
and Wikipedia's typo lists ([`typo-sources.md`](typo-sources.md)).

| | en-typos | es-typos | de-typos |
|---|---:|---:|---:|
| Systematic mistake on every word | no apostrophe (`dont`, `im`) | no accent, no tilde (`esta`, `manana`) | umlaut as `ue` or `u`, `ss` for `ß` |
| Words typed wrong | 37 | 46 | 28 |
| **Dictus: fixed** | 21 | **2** | 22 |
| Dictus: missed | 13 | **42** | 5 |
| Dictus: miscorrected | 3 | 2 | 1 |
| Dictus: wrong words, final text | 16 of 129 | **44 of 119** | 6 of 131 |
| Apple: wrong words, final text | **3** of 129 | ¹ | ¹ |

## The gaps

**Spanish: Dictus restores no accent.** 18 of the 23 Spanish words left wrong in the
touch run, and 42 of 42 accent mistakes in the typo run (`tambien`, `pelicula`,
`telefono`, `manana`, `ninos`, `cafe`...), were committed as typed. The mechanism is
measured:

1. Every one of those unaccented forms is in the shipped Spanish word list
   (`es_frequency.json`, OpenSubtitles counts): `tambien` at rank 1,950, `pelicula`
   8,186, `telefono` 7,711, `manana` 17,358, `ninos` 27,464. They are the misspellings
   of subtitle writers, kept as words.
2. Accent expansion (`AccentExpander.swift`) only overrides an existing word when the
   accented form is more than 5 times as frequent. The raw counts say it is
   (`también` 28× `tambien`, `mañana` 275× `manana`, `niños` 254× `ninos`), but the
   trie stores frequencies log-normalised to 0 to 65,535 (`tools/dict_builder.py`,
   line 218), where 28× becomes about 1.3×. The rule cannot fire.
3. French works because its list does not hold the folded forms (`tres` and `deja` are
   absent, so `inputFreq == 0` and the accented word wins).

On top of that, Spanish real-word accents (`esta`/`está`, `que`/`qué`, `el`/`él`,
`mi`/`mí`, `se`/`sé`, `si`/`sí`, `mas`/`más`) need context, and the Spanish letter page
has no `ñ` key, which Apple's Spanish layout has.

**English: three separate gaps.**

1. *End to end, Apple 0 wrong words, Dictus 9*, on the same taps (#954). Dictus's
   misses are key-proximity choices that a language model would reject (`irving` for
   `morning`, `finish` for `my`, `bone` for `hour`, `meet` for `need`, `hourglass` for
   `hour late`).
2. *The English word list holds classic misspellings*: `teh` (rank 19,420),
   `recieve`, `definately`, `becuase`, `beleive`, `adn`. The typo run committed all six
   as typed, the same mechanism as Spanish. Apostrophe contractions work (`dont`,
   `im`, `didnt`, `youre` were all fixed); the real-word ones do not (`ill` for `I'll`
   four times, `its` for `it's` twice, `were` for `we're`). Apple's keyboard, on the
   same typo run, left **3 wrong words of 129 against Dictus's 16**: it fixed all six
   misspellings and all seven real-word contractions. Its three: `Bering` for `beeing`
   (Dictus wrote the same), `well` for `wll` (Dictus: `all`), and a `to` added at the end
   of one sentence.
3. *Engine time per letter is about ten times the other languages* (p50 1.13 ms against
   0.09 to 0.12), on the same Mac and the same simulator. Not a device number (#591),
   but the ratio is.

**German: close to French.** 7 wrong words of 141, umlaut digraphs fixed (`fuer`,
`schoen`, `koennen`, `spaeter`, `strasse`, `weiss` all corrected). What remains is
context: `hatte`/`hätte`, `wurde`/`würde`, `schon`/`schön`, `das`/`dass` are all real
words and were left alone, and one slip (`udn`) became `in`.

**Prediction.** Dictus offers the next word in its top 3 after 17% to 22% of spaces in
all four languages. There is no Apple figure yet: the simulator replay does not read
Apple's prediction bar. This is the only number behind the US review's "predictive
text kinda weird", and it is not a comparison.

**Real cases** ([`real-cases.md`](real-cases.md)). No user has given an exact word typed
and a wrong word produced in English, Spanish or German. English has one App Store
review (US, 4★, 2026-11-11: no swipe, predictions "kinda weird", haptics, look) and one
GitHub swipe request (#948). Spanish has no typing case of any kind. German has one
general complaint (#109) and the maintainer's own cases. French has about 30 exact
cases, nearly all from the maintainer.

## Proposed order

Titus suggests English first: the largest market and the negative US review. **The
numbers confirm English first, with one change: the first step is shared with
Spanish.**

- *For English first.* English is the only language where the simulator measures
  Dictus against Apple end to end, so every fix gets a before/after against Apple's 0
  on the same taps. It has the only written review that names the keyboard, and the
  largest market. Its gap is real and measured twice against Apple: 9 against 0 wrong
  words on the touch run, 16 against 3 on the typo run. Add misspellings accepted as
  words and a per-letter cost ten times the others.
- *Against, by the numbers alone.* Spanish is the worst language by far (20.6% wrong
  words against 5% to 6% elsewhere, 2 accent fixes out of 46 mistakes). But it has no
  reported case and two ratings without text, and its main cause is the same as one of
  English's: a word list that accepts misspellings, and an accent rule that compares
  log-normalised frequencies.

So:

1. **Word-list hygiene, en and es together** (data). Drop from the shipped lists the
   forms that are misspellings of a far more frequent word: in English the TOEFL and
   Wikipedia pairs (`teh`, `recieve`, `definately`...), in Spanish every unaccented
   form whose accented form is at least 5× as frequent in the raw counts. Or keep them
   and make the accent rule compare raw counts. One change, measured by
   `en-typos` and `es-typos` (Spanish wrong words should fall from 29 towards the
   French level).
2. **English: the language model in the decision** (n-grams, rules). The 9 English
   misses are proximity picks with no context check; the #949 key-target model and the
   n-grams are the levers, measured by `run.sh --langs en` against Apple's 0. Then the
   real-word contractions (`ill`, `its`, `were`) from context, the per-letter engine
   cost, and an Apple reference for the prediction bar (reading it in `sim_replay.py`).
   Swipe typing (#948, the review) is a feature, not autocorrect, and is out of this
   plan.
3. **Spanish: context and the `ñ` key**. Real-word accents (`esta`/`está`,
   `que`/`qué`...) from the n-grams, and the layout question of an `ñ` key on the
   Spanish page. Find one native Spanish typist: today there is no data at all.
4. **German: context only**. `hatte`/`hätte`, `wurde`/`würde`, `schon`/`schön`,
   `das`/`dass` from the n-grams. Check the QWERTZ grid of the replay against the real
   keyboard (never done, unlike French).

French stays the reference and the regression check for each step.

## What each language needs first

| Language | First need | Kind | Measured by |
|---|---|---|---|
| English | Remove misspellings from the word list; context check before a proximity correction | data, then n-grams | `en-typos` against Apple (16 vs 3), `en` against Apple (9 vs 0) |
| Spanish | Accent restoration that can fire: clean list or raw-count rule | data / rule | `es-typos` (today 44 wrong of 119), `es` (29 of 141) |
| German | Real-word umlaut and `dass` from context | n-grams | `de-typos` (today 6 wrong of 131) |
| French | Nothing new; regression check | — | `fr` (9) |

## Limits

- **The touch model is chosen, not measured** (protocol, "Limits"). Numbers compare
  keyboards and commits on the same runs, not with typing studies.
- **Apple outside English is key choice only** on the simulator (footnote ¹). A device
  run is the only way to get Apple's Spanish and German autocorrect.
- **Apple's layouts differ.** Its Spanish page has a tenth key in the second row (`ñ`)
  and its German page the umlauts; the run places each tap on the intended key by key
  units, so narrower keys mean more wrong keys for the same offsets.
- **Not checked against the real keyboard for es and de.** The French replay matched
  the real Dictus keyboard 20 of 20 sentences (#954); the QWERTY Spanish page is the
  English page, the QWERTZ grid (11-key rows) was never compared.
- **Case is ignored by the scorer**, so German lowercased nouns, the largest German
  category in tweets, are not measured.
- **Apple German, sentence 0** typed nothing on the first pass, right after the
  simulator booted; it was retyped alone with `sim_replay.py --start 0 --end 1`.
- **Prediction is scored for Dictus only.**
- Simulator timings compare runs on one Mac; they are not device timings.
