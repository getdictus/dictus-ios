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
| `corpus/mixed.txt`, `corpus/mixed.lang`, `runs/mixed.tsv` | 20 sentences that mix French and English, the gold language of every word (`f` or `e`), and their touch run (#1009). The run the bilingual detection was designed on in #1007. |
| `corpus/mixed-heldout.txt`, `corpus/mixed-heldout.lang`, `runs/mixed-heldout.tsv` | 20 more mixed sentences, written before the bilingual replay first ran. Nothing is ever tuned on them: a change judged on this run needs a new held-out run. #1015's rules were changed after it was read, so for the bilingual check it is a second tuning run. |
| `corpus/mixed-heldout-2.txt`, `corpus/mixed-heldout-2.lang`, `runs/mixed-heldout-2.tsv` | 20 mixed sentences written for #1015 and committed before the bilingual check first typed them (`192f660d`). The held-out run of the check's final rules. |
| `Bilingual.swift` + `score_pair.py` | The bilingual replay (`run.sh --pair fr,en`): the same taps through one engine per language and the DictusCore language detection, then its report. |

## Run

```bash
xcrun simctl boot <udid>                    # headless; your own simulator
tools/keyboard-bench/run.sh --udid <udid> > report.md
```

About two minutes, most of it compiling DictusCore. Writes `taps.tsv`, `commits.tsv`
and `texts.tsv` to `build/keyboard-bench/out/` and prints the report.

## Bilingual replay (#1009)

```bash
tools/keyboard-bench/run.sh --udid <udid> --pair fr,en > report.md
```

Replays `fr`, `en` on QWERTY, `en`, `mixed`, `mixed-heldout` and `mixed-heldout-2` (the layout is the
primary's, AZERTY here, unless `--langs` gives one as `en:qwerty`). Each run goes through
four keyboards on the same taps:

- `mono-fr` and `mono-en`: today's keyboard set to one language, one engine.
- `detect`: two engines, one per language, both loaded for the run's layout. At every
  space, `WordLanguageVote` scores the word, `LanguageWindow` decides the language, that
  language's engine corrects the word, and `BilingualKeepRule` may keep it as typed.
  Letters ask the window's language only. The window carries over from one sentence to
  the next and starts each run in the primary language.
- `check` (#1015): the keyboard's bilingual check, `BilingualKeyboard` in
  `DictusKeyboard/TextPrediction/BilingualAutocorrect.swift`, compiled as shipped. The same
  window, then `BilingualCheck` in DictusCore: the keep rules, Hex's fallback to the other
  language and its tie-break by the last four words. It reads the engines' own tries, not
  a second copy, and asks the full `correctionProposal` of each engine, so with
  `--spatial` both decoders read the same taps (the `mono-*` keyboards read them too;
  `detect` keeps #1010's spell check, without taps).

The keystroke work is the in-process replay's, through the same `replay`. The vote reads
a second trie per language, mounted from the same files as the engine's, which keeps its
own private. Writes `pair.tsv` (one row per committed word: gold and decided language,
intended, typed, final) and `pair-cost.tsv`, and prints the report: wrong words per run
and keyboard, the language decided per word, the words left wrong, and the time per
keystroke.

`--bilingual` types the monolingual runs (no `--pair`) on the bilingual check, the run's
language primary and the other of French and English its partner, as the keyboard's Debug
switch does: `run.sh --spatial --bilingual --langs fr,en` against `run.sh --spatial --langs fr,en`
is the check's monolingual guard, with `score.py`'s report. `KB_TRACE=1` before `run.sh`
prints each word the check commits on stderr: `TRACE <language> <rule> <typed> -> <written>`.

The report also counts, per run and keyboard, the words typed right (the letters that
reached the field are the intended word) that the keyboard changed, by the word's language:
French words broken by the English keyboard, and English words by the French one.

`--probe "word,previous|word"` prints what both dictionaries answer for single words
(log-frequency, expansions, correction, bigram) and the vote, without replaying. The
detection tests' dictionaries (`DictusCore/Tests/DictusCoreTests/LanguageDetectionStubs.swift`)
were read off it.

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
