# Split-pass bench (#499)

Measures how often the keyboard's split pass turns a glued word back into the two
words that were meant ("motsuivant" → "mot suivant"), and how often it cuts a real
word in two. Measurement only: it runs the engine as it ships and changes nothing.

## Run

```bash
xcrun simctl boot <udid>      # headless; any iOS 17+ simulator
tools/split-pass-bench/run.sh --udid <udid> > report.md
```

About two minutes: one to compile DictusCore, a few seconds to measure. The report
(markdown tables, then every case that did not come out right) goes to stdout; one row
per case goes to `build/split-pass-bench/out/cases.tsv`.

## What it runs

`run.sh` compiles, for the iOS Simulator and with the Release settings of the
keyboard target (no `DEBUG`):

- `DictusCore/Sources/DictusCore`, as a static library;
- the vendored C++ trie and its Objective-C++ bridge (`DictusKeyboard/Vendored/AOSPTrie`);
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` and `AOSPTrieEngine.swift`,
  unmodified;
- `main.swift`, the bench.

and runs the binary with `xcrun simctl spawn`. The dictionaries are copied next to the
binary, where `Bundle.main` finds them. No app is installed and no window opens.

Each case goes through `TextPredictionEngine.shared.spellCheck(_:previousWord:isAtSentenceStart:)`,
the call the space bar makes (`DictusKeyboardBridge.autocorrectBeforeCursor`), once
mid-sentence and once autocapitalised at the start of a field. The word's language is
activated first, so the layout, and with it the spacebar neighbours, is that
language's default.

A second trie loaded from the same files answers the questions that explain a miss
(is each half a word, is there a bigram, are the left word's 16 n-gram slots full).
It never decides an outcome.

## Corpus

`DictusCore/Tests/DictusCoreTests/Fixtures/split-pass-corpus.tsv`, built by
`make_corpus.py` (its header says from what). `SplitPassCorpusTests` checks its
format in `swift test`; the bench itself needs a simulator and does not run in CI.

## Limits

- No previous word is passed, so the bigram rerank of single-word corrections
  never runs.
- The contacts and text-replacements lexicon (#873) is empty, and so is the user
  dictionary of a fresh simulator: neither can decide anything here.
- Typed strings are exact. A real glue often carries a typo as well.

## Baseline

`docs/research/499-split-pass/` holds the first capture, taken on develop
`61adacf2` (2026-10-31): the report as printed and the per-case rows.
