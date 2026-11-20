# #995: misspellings in the word lists and real-word contractions

Measured with the keyboard bench of #978 (`tools/keyboard-bench/`, branch
`chore/keyboard-bench-multilingual` at `1df9cec8`), iPhone 17 simulator, iOS 26.5.
Before is develop `0071440e`, after is `15e13e74`, the last code commit of this branch.

## Wrong words in the final text

| Run | Before | After | Apple |
|---|---:|---:|---:|
| en-typos | 16 / 129 | **3 / 129** | 3 / 129 |
| en | 9 / 157 | 9 / 157 | 0 |
| fr | 9 / 152 | 9 / 152 | |
| es | 29 / 141 | 29 / 141 | |
| de | 7 / 141 | 7 / 141 | |
| es-typos | 44 / 119 | 44 / 119 | |
| de-typos | 6 / 131 | 6 / 131 | |

Broken words (typed right, changed): 0 on every run, before and after. The final text of
`fr`, `en`, `es`, `de`, `es-typos` and `de-typos` is byte-identical before and after
(`texts.tsv`). On `en-typos`, exactly the 13 words of the issue change: `teh`,
`recieve`, `definately`, `beleive`, `becuase`, `adn`, `Ill` ×3 and `ill` → `I'll`,
`Its` ×2 → `It's`, `were` → `we're`. The three left are the slips Apple also misses or
misses differently: `Poeple` → `Purple`, `Beeing` → `Bering`, `wll` → `all`.

`es-typos` does not move: its 42 missed words are missing accents (#994) and its two
miscorrections are slips no source list names.

## Held-out counter-cases

`held-out-contractions.txt` (intended) and `.keys` (typed): 15 sentences written for this
PR, 12 where `ill`, `its` or `were` is the word meant (`I will be ill`, `has its own`,
`we were`, `Were you there`, `they sure were fun`...) and 3 where the contraction is.
Before: the 12 kept, the 3 missed. After: the 12 kept, the 3 fixed. The one broken word in
both, `wagged` → `ragged`, is not in the word list and is unrelated.

## Commands

The bench runs from a `git archive` copy of each commit with #978's `tools/keyboard-bench`
extracted over it, outside the repository:

```bash
git archive <commit> | tar -x -C /tmp/tree
git archive 1df9cec8 tools/keyboard-bench | tar -x -C /tmp/tree
cd /tmp/tree
tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,es,de --out out-touch > touch.md
tools/keyboard-bench/run.sh --udid <udid> --langs en-typos,es-typos,de-typos --out out-typos --no-build > typos.md
python3 -I tools/keyboard-bench/make_runs.py --corpus <held-out corpus> --out <runs> --langs en-typos
tools/keyboard-bench/run.sh --udid <udid> --langs en-typos --corpus <held-out corpus> --runs <runs> --out out-held --no-build
```

The held-out corpus is a folder holding the two files above as `en-typos.txt` and
`en-typos.keys`. The reports' `commit:` line was filled in by hand: an archive has no git
metadata.

## On the simulator

`dictus-sim-ill-teh.mp4`: the Dictus keyboard (English) in Reminders, typing
`ill be there with teh book `. `Ill` becomes `I'll` on the first space,
`teh` is previewed as `the` (`dictus-sim-teh-preview.png`) and becomes `the` on the space
(`dictus-sim-ill-teh-after.png`).
