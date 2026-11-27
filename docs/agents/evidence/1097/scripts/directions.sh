#!/bin/zsh
# directions.sh <udid> <label>: hold « e » 1 s, slide to each point over 0.3 s, release.
A=/tmp/axe-1089.Ob43/axe; U=$1; L=$2; D=${0:h}
read_field() { local v; for i in 1 2 3; do v=$($A describe-ui --udid $U | python3 -I $D/field.py); [ "$v" != None ] && break; sleep 1; done; echo $v; }
for case in "102.5 612" "102 555" "102 495" "102 295" "102 635" "102 650" "102 660" "102 665" "102 672" "102 680" "102 760" "73 553" "300 612"; do
  $D/reset.sh $U || { echo "$L [$case] reset failed"; continue; }
  set -- ${=case}
  $A drag --start-x 102 --start-y 612 --end-x $1 --end-y $2 --hold 1.0 --duration 0.3 --steps 15 --udid $U >/dev/null 2>&1 || echo "drag failed"
  sleep 1.2
  echo "$L [$case] -> $(read_field)"
done
