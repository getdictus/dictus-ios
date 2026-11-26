# Keyboard models: `es.hextm`, `de.hextm` and `de.capitals`

The Spanish model is Hex's file, unmodified (#1074); the German model and its capitals
table are Dictus's own (#1075). How `fr.hextm` and `en.hextm` were made is in
`tools/typing-model/README.md`.

## `es.hextm`: Hex's Spanish keyboard model, unmodified

`es.hextm` is the Spanish word model the keyboard's swipe typing (#948) and spatial
autocorrect (#1011) read: 110,000 Spanish words with their frequencies and 326,366 word
pairs, in Hex's "HXTM" v3 format, memory-mapped read-only. It is a copy of
[Hex](https://github.com/anomalyco/hex)'s file, **byte for byte, unmodified**.

| | |
|---|---|
| Source | <https://github.com/anomalyco/hex/blob/dea95c0f8c07e8d975d726d752af560a7f4accae/ios/HEXKeyboard/TypingModel/es.hextm> |
| Hex commit that added it, last to change it | `c14df5a4f0f33769af5e878fba227c9e2842004a` (2026-11-20, "iOS: spatial autocorrect experiment with Google Books models, plus accent and two-letter fixes (#2059)") |
| Hex `dev` when copied | `dea95c0f8c07e8d975d726d752af560a7f4accae` (2026-11-25) |
| Size | 3,599,993 bytes |
| SHA-256 | `02ffcac185eb832d766b300a7454ba069d0b26251469ea7cdc6eda36926ad5ad` |
| Letters | a–z, á é í ó ú ü ñ; each accented letter's base key is its plain letter (ñ on n) |

### Licences

- **The data is under the Mozilla Public License 1.1** (<https://www.mozilla.org/MPL/1.1/>).
  Hex's credits (`android/app/src/main/assets/licenses/credits.txt` at the commit above)
  say: "Spanish spellings: RLA-ES Hunspell dictionaries (es_ES and es_MX), coordinated by
  Santiago Bosio, used under Mozilla Public License 1.1. The frequency model filters by
  these spellings; the original dictionaries are unmodified." The source form of those
  dictionaries: <https://github.com/LibreOffice/dictionaries/tree/762abe74008b94b2ff06db6f4024b59a8254c467/es>.
  RLA-ES offers them under GPL 3+, LGPL 3+ or MPL 1.1, at the user's choice; Hex, and
  Dictus after it, take the MPL 1.1. The MPL is file-level: this file is under it, the rest
  of Dictus stays MIT (a Larger Work, MPL 1.1 §3.7), as for `fr.hextm` under the MPL 2.0.
- **The word and pair counts** come from the Google Books Ngram Viewer, version 3
  (2020-02-17), by Google, under [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/),
  summed over 1980–2019 (same credits file).
- **Hex**, whose script built the file and whose decoder Dictus ports, is MIT, Copyright (c)
  2026 Christopher Langton.

All three are credited in the app, Réglages › Licences (`DictusApp/Views/LicensesView.swift`).
How `fr.hextm` and `en.hextm` were made is in `tools/typing-model/README.md`.

## `de.hextm` and `de.capitals`: Dictus's German keyboard model

`de.hextm` is the German word model the keyboard's swipe typing (#948) and spatial
autocorrect (#1011) read: 95,000 German words with their frequencies and 356,665 word
pairs, in Hex's "HXTM" v3 format, memory-mapped read-only. Unlike `en.hextm` (Hex's) it is
Dictus's own, built by `tools/typing-model/build-typing-model.py`; `de.capitals` beside it
says which of those words are nouns, since the model is lowercase.

| | `de.hextm` | `de.capitals` |
|---|---|---|
| Built | 2026-11-25, `build-typing-model.py de` | 2026-11-25, `build-german-capitals.py` |
| Size | 3,599,995 bytes | 738,275 bytes |
| SHA-256 | `564c1b05c62dc26f925b85a1682126bb57cc18128bab50a6c06c78b1d4e92545` | `16c5c71b3cb4c3861c682bbd32016d7fb051bedb5f537dc7f531d5be75341ede` |
| Holds | 95,000 words, 356,665 pairs, 30 letters (a–z ä ö ü ß) | 48,481 lines `word<TAB>percent` (50–100) |

- **Letters.** ä ö ü have a o u as their base keys and ß has s: QWERTZ swipes the umlauts
  through their own keys, QWERTY and AZERTY through a o u, and every layout swipes ß
  through s (no Dictus layout has an ß key; it is held on s).
- **Capitals.** `GermanCapitals` (DictusCore) writes a swiped word with a capital at 95 or
  more ("Haus", "Straße"), and from 50 only after an article or a determiner ("das Leben",
  but "zu leben"). A word the table leaves out ("gehen", "groß") stays lowercase.

How both were built, from which inputs (each shard's SHA-256), and what the build printed:
`tools/typing-model/README.md`, section "German".

### Licences

- **Word list:** "German wordlist" by Markus Enzenberger and contributors
  (<https://github.com/enz/german-wordlist>, commit `1071d87d`), dedicated to the public
  domain under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). The
  model keeps only its words, and the capitals table reads how it writes them.
- **Counts:** Google Books Ngram Viewer, version 3 (2020-02-17), by Google, under
  [CC BY 3.0 Unported](https://creativecommons.org/licenses/by/3.0/). Changes: counts summed
  over 1980–2019, lowercased, filtered by the list above, the share of capitalised use
  computed per word, probabilities quantized.
- **Hex** (MIT, Copyright (c) 2026 Christopher Langton): the format, the builder Dictus
  adapted, the German recipe it mirrors, and the capitals rules and reader Dictus ported.

All three are credited in the app, Réglages › Licences (`DictusApp/Views/LicensesView.swift`).
