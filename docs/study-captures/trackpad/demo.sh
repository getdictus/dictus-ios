#!/bin/bash
# demo.sh <video.mp4>: records the same space-bar trackpad gestures on the branch simulator.
# Safari is on the test page with the Dictus keyboard up. Each gesture holds the space
# bar 0.7 s still, then slides.
set -u
UDID=216C01D4-A93C-469D-A62D-7E89B3F19D19
S=/private/tmp/claude-501/-Users-pierre--t3-worktrees-dictus-feature-trackpad-hex-34e5d2613279254a/487f7ceb-be44-4dd1-94d3-bd57a456b831/scratchpad
A=$S/axe/axe
OUT="$1"
SX=210; SY=772
drag() { # dx dy duration
  "$A" drag --start-x $SX --start-y $SY --end-x $((SX + $1)) --end-y $((SY + $2)) --hold 0.7 --duration "$3" --steps 90 --udid $UDID >/dev/null
  sleep 1
}
# Caret at the end of the text.
"$A" tap -x 376 -y 186 --udid $UDID >/dev/null
sleep 1
xcrun simctl io $UDID recordVideo --codec=h264 --force "$OUT" >/dev/null 2>&1 &
REC=$!
sleep 2
drag -100 0 1.2    # slow, left along the last line
drag 0 -45 1.0     # up two lines
drag 0 -25 1.0     # up one more line
drag 120 0 0.15    # a fast flick right
drag 0 70 1.0      # back down to the last line
drag -60 -30 1.0   # a slant up and left
sleep 1
kill -INT $REC
wait $REC
echo "$OUT"
