#!/bin/bash
# drive.sh — drive the launched simulator by accessibility identifier, label or recipe.
#
# Usage:
#   .claude/skills/verify-dictus-ios/scripts/drive.sh <command> [args]   (this session's run)
#   DICTUS_VERIFY_RUN=<run-dir> drive.sh <command> [args]                (a given run)
#
# Primitives (exit non-zero when the element never appears):
#   tap-id <identifier>            tap the element whose AXUniqueId matches
#   tap-label <label>              tap the element whose AXLabel matches
#                                  both refuse (exit 1, candidates listed) when several
#                                  elements match; a label clash is resolved with tap-id.
#                                  They also refuse an element off screen: scroll first
#   wait-id <identifier> [secs]    wait until it is on screen (default 15 s)
#   wait-label <label> [secs]
#   gone-id <identifier> [secs]    wait until it has left the screen
#   tab <Accueil|Modèles|Réglages> tap a tab bar item (Home|Models|Settings on an English device)
#                                  (its RadioButton: a screen can repeat the name as a heading)
#   tree                           print the accessibility tree (axe, points)
#   log-mark                       print the App Group log's next line number
#   wait-log <regex> [secs] [from] wait for a log line at or after `from`
#
# Recipes (multi-step, each step checked):
#   relaunch [args…]               terminate and relaunch DictusApp, e.g. `relaunch -AppleLanguages '(en)'`
#   full-access                    Réglages → Général → Clavier → Claviers → Dictus → Accès complet
#   select-keyboard                Safari address bar, long-press the globe, choose Dictus
#   kbd <menu|menu-hold|emoji|abc|mic|mic-fan>
#                                  press a Dictus keyboard control (none is in the a11y tree):
#                                  ☰ tap = voice-note reader, ☰ hold = panel, 😀 = emoji,
#                                  ABC = back to keys, mic tap = dictation, mic hold+drag = fan
#   type <word>                    type lowercase a–z on the Dictus AZERTY keyboard, key by key
#   space                          press the Dictus space bar (autocorrect runs on space)
#   set-default <key> <-bool|-string|-int> <value>
#                                  write an App Group default, then relaunch DictusApp
set -euo pipefail
. "$(dirname "$0")/lib.sh"
load_run "${DICTUS_VERIFY_RUN:-}"

cmd=${1:?usage: drive.sh <command> [args]}
shift

