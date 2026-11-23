#!/bin/sh
# settings-seq.sh <axe> <udid> <app> <prefix> : install app, Settings search empty, then one letter
A=$1; U=$2; APP=$3; P=$4; Y=${5:-600}
xcrun simctl terminate $U com.apple.Preferences 2>/dev/null
xcrun simctl install $U $APP
xcrun simctl launch $U com.apple.Preferences >/dev/null
$A batch --udid $U --step "sleep 3" >/dev/null
$A tap --label "Rechercher" --udid $U >/dev/null
$A batch --udid $U --step "sleep 3" >/dev/null
xcrun simctl io $U screenshot $P-empty.png >/dev/null 2>&1
$A batch --udid $U --step "tap -x 30 -y $Y" --step "sleep 2" >/dev/null
xcrun simctl io $U screenshot $P-letter.png >/dev/null 2>&1
