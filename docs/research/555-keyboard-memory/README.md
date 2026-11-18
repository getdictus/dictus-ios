# Keyboard extension memory on the simulator (#555)

Where the Dictus keyboard's memory sits when it is shown and when it types, what the
two changes on `fix/555-keyboard-memory` move, and what they do not.

Every figure is `phys_footprint` of the `DictusKeyboard` process, read with
`footprint -p <pid>` on the Mac (the number jetsam judges, and the `memMB` of the
debug log), in MiB. Release build, iPhone 17, iOS 26.5 runtime, Xcode 27.2, one
simulator dedicated to this run, slimmed with simslim, Full Access granted, the
keyboard shown in a Reminders title. 2026-11-17.

## What was measured

| Scenario | Base `2e280b7f` | This branch | |
|---|---:|---:|---|
| At rest: fresh keyboard, shown once, 30 s idle (4 runs each) | 37.2 to 37.3 | 37.0 to 37.2 | unchanged |
| 20 more appearances, no typing, then 30 s idle (2 runs each) | 39.0, 39.1 | 38.3, 38.5 | -0.6 |
| Peak over those 21 appearances | 47.6, 47.6 | 39.9, 40.1 | **-7.6** |
| Typing the last 6 French bench sentences (2 runs each) | 40.5, 39.4 | 39.5, 40.2 | unchanged |
| Peak over those French sentences | 49.2, 48.6 | 41.3, 40.8 | **-7.8** |
| Then the last 6 English sentences, then 30 s idle | 42.7, 42.5 | 42.1, 42.0 | -0.5 |
| Peak over that whole typing session | 52.7, 52.2 | 46.8, 46.7 | **-5.7** |
| Full bench typed (20 fr + 20 en sentences, 1 run each), sampled every 2 s: end of English | 43.9 | 43.0 | |
| Same session, highest 2 s sample | 44.5 | 44.4 | |
| Same session, 30 s idle at the end | 43.0 | 44.1 | |

`appearance-trials.txt` and `typing-trials.txt` are the raw lines; `before/` and
`after/` hold the full-bench sessions (`samples.tsv`: epoch, pid, bytes every 2 s;
`phases.tsv`: when each phase started). The full-bench session is one run per side
and its idle ending differs by 1 MB in the other direction, which is within what the
repeated runs show a single run can do. Its process peak (`phys_footprint_peak` in
`footprint-final.txt`) is the one figure that goes the wrong way: 48 MB on the base,
54 MB on the branch, reached between two samples, cause not found. The four
alternating typing runs did not reproduce it: their peaks put the branch 5.5 to 6 MB
lower.

**What moves is the peak, not the plateau.** Each keyboard appearance used to reload
both dictionaries, and each reload decoded a 40 000 to 50 000 word JSON file with
`JSONDecoder`, which peaks about 9.5 MB above the baseline (measured on the Mac with
`/usr/bin/time -l`: 2.5 MB doing nothing, 12.0 MB decoding `fr_frequency.json`). The
sim_replay relaunches Reminders for every sentence, so every sentence was an
appearance and a reload. On this branch an appearance with the same language and
layout reloads nothing, and a real language change parses with `JSONSerialization`,
which peaks 3.5 MB above the baseline for the same 10 000 kept words (6.1 MB in the
same Mac measurement), and the kept words cost the same once loaded (1126 KiB live
against 1124).

**The plateau does not move, and the reason is not ours to change.** See below.

## Typing results are unchanged

- In-process replay (`tools/keyboard-bench/run.sh`), both languages: the two reports
  are identical apart from the commit line and engine timings, and `taps.tsv` (time
  column aside), `commits.tsv` and `texts.tsv` are byte-identical
  (`bench-replay-before.md`, `bench-replay-after.md`).
- Real keyboard, `sim_replay.py`, 40 sentences: the 20 French sentences are identical.
  English differs in one word, sentence 14: `meef` became `meer` on the base build and
  `meet` on this one. That is the tie broken in Swift hash order that the #954 bench
  README documents (over six unseeded replays, `meef` gave `meer` four times and
  `meet` twice); the keyboard draws a new hash seed every launch.
- `DictusCore`: `testShippedFilesKeepEveryWordAboveTheCut` loads the four shipped
  frequency files with the new parser and checks every word above the 10 000th count
  against a `JSONDecoder` reference, and that every word below it is dropped. Words
  tied at the cut were already a per-process draw and are not pinned.

## Where the memory sits

Fresh keyboard, at rest, base build (37 MB):

| Category | Dirty |
|---|---:|
| Malloc Small | 16 MB (live heap 13.3 MB, 86 000 blocks) |
| `__DATA` | 10 MB, 944 images |
| `__DATA_CONST` | 6.0 to 7.0 MB, 973 images |
| page table | 1.6 MB |
| everything else | under 1 MB each |
| mapped files (tries, n-grams) | 17 MB **clean**, 0 dirty |

The linked images are a fixed cost of what the extension links: `FoundationModels`,
`Translation`, `AVFoundation`, `ActivityKit`, `CallKit`, `NaturalLanguage`, `SwiftUI`
and their dependencies load at launch whether or not the keyboard uses them.

The live heap was attributed with `MallocStackLogging=1` set in the simulator's
launchd and `malloc_history -allBySize`, grouping each live block by the innermost
frame in the keyboard binary. Almost all of it is UIKit, SwiftUI, CoreText and the
system spell checker. Our largest own items: theme fonts 1.8 MiB (mostly
`FixFontPathsForSimulator`, which a device does not run), the key views 1.2 MiB,
`viewDidLoad` 1.1 MiB, the n-gram index 1.2 MiB, the frequency dictionary 0.4 MiB.

**Typing adds 6 to 7 MB, and it is Apple's spell checker.** Live heap 13.3 MB at rest,
20.2 MB after typing both languages, +4.5 MB of it untyped blocks. The allocations
sit under `UITextChecker.completions(forPartialWordRange:in:language:)`, which
`TextPredictionEngine.suggestions(for:)` calls on every letter: ProofReader,
Lexicon and LanguageModeling loading each language's data and keeping it. The
completions are a feature, so this stays.

**A deferred step of about 5 MB at rest is the allocator.** Seconds after the first
appearance the footprint jumps from 32 to 37 MB with nothing happening, sometimes at
5 s, sometimes at 20 s. Across the jump the live heap grows by under 1 MB while
Malloc Small dirty grows by 5 MB and its reclaimable pages fall from 8.8 MB to almost
nothing: pages freed by the launch's allocations, marked reusable and not counted,
are counted again when malloc reuses their region. Because its timing varies, a
single 15-second reading can land before it; an early run of this work did, read
32.0 MB, and was wrong to credit the changes with it.

## What a simulator cannot show

No dictation and no polish run here (no model installed), and the emoji panel was not
exercised. The device sessions on the issue put dictation at +18 MB and the emoji
panel at +8 MB; neither is touched by this branch.

## Reproduce

The scripts are in `scripts/`, run from the repository root with `UDID` set to your
own booted simulator, the Dictus keyboard selected in a Reminders title, and the
in-process replay's `taps.tsv` copied to `build/m555/before-replay-out/`:

- `measure.sh <label>`: rest, the full bench in both languages, rest again, sampled
  every 2 s by `sample.sh`; `summarize.py build/m555/<label>` prints the phases.
- `trials.sh` and `typing-trials.sh`: alternate the base and branch builds copied to
  `build/m555/apps/base/` and `build/m555/apps/after/`.
