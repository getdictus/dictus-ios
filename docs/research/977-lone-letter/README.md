# A French lone letter (#977): measured

Device report, 2026-11-19 (iPhone 15 Pro Max, French): `vas avoir des problème z` kept
the `z`, logged `AUTOCORRECT-SKIP word="z" reason=already-valid`. Every letter but `h`,
`p` and `r` is in the French dictionary, so the valid-word guard of `spellCheck` kept it.

The fix is `LoneLetterCorrection` (DictusCore), asked by `SupplementaryLexicon.earlyAnswer`
after a shortcut or a name the dictionary lacks and before the context rules (see the
device test below; the first version asked it in `TextPredictionEngine.checkWord`). In French only `a`, `à` and
`y` stand alone (`LanguageProfile.loneLetterWords`); any other lone letter becomes the
one of them on a neighbouring key of the layout in use, then goes through the `a`/`à`
rule of #501. A letter with no such neighbour, a capital, a letter after an apostrophe,
a letter after a word that names it as a letter (a determiner or `lettre`,
`LanguageProfile.loneLetterMarkers`) and a learned letter are kept. The other languages have no list, so nothing changes
there.

Measured 2026-11-24 with the keyboard bench (#954), iPhone 17 simulator, iOS 26.5,
Xcode 27.2: `before.md` is develop at `fb68bbf5` with this PR's register rows,
`after.md` the branch.

## Bench (#954): fr, en, en-typos

| | before | after |
|---|---:|---:|
| fr: wrong words in the final text | 2 of 152 | 2 of 152 |
| fr: broken / miscorrected / missed | 0 / 0 / 2 | 0 / 0 / 2 |
| en: wrong words in the final text | 8 of 157 | 8 of 157 |
| en: broken / miscorrected / missed | 0 / 1 / 3 | 0 / 1 / 3 |
| en-typos: wrong words in the final text | 1 of 129 | 1 of 129 |
| en-typos: broken / miscorrected / missed | 0 / 1 / 0 | 0 / 1 / 0 |
| Register (#500) | 24 of 33 | **26 of 33** |

`commits.tsv` and `texts.tsv` are identical before and after, and so is every column of
`taps.tsv` but the timings: all 2228 taps resolve to the same key, all words commit the
same. The corpora hold no lone letter other than `a`, `à` and `y`. The register moves on
two of the four rows this PR adds:

| before | typed | develop | branch |
|---|---|---|---|
| vas avoir des problème | z | z | **a** |
| on passe au plan | B | B | B |
| le mot commence par | l'h | l'y | **l'h** |
| la lettre | b | b | b |

## Every lone letter, before and after

The same replay on a register of every letter after `vas avoir des problème`, plus a few
contexts (not committed). Only these change:

| typed | develop | branch | why |
|---|---|---|---|
| `z`, `q` | kept | `a` | next to `a` |
| `t`, `u`, `g` | kept | `y` | next to `y` |
| `p`, `r` | `à` | kept | not in the dictionary, so the trie picked `à`; no key next to them is a word |
| `je vais z`, `je pense z` | `z` | `à` | `a`, then the #501 rule |
| `il t` | `t` | `y` | next to `y` (`il y a`) |
| `il q` | `q` | `a` | next to `a`; #501 keeps `a` after `il` |
| `l'h` | `l'y` | `l'h` | a letter after an apostrophe is kept |

Unchanged: `a`, `y`; `h` (`y` before and after: develop reached it through the trie);
`b c d e f i j k l m n o s v w x`, which have no neighbour that is a word; `B` after
`plan`, `Z` alone and after `la lettre`; `l'z`.

## On the simulator, typed key by key

Rappels title, iPhone 17, iOS 26.5, every key tapped with `axe` (Dictus through
`verify-dictus-ios`'s `drive.sh`), the same sentence on the three keyboards:

| keyboard | field after the last space |
|---|---|
| Apple, French AZERTY | `Vas avoir des probleme z je vais z paris il t a la lettre b plan B` (`l'h` not typed: the apostrophe is on Apple's `123` page) |
| Dictus develop `fb68bbf5` | `Vas avoir des problème z je vais z paris il t à la lettre b plan B le mot commence par l'y` |
| Dictus branch | `Vas avoir des problème a je vais à paris il y a la lettre b plan B le mot commence par l'h` |

On develop the kept `t` also costs the next word: `t a` reads as a noun before `a`, and
the #501 rule writes `à`. The branch log carries `TJ WORD ... typed="z" ... final="a"
outcome=autocorrected by=space branch=lone-letter`.

## Apple

Apple's French autocorrect does not run on the simulator (`docs/keyboard-measurement.md`,
Limits): typed key by key on Apple's AZERTY, `vas avoir des probleme z je vais z paris il
t a la lettre b plan B ` stayed exactly as typed, `probleme` included. What Apple's
keyboard does with a lone `z` needs a device.

## A letter named as a letter (review of #1061)

The first version corrected a lowercase letter meant as a letter when it sat next to `a`
or `y`: `le h aspiré` became `le y aspiré` (develop also writes a lone `h` as `y`,
through the trie, the `h` being missing from the dictionary: measured after `problème`),
`un z` became `un a`. A letter is now kept when the word
right before it is one of `le la l' un une du des de d' ce cet cette chaque lettre
lettres`: none of them can come before `a`, `à` or `y`. `les` is left out, being also
the pronoun of `il les a vus`, so `il les z` still gives `il les a`. Only the word right
before counts: `le problème z` still gives `a`.

The bench (fr, en, en-typos) gives the same report as the first version, timings aside:
its corpora hold no lone letter after one of these words.

## Device test of build 51576519 (2026-11-25)

Pierre, iPhone, French:

| typed | branch, first version | expected |
|---|---|---|
| `problème z` + space | `problème a` | `problème à` (acceptable as is) |
| `il t a` + space | `il t à` | `il y a` |

The simulator gives `il y a`. Cause: the rule sat in `checkWord`, behind the lexicon
check that opens it, and `earlyAnswer` keeps a lexicon word the dictionary knows when
no context rule fires (step 5). An iPhone's lexicon holds short entries from contacts
and text replacements (`a`, `ma`, an all-caps `ST`: #501, #500, #1006), a `T` among them
from a contact's initial, so the `t` was kept as typed. Then the a/à rule (#501), which
reads the text before the cursor, read `il t a`: two words after `il`, `a` is `à`. The
rule now runs in `earlyAnswer`, right after the lexicon verdicts that outrank context
rules (a shortcut, a name the dictionary lacks) and before the rest: a lexicon `T` no
longer keeps `t`, and once the space has written `y`, the `a` reads `il y a` and stays.
Bench (#954), iPhone 17 simulator, iOS 27.2, Xcode 27.2: `device-test-before.md` is the
branch at `fe7d59c2` (the first version merged with develop), `device-test-after.md` this
fix, both with the three register rows it adds.

| | before | after |
|---|---:|---:|
| fr: wrong words in the final text | 2 of 152 | 2 of 152 |
| fr: broken / miscorrected / missed | 0 / 0 / 2 | 0 / 0 / 2 |
| en: wrong words in the final text | 8 of 157 | 8 of 157 |
| en: broken / miscorrected / missed | 0 / 1 / 3 | 0 / 1 / 3 |
| en-typos: wrong words in the final text | 1 of 129 | 1 of 129 |
| en-typos: broken / miscorrected / missed | 0 / 1 / 0 | 0 / 1 / 0 |
| Register (#500) | 28 of 36 | **29 of 36** |

`commits.tsv` and `texts.tsv` are identical, and so are the taps but their timings. One
register row moves, the device case: `il` `t` with a `T` in the lexicon gave `t` and now
gives `y`. Without the `T` it gave `y` before too, which is why the simulator never showed
the bug; `il y` `a` with an `a` in the lexicon stays `a` on both.

Not changed: `problème z` gives `problème a`, as a typed `problème a` does. The corrected
letter already goes through the a/à rule; choosing `à` after `problème` would need a new
rule for nouns, which `le problème a été résolu` and `ce problème a duré` contradict.

## Reproduce

```bash
xcrun simctl boot <udid>                     # your own simulator
tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos > report.md
```
