# #970 and #971 taken over on the new engine (2026-11-21)

Iris's #970 (`il ma` → `il m'a`, `vocaux`, `stylé`, refs #500) and #971 (`a` / `à`,
refs #501) were paused on 2026-11-18. Since then develop took the new engine (#993
`correctionProposal`, #994 participles, #1006 elisions across a space, #1004, #1008).
This page measures both PRs again on develop `a06e3e11`, then the sentence-start rule
that [#979](https://github.com/getdictus/dictus-ios/pull/979) recommended.

All runs: iPhone 17 simulator, iOS 26.5, `tools/keyboard-bench/run.sh` (the #954 replay,
the shipping engine compiled from the tree), `SWIFT_DETERMINISTIC_HASHING=1`.

## The 124 `a` / `à` tokens of #979

#979's corpus (117 sentences, typed lowercase, no accents, a space after every word,
zero-noise taps). The bench now capitalises the first letter of the field, as the
keyboard does, so a sentence-initial `a` is typed `A`.

| Case | Tokens | develop | #971 on develop | #971 + sentence start | Apple |
|---|---:|---:|---:|---:|---:|
| Sentence start (`à demain`) | 9 | 0 | 0 | **8** | 9 |
| Sentence start, longer (`À deux on ira plus vite`) | 6 | 0 | 0 | **6** | 6 |
| After a noun, verb (`le problème a été réglé`) | 10 | 10 | 10 | 10 | 10 |
| After a noun, preposition (`une machine à laver`) | 10 | 0 | 0 | 0 | 9 |
| `a` inside a sentence of another case | 2 | 2 | 2 | 2 | 2 |
| After an adjective (`facile à faire`) | 5 | 0 | 4 | 4 | 5 |
| After a verb (`je pense à toi`) | 15 | 0 | 13 | 13 | 15 |
| Set phrases (`à pied`, `à cause`) | 12 | 0 | 10 | 10 | 12 |
| `il a` + noun / adverb / participle | 12 | 12 | 12 | 12 | 12 |
| Pronoun subject (`ça a marché`) | 5 | 5 | 5 | 5 | 5 |
| Relative clause (`ce que tu as fait a marché`) | 7 | 7 | 7 | 7 | 7 |
| Names (`Marie a`, `écrit à Marie`) | 6 | 4 | 5 | 5 | 6 |
| Elisions (`m'a`, `jusqu'à`, `qu'à`) | 11 | 6 | 10 | 10 | 11 |
| `y a` | 6 | 5 | 6 | 6 | 6 |
| Questions (`à qui tu parles`) | 8 | 3 | 6 | **8** | 8 |
| **Total** | **124** | **54** | **90** | **106** | **123** |

- develop and #971 give exactly #979's numbers (54 and 90): the new engine changed
  nothing for `a` / `à`.
- **No `a` that should stay `a` became `à`** in any column (54 of 54 kept).
- With a device-like lexicon (`--lexicon a,ma`, contacts and replacements holding `a`),
  the last column is unchanged: 106.
- The 18 left: the 10 `noun + à` (`machine à laver`), and 8 scattered (`à tout à
  l'heure`'s second `à`, `jouer à deux`, `penser à tout`, `la première à arriver`,
  `le livre à moitié`, `là à huit heures`, `Thomas à midi`, `qu'à demander`).

## The sentence-start rule

`ContextualHomograph.accentedAtSentenceStart`, on for French: the first word of a
sentence (start of the field, after `.`, `!`, `?`, `…` or a new line) becomes `à`, its
capital kept (`A` → `À`). A clause start after a comma is not a sentence start
(`ce qu'il dit, a choqué` stays). A capital `A` inside a sentence is still left alone.

Tatoeba (731,363 French sentences, 2026-11-21), `tools/a-grave-eval/run.sh`:

| written | occurrences | typed `a` became `à` |
|---|---:|---:|
| `a` (verb), inside a sentence | 64,669 | 45 (0.07%), as on #971 |
| `à` (preposition), inside a sentence | 93,546 | 34,573 (36.96%), as on #971 |
| sentence start, written `à` / `À` | 4,300 | 4,300 |
| sentence start, written `a` / `A` | 106 | 106 |

Read one by one, the 106 plain `A` are nearly all `À` written without its accent
(`A l'école`, `A mon avis`, `A partir de`). About ten are not a preposition, and the
rule turns them into `À`: `A voté` (twice), `C'est le chat ? A demandé le vieil homme`,
`A beau mentir qui vient de loin`, the letter (`A et B`, `A est l'ensemble`), initials
(`E. T. A. Hoffmann` twice, `A. Karpov`), plus `A priori` / `A contrario` (twice /
once), which `à priori` also spells. About 10 wrong for 4,300 right: 0.2% of the
sentence starts.

## The #970 register

`tools/keyboard-bench/register.tsv` (the 15 cases filed on #500), plus seven checks
run outside the repository: `ça ma` and `tu ma` from the PR, and five counter-cases.

| Case | develop | #970 on develop |
|---|---|---|
| `il ma` → `m'a` | `ma` ✗ | `m'a` ✓ |
| `il ma` → `m'a`, `ma` in the lexicon | `ma` ✗ | `m'a` ✓ |
| `ça ma` (plu) → `m'a` | `ma` ✗ | `m'a` ✓ |
| `tu ma` (dit) → `m'as` | `ma` ✗ | `m'as` ✓ |
| `vocaux` | `bocaux` ✗ | `vocaux` ✓ |
| `stylé` | `style` ✗ | `stylé` ✓ |
| `styke`, `styké` → `stylé` | `style` ✗ | `style` ✗ |
| `voczux` → `vocaux` (twice) | `bocaux` ✗ | `bocaux` ✗ |
| `troubz` → `trouvé`, `dais` → `fait`, `mok` → `moi` | ✗ | ✗ |
| `bien arruves`, `Zofiak`, `une pierre`, `qqc` | ✓ | ✓ |
| Counter-cases: `pour ma`, `de ta`, `il la`, `je parle à ma`, `c'est ta` | ✓ | ✓ |
| **Right** | **9 of 22** | **15 of 22** |

Of the 15 filed cases: 4 of 15 on develop, 8 of 15 with #970. What #970 does not fix
(`styke`, `voczux`, `troubz`, `dais`, `mok`) is candidate ranking, #114's and #996's.

## #954 bench

The committed runs, `fr,en`, against develop `a06e3e11`, word by word:

| | develop | this branch |
|---|---:|---:|
| fr wrong words (of 152) | 3 | **2** (`à` in sentence 5 fixed) |
| en wrong words (of 157) | 7 | 7 |
| Broken (typed right, changed), fr / en | 0 / 0 | **0 / 0** |
| Words newly wrong | | **0** |
| `--lexicon a,ma` | | same 307 words |
| `corpus-rare` (zero noise, 176 words): newly wrong | | **0** |
| Engine time, space, p95 (ms, simulator), fr / en | 0.74 / 1.00 | 0.69 / 0.98 |
