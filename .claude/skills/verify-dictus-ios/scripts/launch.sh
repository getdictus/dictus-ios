#!/bin/bash
# launch.sh — create a dedicated simulator for this run, slim it, build DictusApp, install
# it, launch it, and wait until it is really up.
#
# Usage:
#   .claude/skills/verify-dictus-ios/scripts/launch.sh [--lang fr|en] [--skip-onboarding]
#
#   --lang en           device in en-US instead of fr-FR (system labels change; the
#                       recipes in SKILL.md quote the French ones)
#   --skip-onboarding   once the intro is up, set `dictus.hasCompletedOnboarding` in the App
#                       Group defaults and relaunch, straight to the tab bar (no model installed)
#
# Prints, last line on success:
#   READY udid=<udid> run=<run-dir> pid=<pid> screen=<onboarding|home>
#
# Every run gets its own device, named "Dictus Verify <run-id>", which cleanup.sh deletes.
# It never reuses, erases or deletes a device it did not create.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

LANG_CODE=fr
SKIP_ONBOARDING=no
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_CODE=$2; shift 2 ;;
    --skip-onboarding) SKIP_ONBOARDING=yes; shift ;;
    *) die "unknown argument $1" ;;
  esac
done

DEVICE_TYPE="${DICTUS_VERIFY_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17}"
# iOS 26.5, not 27: on iOS 27 the system may mount no third-party keyboard at all.
RUNTIME="${DICTUS_VERIFY_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"

cd "$REPO_ROOT"
COMMIT=$(git rev-parse --short HEAD)
[ -n "$(git status --porcelain -- . ':!.claude')" ] && COMMIT="$COMMIT-dirty"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$COMMIT"
RUN_DIR="$EVIDENCE_ROOT/$RUN_ID"
mkdir -p "$RUN_DIR"
ln -sfn "$RUN_DIR" "$EVIDENCE_ROOT/latest"
REPORT="$RUN_DIR/report.txt"
say() { echo "$*" | tee -a "$REPORT"; }

for tool in xcodebuild axe simslim python3; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

say "verify-dictus-ios launch  commit=$COMMIT  $(xcodebuild -version | head -1)"
say "frontmost app at start: $(frontmost_app)"

# --- Device: created for this run only ---------------------------------------
DEVICE_NAME="$DEVICE_PREFIX $RUN_ID"
UDID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME") \
  || die "could not create $DEVICE_NAME ($DEVICE_TYPE, $RUNTIME)"
XCSTRINGS_BEFORE=$(git status --porcelain -- '*.xcstrings')
cat >"$RUN_DIR/run.env" <<EOF
UDID=$UDID
DEVICE_NAME="$DEVICE_NAME"
COMMIT=$COMMIT
XCSTRINGS_CLEAN_AT_LAUNCH=$([ -z "$XCSTRINGS_BEFORE" ] && echo yes || echo no)
EOF
say "created $DEVICE_NAME $UDID"

# Language and keyboard list, written while the device is shut down (simulator.md §6, §8).
# AppleKeyboardsExpanded is required on a fresh device, or iOS rebuilds the list without Dictus.
PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/.GlobalPreferences.plist"
python3 - "$PREFS" "$KEYBOARD_ID" "$LANG_CODE" <<'PY' || die "could not write device preferences"
import os, plistlib, sys
path, keyboard, lang = sys.argv[1:4]
prefs = plistlib.load(open(path, "rb")) if os.path.exists(path) else {}
if lang == "en":
    prefs["AppleLanguages"], prefs["AppleLocale"] = ["en-US", "fr-FR"], "en_US"
else:
    prefs["AppleLanguages"], prefs["AppleLocale"] = ["fr-FR", "en-GB"], "fr_FR"
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

# simslim disables background daemons through the device's launchd overrides, then boots
# the device slimmed (it leaves it booted). `--keep com.apple.remindd` keeps Reminders
# usable (CLAUDE.md). Run after the preferences write, which needs the device shut down.
simslim on "$UDID" --keep com.apple.remindd >"$RUN_DIR/simslim.log" 2>&1 \
  || die "simslim on failed, see $RUN_DIR/simslim.log"
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "09:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 >/dev/null 2>&1 || true

# axe needs the device attached. Xcode 27 has no Simulator.app and needs nothing; Xcode 26
# needs Simulator.app running in the BACKGROUND (`open -g`), never `open -a Simulator`.
attached=no
for _ in 1 2 3 4 5 6; do
  if axe describe-ui --udid "$UDID" >/dev/null 2>&1; then attached=yes; break; fi
  [ -d "$(xcode-select -p)/Applications/Simulator.app" ] && open -g -a Simulator
  sleep 5
done
[ "$attached" = yes ] || die "axe cannot reach $UDID (docs/agents/simulator.md §5)"
say "booted, slimmed, axe attached"

