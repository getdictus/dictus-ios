# `de.hextm` and `de.capitals`: Dictus's German keyboard model

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

## Licences

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
