# #994: accent restoration, bench before and after

In-process replay (`tools/keyboard-bench/run.sh`), iOS 26.5 simulator (iPhone 17),
2026-11-20, `SWIFT_DETERMINISTIC_HASHING=1`.

- **develop**: `0071440e`, for reference.
- **before**: `e8a83934`, the head of #997 (`fix/993-autocorrect-confidence`), which
  this branch is built on.
- **after**: `a8dde598`, this branch.

All five runs need the bench of PR #978 (`chore/keyboard-bench-multilingual`, not on
`develop`). Each column ran from a `git archive` of that branch outside the repository,
with `DictusCore/Sources` and `DictusKeyboard` of the commit under test copied over it.
The reports print an empty commit because the copy is not a git checkout.

```bash
git archive origin/chore/keyboard-bench-multilingual | tar -x -C <bench>
git archive <commit> DictusCore/Sources DictusKeyboard | tar -x -C <bench>
<bench>/tools/keyboard-bench/run.sh --udid <udid> --langs fr,en,en-typos,es,de > report.md
```

## Autocorrect

| run | accent-only misses (develop → before → after) | miscorrected | broken | fixed |
|---|---|---|---|---|
| fr | 5 → 7 → **2** | 4 → 1 → **0** | 0 → 0 → 0 | 22 → 22 → **28** |
| es | 18 → 18 → **5** | 3 → 1 → **2** | 0 → 0 → 0 | 15 → 16 → **29** |
| en | 0 → 0 → 0 | 4 → 1 → 1 | 0 → 0 → 0 | 11 → 13 → 13 |
| en-typos | 0 → 0 → 0 | 3 → 1 → 1 | 0 → 0 → 0 | 21 → 23 → 23 |
| de | 0 → 0 → 0 | 2 → 0 → 0 | 0 → 0 → 0 | 17 → 16 → 16 |

The two French accent misses left are `a` (à), which belongs to #971, and `decalee`
(décalée), which the dictionary does not have. The French count rose from 5 to 7 with
#997, which keeps `reserve` and `decalee` as typed.

Every word that changed between before and after (`*-commits.tsv`):

| run | typed | before | after |
|---|---|---|---|
| fr | `reserve` after `avons` | reserve | réservé |
| fr | `arrive` after `est` | arrive | arrivé |
| fr | `trouve` after `a` | trouve | trouvé |
| fr | `couches` after `déjà` | couches | couchés |
| fr | `decharge` after `presque` | décharge | déchargé |
| fr | `oublie` after `as` | oublie | oublié |
| es | `llamare`, `manana` ×2, `Manana`, `habia`, `estacion`, `estan`, `Todavia`, `estare`, `gustaria`, `cafe`, `numero`, `telefono` | kept | accented |
| es | `mexico` (meant `médico`) | mexico | **méxico** |

The one new miscorrection is `mexico`: the `d` of `médico` landed on `x`, and `méxico`
is 11x as frequent as `mexico`. The word was wrong before and is wrong after; it moves
from "missed" to "miscorrected". The Spanish accent misses left are `esta` (está),
`llegue` (llegué), `se` (sé), `que` and `Que` (qué). Each bare form is the more
frequent spelling or close to it, and its context is not a participle.

## Engine time (ms), median of three replays

| lang | key | before p50 / p95 | after p50 / p95 |
|---|---|---|---|
| fr | letter | 0.11 / 0.52 | 0.11 / 0.52 |
| fr | space | 0.09 / 0.48 | 0.10 / 0.45 |
| es | letter | 0.10 / 0.80 | 0.10 / 0.72 |
| es | space | 0.08 / 1.07 | 0.10 / 0.63 |
| de | letter | 0.10 / 0.83 | 0.10 / 0.69 |
| en | letter | 1.08 / 2.00 | 0.97 / 1.83 |

The accent pass no longer walks the trie for candidates when it finds an accented
spelling (#997 did, to check for two equally likely spellings), which is the likely
reason for the lower space p95 in Spanish. English runs no code this change touches, so
its 10 % drop is the Mac's load moving between runs, not a speed-up.

The three replays of each commit wrote byte-identical `commits.tsv` files.

## On the real keyboard

`dictus-sim-accents.png` and `.mp4`: the Dictus keyboard on the same simulator, in
Reminders, fed the replay's tap points for fr sentences 9, 11, 13 and 18 with `axe`
(`tools/keyboard-bench/sim_replay.py`, `--grid-top 583.2`). It wrote
(`dictus-sim-texts.tsv`):

- Le train est arrivé avec une heure de retard
- Elle a trouvé un appartement près du centre
- Les enfants sont déjà couchés depuis une heure
- Tu as oublié tes clés sur la table

## After merging #997's device follow-up (`0e0a930d`)

`3c6009ec` merges #997 at `0e0a930d` into this branch. Same bench, same simulator,
2026-11-21, the three commits rerun side by side. The rerun of `d86d5a99` wrote the
same `commits.tsv` as `after-commits.tsv` above, byte for byte.

| run | miscorrected (#997 `0e0a930d` / #1000 `d86d5a99` → merge) | broken | fixed | accent-only misses |
|---|---|---|---|---|
| fr | 1 / 0 → **0** | 0 / 0 → 0 | 22 / 28 → **28** | 7 / 2 → **2** |
| es | 2 / 2 → **3** | 0 / 0 → 0 | 16 / 29 → **29** | 18 / 5 → **5** |
| en | 1 / 1 → 1 | 0 / 0 → 0 | 13 / 13 → 13 | 0 / 0 → 0 |
| en-typos | 1 / 1 → 1 | 0 / 0 → 0 | 23 / 23 → 23 | 0 / 0 → 0 |
| de | 1 / 0 → **1** | 0 / 0 → 0 | 16 / 16 → 16 | 0 / 0 → 0 |

Against `d86d5a99`, two words changed, and they are the two #997's follow-up changes on
its own branch: Spanish `ests` (meant `está`) becomes `esta`, German `vestellt` (meant
`bestellt`) becomes `gestellt`. Against `0e0a930d`, the words that changed are exactly the
accent restorations of the table above (`reserve` → `réservé` after `avons` included).
The accent pass still decides with `AccentRestoration`: the merge drops #997's rewrite of
`ambiguousAccentSpellings`, which this branch had removed. Report and per-word commits:
`after-997-followup.md`, `after-997-followup-commits.tsv`.
