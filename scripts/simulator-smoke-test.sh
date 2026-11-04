#!/bin/bash
# simulator-smoke-test.sh — headless end-to-end smoke test of the app-to-keyboard path (#535).
#
# One command, run on the maintainer's Mac, that proves the plumbing still works after a
# change: the app builds, installs, launches and stays alive; onboarding navigates; the
# keyboard registers, takes Full Access and renders in a host app; its mic hands off to
# DictusApp; and the app answers with the expected no-model failure instead of crashing
# or hanging. It proves nothing about transcription, capture, performance or UX — see
# docs/agents/simulator-smoke-test.md for the full list of what it must not claim.
#
# Every step is an assertion: the script exits non-zero, naming the step, the moment one
# fails. It never brings a window to the front (docs/agents/simulator.md).
#
# What it does:
#   1. Create (once) and erase (every run) its own simulator, `Dictus Smoke`, then write
#      the device language and keyboard list, boot it and wait for `bootstatus`.
#   2. Resolve packages and build DictusApp, signed ad hoc (no CI signing flags).
#   3. Install and launch DictusApp.
#   4. Check the launched pid is still alive after the UI settles.
#   5. Navigate onboarding: Get started -> language step -> Back -> intro.
#   6. Grant Full Access in Settings.
#   7. Mark onboarding finished, focus Safari's address field, long-press the globe,
#      choose Dictus.
#   8. Tap the Dictus mic, with no model installed.
#   9. Assert the keyboard -> app -> keyboard chain in the App Group log.
#  10. Save screenshots, the filtered log and a report outside the repository.
#  11. Uninstall Dictus and shut down the device it booted.
#
# Usage:
#   scripts/simulator-smoke-test.sh
#
# Environment (all optional):
#   DICTUS_SMOKE_OUT          artifact root, default $TMPDIR/dictus-smoke (refused inside the repo)
#   DICTUS_SMOKE_DEVICE_NAME  default "Dictus Smoke"; the device is erased every run, so it
#                             must be one this script owns
#   DICTUS_SMOKE_DEVICE_TYPE  default com.apple.CoreSimulator.SimDeviceType.iPhone-17
#   DICTUS_SMOKE_RUNTIME      default com.apple.CoreSimulator.SimRuntime.iOS-26-5
#
# Requires: Xcode 26.4.1 or newer, axe (brew install cameroncooke/axe/axe), python3.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"

DEVICE_NAME="${DICTUS_SMOKE_DEVICE_NAME:-Dictus Smoke}"
DEVICE_TYPE="${DICTUS_SMOKE_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}"
RUNTIME="${DICTUS_SMOKE_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"
OUT_ROOT="${DICTUS_SMOKE_OUT:-${TMPDIR:-/tmp}/dictus-smoke}"

# The device is erased on every run, so a name must not be able to reach a simulator
# someone else uses. Only names in this script's own namespace are accepted.
case "$DEVICE_NAME" in
  "Dictus Smoke"*) ;;
  *)
    echo "error: DICTUS_SMOKE_DEVICE_NAME must start with 'Dictus Smoke' (got '$DEVICE_NAME'): the device is erased on every run." >&2
    exit 2
    ;;
esac

APP_ID=com.pivi.dictus
KEYBOARD_ID=com.pivi.dictus.keyboard
APP_GROUP=group.solutions.pivi.dictus
DERIVED_DATA=build/DerivedData
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/DictusApp.app"

COMMIT=$(git rev-parse --short HEAD)
if [ -n "$(git status --porcelain)" ]; then COMMIT="$COMMIT-dirty"; fi

# The artifacts must never land in the repository, where they could be committed.
mkdir -p "$OUT_ROOT"
OUT_ROOT=$(cd "$OUT_ROOT" && pwd -P)
case "$OUT_ROOT/" in
  "$(pwd -P)/"*)
    echo "error: DICTUS_SMOKE_OUT ($OUT_ROOT) is inside the repository. Choose a path outside it." >&2
    exit 2
    ;;
