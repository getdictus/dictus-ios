# #993: keyboard bench before and after

In-process replay (`tools/keyboard-bench/run.sh`), iOS 26.5 simulator (iPhone 17),
2026-11-20, `SWIFT_DETERMINISTIC_HASHING=1` unless stated.

- **before**: `develop` at `0071440e`.
- **after**: this branch (`CorrectionRanking`, scorer fixes).
- `fr` and `en` ran from the worktree (`before.md`, `after.md`, `*-commits.tsv`).
- `en-typos` and the held-out runs need the bench of PR #978
  (`chore/keyboard-bench-multilingual`, not on `develop`). They ran from a `git archive`
  of that branch outside the repository, once as is (before) and once with this
  branch's changed files copied over it (after). Those reports print an empty commit
  because the copy is not a git checkout.

## The three runs of the issue

| run | miscorrected | broken | fixed |
|---|---:|---:|---:|
| fr | 4 → **1** | 0 → 0 | 22 → 22 |
| en | 4 → **1** | 0 → 0 | 11 → 13 |
| en-typos | 3 → **1** | 0 → 0 | 21 → 23 |
| **total** | **11 → 3** | 0 → 0 | 54 → 58 |

| typed | before | after |
|---|---|---|
| `reùion` (réunion) | région | kept as typed |
| `decalee` (décalée) | dévaler | kept as typed |
| `reserve` (réservé) | réserve | kept as typed |
| `decharge` (déchargé) | décharge | **décharge** |
| `irning` (morning) | irving | kept as typed |
| `finishy` (my) | finish | **finish** |
| `boue` (hour) | bone | hour |
| `meef` (need) | meet | need |
| `Poeple` (people) | Purple | People |
| `Beeing` (being) | Bering | Being |
| `wll` (will) | all | **all** |

The three left are not reachable with the data the keyboard has:

- `decharge` after `presque`: `décharge` is 5 times as frequent as `déchargé`, and the
  n-gram data has neither after `presque`.
- `finishy`: the `m` of `my` landed on backspace and deleted the space after `finish`.
  `finish` is the only candidate and the typed word is not a word.
- `wll` after `a`: `all` is one neighbouring key away and more frequent than `will`, a
  missing letter away. The n-gram data has neither after `a`.

`hourvlate` (hour late) still becomes `hourglass`, in the glued column: no split is
offered because `v` is not next to the space bar.

## Held out

The constants were fitted on the three runs above, then checked on runs they were not
fitted on. One change came after that check: the context window was anchored on the
cheapest candidate, and German `wenn ic` stayed `ic` because a rare English `if` was
cheaper than `ich`. It is now anchored on the winner without context.

| run | miscorrected | broken | fixed |
|---|---:|---:|---:|
| fr-learned | 5 → 2 | 0 → 0 | 5 → 5 |
| en-learned | 0 → 0 | 0 → 0 | 4 → 4 |
| es | 3 → 1 | 0 → 0 | 15 → 16 |
| de | 2 → 0 | 0 → 0 | 17 → **16** |
| es-typos | 2 → 1 | 0 → 0 | 2 → 3 |
| de-typos | 1 → 0 | 0 → 0 | 22 → 23 |

The German loss is `montg` (meant `montag`), now kept as typed. Its runner-up `monte`
costs 0.83 to reach against 1.00 for `montag`, within 0.25, and scores 0.065 below it,
inside the 0.12 band, so the two read as equally likely. Correcting it would take a
band under 0.065, and `irning` (`irving` 0.097 ahead of `inning`) would then be
corrected to `irving` again, one of the 11 the issue is about. Since the kept word's
candidates are in the bar (below), `montag` is one tap away.

## Determinism

Four replays of fr, en and en-typos **without** the fixed hash seed:

- before: 3 different `commits.tsv` out of 4 (`meef` became `meet` or `meer`, `boue`
  became `bone` or `blue`);
- after: the 4 are byte-identical.

## Engine time (ms), median of three replays

| lang | key | before p50 / p95 | after p50 / p95 |
|---|---|---|---|
| fr | letter | 0.11 / 0.51 | 0.11 / 0.54 |
| en | letter | 0.89 / 1.75 | 0.86 / 1.69 |
| fr | space | 0.09 / 0.43 | 0.09 / 0.48 |
| en | space | 0.05 / 0.61 | 0.05 / 0.70 |

Letters stay within 10 %. Space p95 rises by about 0.06 ms: it now ranks ten
candidates with one bigram lookup each, instead of taking the first of five.

## A kept word is still suggested

When the typed word is kept, the bar still offers the candidates, as Apple's keyboard
does, without a bold slot and without applying anything on space: the bar reads
`TextPredictionEngine.correctionProposal`, the space bar reads `spellCheck`, which only
returns `.autocorrect`. Rerun on the commit that adds this: the `commits.tsv` of all nine
runs (fr, en, en-typos and the six held-out) are byte-identical to the previous commit,
so every number above stands.

`dictus-sim-kept-word-suggestions.png`: the Dictus keyboard on the simulator, French,
`nous avons reserve` typed. The bar shows `"reserve" | réserve | réservé`, none in
bold. A space then left `Nous avons reserve ` in the field.

## On the real keyboard

`dictus-sim-we-need.png` and `.mp4`: the Dictus keyboard on the same simulator, in
Reminders, fed the replay's tap points for en sentence 14 with `axe`. The taps type
`meef`; the keyboard writes "We need to buy tomatoes and some cheese". Before this
change the same taps gave "meet" or "meer", depending on the launch.
