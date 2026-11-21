# Misspellings removed from the keyboard word lists (#995)

The keyboard treats every word of `DictusKeyboard/Resources/<lang>_frequency.json` as
correct and never corrects it. The English list comes from web counts (Norvig's
`count_1w.txt`), so it held `teh`, `recieve`, `definately`, `becuase`, `beleive` and
`adn`, and the keyboard left them as typed. This folder removes the misspellings a
public list names, and records each removal.

| File | What it is |
|---|---|
| `removed-en.tsv`, `removed-es.tsv` | Every removed word: the misspelling, its correct form (the target, which stays in the list), both raw counts, and the source. |
| `prune_misspellings.py` | Selects the removals, rewrites `<lang>_frequency.json` without them, and adds them to `removed-<lang>.tsv`. |
| `apple_spellcheck.swift` | Prints the words the macOS spelling checker flags. The script uses it to keep real words. |

## The rule

A word `W` of the word list is removed when all of these hold:

1. The source list names `W` as a misspelling (English: `W->correction`; Spanish:
   `W||correction`, entries marked `cs` skipped, since they apply to one
   capitalisation only).
2. None of the listed corrections is `W` itself, `W` with accents added, or a phrase.
   The source lists `W` among its corrections when `W` is often right. An accent-only
   pair is the accent rule's case (#994). A phrase (`aver` → `a ver`) leaves the
   target in doubt.
3. The target is the first listed correction that is at least 3 letters long, is in
   the word list, is more frequent than `W` in the list's raw counts, and is within 2
   edits of `W` (an adjacent swap counts as one edit).
4. The macOS spelling checker flags `W` in the language, both lowercase and
   capitalized. For Spanish, the English checker must flag it too: the Spanish source
   also lists loanwords and foreign names (`garage`, `kenya`), which are not typos.
   This is what keeps `thru`, `loosing`, `lsat`, `holliday`, `strat`, `ke`, `zombie`.

The target stays in the list, so the trie corrects `W` towards it.

Result: 56 English words removed (62 named, 6 kept as real words) and 16 Spanish words
(53 named, 37 kept). Each run prints the kept ones.

## Sources and licences

| Language | Source | Revision | sha256 of the raw page | Licence |
|---|---|---|---|---|
| en | [Wikipedia:Lists of common misspellings/For machines](https://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines) | [1199637275](https://en.wikipedia.org/w/index.php?oldid=1199637275) (2024-01-27) | `3b6a9290…3a3050` | CC BY-SA 4.0 |
| es | [Wikipedia:Corrector ortográfico/Listado](https://es.wikipedia.org/wiki/Wikipedia:Corrector_ortogr%C3%A1fico/Listado) | [176376567](https://es.wikipedia.org/w/index.php?oldid=176376567) (2026-11-19) | `46f237ad…2bcf39` | CC BY-SA 4.0 |

Wikipedia text is published under the
[Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
licence, which allows reuse, commercial reuse included, with attribution and under the
same licence. The two `removed-<lang>.tsv` files hold pairs taken from those pages, so
they are distributed under CC BY-SA 4.0, with attribution to the Wikipedia
contributors of the pages above. The shipped word lists only lose entries: they
contain no text from these pages.

**The Birkbeck spelling error corpus is not used.** Roger Mitton's
[download page](https://www.dcs.bbk.ac.uk/~ROGER/corpora.html) states no licence and
points to the Oxford Text Archive, whose user agreement requires a licence from the
rights holder for commercial use. Dictus sells a subscription, and no licence for
the corpus could be confirmed (checked 2026-11-20), so it stays out until one is.

## Run

The pages are downloaded data: fetch them into a folder of their own and run the
interpreter isolated. The script checks the sha256 above before it reads anything.

```bash
curl -sS -o /tmp/misspellings/en.raw "https://en.wikipedia.org/w/index.php?oldid=1199637275&action=raw"
curl -sS -o /tmp/misspellings/es.raw "https://es.wikipedia.org/w/index.php?oldid=176376567&action=raw"
python3 -I tools/misspellings/prune_misspellings.py --lang en --source /tmp/misspellings/en.raw --resources DictusKeyboard/Resources
python3 -I tools/misspellings/prune_misspellings.py --lang es --source /tmp/misspellings/es.raw --resources DictusKeyboard/Resources
python3 tools/dict_builder.py DictusKeyboard/Resources/en_frequency.json DictusKeyboard/Resources/en_spellcheck.dict
python3 tools/dict_builder.py DictusKeyboard/Resources/es_frequency.json DictusKeyboard/Resources/es_spellcheck.dict
```

A word in `removed-<lang>.tsv` is removed on every run, so rerunning on the pruned
lists changes nothing. A list rebuilt from its corpus (`scripts/curate_en_dictionary.py`)
must go through this script again before its trie is built.

The spelling checker's verdicts depend on the macOS version and on words a user taught
it, so a rerun on another Mac can select a different set. The committed TSV is the
reference.
