# `es.hextm`: Hex's Spanish keyboard model, unmodified

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

## Licences

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
