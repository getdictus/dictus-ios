#!/bin/zsh
# reset.sh <udid>: relaunch Settings and focus its search field, empty, keyboard up.
A=/tmp/axe-1089.Ob43/axe; U=$1
xcrun simctl terminate $U com.apple.Preferences >/dev/null 2>&1
xcrun simctl launch $U com.apple.Preferences >/dev/null; sleep 2.5
for i in 1 2 3 4 5; do
  $A tap -x 200 -y 822 --udid $U >/dev/null 2>&1; sleep 1.5
  $A describe-ui --udid $U 2>/dev/null | grep -q '"Clavier suivant"' && exit 0
done
echo "reset: keyboard not up" >&2; exit 1
