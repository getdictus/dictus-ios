# Keyboard bench (#954)

Measures the Dictus keyboard on fast typing, and Apple's keyboard on the same taps.
Measurement only: it runs the keyboard code as it ships and changes nothing.

The protocol (what to run when, how to read the numbers, what each run can and cannot
show) is [`docs/keyboard-measurement.md`](../../docs/keyboard-measurement.md). This
file says what each piece is.

## Pieces

| File | What it is |
|---|---|
| `corpus/fr.txt`, `corpus/en.txt` | 20 everyday sentences per language, the text the typist means. Lowercase, no punctuation. |
| `register.tsv` | Real autocorrect cases reported on #500: the text before the word, the word as typed, what was meant. Committed by the same space-bar path as the runs. |
| `corpus/es.txt`, `corpus/de.txt` | The same for Spanish and German: 20 sentences each from [Tatoeba](https://tatoeba.org) (CC BY 2.0 FR), written by self-declared native speakers. Sources and checks: [`docs/research/multilingual-autocorrect/corpus.md`](../../docs/research/multilingual-autocorrect/corpus.md). |
| `corpus/<lang>-typos.txt`, `corpus/<lang>-typos.keys` | Typo runs for en, es, de: 20 Tatoeba sentences each (`.txt`, what the typist means) and what a typist who makes the language's frequent real mistakes types (`.keys`). |
| `make_typos.py` | Writes the `.keys` files from the `.txt` files and the typo pairs of `docs/research/multilingual-autocorrect/typos-<lang>.tsv`. Deterministic. |
| `make_runs.py` | Turns the corpus into touch runs, with a fixed seed. Rerunning it rewrites the same files byte for byte. A typo run's taps land on the key centres. |
| `corpus/<lang>-learned.txt`, `corpus/<lang>-learned.words` | 8 sentences per language around words the user taught the keyboard, and the learned words the replay seeds before typing them, with their usage counts (#498). |
| `runs/<lang>.tsv` | One row per tap: the key aimed at, where the finger lands relative to its centre (in key units), and when. Committed for fr, en, es, de, the learned runs and the typo runs. |
| `run.sh` + `main.swift` + `DeviceContext.swift` | The in-process replay: compiles the shipping layout and engine sources, replays the runs on a simulator with `simctl spawn`, and prints the report. |
| `sim_replay.py` | Types the runs on a real keyboard in a simulator, Apple's or Dictus, through `axe`, and reads the text back. |
| `probe_boundaries.py` | Sweeps taps across each boundary of the Dictus top row on the real keyboard and prints where a tap types nothing. |
| `score.py` | The report, for every source: a replay directory, a simulator run, or text pasted from a device. |
| `corpus-rare/fr.txt`, `corpus-rare/en.txt` | 20 sentences per language around words the dictionary lacks or ranks low (#949): what a language model must not break. |
| `KeyTargetModel.swift` | The #949 key-target model: picks each letter from the touch point and the letter the word needs next, from the shipped trie. `run.sh --hit model` uses it instead of the plain hit test. |
| `journal_to_run.py` | Turns a typing journal exported from a Debug build (#1001) into `runs/<lang>-journal.tsv` and `corpus/<lang>-journal.txt`, so a session typed on a device replays here. Tests: `python3 -I -m unittest discover -s tools/keyboard-bench/tests`. |
| `Journal.swift` | The typing journal's calls during a replay, at the moments the keyboard makes them. Only a bench built with `run.sh --debug` has the journal: `--journal` turns it on, writes `journal.log` beside the report, and adds the journal's cost per tap to it. |
| `key_targets.sh` + `compare_hits.py` | The #949 spike in one command: draws held-out runs, replays them through both hit tests, and compares them tap by tap. Results: [`docs/research/949-key-targets/`](../../docs/research/949-key-targets/README.md). |

## Run

```bash
xcrun simctl boot <udid>                    # headless; your own simulator
tools/keyboard-bench/run.sh --udid <udid> > report.md
```

About two minutes, most of it compiling DictusCore. Writes `taps.tsv`, `commits.tsv`,
`texts.tsv` and `register.tsv` to `build/keyboard-bench/out/` and prints the report.

## What the replay runs

For each tap, `main.swift`:

1. places it on the letter page of the language's default layout
   (`KeyboardLayouts.current`), laid out as `GiellaKeyboardView` lays it out on a
   402 x 216 pt grid (iPhone 17 upright). The grid arithmetic is the one restated
   piece: the collection view itself cannot run outside a keyboard. Its key centres
   were checked against a screenshot of the real keyboard, within a pixel;
2. types the key it hits into a text buffer. The AZERTY accent key goes through
   `FrenchAdaptiveKey`, as in `DictusKeyboardBridge.handleAdaptiveAccentKey`;
3. on a letter, runs the suggestion work `SuggestionState.updateAsync` runs
   (`spellCheck` when a correction may be previewed, then `suggestions(for:)`), and
   times it;
4. on a space, runs what `DictusKeyboardBridge.autocorrectBeforeCursor` runs:
   `wordAtCursor`, `spellCheck` with the previous word and the sentence position,
   `AutocorrectRejectionMemory.commit`, `AutocorrectCountingSite.apply`, then the
   next-word prediction, and times it.

Everything in steps 2 to 4 is the shipping code, compiled from the repository.

Step 4 also records the next-word predictions the bar would show after the space, and
the report scores them against the word the typist types next.

## Languages

`run.sh --langs fr,en,es,de` replays the four languages on their default layouts:
AZERTY, QWERTY, QWERTY (the same page as English, no `ñ` key) and QWERTZ (with `ü`,
`ö`, `ä`, no `ß`). The typist types no accent or tilde, types the umlauts the QWERTZ
page has, and types `ss` for `ß`. `--langs en-typos,es-typos,de-typos` replays the typo
runs. The QWERTZ grid, whose first two rows hold 11 keys, has not been checked against
the real keyboard the way the French grid was.

Apple's keyboard autocorrects only in English on the simulator: the iOS 26.5, 27.0 and
27.2 simulator runtimes ship English language data (`RequiredAssets_en.bundle`, 97 MB)
and empty bundles for Spanish, German and French (4 KB each). For those three,
`sim_replay.py --keyboard apple` measures Apple's key choice only.

## Repeatability

Three replays in a row give byte-identical `taps.tsv` (time column aside),
`commits.tsv` and `texts.tsv`. Two things had to be pinned for that:

- **The hash seed.** Some corrections are ties the engine breaks in Swift's hash
  order, which changes with every process. Over six unseeded English replays, `boue`
  became `blue` four times and `bone` twice, and `meef` became `meer` four times and
  `meet` twice; the real keyboard on the simulator wrote `meer` where the seeded
  replay writes `meet`. `run.sh` sets `SWIFT_DETERMINISTIC_HASHING=1`. Unset it to see
  which words flip; on a device, every keyboard launch is a new draw.
- **The initial load.** The engine loads French when it is created; switching
  language before that load lands overlaps two loads. The replay waits for it.

## Checked against the real keyboard

`sim_replay.py --keyboard dictus` sends the replay's own tap points to the Dictus
keyboard in a simulator. On the French run, the 20 sentences the real keyboard wrote
are the 20 the replay wrote, autocorrections included (2026-11-15, iOS 26.5, iPhone 17).

Getting there corrected the grid once. The first version laid the keys out left to
right with no gap; the real flow layout spreads the row's leftover point between the
keys, which moves them up to 1 pt right. The drawn key centres settle it: they match
the spread layout to within a pixel.

Where the two still differ: `probe_boundaries.py` found 4 of the 9 top-row boundaries
swallowing taps in a 0.2 to 0.6 pt band. The replay has no such bands, so a replay tap
that lands in one types a letter that the real keyboard does not.
