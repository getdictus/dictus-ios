# #1006: split halves with accents, context-fitting splits, French elision repair

iOS 26.5 simulator (iPhone 17, slimmed), 2026-11-21, `SWIFT_DETERMINISTIC_HASHING=1`.

- **before**: `6541e79c`, the head of #1000 (`fix/994-accent-restoration`) once it merged
  #997 at `0e0a930d`.
- **after**: `d1ababbc`, this branch with that head merged in.

The keyboard bench (#954) ran from a `git archive` of `chore/keyboard-bench-multilingual`
outside the repository, with the commit's sources copied over it, as for #1000. The
split-pass bench (#499) ran from the same copy.

```bash
git archive origin/chore/keyboard-bench-multilingual | tar -x -C <bench>
git archive <commit> DictusCore/Sources DictusCore/Tests/DictusCoreTests/Fixtures DictusKeyboard tools/split-pass-bench | tar -x -C <bench>
<bench>/tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos,es,de > report.md
<bench>/tools/split-pass-bench/run.sh --udid <udid> > split-report.md
```

The same pair of runs on the earlier base (`d86d5a99` against `c9ca8ca6`, #997 at
`e8a83934`) gave the same differences, word for word.

## Keyboard bench (`before.md`, `after.md`)

| run | broken | miscorrected | missed | fixed | glued, split back |
|---|---|---|---|---|---|
| fr | 0 → 0 | 0 → 0 | 3 → 3 | 28 → 28 | 0 → 0 |
| en | 0 → 0 | 1 → 1 | 4 → 4 | 13 → 13 | 1 → 1 |
| en-typos | 0 → 0 | 1 → 1 | 13 → 13 | 23 → 23 | 0 → 0 |
| es | 0 → 0 | 3 → 3 | 9 → 9 | 29 → 29 | 0 → **1** |
| de | 0 → 0 | 1 → 1 | 7 → 7 | 16 → 16 | 0 → 0 |

One word of 716 changed (`*-commits.tsv`): Spanish `Tengoque`, glued for `tengo que`, was
corrected to `Enfoque` and is now split back to `Tengo que`. The direct split carries a
bigram and the only boundary split did not, and a bigram now comes first.

The bench types none of the shapes this change repairs: its corpora have no glued
French participle, no elision typed without its apostrophe, and no mistyped participle
after an auxiliary.

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
| fr letter | 0.11 / 0.53 | 0.11 / 0.55 |
| fr space | 0.10 / 0.50 | 0.10 / 0.48 |
| es space | 0.09 / 0.62 | 0.09 / 0.62 |
| de space | 0.09 / 0.67 | 0.09 / 0.62 |
| en-typos space | 0.05 / 0.69 | 0.05 / 0.69 |

## The device-test cases through the engine

`TextPredictionEngine.correctionProposal`, mid-sentence, on the shipped French
dictionary, with #997 at `0e0a930d` on both sides.

| previous word | typed | before | after |
|---|---|---|---|
| je | `suisnarrive` | `suis arrive` | `suis arrivé` |
| | `donnequoi` | `don quoi` | `donne quoi` |
| | `qunil` | kept, bar offers `subir` / `subi` | `qu'il` |
| | `qunelle` | `quelle` | `qu'elle` |
| | `cnest` | kept, bar offers `chez` / `cents` | `c'est` |
| | `qj'on` | kept | `qu'on` |
| ce | `st` | `s't` | nothing for the word alone; the space bar writes `c'est` |
| ce | `st`, with an all-caps `ST` contact | `ST` | the same as without it |
| qu | `il` | kept | the space bar writes `qu'il` |
| est | `zrrive` | `arrive` | `arrivé` |
| suis | `arribe` | `arrive` | `arrivé` |
| il | `zrrive` | `arrive` | `arrive` |
| | `quille`, `cesse`, `quel` | kept | kept |
| | `dnas` | `dans` | `dans` |
| | `quiz` | `qui` | `qui` |

`qunelle` is the one shape that reads both ways: the `n` typed for the apostrophe
(`qu'elle`) or an extra letter in `quelle`. The repair takes the first reading.

`quiz` is not in the French dictionary, and #997's `0e0a930d` corrects an unknown word
between two close readings. This branch does not change that; on #997's earlier head
`quiz` was kept.

## On the real keyboard

The Dictus keyboard in Reminders, every tap on its key's centre, sent with `axe`
(`tools/keyboard-bench/sim_replay.py --grid-top 583.2`). The typed lines are in
`dictus-sim-typed.txt` and what the keyboard wrote in `dictus-sim-texts.tsv`. All ten lines
came out as intended, the two-word elisions (`ce st`, `qu il`) included, which only the
space bar handles and the in-process replay cannot show.

- The last two lines, `dictus-sim-1006.png`, `dictus-sim-1006-trie.png` and
  `dictus-sim-1006.mp4`: build `d1ababbc` (read from the keyboard's `DictusBuildInfo.plist`).
- The first eight lines: build of `ab71ec37`, on #1000's earlier head. `La quille et le
  quiz` was typed there, before #997 started correcting `quiz`.

## After merging the batch's other heads

2026-11-21, same simulator and recipe. This branch now holds #1002 at `7a2d967f`, #997
at `82ff08e5` and #999 at `c70ce2bf`. Neither tree below is pushed: both were rebuilt
with local merges.

- **before** (`batch-before.md`): #992's head `cc5ee518`, then #997, #1000, #999, #1002,
  #998, #1005, in the merge order. #999 against #1000 and #1005 against #1002 conflict on
  their own; they were resolved by keeping both sides (#1000's profile field before
  #999's, #1005's trait reader with #1002's journal hook).
- **after** (`batch-after.md`): that chain with this branch at `30c58a78` merged on top,
  which `git merge-tree` reports clean.

| run | broken | miscorrected | missed | fixed | glued, split back |
|---|---|---|---|---|---|
| fr | 0 → 0 | 0 → 0 | 3 → 3 | 28 → 28 | 0 → 0 |
| en | 0 → 0 | 1 → 1 | 4 → 4 | 13 → 13 | 1 → 1 |
| en-typos | 0 → 0 | 1 → 1 | 0 → 0 | 36 → 36 | 0 → 0 |
| es | 0 → 0 | 3 → 3 | 9 → 9 | 29 → 29 | 0 → **1** |
| de | 0 → 0 | 1 → 1 | 7 → 7 | 16 → 16 | 0 → 0 |

One committed word of 719 differs, the same as before the batch: Spanish `Tengoque`,
`Enfoque` → `Tengo que`. fr space p50 / p95: 0.10 / 0.44 → 0.10 / 0.42 ms.

The accent after a correction, through `correctionProposal` on the after tree: `est
zrrive` and `suis arribe` give `arrivé`, `il zrrive` gives `arrive`. The before tree
gives `arrive` all three times.

The typing journal (#1001) on the after tree, its own bench three ways (no journal,
DEBUG with the toggle off, journal recording): `commits.tsv` and `texts.tsv`
byte-identical, with the sha256 of #1001's proof (`11ef46a5…f7bc93`,
`45e3dbfb…5afea`). The replay has no elision across a space, so the `elision-repair`
journal line is covered by `TypingJournalTests`, not by this run.

On the after tree too: `swift test` (3752 tests, 0 failures, 3 skipped) and the iOS
Simulator build of `DictusApp`.
