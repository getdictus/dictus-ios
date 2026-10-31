#!/usr/bin/env bash
# Measures the keyboard's split pass on the glued-word corpus (#499).
#
# Compiles the unmodified engine sources with DictusCore for the iOS Simulator
# and runs the result there with `simctl spawn`. Nothing is installed and no app
# or window is involved; the simulator only supplies UIKit, which
# TextPredictionEngine.swift imports.
#
# WHY not a test target: DictusKeyboard has no test bundle, and adding one means
# a new Xcode target. WHY not `swift test`: the engine imports UIKit and links a
# C++ trie through an Objective-C++ bridge, neither of which DictusCore's macOS
# test host has.
#
# Usage:
#   tools/split-pass-bench/run.sh --udid <booted simulator UDID> [--out <dir>]
#
# The simulator must be booted (`xcrun simctl boot <udid>` is headless). Prints the
# report on stdout; writes one row per case to <dir>/cases.tsv.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UDID=""
OUT="$ROOT/build/split-pass-bench/out"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$UDID" ]] || { echo "--udid is required" >&2; exit 2; }
xcrun simctl list devices booted | grep -q "$UDID" || { echo "simulator $UDID is not booted" >&2; exit 1; }

BUILD="$ROOT/build/split-pass-bench"
BIN="$BUILD/bin"
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios17.0-simulator"
AOSP="$ROOT/DictusKeyboard/Vendored/AOSPTrie"
mkdir -p "$BUILD/obj" "$BIN" "$OUT"

# Release settings of the DictusKeyboard target: Swift 5 mode, -O, no DEBUG
# (so AutocorrectDebugLog compiles out exactly as in a TestFlight build), C++ gnu++20.
echo "== DictusCore" >&2
xcrun swiftc -target "$TARGET" -sdk "$SDK" -swift-version 5 -O -parse-as-library \
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
xcrun swiftc -target "$TARGET" -sdk "$SDK" -swift-version 5 -O \
    -I "$BUILD" -L "$BUILD" -lDictusCore -lc++ \
    -import-objc-header "$AOSP/bridge/AOSPTrieBridge.h" \
    "$ROOT/DictusKeyboard/TextPrediction/TextPredictionEngine.swift" \
    "$ROOT/DictusKeyboard/TextPrediction/AOSPTrieEngine.swift" \
    "$ROOT/tools/split-pass-bench/main.swift" \
    "$BUILD"/obj/*.o -o "$BIN/split-pass-bench"

# The engine finds its dictionaries through Bundle.main, which for a bare
# executable is the directory it sits in.
cp "$ROOT"/DictusKeyboard/Resources/*_spellcheck.dict \
   "$ROOT"/DictusKeyboard/Resources/*_ngrams.dict \
   "$ROOT"/DictusKeyboard/Resources/*_frequency.json "$BIN/"

echo "== run on $UDID" >&2
echo "commit: $(git -C "$ROOT" rev-parse HEAD)"
xcrun simctl spawn "$UDID" "$BIN/split-pass-bench" \
    "$ROOT/DictusCore/Tests/DictusCoreTests/Fixtures/split-pass-corpus.tsv" "$OUT/cases.tsv" \
    2> >(grep -v "Lexicon creation for" >&2)
