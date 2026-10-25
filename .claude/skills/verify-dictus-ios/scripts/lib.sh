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

# Each session gets its own pointer to its current run, so parallel sessions on this Mac
# never resolve each other's run (and cleanup.sh never deletes another session's device).
# A session is a worktree by default; set DICTUS_VERIFY_SESSION to split one worktree
# between several sessions. There is deliberately no shared `latest` link.
SESSION_ID="${DICTUS_VERIFY_SESSION:-$(basename "$REPO_ROOT")-$(printf '%s' "$REPO_ROOT" | shasum | cut -c1-8)}"
SESSION_LINK="$EVIDENCE_ROOT/sessions/$SESSION_ID"

# Devices this skill creates carry this prefix, and cleanup.sh refuses to delete any
# device whose name does not start with it.
DEVICE_PREFIX="Dictus Verify"

die() { echo "error: $*" >&2; exit 1; }

# load_run [run-dir] — loads run.env from the given run, else from $DICTUS_VERIFY_RUN, else
# from this session's pointer. Never from another session's.
load_run() {
  local dir=${1:-${DICTUS_VERIFY_RUN:-$SESSION_LINK}}
  [ -f "$dir/run.env" ] || die "no run.env in $dir (run launch.sh first, or pass the run dir from its READY line)"
  # shellcheck disable=SC1091
  . "$dir/run.env"
  RUN_DIR=$(cd "$dir" && pwd -P)
}

center() { python3 -c "print(round($1 + $2 / 2))"; }

# find_frame <id|label> <value> — reads an `axe describe-ui` tree on stdin and prints
# "x y w h" (points) of the first element whose AXUniqueId or AXLabel equals the value.
# First match, not `axe tap --id`: axe refuses when several elements share an identifier,
# and Settings repeats its row identifiers on nested elements. The recipes rely on that;
# drive.sh's tap-id and tap-label go through tap_unique instead, which refuses to guess.
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

# find_matches <id|label> <value> [type] — reads an `axe describe-ui` tree on stdin and
# prints one line per element whose AXUniqueId or AXLabel equals the value (and whose type
# equals `type`, when given): "x y w h", a tab, a description for error messages, a tab,
# then `on` or `off` (whether the frame centre lies on the screen, the first root's frame:
# a list keeps rows laid out below the fold, and a tap there lands on nothing).
# Elements sharing one frame are listed once: a tap at that centre cannot tell them apart.
# Exits 1 when nothing matches.
find_matches() {
  python3 -c '
import json, sys
kind, value, wanted = sys.argv[1], sys.argv[2], sys.argv[3]
key = "AXUniqueId" if kind == "id" else "AXLabel"
seen = []
screen = None
def walk(node):
    if node.get(key) == value and (not wanted or node.get("type") == wanted):
        f = node["frame"]
        frame = (f["x"], f["y"], f["width"], f["height"])
        if frame not in seen:
            seen.append(frame)
            desc = "type=%s label=%r id=%s frame=(%s)" % (
                node.get("type"), node.get("AXLabel"), node.get("AXUniqueId") or "-",
                ", ".join("%g" % round(v, 1) for v in frame))
            cx, cy = frame[0] + frame[2] / 2, frame[1] + frame[3] / 2
            sx, sy, sw, sh = screen
            onscreen = sx <= cx < sx + sw and sy <= cy < sy + sh
            print("%s %s %s %s\t%s\t%s" % (frame + (desc, "on" if onscreen else "off")))
    for child in node.get("children") or []:
        walk(child)
roots = json.load(sys.stdin)
if roots:
    f = roots[0]["frame"]
    screen = (f["x"], f["y"], f["width"], f["height"])
for root in roots:
    walk(root)
sys.exit(0 if seen else 1)
' "$1" "$2" "${3:-}"
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

# tap_unique <id|label> <value> [type] — tap, but only when exactly one element matches
# (once the screen is stable); with several, lists them and exits 1 instead of picking one.
# Also exits 1 when that one element is off screen, rather than tapping nothing.
tap_unique() {
  local kind=$1 value=$2 type=${3:-} what matches count x y w h
  what="$kind '$value'${type:+ of type $type}"
  stable_frame "$kind" "$value" >/dev/null || die "no element with $what on screen"
  matches=$(axe describe-ui --udid "$UDID" 2>/dev/null | find_matches "$kind" "$value" "$type") \
    || die "no element with $what on screen"
  count=$(printf '%s\n' "$matches" | wc -l | tr -d ' ')
  if [ "$count" -gt 1 ]; then
    {
      echo "error: $count elements with $what on screen, refusing to guess which to tap:"
      printf '%s\n' "$matches" | cut -f2 | sed 's/^/  /'
      if [ "$kind" = label ]; then
        echo "  use tap-id <identifier> on the one you mean (id=- means it has none)"
      else
        echo "  the identifier is not unique on this screen: tap-label, or make it unique in the app"
      fi
    } >&2
    exit 1
  fi
  if [ "${matches##*$'\t'}" = off ]; then
    die "the element with $what is off screen at $(printf '%s' "$matches" | cut -f2 | sed 's/.* frame=//'): scroll it into view first"
  fi
  read -r x y w h <<<"${matches%%$'\t'*}"
  axe tap -x "$(center "$x" "$w")" -y "$(center "$y" "$h")" --udid "$UDID" >/dev/null \
    || die "axe could not tap $what"
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