esac
RUN_DIR="$OUT_ROOT/$(date +%Y%m%d-%H%M%S)-$COMMIT"
mkdir -p "$RUN_DIR"
REPORT="$RUN_DIR/report.txt"

UDID=""
RUNTIME_NAME=""
STEP="0 setup"
GROUP_DIR=""
# Set to "checked" once the catalogs' state before the build is known; see cleanup.
XCSTRINGS_STATE=""
XCSTRINGS_BEFORE=""
INSTALLED=no
BOOTED=no
PASSED=no

# --- Output -----------------------------------------------------------------

say() { echo "$*" | tee -a "$REPORT"; }

step() {
  STEP="$1"
  say "[$(date +%H:%M:%S)] step $STEP"
}

fail() {
  say "SMOKE FAIL step $STEP: $*"
  exit 1
}

frontmost_app() {
  # Needs Automation permission for System Events; "unknown" when it is missing.
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' \
    2>/dev/null || echo unknown
}

# Reports the frontmost Mac app, and says so plainly when it could not be read: without
# Automation permission the "never in front" check has checked nothing, and a report
# that stayed silent about it would read as a pass. Not a failure: what is under test is
# Dictus, not this Mac's privacy settings.
report_frontmost() {
  local front
  front=$(frontmost_app)
  if [ "$front" = unknown ]; then
    say "frontmost app $1: foreground check NOT performed (no Automation permission for System Events)"
  else
    say "frontmost app $1: $front"
  fi
}

# --- Cleanup: only what this run created ----------------------------------

# Runs on every exit, pass or fail. `SMOKE PASS` is printed here and only here, after
# the cleanup has succeeded: a run that leaves Dictus installed or the device booted has
# not finished, and its last word must not be a pass.
cleanup() {
  local status=$? problems=""
  set +e
  # Xcode rewrites Localizable.xcstrings during the build. It is build noise (CLAUDE.md);
  # put it back so the run leaves the working tree as it found it, a failed build
  # included. Only when the catalogs were clean before the build, so an uncommitted edit
  # is never thrown away.
  if [ "$XCSTRINGS_STATE" = checked ] && [ -z "$XCSTRINGS_BEFORE" ] \
    && [ -n "$(git status --porcelain -- '*.xcstrings')" ]; then
    git checkout -- '*.xcstrings' || problems="$problems could not restore the .xcstrings catalogs;"
  fi
  if [ -n "$UDID" ]; then
    # Read the whole log before uninstalling: uninstall deletes the App Group container.
    if [ -n "$GROUP_DIR" ] && [ -f "$GROUP_DIR/dictus_debug.log" ]; then
      cp "$GROUP_DIR/dictus_debug.log" "$RUN_DIR/dictus_debug.full.log"
    fi
    if [ $status -ne 0 ]; then
      xcrun simctl io "$UDID" screenshot "$RUN_DIR/failure.png" >/dev/null 2>&1 \
        && say "failure screenshot: $RUN_DIR/failure.png"
      axe describe-ui --udid "$UDID" >"$RUN_DIR/failure-ui.json" 2>/dev/null
    fi
    if [ "$INSTALLED" = yes ]; then
      xcrun simctl uninstall "$UDID" "$APP_ID" >/dev/null 2>&1 \
        || problems="$problems could not uninstall $APP_ID;"
    fi
    if [ "$BOOTED" = yes ]; then
      xcrun simctl shutdown "$UDID" >/dev/null 2>&1 \
        || problems="$problems could not shut down $UDID;"
    fi
  fi
  report_frontmost "at end"
  say "artifacts: $RUN_DIR"
  if [ $status -eq 0 ] && [ -n "$problems" ]; then
    say "SMOKE FAIL step 11 cleanup:$problems"
    exit 1
  fi
  if [ $status -eq 0 ] && [ "$PASSED" = yes ]; then
    say "SMOKE PASS commit=$COMMIT device=$UDID runtime=$RUNTIME_NAME"
  fi
  [ -n "$problems" ] && say "cleanup also failed:$problems"
  exit $status
}
trap cleanup EXIT

