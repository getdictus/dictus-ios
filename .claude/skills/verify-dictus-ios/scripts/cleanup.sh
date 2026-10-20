#!/bin/bash
# cleanup.sh — delete the simulator a run created. Keeps every piece of evidence.
#
# Usage:
#   .claude/skills/verify-dictus-ios/scripts/cleanup.sh [run-dir]
#
# Defaults to the `latest` run. It deletes exactly one device: the UDID recorded in the
# run's run.env, and only if that device's name starts with "Dictus Verify". It never
# kills a process by name, never touches another simulator, and never removes anything
# under the evidence directory. Last line: `CLEANUP OK udid=<udid> deleted=yes`.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

load_run "${1:-}"

NAME=$(xcrun simctl list devices -j | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["udid"] == sys.argv[1]:
            print(d["name"])
' "$UDID")

if [ -z "$NAME" ]; then
  echo "device $UDID is already gone"
else
  case "$NAME" in
    "$DEVICE_PREFIX "*) ;;
    *) die "device $UDID is named '$NAME', not '$DEVICE_PREFIX …': refusing to delete it" ;;
  esac
  # The App Group container goes with the device: copy the log out first.
  if [ -n "${LOG_FILE:-}" ] && [ -f "$LOG_FILE" ]; then
    cp "$LOG_FILE" "$RUN_DIR/dictus_debug.full.log"
    echo "saved $RUN_DIR/dictus_debug.full.log"
  fi
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$UDID"
fi

# Build noise from launch.sh, restored only if the catalogs were clean at launch.
cd "$REPO_ROOT"
if [ "${XCSTRINGS_CLEAN_AT_LAUNCH:-no}" = yes ] && [ -n "$(git status --porcelain -- '*.xcstrings')" ]; then
  git checkout -- '*.xcstrings'
  echo "restored the .xcstrings catalogs"
fi

if xcrun simctl list devices | grep -q "$UDID"; then
  die "device $UDID still exists after delete"
fi
echo "evidence kept: $RUN_DIR ($(find "$RUN_DIR" -type f | wc -l | tr -d ' ') files)"
echo "CLEANUP OK udid=$UDID deleted=yes" | tee -a "$RUN_DIR/report.txt"
