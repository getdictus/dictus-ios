#!/bin/bash
# doctor.sh — read-only health check of the toolchain and of a launched run.
#
# Usage:
#   .claude/skills/verify-dictus-ios/scripts/doctor.sh [run-dir]
#
# Without a run directory it checks this session's run, or only the toolchain when there
# is none. It creates, boots, taps, installs and deletes nothing. Every line is
# `OK`, `WARN` or `FAIL`; the last line is `DOCTOR OK` or `DOCTOR FAIL <n>`.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

fails=0
ok() { echo "OK    $*"; }
warn() { echo "WARN  $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }

# --- Toolchain ----------------------------------------------------------------
XCODE=$(xcodebuild -version 2>/dev/null | head -1)
[ -n "$XCODE" ] && ok "xcode: $XCODE ($(xcode-select -p))" || bad "xcodebuild not found"
for tool in axe simslim argent python3; do
  if command -v "$tool" >/dev/null; then
    ok "$tool: $(command -v "$tool") $("$tool" --version 2>/dev/null | head -1)"
  else
    bad "$tool is not installed (this skill installs nothing)"
  fi
done
if xcrun simctl list runtimes 2>/dev/null | grep -q 'com.apple.CoreSimulator.SimRuntime.iOS-26-5'; then
  ok "runtime iOS 26.5 installed"
else
  bad "runtime iOS 26.5 missing (launch.sh defaults to it)"
fi
if argent server status 2>/dev/null | grep -q 'health:.*ok'; then
  ok "argent tool-server healthy"
else
  warn "argent tool-server not running (axe still works; argent starts it on first use)"
fi
LEFTOVER=$(xcrun simctl list devices 2>/dev/null | grep -c "$DEVICE_PREFIX" || true)
[ "$LEFTOVER" -le 1 ] && ok "$LEFTOVER '$DEVICE_PREFIX' device(s) present" \
  || warn "$LEFTOVER '$DEVICE_PREFIX' devices present: earlier runs were not cleaned up (cleanup.sh <run-dir>)"

# --- Run ----------------------------------------------------------------------
DIR=${1:-${DICTUS_VERIFY_RUN:-$SESSION_LINK}}
if [ ! -f "$DIR/run.env" ]; then
  warn "no run to inspect at $DIR (toolchain only)"
else
  load_run "$DIR"
  ok "run: $RUN_DIR"
  STATE=$(xcrun simctl list devices | grep "$UDID" || true)
  case "$STATE" in
    *"(Booted)"*) ok "device $UDID booted ($DEVICE_NAME)" ;;
    "") bad "device $UDID no longer exists" ;;
    *) bad "device $UDID is not booted: $STATE" ;;
  esac
  if simslim list 2>/dev/null | grep "$UDID" | grep -qi slim; then
    ok "device is slimmed (simslim)"
  else
    warn "simslim does not report $UDID as slimmed"
  fi
  if xcrun simctl get_app_container "$UDID" "$APP_ID" >/dev/null 2>&1; then
    ok "$APP_ID installed"
  else
    bad "$APP_ID not installed"
  fi
  PLUGINS=$(xcrun simctl spawn "$UDID" pluginkit -m -p com.apple.keyboard-service 2>/dev/null || true)
  grep -q "$KEYBOARD_ID" <<<"$PLUGINS" && ok "keyboard extension registered" \
    || bad "keyboard extension not registered with pluginkit"
  SERVICES=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true)
  if grep -q "UIKitApplication:$APP_ID\[" <<<"$SERVICES"; then
    ok "DictusApp running"
  else
    warn "DictusApp not running (normal after Full Access, which kills it)"
  fi
  if [ -f "${LOG_FILE:-}" ]; then
    ok "App Group log: $(wc -l <"$LOG_FILE" | tr -d ' ') lines, last: $(tail -1 "$LOG_FILE" | cut -c1-120)"
    grep -q '<KBD> .*fullAccess=true' "$LOG_FILE" && ok "keyboard has logged fullAccess=true" \
      || warn "keyboard has not logged fullAccess=true yet"
  else
    bad "no dictus_debug.log in the App Group container"
  fi
  axe describe-ui --udid "$UDID" >/dev/null 2>&1 && ok "axe can read the accessibility tree" \
    || bad "axe cannot read $UDID (attachment, simulator.md §5)"
  EXITS=$(xcrun simctl spawn "$UDID" log show --last 30m --style compact \
    --predicate 'process == "SpringBoard" AND eventMessage CONTAINS "Process exited"' 2>/dev/null || true)
  CRASHES=$(grep "pivi.dictus" <<<"$EXITS" | grep "domain:signal" | grep -v SIGKILL || true)
  [ -z "$CRASHES" ] && ok "no Dictus crash signal in SpringBoard's log (30 min)" \
    || bad "Dictus crash: $(head -1 <<<"$CRASHES")"
fi

FRONT=$(frontmost_app)
case "$FRONT" in
  Simulator | DeviceHub) bad "$FRONT is the frontmost app: a window stole focus" ;;
  unknown) warn "frontmost app unreadable (no Automation permission for System Events)" ;;
  *) ok "frontmost app: $FRONT" ;;
esac

[ "$fails" -eq 0 ] && echo "DOCTOR OK" || { echo "DOCTOR FAIL $fails"; exit 1; }