# --- Accessibility tree helpers ---------------------------------------------

# Prints "x y w h" (points) of the first element whose AXUniqueId (`id`) or AXLabel
# (`label`) equals the value, from the tree on stdin. Exits 1 when there is none.
#
# WHY NOT `axe tap --id`: axe refuses when several elements share an identifier, and
# Settings repeats its row identifiers on nested elements (`Keyboard` matches four).
# The first match is the row itself, so its centre is what a finger would press.
find_frame() {
  python3 -c '
import json, sys
kind, value = sys.argv[1], sys.argv[2]
key = "AXUniqueId" if kind == "id" else "AXLabel"
def walk(node):
    if node.get(key) == value:
        f = node["frame"]
        print(f["x"], f["y"], f["width"], f["height"])
        sys.exit(0)
    for child in node.get("children") or []:
        walk(child)
for root in json.load(sys.stdin):
    walk(root)
sys.exit(1)
' "$1" "$2"
}

# wait_for <id|label> <value> [timeout seconds] — prints the frame once it appears.
wait_for() {
  local kind=$1 value=$2 timeout=${3:-15} waited=0 frame
  while [ "$waited" -lt "$timeout" ]; do
    if frame=$(axe describe-ui --udid "$UDID" 2>/dev/null | find_frame "$kind" "$value"); then
      echo "$frame"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

# stable_frame <id|label> <value> — like wait_for, but only once the element has stopped
# moving. Settings inserts rows while its root screen loads (Apple Intelligence's
# follow-up item, measured 2026-10-14), and a frame read a moment too early sends the
# tap to the row below.
stable_frame() {
  local kind=$1 value=$2 previous="" current tries=0
  while [ "$tries" -lt 15 ]; do
    current=$(wait_for "$kind" "$value") || return 1
    if [ "$current" = "$previous" ]; then
      echo "$current"
      return 0
    fi
    previous=$current
    sleep 0.7
    tries=$((tries + 1))
  done
  return 1
}

is_present() {
  axe describe-ui --udid "$UDID" 2>/dev/null | find_frame "$1" "$2" >/dev/null
}

# tap <id|label> <value> [extra axe args] — taps the centre of the element, or fails.
tap() {
  local kind=$1 value=$2 frame x y w h
  shift 2
  frame=$(stable_frame "$kind" "$value") || fail "no element with $kind '$value' on screen"
  read -r x y w h <<<"$frame"
  axe tap -x "$(center "$x" "$w")" -y "$(center "$y" "$h")" --udid "$UDID" "$@" >/dev/null \
    || fail "axe could not tap $kind '$value'"
}

center() { python3 -c "print(round($1 + $2 / 2))"; }

# tap_until <kind> <value> <expect-kind> <expect-value> — taps an element and requires
# that the next screen shows the expected one. When it does not, it goes back with the
# navigation bar's BackButton if there is one and tries again, three times in all.
#
# WHY: a frame read while a screen is still settling sends the tap to whatever moves into
# that spot. Settings' root inserts its Apple Intelligence row late, and on a loaded Mac
# late enough to outlast `stable_frame`: on 2026-10-15 (load average
# ~90), two runs of five tapped "Siri" instead of "Général". Checking where the tap led, and undoing it,
# is what holds whatever the load.
tap_until() {
  local kind=$1 value=$2 expect_kind=$3 expect_value=$4 attempt
  for attempt in 1 2 3; do
    sleep 1
    tap "$kind" "$value"
    if wait_for "$expect_kind" "$expect_value" 10 >/dev/null; then
      return 0
    fi
    say "  tap on $kind '$value' did not reach '$expect_value' (attempt $attempt)"
    if is_present id BackButton; then
      tap id BackButton
    fi
  done
  fail "tapping $kind '$value' never reached $expect_kind '$expect_value'"
}

# --- Log helpers ------------------------------------------------------------

LOG_FILE=""

# wait_log <regex> [timeout] [from line] — waits for a line in the App Group log at or
# after line `from`, and prints the absolute line number of the first match, so that the
# next assertion can start after it.
wait_log() {
  local pattern=$1 timeout=${2:-20} from=${3:-1} waited=0 line
  while [ "$waited" -lt "$timeout" ]; do
    if [ -f "$LOG_FILE" ]; then
      line=$(PATTERN="$pattern" awk -v from="$from" \
        'NR >= from && $0 ~ ENVIRON["PATTERN"] { print NR; exit }' "$LOG_FILE")
      if [ -n "$line" ]; then
        echo "$line"
        return 0
      fi
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

# =============================================================================

say "Dictus simulator smoke test"
say "commit: $COMMIT ($(git rev-parse --abbrev-ref HEAD))"
say "xcode: $(xcodebuild -version | tr '\n' ' ')"
report_frontmost "at start"

command -v axe >/dev/null || fail "axe is not installed (brew install cameroncooke/axe/axe)"

# --- 1. Device ---------------------------------------------------------------
step "1 device"

UDID=$(xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and d.get("isAvailable"):
            print(d["udid"]); sys.exit(0)
' "$DEVICE_NAME" || true)
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME") \
    || fail "could not create '$DEVICE_NAME' ($DEVICE_TYPE, $RUNTIME)"
  say "created device $DEVICE_NAME $UDID"
fi

# The clean baseline: every run starts from an erased device, so nothing a previous run
# left behind (Full Access, App Group state, a half-finished onboarding) can pass for
# this one's result. The device is this script's own, which is what makes erasing it safe.
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$UDID" || fail "could not erase $UDID"

# Device language and keyboard list are written while the device is shut down: a write
# from the host to a booted device does not stick (simulator.md section 6).
#
# AppleKeyboardsExpanded is not optional. On an erased device iOS ignores AppleKeyboards
# without it and rebuilds the list from the languages, without Dictus (measured
# 2026-10-14, iOS 26.5).
PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/.GlobalPreferences.plist"
python3 - "$PREFS" "$KEYBOARD_ID" <<'PY' || fail "could not write the device preferences"
import os, plistlib, sys
path, keyboard = sys.argv[1], sys.argv[2]
prefs = plistlib.load(open(path, "rb")) if os.path.exists(path) else {}
prefs["AppleLanguages"] = ["fr-FR", "en-GB"]
prefs["AppleLocale"] = "fr_FR"
prefs["AppleKeyboards"] = [
    "fr_FR@sw=AZERTY-French;hw=Automatic",
    "en_US@sw=QWERTY;hw=Automatic",
    "emoji@sw=Emoji",
    keyboard,
]
prefs["AppleKeyboardsExpanded"] = 1
os.makedirs(os.path.dirname(path), exist_ok=True)
plistlib.dump(prefs, open(path, "wb"))
PY

xcrun simctl boot "$UDID" || fail "could not boot $UDID"
BOOTED=yes
xcrun simctl bootstatus "$UDID" >/dev/null || fail "bootstatus did not finish for $UDID"

RUNTIME_NAME=$(xcrun simctl list devices -j | python3 -c '
import json, sys
udid = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["udid"] == udid:
            print(runtime.rsplit(".", 1)[-1], d.get("deviceTypeIdentifier", "").rsplit(".", 1)[-1])
' "$UDID")
say "device: $DEVICE_NAME $UDID ($RUNTIME_NAME)"

# axe's point-based commands need the device attached. Before Xcode 27 that meant
# Simulator.app running with the device attached, started with -g so it never comes to
# the front (simulator.md section 5). Xcode 27 ships no Simulator.app and axe works
# without it. Probe first, and only start Simulator.app when the probe says it is needed.
attached=no
for _ in 1 2 3 4 5 6; do
  if axe describe-ui --udid "$UDID" >/dev/null 2>&1; then attached=yes; break; fi
  if [ -d "$(xcode-select -p)/Applications/Simulator.app" ]; then
    open -g -a Simulator
  fi
  sleep 5
done
[ "$attached" = yes ] || fail "axe cannot reach $UDID (see simulator.md section 5)"

# --- 2. Build ----------------------------------------------------------------
step "2 build"

XCSTRINGS_BEFORE=$(git status --porcelain -- '*.xcstrings')
XCSTRINGS_STATE=checked

# No patch step: FluidAudio 0.15.7 builds unpatched since #558. A checkout that resolved
# FluidAudio 0.12 fails here; delete $DERIVED_DATA/SourcePackages and run again (CLAUDE.md).
xcodebuild -resolvePackageDependencies \
  -project Dictus.xcodeproj -scheme DictusApp \
  -derivedDataPath "$DERIVED_DATA" >"$RUN_DIR/resolve.log" 2>&1 \
  || fail "package resolution failed, see $RUN_DIR/resolve.log"

# Without CI's CODE_SIGNING_ALLOWED=NO: an unsigned build has no App Group container on
# the simulator, so the log this test reads would never be written (simulator.md section 2).
xcodebuild build \
  -project Dictus.xcodeproj -scheme DictusApp -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" >"$RUN_DIR/build.log" 2>&1 \
  || fail "build failed, see $RUN_DIR/build.log"

# Xcode rewrites Localizable.xcstrings during the build; cleanup puts it back.

[ -d "$APP_PATH/PlugIns/DictusKeyboard.appex" ] || fail "built app has no DictusKeyboard.appex"

# --- 3. Install and launch ---------------------------------------------------
step "3 install and launch"

INSTALLED=yes
xcrun simctl install "$UDID" "$APP_PATH" || fail "install failed"
# Captured before grepping, here and below: with pipefail, `grep -q` closing the pipe
# early fails the producer with SIGPIPE, and the pipeline with it.
PLUGINS=$(xcrun simctl spawn "$UDID" pluginkit -m -p com.apple.keyboard-service 2>/dev/null || true)
grep -q "$KEYBOARD_ID" <<<"$PLUGINS" || fail "the keyboard extension did not register with pluginkit"

LAUNCH_OUTPUT=$(xcrun simctl launch "$UDID" "$APP_ID") || fail "launch failed: $LAUNCH_OUTPUT"
APP_PID=${LAUNCH_OUTPUT##*: }
say "launched $APP_ID pid $APP_PID"

GROUP_DIR=$(xcrun simctl get_app_container "$UDID" "$APP_ID" groups \
  | awk -F'\t' -v g="$APP_GROUP" '$1 == g { print $2 }')
[ -n "$GROUP_DIR" ] || fail "no App Group container for $APP_GROUP"
LOG_FILE="$GROUP_DIR/dictus_debug.log"

# --- 4. Liveness -------------------------------------------------------------
step "4 liveness"

# `simctl launch` exits 0 for a process that crashes a second later (simulator.md
# section 3). Wait for the first screen, then check the pid itself.
wait_for id onboarding.primary 30 >/dev/null || fail "the onboarding intro never appeared"
ps -p "$APP_PID" >/dev/null || fail "DictusApp pid $APP_PID is gone after launch"
wait_log '<APP> appLaunched' 10 >/dev/null || fail "no '<APP> appLaunched' line in $LOG_FILE"
say "pid $APP_PID alive, appLaunched logged"

# --- 5. Navigation -----------------------------------------------------------
step "5 navigation"

# Intro -> language step -> back. Not "Continuer" on the language step: that starts a
# model download, which this test must never do.
#
# Screenshots of each screen go to the run directory: on 2026-10-15, on a heavily loaded
# Mac, one run left this step for Siri's settings page ("◀ Dictus") without a log line
# saying how. The next occurrence should leave the screens behind it.
sleep 2
is_present id onboarding.back && fail "the intro already shows a back control"
xcrun simctl io "$UDID" screenshot "$RUN_DIR/nav-1-intro.png" >/dev/null 2>&1 || true
tap id onboarding.primary
wait_for id onboarding.back 10 >/dev/null || fail "Get started did not reach the language step"
# The back control exists only on the language step (`OnboardingStep.stepBack`), which is
# what makes it the proof of where the tap landed. Let the push finish before tapping it.
sleep 1
xcrun simctl io "$UDID" screenshot "$RUN_DIR/nav-2-language.png" >/dev/null 2>&1 || true
is_present id onboarding.back || fail "the language step went away before Back was tapped"
tap id onboarding.back
waited=0
while is_present id onboarding.back; do
  [ "$waited" -lt 10 ] || fail "Back did not return to the intro"
  sleep 1
  waited=$((waited + 1))
done
wait_for id onboarding.primary 10 >/dev/null || fail "the intro's Get started is missing after Back"
ps -p "$APP_PID" >/dev/null || fail "DictusApp pid $APP_PID died during navigation"
say "intro -> language -> intro"


# --- 6. Full Access ----------------------------------------------------------
step "6 full access"

xcrun simctl launch "$UDID" com.apple.Preferences >/dev/null || fail "could not open Settings"
wait_for id com.apple.settings.general 20 >/dev/null || fail "Settings did not show its root screen"
tap_until id com.apple.settings.general id Keyboard
tap_until id Keyboard id KEYBOARDS
tap_until id KEYBOARDS id "$KEYBOARD_ID"
tap_until id "$KEYBOARD_ID" id "Autoriser l’accès complet"

# The switch is not in the accessibility tree, only its row is; the switch sits at the
# row's trailing edge. A simulator-style tap does not move it: physical does
# (simulator.md section 8).
#
# WHY THE RETRIES AND THE PAUSES: fired the instant the page or the alert is pushed, a tap
# can be swallowed by the transition and the grant silently does not happen (measured
# 2026-10-14: the keyboard then came up with "Accès complet requis"). So each tap waits
# for its screen to settle and is checked by what it should have caused — the alert
# appearing, then the alert going away. The keyboard's own `fullAccess=true` in step 7
# remains the real proof.
frame=$(stable_frame id "Autoriser l’accès complet") || fail "no Full Access row in the Dictus keyboard settings"
read -r x y w h <<<"$frame"
granted=no
for _ in 1 2 3; do
  sleep 1
  axe tap -x "$(python3 -c "print(round($x + $w - 45))")" -y "$(center "$y" "$h")" \
    --tap-style physical --udid "$UDID" >/dev/null || fail "could not tap the Full Access switch"
  wait_for label Refuser 5 >/dev/null || continue
  sleep 1
  tap label Autoriser
  waited=0
  while is_present label Refuser && [ "$waited" -lt 5 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  is_present label Refuser && continue
  granted=yes
  break
done
[ "$granted" = yes ] || fail "the Full Access confirmation never appeared or never closed"
xcrun simctl io "$UDID" screenshot "$RUN_DIR/full-access.png" >/dev/null 2>&1 || true

# --- 7. Keyboard in a host app -----------------------------------------------
step "7 select the Dictus keyboard"

# DictusApp is terminated on purpose, right before the host app opens: the mic tap below
# then always takes the cold-start path (Darwin post unanswered, URL fallback, app
# launched by the keyboard), instead of depending on whether iOS happened to keep a
# backgrounded process running. Granting Full Access in step 6 already kills the app
# (SpringBoard logs its exit as `domain:tcc(11)`, measured 2026-10-15), but that is
# iOS's behaviour, not a guarantee this test should lean on.
#
# terminate's exit code is not the check: it is non-zero for an app that is already
# gone, which is the outcome wanted. What is checked is that the process is gone —
# launchd no longer lists it and the launch pid has exited — and step 9 then requires
# the cold-start marker, so a warm hand-off cannot pass for this one.
xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
waited=0
while :; do
  SERVICES=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true)
  if ! grep -q "UIKitApplication:$APP_ID\[" <<<"$SERVICES" && ! ps -p "$APP_PID" >/dev/null; then
    break
  fi
  [ "$waited" -lt 10 ] || fail "DictusApp is still running after terminate: the hand-off would not be a cold start"
  sleep 1
  waited=$((waited + 1))
done
say "DictusApp terminated: the mic tap will cold-start it"

# Onboarding is marked finished before the tap (#827). Before it is, the keyboard only
# opens Dictus on onboarding and asks for no dictation, so the chain below would never
# start. Steps 4-5 have already checked the onboarding screens; what follows is the
# hand-off an onboarded user gets. Written while the app is not running, into the App
# Group plist from inside the device, as `verify-dictus-ios`'s `launch.sh
# --skip-onboarding` does.
xcrun simctl spawn "$UDID" defaults write \
  "$GROUP_DIR/Library/Preferences/$APP_GROUP.plist" dictus.hasCompletedOnboarding -bool YES \
  || fail "could not mark onboarding as finished"

xcrun simctl launch "$UDID" com.apple.mobilesafari >/dev/null || fail "could not open Safari"
tap id TabBarItemTitle

# A fresh device shows two first-run splashes the first time a field takes focus:
# Safari's suggestions notice and the keyboard's slide-to-type tip. Both close on
# "Continuer". Neither is part of what is being tested.
for _ in 1 2 3 4; do
  is_present label Continuer || break
  tap label Continuer
  sleep 1
done

frame=$(stable_frame label "Clavier suivant") || fail "no globe key: the keyboard did not come up"
read -r x y w h <<<"$frame"

# A held press needs one HID session, which is `batch`; a tap would cycle past the
# third-party keyboards (simulator.md section 5).
gx=$(center "$x" "$w")
gy=$(center "$y" "$h")
axe batch --udid "$UDID" \
  --step "touch -x $gx -y $gy --down" --step "sleep 1.8" --step "touch -x $gx -y $gy --up" >/dev/null \
  || fail "could not long-press the globe key"
tap label "Dictus, multilingue"

wait_log '<KBD> .*fullAccess=true' 15 >/dev/null || fail "the Dictus keyboard never logged fullAccess=true"

# --- 8. Mic tap --------------------------------------------------------------
step "8 tap the mic"

# The Dictus keyboard's own controls are not in the accessibility tree; its view is one
# opaque remote element (`inputView`). The mic sits at the trailing end of its toolbar,
# the top row of that element. The log lines below are what prove the tap landed.
frame=$(stable_frame id inputView) || fail "no inputView: the Dictus keyboard is not on screen"
read -r x y w h <<<"$frame"
sleep 1
xcrun simctl io "$UDID" screenshot "$RUN_DIR/keyboard.png" >/dev/null 2>&1 || fail "could not take the keyboard screenshot"
LOG_FROM=$(($(wc -l <"$LOG_FILE") + 1))
axe tap -x "$(python3 -c "print(round($x + $w - 45))")" -y "$(python3 -c "print(round($y + 28))")" \
  --udid "$UDID" >/dev/null || fail "could not tap the mic"

# --- 9. Assertions -----------------------------------------------------------
step "9 assert the no-model failure"

# Each line is one link of the chain: the keyboard took the tap, the app was cold-started
# by the keyboard's URL and refused the dictation for want of a model, and the keyboard
# learned of the failure through the App Group. Each search starts after the line the
# previous one matched, so a line from before its cause cannot satisfy it.
#
# WHY THE LAST LINK STARTS AFTER THE HAND-OFF AND NOT AFTER THE APP'S FAILURE LINE: each
# process appends to the log from its own asynchronous queue, so across processes the
# file order is the order of the writes, not of the events. The keyboard's `to=failed`
# landed in the file BEFORE the app's `dictationFailed` in 7 of the 9 runs that produced
# both (measured 2026-10-15), although it can only follow it: the keyboard reaches
# `failed` from `requested` solely by adopting the status the app wrote to the App Group
# (its watchdog resets to idle, never to failed). Requiring file order there would fail
# most runs and prove nothing more. Within one process the order is the event order, and
# the keyboard's line is still required after the app's cold start.
TAP_LINE=$(wait_log '<KBD> keyboardMicTapped' 15 "$LOG_FROM") \
  || fail "no '<KBD> keyboardMicTapped': the mic tap did not reach the keyboard"
# A new process first: `<APP> appLaunched` after the tap is the one line only a process
# started by this hand-off can write. The URL marker alone does not prove it — the app
# logs `coldStartURLReceived` for every keyboard URL, and its `isColdStart=true` means
# "this process has never been active", which a process launched in the background and
# still alive also satisfies (measured 2026-10-15 with the terminate removed: same pid,
# no new appLaunched, `isColdStart=true`).
LAUNCH_LINE=$(wait_log '<APP> appLaunched' 20 $((TAP_LINE + 1))) \
  || fail "no '<APP> appLaunched' after the tap: the hand-off reached a DictusApp that was already running, not a cold start"
URL_LINE=$(wait_log '<APP> coldStartURLReceived isColdStart=true' 20 $((LAUNCH_LINE + 1))) \
  || fail "no '<APP> coldStartURLReceived isColdStart=true' after the launch: DictusApp was not cold-started by the keyboard's URL"
APP_FAILED_LINE=$(wait_log '<APP> dictationFailed error=No model downloaded' 20 $((URL_LINE + 1))) \
  || fail "no '<APP> dictationFailed error=No model downloaded' after the hand-off"
KBD_FAILED_LINE=$(wait_log '<KBD> statusChanged from=requested to=failed' 15 $((URL_LINE + 1))) \
  || fail "the keyboard never saw the failure ('<KBD> statusChanged from=requested to=failed' after the hand-off)"
say "chain at log lines: tap $TAP_LINE, app launch $LAUNCH_LINE, cold start $URL_LINE, app failure $APP_FAILED_LINE, keyboard failure $KBD_FAILED_LINE"

# And nothing died on the way: the app is still running, and SpringBoard recorded no
# crash of any Dictus process during the run.
SERVICES=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null || true)
grep -q "UIKitApplication:$APP_ID\[" <<<"$SERVICES" || fail "DictusApp is not running after the hand-off"
EXITS=$(xcrun simctl spawn "$UDID" log show --last 15m --style compact \
  --predicate 'process == "SpringBoard" AND eventMessage CONTAINS "Process exited"' 2>/dev/null || true)
# SIGKILL is left out on purpose: it is how the system reclaims an extension it is done
# with — the widget extension is killed that way after rendering, in every run (measured
# 2026-10-14). A crash is the other signals: SIGSEGV, SIGABRT, SIGBUS, SIGTRAP, SIGILL.
CRASHES=$(grep "pivi.dictus" <<<"$EXITS" | grep "domain:signal" | grep -v "SIGKILL" || true)
if [ -n "$CRASHES" ]; then
  echo "$CRASHES" >"$RUN_DIR/process-exits.log"
  fail "a Dictus process crashed during the run, see $RUN_DIR/process-exits.log"
fi

# --- 10. Evidence -------------------------------------------------------------
step "10 evidence"

sleep 2
xcrun simctl io "$UDID" screenshot "$RUN_DIR/final.png" >/dev/null 2>&1 || fail "could not take the final screenshot"
# The Full Access line predates the tap, so it is taken from the whole log.
{
  grep -m1 '<KBD> .*fullAccess=true' "$LOG_FILE" || true
  tail -n +"$LOG_FROM" "$LOG_FILE" \
    | grep -E 'keyboardMicTapped|coldStart|dictationStarted|dictationFailed|statusChanged|dictationMessage|hostReturn|appLaunched' \
    || true
} >"$RUN_DIR/evidence.log"
say "screenshots: $RUN_DIR/keyboard.png $RUN_DIR/final.png"
say "evidence: $RUN_DIR/evidence.log"

# The run must not have put a simulator window in front of the maintainer's work.
# An unreadable frontmost app is reported by cleanup, not failed here.
FRONT_END=$(frontmost_app)
case "$FRONT_END" in
  Simulator | DeviceHub) fail "$FRONT_END is the frontmost app" ;;
esac

# --- 11. Cleanup: in the EXIT trap, which prints the result line ---------------
step "11 cleanup"
PASSED=yes