# --- Build: signed ad hoc, never with CI's CODE_SIGNING_ALLOWED=NO --------------
# An unsigned build has no App Group container in the simulator, so no dictus_debug.log.
xcodebuild -resolvePackageDependencies -project Dictus.xcodeproj -scheme DictusApp \
  -derivedDataPath "$DERIVED_DATA" >"$RUN_DIR/resolve.log" 2>&1 \
  || die "package resolution failed, see $RUN_DIR/resolve.log"
xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" >"$RUN_DIR/build.log" 2>&1 \
  || die "build failed, see $RUN_DIR/build.log"
# The build may rewrite Localizable.xcstrings: build noise, never committed (CLAUDE.md).
if [ -z "$XCSTRINGS_BEFORE" ] && [ -n "$(git status --porcelain -- '*.xcstrings')" ]; then
  git checkout -- '*.xcstrings'
  say "restored the .xcstrings catalogs the build rewrote"
fi
[ -d "$APP_PATH/PlugIns/DictusKeyboard.appex" ] || die "built app has no DictusKeyboard.appex"
say "built $(git rev-parse --short HEAD)"

# --- Install, launch, and wait for the real ready state -----------------------
xcrun simctl install "$UDID" "$APP_PATH"
PLUGINS=$(xcrun simctl spawn "$UDID" pluginkit -m -p com.apple.keyboard-service 2>/dev/null || true)
grep -q "$KEYBOARD_ID" <<<"$PLUGINS" || die "the keyboard extension did not register with pluginkit"

LAUNCH_OUTPUT=$(xcrun simctl launch "$UDID" "$APP_ID") \
  || die "launch failed: $LAUNCH_OUTPUT"
APP_PID=${LAUNCH_OUTPUT##*: }

GROUP_DIR=$(xcrun simctl get_app_container "$UDID" "$APP_ID" groups \
  | awk -F'\t' -v g="$APP_GROUP" '$1 == g { print $2 }')
[ -n "$GROUP_DIR" ] || die "no App Group container for $APP_GROUP (unsigned build?)"
LOG_FILE="$GROUP_DIR/dictus_debug.log"
cat >>"$RUN_DIR/run.env" <<EOF
APP_PID=$APP_PID
GROUP_DIR="$GROUP_DIR"
LOG_FILE="$GROUP_DIR/dictus_debug.log"
EOF

# Ready means: the first screen's controls are in the accessibility tree, the launched pid
# is still alive, and the app wrote `<APP> appLaunched` to the App Group log. `simctl
# launch` exits 0 for an app that crashes a second later, so none of the three is optional.
SCREEN=""
for _ in $(seq 1 40); do
  TREE=$(axe describe-ui --udid "$UDID" 2>/dev/null || true)
  if find_frame id onboarding.primary <<<"$TREE" >/dev/null; then SCREEN=onboarding; break; fi
  if find_frame label Accueil <<<"$TREE" >/dev/null || find_frame label Home <<<"$TREE" >/dev/null; then
    SCREEN=home; break
  fi
  sleep 1
done
[ -n "$SCREEN" ] || die "neither the onboarding intro nor the tab bar appeared within 40 s"
ps -p "$APP_PID" >/dev/null || die "DictusApp pid $APP_PID is gone after launch"
wait_log '<APP> appLaunched' 15 >/dev/null || die "no '<APP> appLaunched' in $LOG_FILE"

# The onboarding flag lives in the App Group suite, not the app's standard defaults, so a
# `-dictus.hasCompletedOnboarding YES` launch argument does not reach it. It is written
# into the group's plist from inside the device, then the app is relaunched.
if [ "$SKIP_ONBOARDING" = yes ] && [ "$SCREEN" = onboarding ]; then
  xcrun simctl terminate "$UDID" "$APP_ID" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl spawn "$UDID" defaults write \
    "$GROUP_DIR/Library/Preferences/$APP_GROUP.plist" dictus.hasCompletedOnboarding -bool YES
  LAUNCH_OUTPUT=$(xcrun simctl launch "$UDID" "$APP_ID") || die "relaunch failed: $LAUNCH_OUTPUT"
  APP_PID=${LAUNCH_OUTPUT##*: }
  sed -i '' "s/^APP_PID=.*/APP_PID=$APP_PID/" "$RUN_DIR/run.env"
  wait_for label Accueil 30 >/dev/null || wait_for label Home 5 >/dev/null \
    || die "the tab bar did not appear after skipping onboarding"
  ps -p "$APP_PID" >/dev/null || die "DictusApp pid $APP_PID is gone after relaunch"
  SCREEN=home
fi
echo "SCREEN=$SCREEN" >>"$RUN_DIR/run.env"

sleep 1
xcrun simctl io "$UDID" screenshot "$RUN_DIR/00-launch.png" >/dev/null 2>&1 || true
say "READY udid=$UDID run=$RUN_DIR pid=$APP_PID screen=$SCREEN"
