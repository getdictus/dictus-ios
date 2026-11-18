#!/bin/bash
# measure.sh <label>: footprint of the Dictus keyboard at rest, then while the
# keyboard-bench runs (fr, en) are typed on it, then at rest again.
set -u
UDID=${UDID:?set UDID to your own simulator}
LABEL=$1
ROOT=$(git rev-parse --show-toplevel)
OUT=$ROOT/build/m555/$LABEL
mkdir -p "$OUT"; : > "$OUT/samples.tsv"; : > "$OUT/phases.tsv"
GROUP_DIR=$(xcrun simctl get_app_container $UDID com.pivi.dictus groups | awk -F'\t' '$1=="group.solutions.pivi.dictus"{print $2}')
PLIST="$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist"
mark() { echo -e "$(date +%s)\t$1" >> "$OUT/phases.tsv"; echo "$(date +%T) $1"; }
kbpid() { ps -axo pid,command | grep "$UDID" | grep 'DictusKeyboard.appex/DictusKeyboard' | grep -v grep | awk '{print $1}' | head -1; }
show_keyboard() {
  xcrun simctl terminate $UDID com.apple.reminders >/dev/null 2>&1
  xcrun simctl launch $UDID com.apple.reminders >/dev/null; sleep 2.5
  axe tap --label Rappel --udid $UDID >/dev/null; sleep 1.5
}

xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string fr
# A fresh keyboard process: the measurement starts from a cold extension.
xcrun simctl terminate $UDID com.apple.reminders >/dev/null 2>&1
P=$(kbpid); [ -n "$P" ] && kill "$P"; sleep 3
"$(dirname "$0")/sample.sh" $UDID "$OUT/samples.tsv" &
SAMPLER=$!
trap 'kill $SAMPLER' EXIT
mark start
show_keyboard
mark rest-start
sleep 30
mark rest-end
python3 -I tools/keyboard-bench/sim_replay.py --udid $UDID --lang fr --keyboard dictus \
  --taps build/m555/before-replay-out/taps.tsv --grid-top 583.2 --bench tools/keyboard-bench --out "$OUT/sim-fr" > "$OUT/sim-fr.log" 2>&1
mark fr-end
xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string en
python3 -I tools/keyboard-bench/sim_replay.py --udid $UDID --lang en --keyboard dictus \
  --taps build/m555/before-replay-out/taps.tsv --grid-top 583.2 --bench tools/keyboard-bench --out "$OUT/sim-en" > "$OUT/sim-en.log" 2>&1
mark en-end
xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string fr
show_keyboard
mark rest2-start
sleep 30
mark rest2-end
footprint -p "$(kbpid)" > "$OUT/footprint-final.txt" 2>&1
heap "$(kbpid)" -sortBySize > "$OUT/heap-final.txt" 2>&1
mark done
