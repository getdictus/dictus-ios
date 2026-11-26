# Swipe decoder bench (#948)

Measures DictusCore's `SwipeDecoder` (swipe typing, ported from Hex) on synthetic swipes,
for English, French and Spanish, with four kinds of finger. Measurement only: nothing in the
keyboard calls the decoder yet (the gesture is PR B, the setting PR C).

```bash
tools/swipe-bench/run.sh                                   # the table below, about 2 min on an M1 Pro
tools/swipe-bench/run.sh --memory --langs fr --styles typical
```

It runs on the Mac, with no simulator: the decoder is in DictusCore and needs nothing from
UIKit. `run.sh` builds in release; a debug build decodes about fifty times slower.

## What it does

For every word of the held-out sentences (`sentences/<lang>-test.tsv`), it draws a swipe
through the word's keys as a finger would, reads it with `SwipeDecoder` as it ships (Hex's
parameters, unchanged), with the true word before as context, and scores it the way Hex
scores its own (`android/benchmark/typing/README.md` in Hex, "Swipe typing"):

- **First word right:** the decoder's first reading is the word.
- **Top 4:** the word is among its first four readings, the one the keyboard would type and
  the three the bar would offer.
- **Decode:** the time of one `SwipeDecoder.read`, the call the keyboard makes when the
  finger lifts: median and 95th percentile.

Words of one key ("a", "à", "y") are tapped, not swiped, and are left out. So are the words
the decoder cannot read at all (counted below the table): words the model lacks ("tom",
"mary", French `l'` and `d'` forms) and, in French, words with œ or æ, which have no key.
English reads Dictus's own contractions (`englishProfile`) as extra words, at Hex's cost
of a common contraction, since Google Books splits "don't" and the model barely has it.

