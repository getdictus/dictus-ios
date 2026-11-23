#!/bin/sh
# apps-seq.sh <axe> <udid> <app> <prefix> <convY> <composeY> <letterY>
A=$1; U=$2; APP=$3; P=$4; CY=$5; MY=$6; LY=$7
for b in com.apple.MobileSMS com.apple.mobilesafari com.apple.Preferences; do xcrun simctl terminate $U $b 2>/dev/null; done
xcrun simctl install $U $APP
# Messages: open the first conversation, focus the compose box, then type one letter
xcrun simctl launch $U com.apple.MobileSMS >/dev/null
$A batch --udid $U --step "sleep 4" --step "tap -x 210 -y $CY" --step "sleep 3" --step "tap -x 230 -y $MY" --step "sleep 7" >/dev/null
xcrun simctl io $U screenshot $P-messages.png >/dev/null 2>&1
$A batch --udid $U --step "tap -x 30 -y $LY" --step "sleep 2" >/dev/null
xcrun simctl io $U screenshot $P-messages-letter.png >/dev/null 2>&1
xcrun simctl terminate $U com.apple.MobileSMS
# Safari: focus the address bar
xcrun simctl launch $U com.apple.mobilesafari >/dev/null
$A batch --udid $U --step "sleep 4" >/dev/null
$A tap --label "Adresse" --udid $U >/dev/null
$A batch --udid $U --step "sleep 3" >/dev/null
xcrun simctl io $U screenshot $P-safari.png >/dev/null 2>&1
xcrun simctl terminate $U com.apple.mobilesafari
