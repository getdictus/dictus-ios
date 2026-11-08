#!/bin/bash
# evidence.sh — capture the current screen, its accessibility tree and the log tail.
#
# Usage:
#   .claude/skills/verify-dictus-ios/scripts/evidence.sh <name> [run-dir]
#
# Writes into the run directory (never into the repository):
#   <name>.png        screenshot, device pixels
#   <name>.ui.json    `axe describe-ui` tree (points)
#   <name>.log        last 40 lines of dictus_debug.log
# and appends one line per capture to report.txt.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

NAME=${1:?usage: evidence.sh <name> [run-dir]}
load_run "${2:-}"

xcrun simctl io "$UDID" screenshot "$RUN_DIR/$NAME.png" >/dev/null 2>&1 \
  || die "screenshot failed for $UDID"
axe describe-ui --udid "$UDID" >"$RUN_DIR/$NAME.ui.json" 2>/dev/null || echo '[]' >"$RUN_DIR/$NAME.ui.json"
if [ -f "${LOG_FILE:-}" ]; then tail -40 "$LOG_FILE" >"$RUN_DIR/$NAME.log"; fi
echo "[$(date +%H:%M:%S)] evidence $NAME: $RUN_DIR/$NAME.png" | tee -a "$RUN_DIR/report.txt"
