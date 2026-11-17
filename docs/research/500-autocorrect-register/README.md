# Autocorrect register (#500): measured, triaged

The nine cases filed on #500 up to 2026-11-01, replayed by the keyboard bench
(`tools/keyboard-bench/register.tsv`, [protocol](../../keyboard-measurement.md)), taken
2026-11-17 on an iPhone 17 simulator, iOS 26.5, Xcode 27.2.

| File | Code measured |
|---|---|
| `before.md` | develop at `2e280b7f`, with the register replay of `d6863e62` (the bench only) |
| `before-lexicon.md` | `a46d9eb0` (both fixes), with the lexicon cases of `7ac5981b`: the device failure reproduced |
| `after.md` | `57665d0a`, the branch with the lexicon ordering fixed |

## Before and after

| | before | after |
|---|---:|---:|
| Register, the nine filed cases | 0 of 9 | **3 of 9** |
| Register, with the four lexicon cases | 6 of 13 (`a46d9eb0`) | **7 of 13** |
| fr bench: broken / miscorrected / missed | 0 / 4 / 5 | 0 / 4 / 5 |
| en bench: broken / miscorrected / missed | 0 / 4 / 3 | 0 / 4 / 3 |
| fr bench: wrong words in the final text | 9 of 152 | 9 of 152 |
| en bench: wrong words in the final text | 9 of 157 | 9 of 157 |

Every row of the touch runs is the same before and after; only the register moves.
Before the fixes, the replay reproduces all nine outcomes as they were reported.

## The device test that failed, and the lexicon cases

The first device test of the PR (2026-11-17, iPhone 15 Pro Max) left `il ma` as typed.
Its log reads `AUTOCORRECT-SKIP word="ma" reason=lexicon`, with `lexicon loaded: 10
shortcuts, 1575 words`. The contacts and text-replacements lexicon (#873) held `ma`,
its verdict `.keep` returned first in `spellCheck(_:previousWord:)`, and the context
override never ran. The simulator has no contacts, so neither the bench nor the
simulator saw it.

The order is now:

1. A shortcut (`qqc` → "quelque chose") returns first, whatever precedes it.
2. A kept word the dictionary does not know (a name: `zofiak` → "Zofiak") returns first.
3. A kept word the dictionary knows (`ma`, `pierre`) waits for the context overrides,
   and is kept when none applies.

Step 3 can only change a word the dictionary already knows, and only through a
context override, which exists because that word is never right in that position.

`register.tsv` now carries a `lexicon` column, and four cases with one: the device
failure, the name, the dictionary word with a contact Pierre, and the shortcut. All
four come out right after the fix; only the first was wrong before.

## The nine cases

| Typed (after) | Meant | Dictus | Why | Owner |
|---|---|---|---|---|
| `ma` (il) | m'a | **fixed** | Valid word in an impossible position. The bigrams cannot tell: they keep 16 followers per word, and after `il` both `ma` and `la` score zero. Fixed by a French context override. | this PR |
| `vocaux` | vocaux | **fixed** | Missing from the dictionary: Lexique count 18, below the top-40K cut. Added. | this PR |
| `stylé` | stylé | **fixed** | Missing from the dictionary: count 23, below the cut. Added with its inflections. | this PR |
| `styké` | stylé | style | `stylé` now exists, but at count 23 against 3529 for `style`, the trie still prefers `style`. The typed `é` is not weighed as evidence. | scoring, #114 |
| `styke` | stylé | style | As above, and `style` is a fair reading of `styke`. | scoring, #114 |
| `troubz` (comment as tu) | trouvé | trouve | Both forms are trie candidates; neither has a bigram after `tu`, and the trigram after `as tu` predicts `as`, `es`, `ne`, `veux`... never `trouvé`. Choosing the participle needs the auxiliary two words back. | n-grams, #114 |
| `arruves` (bien) | arrivés | arrives | `arrivés` is the trie's first alternative and the more frequent form (35334 against 33700), but the accent costs distance, and `bien` has no bigram for either. | n-grams / scoring, #114 |
| `dais` (ce que tu as) | fait | dais | `dais` is a word (a canopy), so the valid-word guard keeps it. `fait` is the second prediction after `as`, but at edit distance 2. Replacing a valid word two edits away is the `fais` → `vais` failure the guard exists for. | scoring, #114 |
| `mok` | moi | m'ok | Contraction expansion runs before the trie and accepts any dictionary word after an elision letter, `ok` included. The trie alone writes `moi`. | contraction expansion, new issue |

So of the nine: 3 fixed here, 2 n-gram coverage, 3 scoring, 1 a contraction rule.
None is a context signal the engine has and ignores: the previous word already
reranks corrections (`spellCheck(_:previousWord:)`), and where it failed above, the
data it reads holds nothing for the pair.

## What was tried and not shipped

**A bigram gate on contraction expansion, for `mok`.** Requiring the suffix to be a
seen follower of its elided letter blocks `m'ok`, but also blocks real ones: the
followers of `m` and `t` in `fr_ngrams.dict` are mostly LaTeX tokens from the
Wikipedia corpus (`displaystyle`, `frac`), so `en` after `m` scores zero (`m'en`), and
`as` and `or` have no evidence after any letter (`l'as`, `d'or`). Measured in the
replay engine on 2026-11-17.

**A vowel-or-h rule on the same expansion.** French elides only before a vowel or a
mute h, and the expansion ignores it: `dje`, `sla` and `mta` expand to `d'je`, `s'la`
and `m'ta` today. The rule is right and safe, but it does not catch `mok` (`ok` starts
with a vowel), so it belongs to the contraction issue rather than to this register.

## Reproduce

```bash
xcrun simctl boot <udid>                     # your own simulator
tools/keyboard-bench/run.sh --udid <udid> > report.md
```

The register is the last section of the report. New cases go in
`tools/keyboard-bench/register.tsv`, one row each, characters as reported.