| File | What it is |
|---|---|
| `sentences/<lang>-test.tsv`, `-dev.tsv` | 2,000 test and 500 dev sentences per language from [Tatoeba](https://tatoeba.org) (CC BY 2.0 FR; each row has its sentence id and author), written by self-declared native speakers. en and fr from the exports of 2026-11-21, es (`spa`) from the export of 2026-11-25. The bench reports on the test split; nothing is tuned on it or on the dev split, which is there for whoever tunes the decoder later. |
| `make_sentences.py` | Picks them from the Tatoeba exports, deterministically. Its header says how. |
| `Sources/swipe-bench/SwipePaths.swift` | The path generator, ported from Hex's `swipe_paths.py` (MIT): via points around each key, rounded corners, an overshoot or a stop short, a wobble, minimum-jerk timing at 120 Hz. Hex's four presets are the four styles: `clean` (Hex's `none`: through the centres, unrounded, even speed), `neat`, `typical`, `sloppy`. Same random numbers in the same order as Hex's, seed 1. |
| `Sources/swipe-bench/LetterPage.swift` | Dictus's letter page: QWERTY for en and es (no ñ key: ñ is held on n, and swiped through it), AZERTY for fr, an iPhone 17 held upright (402 x 216 pt), laid out by `KeyPlaneGeometry`. The finger aims at the keycaps; the decoder gets the keys as #1011's `spatialKeys` reads them (`--keys` for the alternatives). |
| `Sources/swipe-bench/main.swift` | The runs, the scoring, the memory mode and the cross-check against Hex's own paths. |

## Results (2026-11-24, develop fda23bcb + this branch, M1 Pro)

| Language | Style | Words swiped | First word right | Top 4 | Decode, median / p95 |
|---|---|---:|---:|---:|---:|
| en | clean | 12,735 | 98.7% | 100.0% | 0.74 / 2.01 ms |
| en | neat | 12,735 | 98.4% | 99.9% | 0.76 / 2.05 ms |
| en | typical | 12,735 | 96.3% | 99.6% | 0.75 / 2.04 ms |
| en | sloppy | 12,735 | 80.9% | 91.6% | 0.74 / 2.00 ms |
| fr | clean | 12,543 | 97.4% | 99.9% | 0.75 / 2.61 ms |
| fr | neat | 12,543 | 97.1% | 99.8% | 0.70 / 2.57 ms |
| fr | typical | 12,543 | 95.5% | 99.3% | 0.68 / 2.53 ms |
| fr | sloppy | 12,543 | 82.6% | 92.2% | 0.65 / 2.44 ms |
| es | clean | 12,163 | 96.3% | 100.0% | 0.65 / 2.63 ms |
| es | neat | 12,163 | 95.9% | 100.0% | 0.62 / 2.58 ms |
| es | typical | 12,163 | 93.9% | 99.4% | 0.62 / 2.59 ms |
| es | sloppy | 12,163 | 82.0% | 92.7% | 0.61 / 2.42 ms |

Spanish added 2026-11-25 (develop aaa7c06d + feature/swipe-es, M1), with Hex's `es.hextm`
unmodified (`DictusKeyboard/Resources/README.md`); en and fr rerun the same day, unchanged
to the tenth. Of the 13,175 Spanish words, 458 are one key and 554 can't be read. Typical
fingers:

- **Words with ñ: 94.2% first, 99.3% in the top 4** (137 words), swiped through n. The
  misses are pairs on one path whose plain spelling is a word too ("uñas" read "una",
  "moño" "mono", "sueña" "suena"): Hex's layout has an ñ key and does not meet them.
- **Words with an accented vowel: 74.4% first, 98.9% top 4** (1,573). Nearly all the misses
  are Spanish's accent pairs, one path and both words common: "él"/"el" (79), "está"/"esta"
  (53), "qué"/"que" (52), "quién", "cómo", "dónde", "cuál", "tú". The sentences drop ¿ and
  ¡ (`make_sentences.py`), and after either the decoder has no word before anyway, so a
  question's "qué" is read cold.
- **Against Hex:** Hex publishes 94.3% / 99.4% for Spanish, typical fingers, on its own
  held-out sentences and a layout with an ñ key (`android/benchmark/typing/README.md`,
  2026-11-23); 93.9% / 99.4% here, on Dictus's sentences and a layout without one.

Of the 14,131 English words, 752 are one key and 644 can't be read; of the 13,567 French
ones, 447 and 577. The times are the Mac's, one core, with other work on the machine: an
iPhone's will differ, and PR B must time it there.

### Against Hex's published numbers

Hex publishes, for typical fingers on its own held-out Tatoeba sentences: **97.1%** first
word right in English on the iPhone (`ios/docs/keyboard.md`, with the iPhone generator) and
96.9% / 99.6% with the shared Python generator, and **95.2% / 99.3%** in French on Android
(`android/benchmark/typing/README.md`, the same on the iPhone); neat English 99.0% / 99.9%,
sloppy 82.0% / 92.2%.

To tell the port from everything else, the bench also reads Hex's own paths
(`--hex-paths`, the output of Hex's `swipe_paths.py` on Hex's held-out sentences, gunzipped;
run locally, nothing of it committed). Typical fingers, first word right / top 4:

| | English | French |
|---|---:|---:|
| Hex, published (same paths) | 96.9% / 99.6% (12,514 words) | 95.2% / 99.3% (12,666) |
| This port, Hex's current model | 96.6% / 99.7% (12,510) | 95.1% / 99.2% (12,666) |
| This port, Dictus's model | 96.4% / 99.6% (12,501) | 95.1% / 99.3% (12,549) |
| This port, Dictus's model, our sentences | 96.3% / 99.6% (12,735) | 95.5% / 99.3% (12,543) |

So:

- **The port reads as Hex does.** On Hex's paths and Hex's French model it swipes exactly
  Hex's 12,666 words and lands 0.1 point under Hex. That 0.1 is Hex's never-suggest list
  (Hex data, not copied) and the rare-name ranking Hex's keyboard adds on top of the decoder.
- **English, 0.5 point under Hex**, in two parts. 0.3 point is the contraction list: Dictus's
  (`englishProfile`, 38 forms) has no "won't", "let's", "we'll", "we'd" or "he'd", which
  Hex's has, and Hex prices its ten commonest ("it's", "I'm") 1.5 nats lower; of the 455
  misses on Hex's paths, 111 are contractions ("it's" read "its" 31 times, "won't" read
  "wont" 18). No Hex word list is copied, so closing it means growing Dictus's own list
  (PR B). The other 0.2 point is the model: `en.hextm` is the copy #1013 took of Hex's,
  which Hex has rebuilt since (86,247 words against our 86,133).
- **French, 0.1 point under Hex on Hex's sentences, 0.3 over on ours.** Our `fr.hextm` is
  Dictus's own and reads as well as Hex's on the words both know. It knows fewer of Hex's
  test words: 608 unreadable against 491, mostly "tom" (138 times: Tatoeba's Tom) and
  `l'` and `d'` forms.
- **The key geometry doesn't matter here:** reading the keys at their keycaps (as Hex's
  keyboard does, `--keys caps`) or with the pitch `GiellaKeyboardView.spatialKeys()` computes
  (`--keys keyboard`, whose unit is the first letter's touch target, 43 pt on a 39.5 pt key)
  moves the typical numbers by 0.2 point at most, the sloppy ones by 0.6.

### What a swipe cannot read yet

- **French elisions.** Google Books splits `l'` and `d'` off their word, so `fr.hextm` has no
  "l'école" or "d'être" (`tools/typing-model/README.md`). On Hex's French test sentences 267
  words are `l'` or `d'` plus a word the model knows: a single swipe can't produce them.
  Typing `l'` and swiping the word works; reading the clitic from the swipe is for PR B.
  Other elisions are whole in the model and swipe as one word, the apostrophe for free
  ("aujourd'hui", "j'ai", "qu'il").
- **Same path, accent apart.** "où" and "ou", "là" and "la" draw one path: only the word
  before tells them apart. They are the commonest French misses (23 and 18 on Hex's paths).
- **Very short swipes.** A two-letter word whose keys touch ("de": d under e on AZERTY) can
  draw a path shorter than the 0.6 key the decoder reads as a swipe, and reads as nothing.
  On the keyboard such a stroke would be taken as a tap anyway.
- **œ and æ** have no key, so "cœur" can't be swiped (as in Hex).

## Memory

`--memory` swipes one language and style in a fresh process, each path drawn, read and
dropped before the next, and reports the process's footprint (what jetsam counts against
the keyboard extension) and the live heap.

| | en typical | fr typical | es typical (2026-11-25) |
|---|---:|---:|---:|
| Model, mapped read-only | 3.43 MB | 3.43 MB | 3.43 MB |
| Footprint, model loaded | 2.69 MB | 2.64 MB | 1.81 MB |
| Peak footprint during 12,500 swipes | 6.80 MB | 8.83 MB | 2.39 MB (12,163) |
| Most words scored by one swipe | 13,412 | 26,036 | 20,843 |
| Live heap kept after all the swipes | 0 | 0 | 0 |

- **Nothing is kept between swipes.** `read` is a non-mutating method of a struct whose only
  reference is the immutable model, so it cannot store anything; the live heap after
  12,500 swipes is what it was before (the 128 KB difference is the bench's own tally).
- **A swipe needs up to about 4 to 6 MB while it decodes**: the candidate words that start
  near the finger and pass the key filters, up to 26,000 for a long French swipe, each with
  its keys, length and costs, plus the sort. It is freed when `read` returns, but the
  allocator keeps the pages for reuse, so the footprint stays at its peak. That peak follows
  the largest swipe, not the number of swipes: French, typical, 4.0 MB above the loaded
  footprint after 630 swipes, 4.9 MB after 3,128, 5.3 to 6.2 MB after 12,543 (two runs).
- **The model's pages are clean.** Beyond the footprint's growth, swiping makes another
  2.7 MB (en) and 3.7 MB (fr) resident: the model's file-backed pages, about all of its
  3.43 MB in French. They do not count toward the footprint, and iOS can drop them under
  pressure.

For the keyboard's ~50 MB, that is up to about 6 MB more at the moment of a swipe, against a
budget the keyboard already shares with the spatial decoder's model (#1011) and the
dictation path. Not at risk on these numbers, but PR B should read the real footprint on a
device while swiping (Xcode's memory gauge).

## Licences

- `SwipePaths.swift` is Hex code (MIT, Copyright (c) 2026 Christopher Langton), ported
  from `android/benchmark/typing/swipe_paths.py` at anomalyco/hex@b3a95517; the full notice
  is at its top. `main.swift`, `LetterPage.swift` and `make_sentences.py` are Dictus's.
- The sentences are Tatoeba's (https://tatoeba.org), CC BY 2.0 FR
  (https://creativecommons.org/licenses/by/2.0/fr/), credited per row (id and author), in
  English, French and Spanish.
- No Hex data is in this folder: not its models, word lists, held-out sentences or paths.
  (The Spanish model the bench reads, `es.hextm`, is Hex's, but it lives in the keyboard's
  resources with its own README and licence, not here.)
  The cross-check above reads them from a local clone of Hex.
