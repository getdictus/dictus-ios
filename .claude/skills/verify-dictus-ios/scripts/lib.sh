#!/bin/bash
# lib.sh — shared constants and accessibility helpers for the verify-dictus-ios scripts.
#
# Sourced, never run. Every helper takes the device from $UDID, which each script loads
# from the run's `run.env` (written by launch.sh). Nothing here creates, erases or
# deletes a device; launch.sh and cleanup.sh are the only scripts that do.

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
REPO_ROOT=$(cd "$SKILL_DIR/../../.." && pwd)

APP_ID=com.pivi.dictus
KEYBOARD_ID=com.pivi.dictus.keyboard
APP_GROUP=group.solutions.pivi.dictus
DERIVED_DATA="$REPO_ROOT/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/DictusApp.app"

# Evidence lives outside the repository, one directory per run, and is never deleted by
# these scripts — cleanup.sh included.
EVIDENCE_ROOT="${DICTUS_VERIFY_EVIDENCE:-$HOME/dev/dictus-evidence/verify-skill}"

# Devices this skill creates carry this prefix, and cleanup.sh refuses to delete any
# device whose name does not start with it.
DEVICE_PREFIX="Dictus Verify"

die() { echo "error: $*" >&2; exit 1; }

# load_run [run-dir] — loads run.env from the given run, or from the `latest` link.
load_run() {
  local dir=${1:-$EVIDENCE_ROOT/latest}
  [ -f "$dir/run.env" ] || die "no run.env in $dir (run launch.sh first)"
  # shellcheck disable=SC1091
  . "$dir/run.env"
  RUN_DIR=$(cd "$dir" && pwd -P)
}

center() { python3 -c "print(round($1 + $2 / 2))"; }

# find_frame <id|label> <value> — reads an `axe describe-ui` tree on stdin and prints
# "x y w h" (points) of the first element whose AXUniqueId or AXLabel equals the value.
# First match, not `axe tap --id`: axe refuses when several elements share an identifier,
# and Settings repeats its row identifiers on nested elements.
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

# stable_frame <id|label> <value> — wait_for, but only once the element stopped moving
# (Settings inserts rows while its root loads, and an early frame hits the row below).
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

# tap <id|label> <value> [extra axe args] — taps the element's centre, or fails.
tap() {
  local kind=$1 value=$2 frame x y w h
  shift 2
  frame=$(stable_frame "$kind" "$value") || die "no element with $kind '$value' on screen"
  read -r x y w h <<<"$frame"
  axe tap -x "$(center "$x" "$w")" -y "$(center "$y" "$h")" --udid "$UDID" "$@" >/dev/null \
    || die "axe could not tap $kind '$value'"
}

# tap_until <kind> <value> <expect-kind> <expect-value> — taps, requires the expected
# element on the next screen, goes back with BackButton and retries otherwise (3 tries).
tap_until() {
  local kind=$1 value=$2 expect_kind=$3 expect_value=$4 attempt
  for attempt in 1 2 3; do
    sleep 1
    tap "$kind" "$value"
    if wait_for "$expect_kind" "$expect_value" 10 >/dev/null; then
      return 0
    fi
    echo "  tap on $kind '$value' did not reach '$expect_value' (attempt $attempt)" >&2
    if is_present id BackButton; then tap id BackButton; fi
  done
  die "tapping $kind '$value' never reached $expect_kind '$expect_value'"
}

# wait_log <regex> [timeout] [from line] — prints the line number of the first match in
# the App Group log at or after `from`.
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

frontmost_app() {
  # Needs Automation permission for System Events; "unknown" when it is missing.
  osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' \
    2>/dev/null || echo unknown
}
