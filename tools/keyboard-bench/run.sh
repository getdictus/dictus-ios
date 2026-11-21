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
#       [--debug] [--journal] [--lm <model.gguf>] [--lm-weights <w,w,...>] [--lm-budget-ms <ms>]
#
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
# #996: --lm turns the keyboard's language model on with a GGUF file, which needs
# llama.cpp (tools/keyboard-lm/build-llama.sh). The bench then replays once per weight of
# --lm-weights (default: the engine's) into <dir>/w<weight>/ and prints one report per
# weight. --lm-budget-ms is how long a caller waits for the model; unset, it waits for
# every answer, and taps.tsv's lm_ms column holds the model's time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UDID=""
OUT="$ROOT/build/keyboard-bench/out"
LANGS="fr,en"
WIDTH=402
HEIGHT=216
CORPUS="$ROOT/tools/keyboard-bench/corpus"
RUNS="$ROOT/tools/keyboard-bench/runs"
HIT="plain"
MODEL=""
BUILD_BENCH=1
DEBUG=0
JOURNAL=0
LM=""
LM_WEIGHTS=""
LM_BUDGET_MS=""
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
        --lm) LM="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
        --lm-weights) LM_WEIGHTS="$2"; shift 2 ;;
        --lm-budget-ms) LM_BUDGET_MS="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$UDID" ]] || { echo "--udid is required" >&2; exit 2; }
xcrun simctl list devices booted | grep -q "$UDID" || { echo "simulator $UDID is not booted" >&2; exit 1; }

BENCH="$ROOT/tools/keyboard-bench"
# A DEBUG bench has its own build directory, so the two never reuse each other's binary.
BUILD="$ROOT/build/keyboard-bench$([[ $DEBUG == 1 ]] && echo -debug || true)$([[ -n $LM ]] && echo -lm || true)"
DEFINES=()
[[ $DEBUG == 1 ]] && DEFINES=(-D DEBUG)
# With --lm, DictusCore is compiled against llama.cpp's simulator slice, as Xcode compiles
# it once build-llama.sh has run, and the bench links the library.
LLAMA_FLAGS=()
LLAMA_LINK=()
if [[ -n $LM ]]; then
    SLICE="$ROOT/DictusCore/LocalLlama/llama.xcframework/ios-arm64_x86_64-simulator"
    [[ -f $SLICE/libllama.a ]] || { echo "no llama.cpp: run tools/keyboard-lm/build-llama.sh" >&2; exit 1; }
    [[ -f $LM ]] || { echo "no model file $LM" >&2; exit 1; }
    LLAMA_FLAGS=(-I "$SLICE/Headers/llama")
    LLAMA_LINK=(-I "$SLICE/Headers/llama" "$SLICE/libllama.a" -framework Accelerate)
fi
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
    xcrun swiftc -target "$TARGET" -sdk "$SDK" -swift-version 5 -O ${DEFINES[@]+"${DEFINES[@]}"} \
        ${LLAMA_FLAGS[@]+"${LLAMA_FLAGS[@]}"} -parse-as-library \
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
        -I "$BUILD" -L "$BUILD" -lDictusCore -lc++ ${LLAMA_LINK[@]+"${LLAMA_LINK[@]}"} \
        -import-objc-header "$AOSP/bridge/AOSPTrieBridge.h" \
        "$ROOT/DictusKeyboard/TextPrediction/TextPredictionEngine.swift" \
        "$ROOT/DictusKeyboard/TextPrediction/AOSPTrieEngine.swift" \
        "$ROOT/DictusKeyboard/KeyboardLayouts.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/KeyDefinition.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/KeyboardDefinition.swift" \
        "$ROOT/DictusKeyboard/Vendored/Models/SystemKeys.swift" \
        "$BENCH/DeviceContext.swift" \
        "$BENCH/KeyTargetModel.swift" \
        "$BENCH/Journal.swift" \
        "$BENCH/main.swift" \
        "$BUILD"/obj/*.o -o "$BIN/keyboard-bench"

    # The engine finds its dictionaries through Bundle.main, which for a bare
    # executable is the directory it sits in.
    cp "$ROOT"/DictusKeyboard/Resources/*_spellcheck.dict \
       "$ROOT"/DictusKeyboard/Resources/*_ngrams.dict \
       "$ROOT"/DictusKeyboard/Resources/*_frequency.json "$BIN/"
fi
[[ -x "$BIN/keyboard-bench" ]] || { echo "no bench binary: run without --no-build first" >&2; exit 1; }

# Fixed hash seed. Some corrections are ties the engine breaks in Swift's hash order,
# which changes from one process to the next: "boue" and "meef" each came out two
# different ways over six runs (tools/keyboard-bench/README.md). With the seed fixed, a replay is repeatable and a change in
# the report is a change in the code. Drop the variable to see which words flip.
echo "== replay on $UDID" >&2
# The engine prints its load messages on stdout; they belong with the build log, not the report.
SIMCTL_CHILD_SWIFT_DETERMINISTIC_HASHING=1 SIMCTL_CHILD_KB_JOURNAL="$JOURNAL" \
SIMCTL_CHILD_KB_LM="$LM" SIMCTL_CHILD_KB_LM_WEIGHTS="$LM_WEIGHTS" SIMCTL_CHILD_KB_LM_BUDGET_MS="$LM_BUDGET_MS" \
SIMCTL_CHILD_KB_CORPUS="$CORPUS" SIMCTL_CHILD_KB_RUNS="$RUNS" SIMCTL_CHILD_KB_HIT="$HIT" SIMCTL_CHILD_KB_MODEL="$MODEL" \
    xcrun simctl spawn "$UDID" "$BIN/keyboard-bench" "$BENCH" "$LANGS" "$OUT" "$WIDTH" "$HEIGHT" \
    2> >(grep -v "Lexicon creation for" >&2) >&2

KEYBOARD="Dictus (replay, ${WIDTH}x${HEIGHT} pt grid, hit test: $HIT${MODEL:+ $MODEL}$([[ $DEBUG == 1 ]] && echo ", DEBUG, journal $([[ $JOURNAL == 1 ]] && echo on || echo off)" || true)"
if [[ -z $LM ]] || [[ ${LM_WEIGHTS//[^,]/} == "" ]]; then
    python3 -I "$BENCH/score.py" --commit "$(git -C "$ROOT" rev-parse HEAD)" \
        --keyboard "$KEYBOARD${LM:+, language model $(basename "$LM")${LM_WEIGHTS:+ w=$LM_WEIGHTS}})" --dir "$OUT"
else
    for DIR in "$OUT"/w*/; do
        python3 -I "$BENCH/score.py" --commit "$(git -C "$ROOT" rev-parse HEAD)" \
            --keyboard "$KEYBOARD, language model $(basename "$LM") $(basename "$DIR"))" --dir "$DIR"
    done
fi
