#!/usr/bin/env bash
# Replays the touch runs through the Dictus keyboard and prints the report (#954).
#
# Compiles the unmodified layout and engine sources with DictusCore for the iOS
# Simulator and runs the result there with `simctl spawn`, the way
# tools/split-pass-bench does. Nothing is installed and no window opens; the
# simulator only supplies UIKit, which the layout and engine sources import.
#
# Usage:
#   tools/keyboard-bench/run.sh --udid <booted simulator UDID> [--out <dir>]
#       [--langs fr,en] [--width 402] [--height 216]
#       [--corpus <dir>] [--runs <dir>] [--hit plain|model] [--model <spec>] [--no-build]
#       [--debug] [--journal] [--spatial] [--spatial-tune <k=v,...>] [--layout azerty|qwerty|qwertz]
#       [--pair fr,en [--probe <word,previous|word,...>]] [--bilingual] [--lexicon a,ma]
#
# --lexicon loads those words as contacts / text replacements (#873), the way an iPhone
# hands its lexicon to the keyboard. The default is none, as on a fresh simulator.
# --width and --height are the key grid in points. The defaults are an iPhone 17
# held upright: 402 pt wide, and the 216 pt KeyboardHeightProvider gives a 6.3" screen.
# Writes taps.tsv, commits.tsv and texts.tsv to <dir>; prints the report on stdout.
#
# #949 spike: --corpus and --runs replay other runs than the committed ones, --hit model
# picks each letter with tools/keyboard-bench/KeyTargetModel.swift instead of today's hit
# test, --model sets its parameters (`sx=0.25,sy=0.25,core=0.25,w=1,floor=0.1,ngram=1,nw=1`),
# and --no-build reuses the binary the previous run compiled.
#
# #1001: --debug compiles DictusCore, the engine and the bench with DEBUG, as a Debug
# build of the keyboard is, so the typing journal exists; its toggle stays off.
# --journal turns the toggle on and writes the journal of the replay to <dir>/journal.log.
# The two give the journal's cost (taps.tsv's journal_ns) and show that it changes
# nothing the keyboard types (commits.tsv and texts.tsv identical).
#
# #1011: --spatial turns on the spatial decoder, as its Debug switch does in the keyboard:
# the space bar reads each word's taps before the trie reads its letters. --spatial-tune
# changes Hex's parameters for a sweep (`validMargin=inf`); see main.swift. --layout replays
# every language on that layout, for a device journal typed on another layout than the
# language's default; the bench puts the App Group's layouts back when it ends. With
# --pair, --spatial reads the taps in every policy (#1015: the pair replay runs the
# spatial decoder, so #1010's refusal of --pair with --spatial is lifted); each pair run
# still names its layout in --langs.
# #1009: --pair replays a bilingual keyboard (primary,secondary): every run under the
# primary alone, the secondary alone, and language detection. --langs then takes corpus
# names with an optional layout (`en:qwerty`; default the primary's), and defaults to
# fr, en:qwerty, en, mixed, mixed-heldout and mixed-heldout-2. Writes pair.tsv and pair-cost.tsv and
# prints score_pair.py's report. --probe prints what both dictionaries answer for single
# words instead of replaying.
#
# #1015: --pair also replays the bilingual check (policy `check`), and with --spatial
# every policy reads the taps. --bilingual types the monolingual runs on the bilingual
# check, the run's language primary and the other of French and English its partner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UDID=""
OUT="$ROOT/build/keyboard-bench/out"
LANGS=""
WIDTH=402
HEIGHT=216
CORPUS="$ROOT/tools/keyboard-bench/corpus"
RUNS="$ROOT/tools/keyboard-bench/runs"
HIT="plain"
MODEL=""
BUILD_BENCH=1
DEBUG=0
JOURNAL=0
SPATIAL=0
SPATIAL_TUNE=""
LAYOUT=""
PAIR=""
PROBE=""
BILINGUAL=0
LEXICON=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --langs) LANGS="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --corpus) CORPUS="$(cd "$2" && pwd)"; shift 2 ;;
        --runs) RUNS="$(cd "$2" && pwd)"; shift 2 ;;
        --hit) HIT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --no-build) BUILD_BENCH=0; shift ;;
        --debug) DEBUG=1; shift ;;
        --journal) DEBUG=1; JOURNAL=1; shift ;;
        --spatial) SPATIAL=1; shift ;;
        --layout) LAYOUT="$2"; shift 2 ;;
        --spatial-tune) SPATIAL_TUNE="$2"; shift 2 ;;
        --pair) PAIR="$2"; shift 2 ;;
        --probe) PROBE="$2"; shift 2 ;;
        --bilingual) BILINGUAL=1; shift ;;
        --lexicon) LEXICON="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$UDID" ]] || { echo "--udid is required" >&2; exit 2; }
