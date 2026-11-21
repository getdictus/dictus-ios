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

## Device follow-up: close readings are corrected (2026-11-21)

**What Pierre gains.** Five of the six device typos are now written as a word
instead of being left as typed: `zrreve` → arrive, `sats` → sais, `zrrive` and
`arribe` → arrive (`arrivé` was meant; it is second in the bar), `qur` → sur (`que`
was meant; second in the bar). A typo kept while the bar offered corrections is no
longer learned (`arribe` → learned → `areibe` became `arribe` on the device).

**What he loses.** Two words of the held-out runs, typed wrong and left as typed
before, are now written as the wrong word: Spanish `ests` → `esta` (meant `está`)
and German `vestellt` → `gestellt` (meant `bestellt`). Nothing else moves on the
nine runs: no word broken, no fixed word lost.

**Recommendation: accept them.** Both are the rule doing what it says on a word the
data cannot place, the same choice it makes for `sats` and `qur`. Two principled
changes were tried and measured (below); neither avoids them without losing one of
the device fixes.

### The rule

Pierre's device test of the PR (build `b85eeb31`, typing journal) found the
ambiguity band too conservative: `zrrive` (after `est`), `zrreve`, `arribe`
(after `suis`), `sats` (after `les`) and `qur` (after `passai`) were offered in
the bar and left as typed, where Apple's keyboard corrects them. When the runner-up
is a close reading, the close readings are now settled by context, then frequency.
The typed word is still kept when three or more readings are close once accents are
dropped, or when the pick scores under 0.15. The accent pass keeps its tie rule.

The band opens on the runner-up, as the ambiguity test did before the follow-up
(`109e4062`). Opening it on any close candidate kept `rins` (en-learned, meant
`runs`): `rims`, `ribs` and `fins` are as close as `runs`, but the runner-up is
`find`, a key further, and e8a83934 corrected it.

The trie's real top ten for each case, read with the bench's dictionaries, sit in
`CorrectionRankingTests`. The n-gram data has no pair for any of them
(`est arrivé`, `suis arrivé`, `les sais`, `passai que` all score 0), so frequency
decides. Scores below are cost / frequency / score, score = frequency / 65535 -
0.35 × cost.

| typed | meant | e8a83934 | now | close readings |
|---|---|---|---|---|
| `zrrive`, `arribe` | arrivé | kept | arrive | arrive 0.40 / 46814 / 0.574, arrivé 0.55 / 42907 / 0.462 (one reading) |
| `zrreve` | arrive | kept | arrive | arrête 1.356 / 45984 / 0.227, arrive 1.40 / 46814 / 0.224 |
| `sats` | sais | kept | sais | sais 1.00 / 53558 / 0.467, sans 1.00 / 52050 / 0.444 |
| `qur` | que or qui | kept | sur | sur 0.40 / 55999 / 0.714, que 0.40 / 55817 / 0.712 |
| `Disxord`, French | Discord | discord | discord | discord 0.40 only |
| `Disxord`, English | Discord | kept | kept | discard 1.40 / 39806 / 0.117, under 0.15 |
| **`ests`** (es) | **está** | kept | **esta** (wrong) | esta 0.40 / 55117 / 0.701, este 0.50 / 54311 / 0.654; `está` 1.00 / 58451 / 0.542 is not close |
| **`vestellt`** (de) | **bestellt** | kept | **gestellt** (wrong) | gestellt 0.405 / 37177 / 0.426, bestellt 0.400 / 35160 / 0.397 |

### Bench, nine runs, `109e4062` against `e8a83934`

`after-device-followup.md` (fr, en) and `after-device-followup-other-runs.md` (the
seven others, from the archive of `chore/keyboard-bench-multilingual`).

| run | miscorrected | broken | fixed | words that changed |
|---|---:|---:|---:|---|
| fr | 1 → 1 | 0 → 0 | 22 → 22 | none |
| en | 1 → 1 | 0 → 0 | 13 → 13 | none |
| en-typos | 1 → 1 | 0 → 0 | 23 → 23 | none |
| es | 1 → **2** | 0 → 0 | 16 → 16 | `ests` → esta (meant está) |
| de | 0 → **1** | 0 → 0 | 16 → 16 | `vestellt` → gestellt (meant bestellt) |
| fr-learned | 2 → 2 | 0 → 0 | 5 → 5 | none |
| en-learned | 0 → 0 | 0 → 0 | 4 → 4 | none |
| es-typos | 1 → 1 | 0 → 0 | 3 → 3 | none |
| de-typos | 0 → 0 | 0 → 0 | 23 → 23 | none |

`irning`, `decalee`, `reùion`, `reserve` and `montg` stay as typed.

### Two tries to avoid `ests` and `vestellt`, measured and dropped

Both ran on the nine runs from a throwaway local commit on top of `109e4062`.

1. **Prefer a single neighbouring-key slip over an insertion** between close readings
   (cost under 1.0 before 1.0 or more). No word changed on the nine runs: in both
   words, both readings are one neighbouring key away (`v`→`b` 0.400, `v`→`g` 0.405;
   `s`→`a` 0.40, `s`→`e` 0.50). Nothing to gain.
2. **Cheapest close reading first.** Fixes `vestellt` → bestellt (de: 1 → 0
   miscorrected, 16 → 17 fixed), leaves `ests` → esta, and turns the device case
   `zrreve` into `arrête` (1.356 against 1.40 for `arrive`). Trades a device fix for a
   held-out word. Dropped.

What fixing them would cost:

- `vestellt` → bestellt: one device fix, `zrreve`, which becomes `arrête`. The two
  readings differ by 0.005 in cost; only a cost-first pick tells them apart.
- `ests` kept: it has the shape of `qur` (two one-key readings, both very frequent).
  The only feature in the data that separates them is the cost gap, 0.10 for `ests`
  against 0 for `qur` and `sats` and 0.044 for `zrreve`: a threshold set between 0.044
  and 0.10 for one word. Not measured on the bench, not proposed.

### Simulator and learning

`dictus-sim-arribe-bar.png` and `dictus-sim-arribe-sats-after.png`: the Dictus
keyboard on the simulator, French, the taps of `je suis arribe tu les sats `. Before
the space the bar shows `"arribe" | arrive | arrivé` with `arrive` in bold; the text
ends as "Je suis arrive tu les sais".

A word kept as typed while the bar offered corrections is no longer counted toward
learning: `arribe`, kept twice that way on the device, had been learned, and
`areibe` then became `arribe`. A tap on the typed word and an undo still teach it
(`AutocorrectRejectionMemoryTests`).
