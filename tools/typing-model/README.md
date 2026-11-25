# Spatial decoder models (#1011)

The `.hextm` files in `DictusKeyboard/Resources/` are what the spatial and swipe decoders
(`DictusCore/Sources/DictusCore/SpatialDecoder/`) read: a word list with each word's
frequency and the word pairs that tell the most over it, memory-mapped read-only. The
format is Hex's "HXTM" v3 ([github.com/anomalyco/hex](https://github.com/anomalyco/hex),
MIT), described at the top of `build-typing-model.py`.

| File | Words | Pairs | Size | SHA-256 | Built from |
|---|---:|---:|---:|---|---|
| `en.hextm` | 90,000 | budget-bound | 3.60 MB | `14370569c747a7ef…` | Hex's own file, byte-identical (`ios/HEXKeyboard/TypingModel/en.hextm`) |
| `fr.hextm` | 110,000 | 322,885 of 1,336,964 useful | 3.60 MB | `62d0cb3b6a9c6e12…` | this script, 2026-11-21 |
| `de.hextm` | 95,000 | 356,665 of 1,784,994 useful | 3.60 MB | `564c1b05c62dc26f…` | this script, 2026-11-25 (#948) |

German also ships `de.capitals` (738,275 bytes, SHA-256 `16c5c71b3cb4c386…`), the share of
each word's uses written with a capital, built by `build-german-capitals.py` from the
same shards: the model is lowercase, and German writes its nouns with a capital.

## Sources and licences

- **Google Books Ngram Viewer, version 3 (2020-02-17)**, by Google, under
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/): word and word-pair counts,
  summed over 1980-2019. Attribution is required; it is in the app's Licences screen.
- **German word list:** "German wordlist" by Markus Enzenberger and contributors
  ([github.com/enz/german-wordlist](https://github.com/enz/german-wordlist), commit
  `1071d87d9535b57b80ec076c699f2578a28ee9dc`, file `words`, 685,829 entries, SHA-256
  `20095928ca70974fb5d86e44f10181cee16e2831b0d4b1a4ddd12c261aebc5e9`), dedicated to the
  public domain under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). It asks
  for nothing; the Licences screen credits it anyway. It writes each word as German does
  ("Haus", "gehen"), which `build-german-capitals.py` reads, and follows the reformed
  spelling ("dass", not "daß") and Scrabble's rules: no names, no abbreviations, nothing
  over 25 letters.
- **English word list:** SCOWL and VarCon, sizes up to 70, by Kevin Atkinson. Its notice
  asks to travel with the output, and does, in the Licences screen.
- **French word list:** Grammalecte's "Classique" French dictionary, version 7.7, as
  LibreOffice ships it (`fr_FR/dictionaries/fr.dic` and `fr.aff`), under the
  [MPL 2.0](https://mozilla.org/MPL/2.0/). It only filters which Google Books words are
  kept; the model holds none of its affix rules, but it does hold word forms the
  dictionary generates. Read conservatively, that makes `fr.hextm` a file derived from
  MPL-covered material, so `fr.hextm` itself is offered under the MPL 2.0, as Hex does
  for its Spanish model (RLA-ES, MPL 1.1). The MPL is file-level: the rest of Dictus stays
  MIT (MPL §3.3, Larger Work), and it allows App Store distribution. What it asks, and what
  the Licences screen gives: the notice, the licence, and where the source form of the
  dictionary is (<https://github.com/LibreOffice/dictionaries/tree/master/fr_FR>).
  Plus the elided clitics `c' d' j' l' m' n' s' t' qu' jusqu' lorsqu' puisqu' quoiqu'`,
  which Hunspell does not list on their own.

## What Google Books does with French elisions

Google Books v3 keeps most elisions whole (`j'ai`, `c'est`, `qu'il`, `aujourd'hui`: 7,088
such forms in the French vocabulary) and splits off only `l'` and `d'` (`l'` + `homme`).
`SpatialCorrection` reads a word the same way: after `l'` or `d'`, what follows, with the
clitic as the previous word; anything else whole, its apostrophes left out of the taps.

## German (#948)

Hex ships a German model too, but Dictus builds its own: Hex keeps every alphabetic token
of the German corpus (no word list), and gives ß no key, where Dictus has none to give it.
The recipe is otherwise Hex's (`android/benchmark/typing/build-layout-model.py`): all 8
one-gram and 181 two-gram German shards, letters a–z ä ö ü ß, the 95,000 commonest words
the list knows. ß gets the base letter s (`BASE_LETTER`), so a swipe through s reads it;
ä ö ü get a o u as their bases, read on QWERTY and AZERTY, while QWERTZ has keys for them.

Inputs, all fetched by the scripts:

- the 189 shards, 153.1 GB, each listed with its SHA-256 and size in
  [`de-inputs.sha256`](de-inputs.sha256) (hashed by `build-typing-model.py` before each is
  deleted);
- the word list above, checked against its SHA-256 by the script.

```bash
W=/tmp/swipe-de/work    # outside the repository; ~5 GB at a time
WORKERS=4 python3 -I tools/typing-model/build-typing-model.py de $W DictusKeyboard/Resources/de.hextm
curl -sSfL -o /tmp/swipe-de/words \
  https://raw.githubusercontent.com/enz/german-wordlist/1071d87d9535b57b80ec076c699f2578a28ee9dc/words
python3 -I tools/typing-model/build-german-capitals.py DictusKeyboard/Resources/de.hextm \
  /tmp/swipe-de/words /tmp/swipe-de/caps DictusKeyboard/Resources/de.capitals
```

Measured 2026-11-25 on the shared M1, 4 workers: 1 h 35 min for the model (3.1 GB of memory
at the peak), about 5 min for the capitals (the 8 one-gram shards streamed again, never
stored). The builder that ran had SHA-256 `b9b1e2642ad7b9c9…`, the committed file.

What the capitals script printed: of the 95,000 words, 44,921 the list has only with a
capital (written at 100), 43,191 only in lowercase (left out, never capitalised), and 6,888
both ways, decided by the books' share and Hex's caps: 48,481 lines, 46,703 at 95% or more
(a noun wherever it stands), 1,778 at 50–94% (a noun after an article or determiner), 91
moved down to 94% as also a verb form or stem ("frage", "kauf", "spiel"). Python 3.13.2.

## Rebuilding

```bash
python3 -m venv /tmp/venv && /tmp/venv/bin/pip install spylls
/tmp/venv/bin/python -I tools/typing-model/build-typing-model.py fr <workdir> DictusKeyboard/Resources/fr.hextm
```

`<workdir>` outside the repository. French downloads about 95 GB of Google Books shards
(6 one-gram, 115 two-gram files); each is deleted once counted, so the disk never holds
more than one per worker (about 1 GB each). Measured on an M1 with 5 workers
(`WORKERS=5`): 1 h 35 min, bound by the download, and 1.6 GB of memory at the peak. Every
stage is cached in `<workdir>`, so a rerun resumes. The output is deterministic for the
same inputs.
