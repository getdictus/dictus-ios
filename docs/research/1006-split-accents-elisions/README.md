# #1006: split halves with accents, context-fitting splits, French elision repair

iOS 26.5 simulator (iPhone 17, slimmed), 2026-11-21, `SWIFT_DETERMINISTIC_HASHING=1`.

- **before**: `d86d5a99`, the head of #1000 (`fix/994-accent-restoration`), which this
  branch is built on. It contains #997 at `e8a83934`.
- **after**: `c9ca8ca6`, this branch.

The keyboard bench (#954) ran from a `git archive` of `chore/keyboard-bench-multilingual`
outside the repository, with the commit's `DictusCore/Sources`, `DictusKeyboard` and
`tools/split-pass-bench` copied over it, as for #1000. The split-pass bench (#499) ran from
the same copy.

```bash
git archive origin/chore/keyboard-bench-multilingual | tar -x -C <bench>
git archive <commit> DictusCore/Sources DictusCore/Tests/DictusCoreTests/Fixtures DictusKeyboard tools/split-pass-bench | tar -x -C <bench>
<bench>/tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos,es,de > report.md
<bench>/tools/split-pass-bench/run.sh --udid <udid> > split-report.md
```

## Keyboard bench (`before.md`, `after.md`)

| run | broken | miscorrected | missed | fixed | glued, split back |
|---|---|---|---|---|---|
| fr | 0 → 0 | 0 → 0 | 3 → 3 | 28 → 28 | 0 → 0 |
| en | 0 → 0 | 1 → 1 | 4 → 4 | 13 → 13 | 1 → 1 |
| en-typos | 0 → 0 | 1 → 1 | 13 → 13 | 23 → 23 | 0 → 0 |
| es | 0 → 0 | 2 → 2 | 10 → 10 | 29 → 29 | 0 → **1** |
| de | 0 → 0 | 0 → 0 | 8 → 8 | 16 → 16 | 0 → 0 |

One word of 716 changed (`*-commits.tsv`): Spanish `Tengoque`, glued for `tengo que`, was
corrected to `Enfoque` and is now split back to `Tengo que`. The direct split carries a
bigram and the only boundary split did not, and a bigram now comes first.

The bench types none of the shapes this change repairs: its corpora have no glued
French participle and no elision typed without its apostrophe.

## Split-pass bench (`split-before.md`, `split-after.md`), 678 cases

Three wrong splits become right, nothing else moves:

| case | typed | before | after |
|---|---|---|---|
| fr-missed-space-057 | `personnesâgées` | `perso engagées` | `personnes âgées` |
| de-missed-space-012 | `wennich` | `wen ich` | `wenn ich` |
| es-missed-space-040 | `amablecon` | `ama leon` | `amable con` |

Each time a boundary split with no bigram (cut at the `n` or `b` next to the spacebar,
the right half corrected) beat a direct split with one. No legit compound is split and no
false replacement is added. The bench compares accent-insensitively, so it cannot show
the accent restoration of the halves.

## Engine time (ms, p50 / p95, one replay each)

| | before | after |
|---|---|---|
| fr letter | 0.12 / 0.56 | 0.11 / 0.53 |
| fr space | 0.10 / 0.55 | 0.10 / 0.50 |
| es space | 0.11 / 1.29 | 0.10 / 0.74 |
| de space | 0.08 / 0.70 | 0.10 / 0.95 |

One replay per commit: the spread between the two is the Mac's load, in both directions.

## The device-test cases through the engine

`TextPredictionEngine.correctionProposal`, mid-sentence, on the shipped French
dictionary. Before is `d86d5a99`, after is `c9ca8ca6`.

| previous word | typed | before | after |
|---|---|---|---|
| je | `suisnarrive` | `suis arrive` | `suis arrivé` |
| | `donnequoi` | `don quoi` | `donne quoi` |
| | `qunil` | kept, bar offers `subir` / `subi` | `qu'il` |
| | `qj'on` | kept | `qu'on` |
| ce | `st` | `s't` | nothing for the word alone; the space bar writes `c'est` |
| ce | `st`, with an all-caps `ST` contact | `ST` | the same as without it |
| qu | `il` | kept | the space bar writes `qu'il` |
| | `quille`, `cesse`, `quel` | kept | kept |
| | `quiz` | kept, bar offers `qui` / `suis` | the same |
| | `dnas` | `dans` | `dans` |

With #997 at `0e0a930d` (`git merge-tree` of this branch and #997's head, with
`CorrectionRanking.swift` resolved by keeping #1000's deletion of
`ambiguousAccentSpellings`):

| previous word | typed | #997 alone | with this branch |
|---|---|---|---|
| est | `zrrive` | `arrive` | `arrivé` |
| suis | `arribe` | `arrive` | `arrivé` |
| il | `zrrive` | `arrive` | `arrive` |
| | `quiz` | `qui` | `qui` |

`quiz` is not in the French dictionary, and #997's `0e0a930d` corrects an unknown word
between two close readings. This branch does not change that.

## On the real keyboard

`dictus-sim-1006.png` and `.mp4`: the Dictus keyboard in Reminders, every tap on its
key's centre, sent with `axe` (`tools/keyboard-bench/sim_replay.py --grid-top 583.2`).
The typed lines are in `dictus-sim-typed.txt` and what the keyboard wrote in
`dictus-sim-texts.tsv`. All nine lines came out as intended, the two-word elisions
(`ce st`, `qu il`) included, which only the space bar handles and the in-process replay
cannot show. The build was the code of `ab71ec37`; `c9ca8ca6` adds only the trie
correction's accents, which none of these lines reaches.