if [[ -z "$LANGS" ]]; then
    if [[ -n "$PAIR" ]]; then LANGS="fr,en:qwerty,en,mixed,mixed-heldout,mixed-heldout-2"; else LANGS="fr,en"; fi
fi
xcrun simctl list devices booted | grep -q "$UDID" || { echo "simulator $UDID is not booted" >&2; exit 1; }

BENCH="$ROOT/tools/keyboard-bench"
# A DEBUG bench has its own build directory, so the two never reuse each other's binary.
BUILD="$ROOT/build/keyboard-bench$([[ $DEBUG == 1 ]] && echo -debug || true)"
DEFINES=()
[[ $DEBUG == 1 ]] && DEFINES=(-D DEBUG)
BIN="$BUILD/bin"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios17.0-simulator"
AOSP="$ROOT/DictusKeyboard/Vendored/AOSPTrie"
mkdir -p "$BUILD/obj" "$BIN" "$OUT"
# The spawned process does not run in this directory: hand it an absolute path.
OUT="$(cd "$OUT" && pwd)"

if [[ $BUILD_BENCH == 1 ]]; then
    # Release settings of the DictusKeyboard target: Swift 5 mode, -O, no DEBUG, C++ gnu++20.
    echo "== DictusCore" >&2
    xcrun swiftc -target "$TARGET" -sdk "$SDK" -swift-version 5 -O ${DEFINES[@]+"${DEFINES[@]}"} -parse-as-library \
        -module-name DictusCore -emit-module -emit-module-path "$BUILD/DictusCore.swiftmodule" \
        -emit-library -static -o "$BUILD/libDictusCore.a" \
        $(find "$ROOT/DictusCore/Sources/DictusCore" -name '*.swift' | sort) 2>"$BUILD/dictuscore.log" \
        || { cat "$BUILD/dictuscore.log" >&2; exit 1; }

    echo "== AOSP trie" >&2
    for src in "$AOSP"/src/*.cpp "$AOSP/bridge/AOSPTrieBridge.mm"; do
        xcrun clang++ -target "$TARGET" -isysroot "$SDK" -std=gnu++20 -fobjc-arc -Os -w \
            -I "$AOSP/include" -I "$AOSP/bridge" -c "$src" -o "$BUILD/obj/$(basename "$src").o"
    done

    echo "== bench" >&2
    xcrun swiftc -target "$TARGET" -sdk "$SDK" -swift-version 5 -O ${DEFINES[@]+"${DEFINES[@]}"} \
        -I "$BUILD" -L "$BUILD" -lDictusCore -lc++ \
        -import-objc-header "$AOSP/bridge/AOSPTrieBridge.h" \
        "$ROOT/DictusKeyboard/TextPrediction/TextPredictionEngine.swift" \
        "$ROOT/DictusKeyboard/TextPrediction/AOSPTrieEngine.swift" \
        "$ROOT/DictusKeyboard/TextPrediction/SpatialAutocorrect.swift" \
        "$ROOT/DictusKeyboard/TextPrediction/BilingualAutocorrect.swift" \
        "$ROOT/DictusKeyboard/TextPrediction/TrieLanguageEvidence.swift" \
        "$ROOT/DictusKeyboard/KeyboardLayouts.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/KeyDefinition.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/KeyboardDefinition.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/SystemKeys.swift" \
        "$BENCH/DeviceContext.swift" \
        "$BENCH/KeyTargetModel.swift" \
        "$BENCH/Journal.swift" \
        "$BENCH/Bilingual.swift" \
        "$BENCH/main.swift" \
        "$BUILD"/obj/*.o -o "$BIN/keyboard-bench"

    # The engine finds its dictionaries through Bundle.main, which for a bare
    # executable is the directory it sits in.
    cp "$ROOT"/DictusKeyboard/Resources/*_spellcheck.dict \
       "$ROOT"/DictusKeyboard/Resources/*_ngrams.dict \
       "$ROOT"/DictusKeyboard/Resources/*_frequency.json \
       "$ROOT"/DictusKeyboard/Resources/*.hextm "$BIN/"
fi
[[ -x "$BIN/keyboard-bench" ]] || { echo "no bench binary: run without --no-build first" >&2; exit 1; }

# Fixed hash seed. Some corrections are ties the engine breaks in Swift's hash order,
# which changes from one process to the next: "boue" and "meef" each came out two
# different ways over six runs (tools/keyboard-bench/README.md). With the seed fixed, a replay is repeatable and a change in
# the report is a change in the code. Drop the variable to see which words flip.
echo "== replay on $UDID" >&2
# The engine prints its load messages on stdout; they belong with the build log, not the report.
if [[ -n "$PAIR" ]]; then
    export SIMCTL_CHILD_SWIFT_DETERMINISTIC_HASHING=1 SIMCTL_CHILD_KB_CORPUS="$CORPUS" SIMCTL_CHILD_KB_RUNS="$RUNS" \
        SIMCTL_CHILD_KB_PAIR="$PAIR" SIMCTL_CHILD_KB_SPATIAL="$SPATIAL" SIMCTL_CHILD_KB_LAYOUT="$LAYOUT" \
        SIMCTL_CHILD_KB_SPATIAL_TUNE="$SPATIAL_TUNE" SIMCTL_CHILD_KB_TRACE="${KB_TRACE:-0}"
    if [[ -n "$PROBE" ]]; then
        # The probe's table is the output: only the engine's messages start with "[".
        SIMCTL_CHILD_KB_PROBE="$PROBE" xcrun simctl spawn "$UDID" "$BIN/keyboard-bench" "$BENCH" "$LANGS" "$OUT" \
            "$WIDTH" "$HEIGHT" 2> >(grep -v "Lexicon creation for" >&2) | grep -v '^\['
        exit 0
    fi
    xcrun simctl spawn "$UDID" "$BIN/keyboard-bench" "$BENCH" "$LANGS" "$OUT" "$WIDTH" "$HEIGHT" \
        2> >(grep -v "Lexicon creation for" >&2) >&2
    python3 -I "$BENCH/score_pair.py" --commit "$(git -C "$ROOT" rev-parse HEAD)" --pair "$PAIR" --dir "$OUT"
    exit 0
fi
SIMCTL_CHILD_SWIFT_DETERMINISTIC_HASHING=1 SIMCTL_CHILD_KB_JOURNAL="$JOURNAL" \
SIMCTL_CHILD_KB_SPATIAL="$SPATIAL" SIMCTL_CHILD_KB_LAYOUT="$LAYOUT" SIMCTL_CHILD_KB_SPATIAL_TUNE="$SPATIAL_TUNE" \
SIMCTL_CHILD_KB_BILINGUAL="$BILINGUAL" SIMCTL_CHILD_KB_TRACE="${KB_TRACE:-0}" \
SIMCTL_CHILD_KB_CORPUS="$CORPUS" SIMCTL_CHILD_KB_RUNS="$RUNS" SIMCTL_CHILD_KB_HIT="$HIT" SIMCTL_CHILD_KB_MODEL="$MODEL" \
SIMCTL_CHILD_BENCH_LEXICON="$LEXICON" \
    xcrun simctl spawn "$UDID" "$BIN/keyboard-bench" "$BENCH" "$LANGS" "$OUT" "$WIDTH" "$HEIGHT" \
    2> >(grep -v "Lexicon creation for" >&2) >&2

python3 -I "$BENCH/score.py" --commit "$(git -C "$ROOT" rev-parse HEAD)" \
    --keyboard "Dictus (replay, ${WIDTH}x${HEIGHT} pt grid, hit test: $HIT${MODEL:+ $MODEL}$([[ $SPATIAL == 1 ]] && echo ", spatial decoder${SPATIAL_TUNE:+ $SPATIAL_TUNE}" || true)$([[ $BILINGUAL == 1 ]] && echo ", bilingual check" || true)$([[ $DEBUG == 1 ]] && echo ", DEBUG, journal $([[ $JOURNAL == 1 ]] && echo on || echo off)" || true))" --dir "$OUT"
