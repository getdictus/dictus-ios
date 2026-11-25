# Keyboard baseline (#954)

The first run of the [keyboard measurement protocol](../../keyboard-measurement.md),
taken 2026-11-15 on an iPhone 17 simulator, iOS 26.5, Xcode 27.2.

The keyboard code measured is develop at `3fa26bf1`. The branch that produced these
files adds only `tools/keyboard-bench/` and docs, and develop's later commits up to
`31ed6606` change version numbers and docs, no code. The reports name `d9a50547`, the
branch commit whose tool produced them.

## Files

| Path | What |
|---|---|
| `dictus-replay/` | `run.sh`: the in-process replay. `report.md` as printed, and every tap, word and sentence. |
| `apple-simulator/` | `sim_replay.py --keyboard apple`: Apple's keyboard, same taps, same rhythm. |
| `dictus-simulator/` | `sim_replay.py --keyboard dictus`: the real Dictus keyboard fed the replay's tap points. |
| `top-row-boundaries.txt` | `probe_boundaries.py`: where a tap between two Dictus top-row keys goes. |

## Dictus against Apple, same 1607 taps

| | Dictus fr | Apple fr | Dictus en | Apple en |
|---|---:|---:|---:|---:|
| Wrong words in the final text | 9 of 152 | 33 of 152 | 9 of 157 | **0** of 157 |
| Character errors, accents ignored, final text | 4 | 17 | 17 | 0 |
| Character errors, accents ignored, **before** autocorrect | 13 | 17 | 28 | n/a |

Read the rows with the simulator's one gap in mind: **Apple's French autocorrect does
not run there** (typed slowly, `tres prendrr ` stayed `Tres prendrr`), its English one
does.

- **English, end to end: Apple 0 wrong words, Dictus 9.** Same taps, both
  autocorrecting. Apple's output is exact. Dictus writes `irving` for `morning`,
  `finish` for `my`, `bone` for `hour`, `meet` for `need`, `hourglass` for
  `hour late`, and leaves `een` and `bern` for `been` and `s` for `is`.
- **French, key choice only: Dictus 13 character errors, Apple 17,** out of 801. With
  no autocorrect, Apple's final text is its key choice, compared with the Dictus text
  before autocorrect. On this simulator Apple's French key choice is no better than
  Dictus's plain hit test. Whether Apple's key-target resizing runs without its
  French language model here is not known.
- **Dictus autocorrect, French:** of 152 words, 22 typed wrong and fixed, 0 broken,
  4 miscorrected (`région` for `réunion`, `dévaler` for `décalée`, `réserve`,
  `décharge`), 5 left wrong, all 5 a missing accent (`arrive`, `trouve`, `couches`,
  `oublie`, `a` for `à`, #501).
- **Spacebar:** French 0 of 152 space taps missed, English 2 of 157. One landed on
  `v`: `hourvlate` was corrected to `hourglass` instead of split (#499). The other
  landed below the key grid, where nothing types, and the split pass recovered the
  two glued words.
- **Engine time per keystroke, replay:** French letters p50 0.11 ms, p95 0.51 ms;
  English letters p50 0.93 ms, p95 1.73 ms, about eight times the French cost on the
  same Mac. Spaces are under 0.7 ms p95 in both. Simulator numbers, for comparing runs,
  not a device figure (#591).

## The replay types what the real keyboard types

Fed the replay's own tap points, the real Dictus keyboard on the simulator wrote:

- **French: 20 of 20 sentences identical**, autocorrections included.
- **English: 15 of 20.** Every difference has a measured cause:

| Sentence | Real keyboard | Replay | Cause |
|---|---|---|---|
| 2 | `kn` | `in` | Tap at 53.99 pt in a 54 pt row; the grid top is read off pixels, a third of a point each. |
| 4 | field closed | text | A tap on return: Reminders ends the title. The replay types nothing for return. |
| 11 | `Sh` | `She` | Tap at x 120.70: inside the e/r dead band below. |
| 13 | `boy` | `bone` | Tap at x 120.19: at the edge of the same band. |
| 14 | `meer` | `meet` | A tie broken in hash order: over six unseeded replays, `meef` gave `meer` four times. |

Sentences 11 and 13 were predicted from the band table before the English run.

## Two findings about the keyboard

1. **Dead bands between top-row keys.** On 4 of the 9 boundaries of the top row, a tap
   in a band of 0.2 to 0.6 pt types nothing (`top-row-boundaries.txt`: a/z, e/r, y/u,
   i/o). The haptic fires, no letter arrives. The other 5 boundaries have none, at
   0.1 pt resolution. Seen on the simulator only; rows 2 to 4 were not probed.
2. **Ties broken in hash order.** Some corrections come out one way or another
   depending on the process's hash seed (`boue` → `blue` or `bone`, `meef` → `meer`
   or `meet`). On a device the seed changes with every keyboard launch, so the same
   typo can be corrected differently from one day to the next.

Also measured while building the protocol: `KeyTapSignposter` defines per-keystroke
signposts but nothing calls it, so a device trace holds no keystroke timing today.
