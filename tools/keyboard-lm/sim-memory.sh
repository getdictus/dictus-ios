#!/usr/bin/env bash
# Measures the Dictus keyboard's memory with the language model off or on, in a simulator (#996).
#
# Usage:
#   tools/keyboard-lm/sim-memory.sh --udid <udid> --model <file.gguf | none> --taps <taps.tsv> \
#       --out <dir> [--sentences 5] [--grid-top 583.2]
#
# Needs a booted simulator with a Debug build of DictusApp installed, the Dictus keyboard
# enabled with Full Access, and Reminders already showing it (long-press the globe once,
# pick Dictus). --taps is a taps.tsv the in-process replay wrote for the French run.
#
# Turns the model on with the Debug-only App Group key (TextPredictionEngine.languageModelDebugKey)
# and copies the model into the App Group's keyboard-lm/ folder, or turns it off. Then it
# ends the keyboard's process, opens a new reminder so the keyboard starts again, waits,
# reads phys_footprint, types the first --sentences French sentences with sim_replay.py,
# and reads phys_footprint again. Writes footprint.tsv and the typed texts.tsv to --out.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UDID=""
MODEL=""
TAPS=""
OUT=""
SENTENCES=5
GRID_TOP=583.2
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --taps) TAPS="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --sentences) SENTENCES="$2"; shift 2 ;;
        --grid-top) GRID_TOP="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -n $UDID && -n $MODEL && -n $TAPS && -n $OUT ]] || { echo "--udid, --model, --taps and --out are required" >&2; exit 2; }
mkdir -p "$OUT"

KEY=debug.keyboardLanguageModel
GROUP=group.solutions.pivi.dictus
GROUP_DIR=$(xcrun simctl get_app_container "$UDID" com.pivi.dictus groups | awk -v g="$GROUP" '$1 == g {print $2}')
[[ -d $GROUP_DIR ]] || { echo "no App Group container: is DictusApp installed?" >&2; exit 1; }
PLIST="$GROUP_DIR/Library/Preferences/$GROUP.plist"

if [[ $MODEL == none ]]; then
    xcrun simctl spawn "$UDID" defaults delete "$PLIST" "$KEY" >/dev/null 2>&1 || true
else
    mkdir -p "$GROUP_DIR/keyboard-lm"
    NAME=$(basename "$MODEL")
    cmp -s "$MODEL" "$GROUP_DIR/keyboard-lm/$NAME" || cp "$MODEL" "$GROUP_DIR/keyboard-lm/$NAME"
    xcrun simctl spawn "$UDID" defaults write "$PLIST" "$KEY" -string "$NAME"
fi

# The simulator's processes are the Mac's: the keyboard is the one whose path is in this device.
keyboard_pid() {
    ps -axo pid=,comm= | awk -v u="$UDID" '$2 ~ u && $2 ~ /DictusKeyboard$/ {print $1}' | head -1
}
footprint_mb() {
    footprint -p "$1" 2>/dev/null | awk '/phys_footprint:/ {print $2, $3; exit}'
}

OLD=$(keyboard_pid)
[[ -n $OLD ]] && kill "$OLD" && sleep 1
python3 -I - "$UDID" <<'PY'
import subprocess, sys, time
udid = sys.argv[1]
subprocess.run(["xcrun", "simctl", "terminate", udid, "com.apple.reminders"], capture_output=True)
subprocess.run(["xcrun", "simctl", "launch", udid, "com.apple.reminders"], check=True, capture_output=True)
time.sleep(2.5)
subprocess.run(["axe", "tap", "--label", "Rappel", "--udid", udid], check=True, capture_output=True)
PY
sleep 8
PID=$(keyboard_pid)
[[ -n $PID ]] || { echo "the keyboard did not start" >&2; exit 1; }
LOADED=$(footprint_mb "$PID")

python3 -I "$ROOT/tools/keyboard-bench/sim_replay.py" --udid "$UDID" --lang fr --keyboard dictus \
    --taps "$TAPS" --grid-top "$GRID_TOP" --bench "$ROOT/tools/keyboard-bench" --out "$OUT" --end "$SENTENCES" >&2
AFTER_PID=$(keyboard_pid)
TYPED=$(footprint_mb "$AFTER_PID")

printf 'model\tpid\tfootprint_after_appear\tpid_after_typing\tfootprint_after_typing\n%s\t%s\t%s\t%s\t%s\n' \
    "$(basename "$MODEL")" "$PID" "$LOADED" "$AFTER_PID" "$TYPED" | tee "$OUT/footprint.tsv"
