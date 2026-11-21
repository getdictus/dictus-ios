# Measuring the keyboard

The reference measurement for keyboard work (#954): wrong letters, wrong
autocorrections, missed spacebar taps and per-keystroke time, for the Dictus keyboard
and for Apple's on the same input. Any change to the key grid, autocorrect,
suggestions or the space bar (#949, #500, #501, #498, #114, #499, #591) reports these
numbers before and after.

The tool is `tools/keyboard-bench/` ([README](../tools/keyboard-bench/README.md)). The
first baseline is [`docs/research/954-keyboard-baseline/`](research/954-keyboard-baseline/README.md).

## The input

- **Corpus.** `tools/keyboard-bench/corpus/fr.txt` and `en.txt`: 20 everyday sentences
  each, written for this bench. Lowercase, no punctuation, no apostrophes, no digits.
  French keeps its accents: they are part of what autocorrect has to produce.
- **Touch runs.** `tools/keyboard-bench/runs/fr.tsv` and `en.tsv`: one row per tap.
  The typist types fast and plainly: lowercase, no accent typed (`tres` for `très`),
  one space after every word. Each tap aims at the centre of its key and lands off it
  by a Gaussian offset (sigma 0.22 key widths across, 0.18 row heights down, centred
  0.05 rows below the key centre), 170 ms apart on average. The seed is fixed and the
  files are committed, so every run sees the same 1607 taps. Offsets are in key units,
  which is what lets the same run drive keyboards whose keys are not in the same place.

- **Learned words** (#498). `corpus/fr-learned.txt` and `en-learned.txt` hold 8
  sentences each around words the dictionary does not have (`dictus`, `testflight`,
  `kubernetes`...), and `corpus/<lang>-learned.words` the user dictionary the replay
  seeds before typing them: each word with its usage count, a few learned typos of
  common words (`mzrci`, `thabks`) among them, learned once. Pass
  `--langs fr,en,fr-learned,en-learned` to `run.sh` to replay them. The `fr` and `en`
  runs start from an empty user dictionary.

The touch model is chosen, not measured. It decides how many letters go wrong before
any keyboard logic runs, so numbers are comparable between runs of the same files and
not with typing studies. Changing it (`make_runs.py`) starts a new series.

## Three ways to run it

| | In-process replay | Real keyboard, simulator | Device |
|---|---|---|---|
| Command | `run.sh` | `sim_replay.py` | typing by hand, then `score.py --typed` |
| Takes | ~2 min | ~15 min per language and keyboard | ~10 min per language and keyboard |
| Dictus | yes | yes | yes |
| Apple | no | yes; English autocorrects, French does not (below) | yes |
| Wrong letters | per tap | from the text | from the text |
| Autocorrect outcomes | per word | from the text | from the text |
| Missed spacebar | per tap, and glued words | glued words | glued words |
| Per-keystroke time | engine work, simulator | no | not yet (below) |

Use the in-process replay for every before/after on a branch. Use the simulator run
to compare with Apple, and to check that the replay still types what the real
keyboard types. Use a device run before claiming a result holds on a phone.

### 1. In-process replay

```bash
xcrun simctl boot <udid>                     # your own simulator, headless
tools/keyboard-bench/run.sh --udid <udid> > report.md
```

It compiles the keyboard's layout, the text prediction engine, the vendored C++ trie
and DictusCore from the working tree, replays both runs through them on the simulator
with `simctl spawn` (no app installed, no window), and prints the report. The
per-tap, per-word and per-sentence rows are in `build/keyboard-bench/out/`.

For a before/after, run it on both commits and diff the two reports. The replay is
repeatable: three runs in a row gave identical output, timings aside.

### 2. Real keyboard on a simulator

`sim_replay.py` types the same taps with `axe` into a Reminders title and reads the
title back. It needs the keyboard under test showing in Reminders, and Reminders past
its first-launch screens (the script's header says how).

```bash
# Apple's keyboard (French AZERTY for fr, English QWERTY for en)
python3 -I tools/keyboard-bench/sim_replay.py --udid <udid> --lang fr --keyboard apple \
    --bench tools/keyboard-bench --out build/keyboard-bench/apple-fr

# The Dictus keyboard, fed the points the in-process replay computed
python3 -I tools/keyboard-bench/sim_replay.py --udid <udid> --lang fr --keyboard dictus \
    --taps build/keyboard-bench/out/taps.tsv --grid-top 583.2 \
    --bench tools/keyboard-bench --out build/keyboard-bench/dictus-sim-fr

python3 -I tools/keyboard-bench/score.py --dir build/keyboard-bench/apple-fr --keyboard "Apple, simulator"
```

`--grid-top` is the screen y of the Dictus key grid's top edge: 583.2 pt on an iPhone
17 under iOS 26.5, read off a screenshot (the four row centres sit at 610.2, 664.2,
718.2 and 772.2). Remeasure it on another device type.

Taps keep the run's rhythm: `axe` sleeps between them for the run's own intervals.

### 3. Device

What a device adds is the real finger and the real hardware. A Release build gives no
touch points. A Debug build records them in its typing journal (#1001), with the
"Autocorrect debug logs" switch on (Settings, Developer): every tap with its key and
its offset from the key centre, every committed word with its candidates, the bar, and
what the user did next. Export the logs, then turn the session into a run and replay
it before and after a change:

```bash
python3 -I tools/keyboard-bench/journal_to_run.py dictus-logs.txt build/keyboard-bench/session
tools/keyboard-bench/run.sh --udid <udid> --langs fr-journal \
    --corpus build/keyboard-bench/session/corpus --runs build/keyboard-bench/session/runs
```

A replayed session types every tap on the key it hit on the device: checked on the
bench's own journal, 1604 of 1604 taps resolved to the same key and 306 of 307 words
came out the same; the other one was capitalised, because the converter starts a new
sentence at a return tap, as the device does. Taps on the symbols page, held-backspace
repeats and words tapped in the bar do not replay; the converter counts them.

**Accuracy.** For each keyboard (Apple's, then Dictus) and each language:

1. Open Notes, a new note.
2. Type the 20 sentences of `tools/keyboard-bench/corpus/<lang>.txt`, one per line,
   at your normal fast speed, thumbs only, looking at the sentence, not the keys. No
   backspace, no tapping a suggestion: the keyboard's own output is what is measured.
3. Copy the note into a text file on the Mac, one sentence per line.
4. Score it:

   ```bash
   python3 -I tools/keyboard-bench/score.py --typed fr:dictus-fr.txt --keyboard "Dictus, device"
   ```

A person's errors are not a seeded run: the same person on the same day gives
comparable numbers, a different day less so. Type Apple and Dictus back to back.

**Per-keystroke time: not measurable on a device today.** The keyboard defines
`touchDown` / `touchUp` signpost intervals (`KeyTapSignposter`, subsystem
`com.pivi.dictus.keyboard`, category `KeyPress`), but nothing calls them. Measured on
the simulator: a 25 s `xctrace record --template Logging --all-processes` covering 33
taps on the Dictus keyboard holds no `KeyPress` signpost. Wiring them into
`GiellaKeyboardView` and the bridge is a keyboard change and belongs to #591. Until
then, the replay's engine time is the only per-keystroke number. Once they emit:

```bash
xcrun xctrace record --template Logging --device <device udid> --all-processes \
    --time-limit 60s --output build/keyboard-bench/device.trace
xcrun xctrace export --input build/keyboard-bench/device.trace \
    --xpath '/trace-toc/run/data/table[@schema="os-signpost"]' > build/keyboard-bench/signposts.xml
```

## Reading the report

- **Wrong letter**: a tap that resolved to another key than the one aimed at.
  Keyboard geometry only; nothing downstream can change it. #949 moves this number.
- **Broken / miscorrected**: the wrong autocorrections. Broken is a correctly typed
  word that autocorrect changed; miscorrected is a mistyped word changed into another
  wrong word. These two must not go up.
- **Missed (typed wrong, kept)**, with its **accent only** part: words autocorrect
  left wrong. The accent-only column is French words like `arrivé` typed `arrive`.
- **Missed space / glued**: a space tap that landed on a letter, and whether the split
  pass recovered the two words (#499).
- **Char error rate, accents ignored**: on a keyboard whose autocorrect is off, these
  are its wrong keys. That is the column to read for Apple's French run.
- **Engine time**: the work one keystroke triggers in the text prediction engine,
  serialised on one thread. In the keyboard the letter work runs on a background
  queue and can be cancelled by the next keystroke, so this is an upper bound on that
  work and says nothing about touch handling or drawing. Compare runs on the same Mac.

## Limits

- **Apple's French autocorrect does not run on the simulator.** Measured on iOS 26.5:
  typed slowly, `tres prendrr ` stayed `Tres prendrr`, with Correction automatique on.
  Its English autocorrect does run. So the simulator gives Apple's French key choice,
  not its French autocorrect; a device run gives both.
- **The replay's grid has no dead bands; the real keyboard has some.** On the
  simulator, 4 of the 9 boundaries between top-row keys swallow a tap that lands within
  a 0.2 to 0.6 pt band, typing nothing (the a/z, e/r, y/u and i/o boundaries;
  `docs/research/954-keyboard-baseline/`). A replay tap that lands there types a letter
  in the replay and nothing on the real keyboard.
- **One keyboard state.** No contacts lexicon, no undo, no
  suggestion tapped, no shift, no symbols page. A tap on shift, return, 123 or emoji
  types nothing in the replay. On the real keyboard a tap on return ends the Reminders
  title, and `sim_replay.py` records that sentence as `[return key: field closed]`.
- **A third of a point.** `--grid-top` is read off pixels, a third of a point each. A
  replay tap that close to a row boundary can land in the other row on the real
  keyboard: one English tap at 53.99 pt in a 54 pt row typed `k` for `i`.
- **Ties.** Until #993, some corrections were ties broken in hash order, which a device
  redraws on every keyboard launch. They are now broken by cost, then by word: four
  unseeded replays gave byte-identical commits
  ([`research/993-autocorrect-confidence/`](research/993-autocorrect-confidence/README.md)).
  The replay still pins the seed; unset `SWIFT_DETERMINISTIC_HASHING` in `run.sh` to
  check that nothing flips.
- **Simulator timing is not device timing**, and is only comparable on the same Mac.
