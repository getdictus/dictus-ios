#!/usr/bin/env bash
# The #949 spike in one command: replays fast typing through today's hit test and through
# the key-target model (KeyTargetModel.swift), and prints the comparison tables
# docs/research/949-key-targets/ reports.
#
# Run sets, all drawn by make_runs.py with fixed seeds, so every table is repeatable:
#   committed  the #954 runs (seed 954): the set the model's parameters were chosen on
#   held-out   the same corpus, seed 949, 10 passes: the set the verdict is read on
#   sloppy     the same corpus, seed 950, 5 passes, sigma 0.30 x 0.25: a less precise typist
#   rare       corpus-rare (words the dictionary lacks or ranks low), seed 949, 5 passes
#
# Usage:
#   tools/keyboard-bench/key_targets.sh --udid <booted simulator UDID> [--model <spec>] [--sets committed,held-out]
#       [--no-build]   reuse the binary a previous run compiled
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH="$ROOT/tools/keyboard-bench"
WORK="$ROOT/build/key-targets"
UDID=""
MODEL=""
SETS="committed,held-out,sloppy,rare"
BUILD=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --sets) SETS="$2"; shift 2 ;;
        --no-build) BUILD="--no-build"; shift ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n "$UDID" ]] || { echo "--udid is required" >&2; exit 2; }

make_runs() { python3 -I "$BENCH/make_runs.py" "$@" >/dev/null; }
mkdir -p "$WORK"
make_runs --corpus "$BENCH/corpus" --out "$WORK/runs-held-out" --seed 949 --passes 10
make_runs --corpus "$BENCH/corpus" --out "$WORK/runs-sloppy" --seed 950 --passes 5 --sigma-x 0.30 --sigma-y 0.25
make_runs --corpus "$BENCH/corpus-rare" --out "$WORK/runs-rare" --seed 949 --passes 5

# Build once, with the first replay; the others reuse the binary.
build="$BUILD"
for set in ${SETS//,/ }; do
    case "$set" in
        committed) corpus="$BENCH/corpus"; runs="$BENCH/runs" ;;
        held-out|sloppy) corpus="$BENCH/corpus"; runs="$WORK/runs-$set" ;;
        rare) corpus="$BENCH/corpus-rare"; runs="$WORK/runs-rare" ;;
        *) echo "unknown set: $set" >&2; exit 2 ;;
    esac
    for hit in plain model; do
        mkdir -p "$WORK/$set/$hit"
        "$BENCH/run.sh" --udid "$UDID" --out "$WORK/$set/$hit" --corpus "$corpus" --runs "$runs" \
            --hit "$hit" --model "$MODEL" $build > "$WORK/$set/$hit/report.md" 2> "$WORK/$set/$hit/log.txt" \
            || { tail -20 "$WORK/$set/$hit/log.txt" >&2; exit 1; }
        build="--no-build"
    done
    python3 -I "$BENCH/compare_hits.py" --plain "$WORK/$set/plain" --model "$WORK/$set/model" --title "$set${MODEL:+ ($MODEL)}" \
        --bands "$ROOT/docs/research/954-keyboard-baseline/top-row-boundaries.txt"
done
