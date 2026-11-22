#!/usr/bin/env bash
# Checks that the typing journal (#1001) is absent from a Release binary: no symbol of
# its types, no line it writes, no control of it. It exists only under `#if DEBUG`.
#
# Usage:
#   scripts/check-journal-release.sh <Release products dir>   # DictusApp.app and its keyboard
#   scripts/check-journal-release.sh --debug <Debug products dir>  # the same names ARE there
#
# Build the products first, for instance:
#   xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -configuration Release \
#       -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO -derivedDataPath build/DerivedData-release
#   scripts/check-journal-release.sh build/DerivedData-release/Build/Products/Release-iphoneos
#
# The --debug form is the control: a check that finds nothing in the Debug build would
# prove nothing about the Release one.
set -euo pipefail

EXPECT_PRESENT=0
if [[ "${1:-}" == "--debug" ]]; then EXPECT_PRESENT=1; shift; fi
PRODUCTS="${1:?usage: check-journal-release.sh [--debug] <products dir>}"

APP="$PRODUCTS/DictusApp.app"
BINARIES=("$APP/DictusApp" "$APP/PlugIns/DictusKeyboard.appex/DictusKeyboard")
for b in "${BINARIES[@]}"; do [[ -f "$b" ]] || { echo "missing binary: $b" >&2; exit 2; }; done

# Symbols: the journal's types, demangled. Strings: what it writes and its button.
SYMBOLS='TypingJournal'
STRINGS='TJ TAP|TJ WORD|TJ FIELD|TJ REACT|TJ BARTAP|Clear typing journal|com\.pivi\.dictus\.typingjournal'

status=0
for b in "${BINARIES[@]}"; do
    name="${b#"$PRODUCTS"/}"
    # A Debug build keeps its code in <binary>.debug.dylib beside a stub executable.
    files=("$b")
    [[ -f "$b.debug.dylib" ]] && files+=("$b.debug.dylib")
    # Read first, counted after: a failing nm or strings must stop the check, not read as zero.
    symtab=$(for f in "${files[@]}"; do xcrun nm -a "$f" || exit 1; done | xcrun swift-demangle) \
        || { echo "nm failed on $name" >&2; exit 2; }
    text=$(for f in "${files[@]}"; do strings -a "$f" || exit 1; done) || { echo "strings failed on $name" >&2; exit 2; }
    [[ -n "$symtab" && -n "$text" ]] || { echo "nothing read from $name" >&2; exit 2; }
    symbols=$(grep -c -E "$SYMBOLS" <<<"$symtab" || true)
    strings=$(grep -c -E "$STRINGS" <<<"$text" || true)
    echo "$name (${#files[@]} file(s)): $symbols journal symbols, $strings journal strings"
    if [[ $EXPECT_PRESENT == 1 ]]; then
        [[ $symbols -gt 0 && $strings -gt 0 ]] || status=1
    else
        [[ $symbols -eq 0 && $strings -eq 0 ]] || status=1
    fi
done

if [[ $status == 0 ]]; then
    [[ $EXPECT_PRESENT == 1 ]] && echo "PASS: the Debug build carries the journal" || echo "PASS: no journal in the Release build"
else
    [[ $EXPECT_PRESENT == 1 ]] && echo "FAIL: the Debug build should carry the journal" || echo "FAIL: the Release build carries the journal"
fi
exit $status
