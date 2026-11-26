# Spatial decoder models (#1011)

The three `.hextm` files in `DictusKeyboard/Resources/` are what the spatial and swipe
decoders (`DictusCore/Sources/DictusCore/SpatialDecoder/`) read: a word list with each word's
frequency and the word pairs that tell the most over it, memory-mapped read-only. The
format is Hex's "HXTM" v3 ([github.com/anomalyco/hex](https://github.com/anomalyco/hex),
MIT), described at the top of `build-typing-model.py`.

| File | Words | Pairs | Size | SHA-256 | Built from |
|---|---:|---:|---:|---|---|
| `en.hextm` | 90,000 | budget-bound | 3.60 MB | `14370569c747a7ef…` | Hex's own file, byte-identical (`ios/HEXKeyboard/TypingModel/en.hextm`) |
| `fr.hextm` | 110,000 | 322,885 of 1,336,964 useful | 3.60 MB | `62d0cb3b6a9c6e12…` | this script, 2026-11-21 |
| `es.hextm` | 110,000 | 326,366 | 3.60 MB | `02ffcac185eb832d…` | Hex's own file, byte-identical (`ios/HEXKeyboard/TypingModel/es.hextm` at anomalyco/hex@c14df5a4), not rebuilt here: see `DictusKeyboard/Resources/README.md` |

## Sources and licences

- **Google Books Ngram Viewer, version 3 (2020-02-17)**, by Google, under
  [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/): word and word-pair counts,
  summed over 1980-2019. Attribution is required; it is in the app's Licences screen.
- **Spanish word list (Hex's, for `es.hextm`):** the RLA-ES Hunspell dictionaries (es_ES and
  es_MX), coordinated by Santiago Bosio, under the [MPL 1.1](https://www.mozilla.org/MPL/1.1/),
  as Hex credits them. `es.hextm` is offered under the MPL 1.1 likewise; its notice and
  the dictionaries' source location are in the Licences screen.
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
