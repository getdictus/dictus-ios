#!/usr/bin/env bash
# Measures the French a/à rule (#501) on Tatoeba's French sentences, on the Mac.
#
# Usage: tools/a-grave-eval/run.sh [--show-wrong N]
#
# Downloads the sentences once into build/a-grave-eval (CC BY 2.0 FR, tatoeba.org),
# compiles DictusCore from the working tree and prints the table.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/build/a-grave-eval"
CORPUS="$BUILD/fra_sentences.tsv"
mkdir -p "$BUILD"

if [[ ! -s "$CORPUS" ]]; then
    curl -sfL -o "$CORPUS.bz2" "https://downloads.tatoeba.org/exports/per_language/fra/fra_sentences.tsv.bz2"
    bunzip2 -f "$CORPUS.bz2"
fi

SOURCES=()
while IFS= read -r source; do SOURCES+=("$source"); done \
    < <(find "$ROOT/DictusCore/Sources/DictusCore" -name '*.swift' | sort)
xcrun swiftc -swift-version 5 -O -parse-as-library \
    -module-name DictusCore -emit-module -emit-module-path "$BUILD/DictusCore.swiftmodule" \
    -emit-library -static -o "$BUILD/libDictusCore.a" "${SOURCES[@]}"
xcrun swiftc -swift-version 5 -O -I "$BUILD" -L "$BUILD" -lDictusCore \
    "$ROOT/tools/a-grave-eval/main.swift" -o "$BUILD/a-grave-eval"

echo "corpus: $(wc -l < "$CORPUS" | tr -d ' ') Tatoeba sentences, $(date -r "$CORPUS" +%Y-%m-%d)"
"$BUILD/a-grave-eval" "$CORPUS" "$@"
