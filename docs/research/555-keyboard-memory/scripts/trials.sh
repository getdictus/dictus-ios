#!/bin/bash
# trials.sh: for each build, a fresh keyboard shown once (30 s idle), then 20 more
# appearances (30 s idle): phys_footprint and phys_footprint_peak at both points.
UDID=${UDID:?set UDID to your own simulator}
kbpid(){ ps -axo pid,command | grep "$UDID" | grep 'DictusKeyboard.appex/DictusKeyboard' | grep -v grep | awk '{print $1}' | head -1; }
show(){ xcrun simctl terminate $UDID com.apple.reminders >/dev/null 2>&1; xcrun simctl launch $UDID com.apple.reminders >/dev/null; sleep 3; axe tap --label Rappel --udid $UDID >/dev/null 2>&1; sleep 2.5; }
fp(){ footprint -p $(kbpid) --noCategories -f bytes | awk '/phys_footprint:/{a=$2} /phys_footprint_peak:/{b=$2} END{printf "%.1f (peak %.1f)", a/1048576, b/1048576}'; }
for build in base after base after; do
  xcrun simctl install $UDID build/m555/apps/$build/DictusApp.app
  P=$(kbpid); [ -n "$P" ] && kill $P; sleep 3
  show; sleep 30; A=$(fp)
  for i in $(seq 2 21); do show; done; sleep 30
  echo "$build: 1 appearance $A | 21 appearances $(fp) | pid $(kbpid)"
done
