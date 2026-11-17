#!/bin/bash
# typing-trials.sh: per build, a fresh keyboard, 30 s idle, then the last 6 French and
# last 6 English keyboard-bench sentences typed on it, then 30 s idle:
# phys_footprint and phys_footprint_peak.
UDID=${UDID:?set UDID to your own simulator}
GROUP_DIR=$(xcrun simctl get_app_container $UDID com.pivi.dictus groups | awk -F'\t' '$1=="group.solutions.pivi.dictus"{print $2}')
PLIST="$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist"
kbpid(){ ps -axo pid,command | grep "$UDID" | grep 'DictusKeyboard.appex/DictusKeyboard' | grep -v grep | awk '{print $1}' | head -1; }
show(){ xcrun simctl terminate $UDID com.apple.reminders >/dev/null 2>&1; xcrun simctl launch $UDID com.apple.reminders >/dev/null; sleep 3; axe tap --label Rappel --udid $UDID >/dev/null 2>&1; sleep 2.5; }
fp(){ footprint -p $(kbpid) --noCategories -f bytes | awk '/phys_footprint:/{a=$2} /phys_footprint_peak:/{b=$2} END{printf "%.1f (peak %.1f)", a/1048576, b/1048576}'; }
for build in base after base after; do
  xcrun simctl install $UDID build/m555/apps/$build/DictusApp.app
  xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string fr
  P=$(kbpid); [ -n "$P" ] && kill $P; sleep 3
  show; sleep 30; A=$(fp)
  python3 -I tools/keyboard-bench/sim_replay.py --udid $UDID --lang fr --keyboard dictus --taps build/m555/before-replay-out/taps.tsv --grid-top 583.2 --bench tools/keyboard-bench --out build/m555/tt-$build-fr --start 14 > /dev/null
  F=$(fp)
  xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string en
  python3 -I tools/keyboard-bench/sim_replay.py --udid $UDID --lang en --keyboard dictus --taps build/m555/before-replay-out/taps.tsv --grid-top 583.2 --bench tools/keyboard-bench --out build/m555/tt-$build-en --start 14 > /dev/null
  xcrun simctl spawn $UDID defaults write "$PLIST" dictus.language -string fr
  show; sleep 30
  echo "$build: rest $A | after fr $F | after en + 30 s $(fp) | pid $(kbpid)"
done
