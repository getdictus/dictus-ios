# #995: misspellings in the word lists and real-word contractions

Measured with the keyboard bench of #978 (`tools/keyboard-bench/`, branch
`chore/keyboard-bench-multilingual` at `1df9cec8`), iPhone 17 simulator, iOS 26.5.

This branch is based on #997 (`fix/993-autocorrect-confidence` at `e8a83934`).
The columns:

- **develop**: `0071440e`, for reference.
- **#997**: `e8a83934`, the base of this branch.
- **this PR**: `ac2c502e`, the last code state of this branch.

## Wrong words in the final text

| Run | develop | #997 | this PR | Apple |
|---|---:|---:|---:|---:|
| en-typos | 16 / 129 | 14 / 129 | **1 / 129** | 3 / 129 |
| en | 9 / 157 | 7 / 157 | 7 / 157 | 0 |
| fr | 9 / 152 | 9 / 152 | 9 / 152 | |
| es | 29 / 141 | 28 / 141 | 28 / 141 | |
| de | 7 / 141 | 8 / 141 | 8 / 141 | |
| es-typos | 44 / 119 | 43 / 119 | 43 / 119 | |
| de-typos | 6 / 131 | 5 / 131 | 5 / 131 | |

Broken words (typed right, changed): 0 on every run, in all three columns.

Against #997, the final text of `fr`, `en`, `es`, `de`, `es-typos` and `de-typos` is
byte-identical (`texts.tsv`). On `en-typos`, exactly the 13 words of the issue change:

- `teh`, `recieve`, `definately`, `beleive`, `becuase` and `adn` are corrected;
- `Ill` (three times) and `ill` become `I'll`;
- `Its` (twice) becomes `It's`;
- `were` becomes `we're`.

The one word left is `wll`, which becomes `all`. #997 already fixed `Poeple` and
`Beeing`.

`es-typos` does not move. Its missed words are missing accents (#994). None of its
mistakes is in the source list.

The first version of this PR, on develop (`15e13e74`, before the rebase), measured
16 → 3 on `en-typos`. Its reports are the `pr-on-develop-15e13e74-*` files.

## Held-out counter-cases

The run is in `held-out-contractions.txt` (intended text) and `.keys` (typed text). It
has 15 sentences written for this PR:

- 12 where `ill`, `its` or `were` is the word meant (`I will be ill`, `has its own`,
  `we were`, `Were you there`, `they sure were fun`...);
- 3 where the contraction is meant.

| Base | Counter-cases kept | Contractions fixed |
|---|---|---|
| #997 | all 12 | none of the 3 |
| this PR | all 12 | all 3 |

## With #1000 (accent restoration)

#1000 is `fix/994-accent-restoration` at `d86d5a99`, also based on #997.

**Merge.** The textual conflict is in `LanguageProfile.swift` only: both PRs add fields
and `init` parameters. Keeping both sides resolves it.

**Throwaway merge.** It was built locally and never pushed:

- the DictusApp simulator build succeeds;
- `swift test` runs 3,623 tests with 0 failures.

**Bench.** Against #1000 alone, the merge changes only the 13 `en-typos` words: 14 → 1
wrong words. Every other run's final text is identical (`pr1000-d86d5a99-*` and
`merge-with-pr1000-*`).

## Commands

Each bench runs from a `git archive` copy of the commit, with #978's
`tools/keyboard-bench` extracted over it, outside the repository:

```bash
git archive <commit> | tar -x -C /tmp/tree
git archive 1df9cec8 tools/keyboard-bench | tar -x -C /tmp/tree
cd /tmp/tree
tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,es,de --out out-touch > touch.md
tools/keyboard-bench/run.sh --udid <udid> --langs en-typos,es-typos,de-typos --out out-typos --no-build > typos.md
python3 -I tools/keyboard-bench/make_runs.py --corpus <held-out corpus> --out <runs> --langs en-typos
tools/keyboard-bench/run.sh --udid <udid> --langs en-typos --corpus <held-out corpus> --runs <runs> --out out-held --no-build
```

The held-out corpus is a folder holding the two files above, named `en-typos.txt` and
`en-typos.keys`.

An archive has no git metadata, so the reports' `commit:` line was filled in by hand.

## On the simulator

This was recorded on `ac2c502e`, rebased on #997.

`dictus-sim-ill-teh.mp4` shows the Dictus keyboard (English) in Reminders, typing
`ill be there with teh book `:

- `Ill` becomes `I'll` on the first space;
- `teh` is previewed as `the` (`dictus-sim-teh-preview.png`);
- `teh` becomes `the` on the space (`dictus-sim-ill-teh-after.png`).
