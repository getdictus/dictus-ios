#!/bin/bash
# Show the Dictus keyboard's real RecordingOverlay in a simulator, without a microphone.
#
# Usage: inject-recording.sh <udid> [seconds=14]
#
# WHY: a real dictation in a simulator records the Mac's microphone, which is
# the room the maintainer works in (docs/agents/simulator.md, section 8), and
# needs a downloaded model. The keyboard draws its overlay from App Group
# state alone, so this script writes that state the way DictusApp does
# (UnifiedAudioEngine: status, a ~1 Hz heartbeat, 30 waveform bins, elapsed
# seconds, then the Darwin notifications), and the shipping keyboard renders it.
# Nothing in the app is changed; the screenshot is the real UI.
#
# Prerequisites: Dictus installed and launched once (the App Group exists),
# the Dictus keyboard on screen in some text field. Screenshot while it runs:
#   xcrun simctl io <udid> screenshot shot.png
#
# The heartbeat is written as a string on purpose: `defaults write -float`
# stores a float32, which rounds a Unix timestamp by minutes, and the keyboard
# then judges the session orphaned and cancels it (measured 2026-10-03).
set -euo pipefail
UDID="$1"
DUR="${2:-14}"
GROUP=$(xcrun simctl get_app_container "$UDID" com.pivi.dictus groups | awk -F'\t' '/group.solutions.pivi.dictus/{print $2}')
PL="$GROUP/Library/Preferences/group.solutions.pivi.dictus"
w() { xcrun simctl spawn "$UDID" defaults write "$PL" "$@"; }
now() { python3 -c "import time; print(time.time())"; }
post() { xcrun simctl spawn "$UDID" notifyutil -p "$1"; }

w dictus.dictationStatus recording
w dictus.recordingHeartbeat -string "$(now)"
post com.pivi.dictus.statusChanged
START=$(now)
i=0
while python3 -c "import sys,time; sys.exit(0 if time.time()-$START < $DUR else 1)"; do
  HEX=$(python3 - "$i" <<'PY'
import json, math, random, sys
i = int(sys.argv[1]); random.seed(i)
bins = []
for k in range(30):  # UnifiedAudioEngine.waveformBarCount
    t = (k + i * 2) / 30
    env = 0.55 + 0.3 * math.sin(2 * math.pi * t * 1.3) + 0.2 * math.sin(2 * math.pi * t * 3.7 + 1) + 0.25 * (k / 29)
    bins.append(round(max(0.05, min(1.0, env * (0.7 + 0.5 * random.random()))), 3))
print(json.dumps(bins).encode().hex())
PY
)
  T=$(now)
  w dictus.waveformEnergy -data "$HEX"
  w dictus.recordingElapsedSeconds -float "$(python3 -c "print(round($T - $START + 3.0, 2))")"
  w dictus.recordingHeartbeat -string "$T"
  post com.pivi.dictus.waveformUpdate
  i=$((i + 1))
done
# Leave the keyboard idle again.
w dictus.dictationStatus idle
xcrun simctl spawn "$UDID" defaults delete "$PL" dictus.waveformEnergy 2>/dev/null || true
xcrun simctl spawn "$UDID" defaults delete "$PL" dictus.recordingHeartbeat 2>/dev/null || true
post com.pivi.dictus.statusChanged