case "$cmd" in
  tap-id) tap_unique id "${1:?identifier}"; echo "tapped id $1" ;;
  tap-label) tap_unique label "${1:?label}"; echo "tapped label $1" ;;
  wait-id) wait_for id "$1" "${2:-15}" >/dev/null || die "id '$1' never appeared"; echo "present id $1" ;;
  wait-label) wait_for label "$1" "${2:-15}" >/dev/null || die "label '$1' never appeared"; echo "present label $1" ;;
  gone-id)
    waited=0
    while is_present id "$1"; do
      [ "$waited" -lt "${2:-10}" ] || die "id '$1' is still on screen"
      sleep 1; waited=$((waited + 1))
    done
    echo "gone id $1" ;;
  tab)
    # Tab bar items are RadioButtons labelled with the tab name. Their identifiers are SF
    # Symbol names, not ours, and the Models screen also has a « Modèles » heading.
    tap_unique label "${1:?tab name}" RadioButton; echo "tapped tab $1" ;;
  tree) axe describe-ui --udid "$UDID" ;;
  log-mark) echo $(($( [ -f "$LOG_FILE" ] && wc -l <"$LOG_FILE" || echo 0) + 1)) ;;
  wait-log)
    line=$(wait_log "$1" "${2:-20}" "${3:-1}") || die "no log line matching '$1'"
    echo "log line $line: $(sed -n "${line}p" "$LOG_FILE" | cut -c1-200)" ;;

  relaunch)
    xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
    sleep 1
    out=$(xcrun simctl launch "$UDID" "$APP_ID" "$@") || die "launch failed: $out"
    pid=${out##*: }
    sed -i '' "s/^APP_PID=.*/APP_PID=$pid/" "$RUN_DIR/run.env"
    sleep 3
    ps -p "$pid" >/dev/null || die "DictusApp pid $pid died after relaunch"
    echo "relaunched pid $pid $*" ;;

  full-access)
    # simulator.md §8 and scripts/simulator-smoke-test.sh step 6. French system labels.
    xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null || die "could not open Settings"
    wait_for id com.apple.settings.general 20 >/dev/null || die "Settings root did not appear"
    tap_until id com.apple.settings.general id Keyboard
    tap_until id Keyboard id KEYBOARDS
    tap_until id KEYBOARDS id "$KEYBOARD_ID"
    tap_until id "$KEYBOARD_ID" id "Autoriser l’accès complet"
    # The switch is not in the tree, only its row; a physical-style tap moves it.
    frame=$(stable_frame id "Autoriser l’accès complet") || die "no Full Access row"
    read -r x y w h <<<"$frame"
    granted=no
    for _ in 1 2 3; do
      sleep 1
      axe tap -x "$(python3 -c "print(round($x + $w - 45))")" -y "$(center "$y" "$h")" \
        --tap-style physical --udid "$UDID" >/dev/null || die "could not tap the switch"
      wait_for label Refuser 5 >/dev/null || continue
      sleep 1
      tap label Autoriser
      waited=0
      while is_present label Refuser && [ "$waited" -lt 5 ]; do sleep 1; waited=$((waited + 1)); done
      is_present label Refuser && continue
      granted=yes; break
    done
    [ "$granted" = yes ] || die "the Full Access alert never appeared or never closed"
    echo "full access granted (proof: the keyboard logs fullAccess=true once shown)" ;;

  select-keyboard)
    xcrun simctl launch "$UDID" com.apple.mobilesafari >/dev/null || die "could not open Safari"
    tap id TabBarItemTitle
    # Two first-run splashes on a fresh device, both closed by "Continuer".
    for _ in 1 2 3 4; do
      is_present label Continuer || break
      tap label Continuer; sleep 1
    done
    frame=$(stable_frame label "Clavier suivant") || die "no globe key: no keyboard on screen"
    read -r x y w h <<<"$frame"
    gx=$(center "$x" "$w"); gy=$(center "$y" "$h")
    # Long press in ONE HID session (batch). A tap cycles past third-party keyboards.
    axe batch --udid "$UDID" --step "touch -x $gx -y $gy --down" --step "sleep 1.8" \
      --step "touch -x $gx -y $gy --up" >/dev/null || die "could not long-press the globe"
    tap label "Dictus, multilingue"
    stable_frame id inputView >/dev/null || die "the Dictus keyboard did not come up"
    echo "Dictus keyboard selected in Safari" ;;

  kbd)
    # The keyboard draws in one opaque remote element, `inputView`; its controls sit at
    # fixed offsets from that frame (measured on iPhone 17, iOS 26.5, keys mode).
    # The App Group log, not the tree, proves what a press did.
    frame=$(stable_frame id inputView) || die "no inputView: the Dictus keyboard is not on screen"
    read -r x y w h <<<"$frame"
    mx=$(python3 -c "print(round($x + $w - 45))"); top=$(python3 -c "print(round($y + 28))")
    case "${1:?kbd control}" in
      menu) axe tap -x "$(python3 -c "print(round($x + 40))")" -y "$top" --udid "$UDID" >/dev/null ;;
      menu-hold)
        hx=$(python3 -c "print(round($x + 40))")
        # One HID session; a swipe as the last step so the release reaches SwiftUI.
        axe batch --udid "$UDID" --step "touch -x $hx -y $top --down" --step "sleep 0.8" \
          --step "swipe --start-x $hx --start-y $top --end-x $((hx + 1)) --end-y $((top - 1)) --duration 0.2" >/dev/null ;;
      emoji) axe tap -x "$(python3 -c "print(round($x + 90))")" -y "$(python3 -c "print(round($y + 240))")" --udid "$UDID" >/dev/null ;;
      abc) axe tap -x "$(python3 -c "print(round($x + 22))")" -y "$(python3 -c "print(round($y + 250))")" --udid "$UDID" >/dev/null ;;
      mic) axe tap -x "$mx" -y "$top" --udid "$UDID" >/dev/null ;;
      mic-fan)
        # Hold, then drag up into the fan and release on nothing: the fan opens and aborts,
        # no mode is armed and nothing records. Screenshot during the drag to see it.
        axe batch --udid "$UDID" --step "touch -x $mx -y $top --down" --step "sleep 1.2" \
          --step "swipe --start-x $mx --start-y $top --end-x $((mx - 57)) --end-y $((top - 109)) --duration 2.5" >/dev/null ;;
      *) die "unknown keyboard control '$1'" ;;
    esac
    echo "pressed keyboard $1" ;;

  type | space)
    # Typed through the Dictus keyboard itself, key by key: `axe type` sends hardware
    # keyboard events, which reach the text field without going through the extension and
    # so never trigger its autocorrect. AZERTY, letters page, measured on iPhone 17 / iOS
    # 26.5: ten keys per row on a 40.2 pt pitch; rows 80, 132, 187 pt below inputView's
    # top; row 3 holds w x c v b n between shift and backspace; space at (220, +239).
    frame=$(stable_frame id inputView) || die "no inputView: the Dictus keyboard is not on screen"
    read -r x y w h <<<"$frame"
    press() { axe tap -x "$(python3 -c "print(round($x + $1))")" -y "$(python3 -c "print(round($y + $2))")" --udid "$UDID" >/dev/null; sleep 0.35; }
    if [ "$cmd" = space ]; then press 220 239; echo "pressed space"; exit 0; fi
    word=${1:?word}
    for ((i = 0; i < ${#word}; i++)); do
      c=${word:$i:1}
      pos=$(python3 -c "
import sys
c=sys.argv[1]; p=40.2
for row,keys,y,x0 in ((0,'azertyuiop',80,20.1),(1,'qsdfghjklm',132,20.1),(2,'wxcvbn',187,80.4)):
    if c in keys: print(round(x0+p*keys.index(c)), y); sys.exit(0)
sys.exit(1)" "$c") || die "'$c' is not a lowercase a–z letter on the AZERTY letters page"
      press $pos
    done
    echo "typed $word" ;;

  set-default)
    # App Group defaults (`dictus.*`) live in the group's plist, which a launch argument
    # does not reach. Written from inside the device with the app stopped, then relaunched.
    key=${1:?key}; type=${2:?-bool|-string|-int}; value=${3:?value}
    xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
    sleep 1
    xcrun simctl spawn "$UDID" defaults write "$GROUP_DIR/Library/Preferences/$APP_GROUP.plist" \
      "$key" "$type" "$value"
    out=$(xcrun simctl launch "$UDID" "$APP_ID") || die "relaunch failed: $out"
    sed -i '' "s/^APP_PID=.*/APP_PID=${out##*: }/" "$RUN_DIR/run.env"
    sleep 3
    echo "set $key=$value, relaunched pid ${out##*: }" ;;

  *) die "unknown command '$cmd' (see the header of $0)" ;;
esac
