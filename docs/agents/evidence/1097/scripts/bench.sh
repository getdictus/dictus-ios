#!/bin/zsh
# bench.sh <udid> <label> : 20 taps over e s r d t f y g u h i j o k per case, Settings search
# field, French AZERTY, iPhone 17. Cases: hold durations (ms) and short slides (pt, over 100 ms).
A=/tmp/axe-1089.Ob43/axe; U=$1; L=$2; D=${0:h}
typeset -A X Y
X=(e 102 s 62.5 r 141 d 102 t 181 f 141 y 220.6 g 181 u 260 h 221 i 300 j 260 o 339 k 300)
Y=(e 612 s 666 r 612 d 666 t 612 f 666 y 612 g 666 u 612 h 666 i 612 j 666 o 612 k 666)
SEQ=(e s r d t f y g u h i j o k e s r d t f)
run_case() { # $1 kind (hold|slide) $2 value
  $D/reset.sh $U
  for k in $SEQ; do
    if [ $1 = hold ]; then
      # A held press: AXe's touch --delay and tap --hold overshoot by more than the popup's
      # 0.5 s, so the press is a swipe that drifts 0.5 pt, whose duration AXe keeps.
      $A swipe --start-x $X[$k] --start-y $Y[$k] --end-x $(( X[$k] + 0.5 )) --end-y $Y[$k] --duration $(( $2 / 1000.0 )) --udid $U >/dev/null 2>&1
    else
      $A swipe --start-x $X[$k] --start-y $Y[$k] --end-x $(( X[$k] + $2 )) --end-y $Y[$k] --duration 0.1 --udid $U >/dev/null 2>&1
    fi
    sleep 0.35
  done
  sleep 0.8
  local got=$($A describe-ui --udid $U | python3 -I $D/field.py)
  local score=$(python3 -I $D/score.py "${(j::)SEQ}" "$got")
  echo "$L $1 $2 $score $got"
}
for v in 10 50 100 200 300 400 520 550 700; do run_case hold $v; done
for v in 2 5 10; do run_case slide $v; done
