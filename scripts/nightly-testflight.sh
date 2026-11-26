#!/bin/bash
# nightly-testflight.sh — build develop's tip and send it to internal TestFlight.
#
# Two slots, run by launchd (install, uninstall and logs in docs/nightly-testflight.md):
#   soir  22:00         scripts/launchd/solutions.pivi.dictus.nightly-testflight.plist
#   midi  12:00, 12:30  scripts/launchd/solutions.pivi.dictus.midday-testflight.plist
# Each run builds, or skips and says why, or fails and says where. Two outputs:
#   ~/dev/proofs/nightly/<stem>.md              the summary, one screen
#   ~/Library/Logs/dictus-nightly/<stem>.log    everything, credentials redacted
# <stem> is <date> for soir (the names the first nightly used) and <date>-midi for midi.
# A run that does not build never overwrites a summary of the same slot and day that
# says built or uploaded: it writes <stem>.retry.md (the 12:30 attempt after 12:00).
#
# A real run, in order. Any skip or failure stops it at that step:
#    1. lock; skip if another nightly, a cut/upload/promote script or an archive is running
#    2. git fetch; HEAD = origin/develop
#    3. skip if a build/NN tag already points to HEAD
#    4. skip unless the CI run of HEAD on develop has every job of CI_JOBS green (read only)
#    5. skip if HEAD's marketing version is the one on main (closed train, ASC refuses it)
#    6. NN = max(highest build number in App Store Connect, highest build/NN tag) + 1
#    7. detached worktree at HEAD; CFBundleVersion = NN in the four plists, never committed
#    8. scripts/upload-testflight.sh from that worktree: archive, export, upload, wait.
#       Once the upload is committed the build exists in App Store Connect, so a
#       processing wait that runs out is not a failure: the run waits T_PROCESS more,
#       then goes on (status `uploaded` if App Store Connect is still processing)
#    9. check the IPA: build NN, and DictusBuildInfo names HEAD in the app and the keyboard
#   10. push the lightweight tag build/NN, alone
#   11. What to Test in fr-FR and en-GB, from each merged PR's `## TestFlight` block
#   12. remove the worktree and its temp dirs; keep only the latest IPA
#
# Internal only, both slots. Team PIVI sees every build because that group has access to
# all builds. This script adds no group, submits nothing to beta review and never touches
# the App Store.
#
# Usage:
#   scripts/nightly-testflight.sh [--slot midi|soir] [--dry-run]
#     --slot      soir (default) or midi: sets the file names and the What to Test
#                 header, nothing else
#     --dry-run   steps 1-6 for real (fetch, tags, CI, gh and ASC reads), then prints
#                 7-12 without doing them
#   NIGHTLY_CACHE_DIR, NIGHTLY_LOG_DIR and NIGHTLY_PROOF_DIR move the three directories,
#   to try the script without touching the real ones.
#
# Written for /bin/bash 3.2, the one macOS ships: no associative arrays, no mapfile.
set -Eeuo pipefail

# --- Constants ---------------------------------------------------------------
ASC_APP_ID="6761262378"
GH_REPO="getdictus/dictus-ios"
CI_WORKFLOW="ci.yml"
CI_JOBS="SwiftLint|iOS (build + DictusCore + App Tests)"
PLISTS="DictusApp/Info.plist DictusKeyboard/Info.plist DictusShare/Info.plist DictusWidgets/Info.plist"
PB=/usr/libexec/PlistBuddy

# Timeouts, in seconds. A step that waits on a keychain or permission prompt never
# returns on its own; the timeout is what turns that into a clear failure line.
T_NET=120        # git fetch, git push
T_READ=90        # one gh or asc read
T_NOTES=120      # one What to Test write
T_PROBE=30       # the signing probe
T_UPLOAD=7200    # archive + export + upload + processing
T_PROCESS=2700   # the extra processing wait, when upload-testflight.sh's own ran out

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=20"
export GH_PROMPT_DISABLED=1
# The limit of one asc request, for the reads. Not the processing wait, which
# upload-testflight.sh bounds by ASC_PROCESSING_TIMEOUT (10 to 30 minutes in practice).
export ASC_TIMEOUT=90s
export ASC_PROCESSING_TIMEOUT=45m

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(git -C "$SCRIPT_DIR" rev-parse --path-format=absolute --git-common-dir)
REPO=$(dirname "$REPO")   # the main clone; worktrees share its refs and tags

DATE=$(date +%F)
CACHE_DIR="${NIGHTLY_CACHE_DIR:-$HOME/Library/Caches/dictus-nightly}"
LOG_DIR="${NIGHTLY_LOG_DIR:-$HOME/Library/Logs/dictus-nightly}"
PROOF_DIR="${NIGHTLY_PROOF_DIR:-$HOME/dev/proofs/nightly}"
KEEP_DIR="$CACHE_DIR/ipa"
KEEP_MANIFEST="$KEEP_DIR/created-by-nightly.txt"
LOCK_DIR="$CACHE_DIR/lock"

DRY_RUN=0
SLOT="soir"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --slot) [ $# -ge 2 ] || { echo "error: --slot needs midi or soir" >&2; exit 2; }
            SLOT=$2; shift ;;
    --slot=*) SLOT=${1#--slot=} ;;
    -h|--help) sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "error: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
  shift
done
# What the slot sets, and nothing else: the file names, the titles, the notes header.
case "$SLOT" in
  soir) STEM="$DATE";      TITLE="Nightly TestFlight"
        NOTES_HEAD_FR="Build du soir de develop"; NOTES_HEAD_EN="Nightly develop build" ;;
  midi) STEM="$DATE-midi"; TITLE="Midday TestFlight"
        NOTES_HEAD_FR="Build de midi de develop"; NOTES_HEAD_EN="Midday develop build" ;;
  *) echo "error: --slot must be midi or soir, not '$SLOT'" >&2; exit 2 ;;
esac

# REAL_SUMMARY is where a real run of this slot writes; a dry run writes beside it, so
# it never overwrites a real run.
REAL_SUMMARY="$PROOF_DIR/$STEM.md"
if [ "$DRY_RUN" -eq 1 ]; then
  LOG="$LOG_DIR/$STEM.dry-run.log"
  SUMMARY="$PROOF_DIR/$STEM.dry-run.md"
else
  LOG="$LOG_DIR/$STEM.log"
  SUMMARY="$REAL_SUMMARY"
fi

# --- State the summary reports ----------------------------------------------
STATUS="failed"
REASON="stopped before the first step"
SHA=""
SHORT=""
VERSION=""
NN=""
PREV_TAG=""
PR_LINES=""
PR_TABLE=""
FR_NOTES=""
EN_NOTES=""
UPLOAD_STATE=""
PROCESSED=0
CI_STATE="not read"
ASC_STATE="not read"
BUILD_INFO_STATE="not checked"
DRY_SKIPS=""
LOCK_HELD=0
RUN_DIR=""
WT=""
TAG_CREATED=0
TAG_PUSHED=0
IPA_KEPT=""

# fd 3 is where run_timeout reports a timeout: the terminal until logging starts, the
# log after. Not stdout, which a $(...) around the call would capture.
exec 3>&2

log() { printf '%s  %s\n' "$(date +%H:%M:%S)" "$*"; }
would() { log "DRY-RUN would: $*"; }

# run_timeout SECONDS LABEL CMD... — CMD in its own process group, stdin closed.
# Past SECONDS the whole group is killed and the call returns 124.
run_timeout() {
  local secs=$1 label=$2 rc=0
  shift 2
  perl -e '
    my $secs = shift @ARGV;
    my $pid = fork() // die "fork: $!\n";
    if ($pid == 0) { setpgrp(0, 0); exec { $ARGV[0] } @ARGV or die "exec $ARGV[0]: $!\n"; }
    $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 10; kill "KILL", -$pid; waitpid($pid, 0); exit 124; };
    alarm $secs;
    waitpid($pid, 0);
    alarm 0;
    exit(($? & 127) ? 128 + ($? & 127) : $? >> 8);
  ' "$secs" "$@" </dev/null || rc=$?
  if [ "$rc" -eq 124 ]; then
    log "TIMEOUT: '$label' did not finish within ${secs}s and was killed." \
        "If a keychain or permission dialog is on screen, that is what it was waiting on." >&3
  fi
  return "$rc"
}

# --- Credentials, before logging starts, never printed ----------------------
# scripts/upload-testflight.sh reads ASC_KEY_ID and ASC_ISSUER_ID from the environment.
# launchd does not source ~/.zshrc, so when they are not exported, ask asc for its
# default profile: it keeps both in the login keychain. Under a timeout, because a
# locked keychain answers with a dialog, not an error. Nothing here is printed; the
# log filter below also replaces both values wherever a tool echoes them.
CRED_NOTE="from the environment"
if [ -z "${ASC_KEY_ID:-}" ]; then
  ASC_KEY_ID=$(run_timeout "$T_READ" "asc auth status" asc auth status --output json 2>/dev/null \
    | jq -r '[.credentials[]? | select(.isDefault) | .keyId][0] // empty' 2>/dev/null || true)
  CRED_NOTE="from asc's default profile (keychain)"
fi
if [ -z "${ASC_ISSUER_ID:-}" ]; then
  ASC_ISSUER_ID=$(run_timeout "$T_READ" "asc auth issuer-id" asc auth issuer-id 2>/dev/null || true)
fi
export ASC_KEY_ID="${ASC_KEY_ID:-}" ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"

# --- Logging: stdout and stderr go to the log, through a redaction filter ----
mkdir -p "$CACHE_DIR" "$LOG_DIR" "$PROOF_DIR" "$KEEP_DIR"
exec > >(perl -pe 'BEGIN { $| = 1; @s = grep { length } @ENV{qw(ASC_KEY_ID ASC_ISSUER_ID)} }
                   for my $s (@s) { s/\Q$s\E/<redacted>/g }' | tee -a "$LOG") 2>&1
exec 3>&1

skip() {
  if [ "$DRY_RUN" -eq 1 ]; then
    log "DRY-RUN: a real run would SKIP here: $*"
    DRY_SKIPS="${DRY_SKIPS}- $*
"
    return 0
  fi
  STATUS="skipped"
  REASON="$*"
  log "SKIP: $*"
  exit 0
}

fail() {
  STATUS="failed"
  REASON="$*"
  log "FAIL: $*"
  exit 1
}

on_err() { REASON="unexpected error at line $1 (exit $2); see the log"; }
trap 'on_err "$LINENO" "$?"' ERR

# summary_status FILE — the Status a summary reports; empty when the file is absent.
summary_status() {
  [ -f "$1" ] || return 0
  sed -n 's/^- Status: \*\*\([a-z-]*\)\*\*$/\1/p' "$1" | head -1
}

# summary_target FILE — where a real run writes its summary. A run that did not build
# (a skip, a failure, the 12:30 attempt finding the tag 12:00 pushed) never replaces a
# summary of the same slot and day that reports a build: it writes <stem>.retry.md.
summary_target() {
  case "$STATUS" in built|uploaded) echo "$1"; return 0 ;; esac
  case "$(summary_status "$1")" in
    built|uploaded) echo "${1%.md}.retry.md" ;;
    *) echo "$1" ;;
  esac
}

write_summary() {
  if [ "$DRY_RUN" -eq 0 ]; then SUMMARY=$(summary_target "$SUMMARY"); fi
  local tmp="$SUMMARY.tmp"
  {
    if [ "$DRY_RUN" -eq 1 ]; then echo "# $TITLE, $DATE (dry run)"; else echo "# $TITLE, $DATE"; fi
    echo
    echo "- Status: **$STATUS**"
    echo "- Reason: $REASON"
    echo "- Build: ${NN:-none}${VERSION:+ (version $VERSION)}"
    echo "- Commit: ${SHORT:-unknown} (origin/develop${SHA:+, $SHA})"
    echo "- CI: $CI_STATE"
    echo "- App Store Connect: $ASC_STATE"
    if [ -n "$UPLOAD_STATE" ]; then echo "- Upload: $UPLOAD_STATE"; fi
    echo "- DictusBuildInfo: $BUILD_INFO_STATE"
    [ -n "$IPA_KEPT" ] && echo "- IPA kept: $IPA_KEPT"
    echo "- Log: $LOG"
    if [ -n "$DRY_SKIPS" ]; then
      echo
      echo "## A real run would have skipped"
      echo
      printf '%s' "$DRY_SKIPS"
    fi
    echo
    echo "## PRs merged since ${PREV_TAG:-the previous build tag}"
    echo
    if [ -n "$PR_LINES" ]; then printf '%s\n' "$PR_LINES" | sed 's/^/- /'; else echo "- none found"; fi
    if [ -n "$FR_NOTES" ]; then
      echo
      echo "## What to Test"
      echo
      echo '```text'
      printf '%s\n' "$FR_NOTES"
      echo '```'
      echo
      echo '```text'
      printf '%s\n' "$EN_NOTES"
      echo '```'
    fi
  } > "$tmp" && mv "$tmp" "$SUMMARY"
}

cleanup() {
  local rc=$?
  set +e
  trap - ERR
  if [ "$TAG_CREATED" -eq 1 ] && [ "$TAG_PUSHED" -eq 0 ]; then
    git -C "$REPO" tag -d "build/$NN" >/dev/null 2>&1 && log "cleanup: deleted the local tag build/$NN (never pushed)"
  fi
  if [ -n "$WT" ] && [ -d "$WT" ]; then
    git -C "$REPO" worktree remove --force "$WT" && log "cleanup: removed worktree $WT"
  fi
  # RUN_DIR was made by mktemp under CACHE_DIR; refuse anything else.
  case "$RUN_DIR" in
    "$CACHE_DIR"/run-"$DATE".*) rm -rf "$RUN_DIR" && log "cleanup: removed $RUN_DIR" ;;
    "") ;;
    *) log "cleanup: refused to remove unexpected path $RUN_DIR" ;;
  esac
  if [ "$LOCK_HELD" -eq 1 ]; then rm -rf "$LOCK_DIR"; fi
  write_summary
  log "summary: $SUMMARY"
  if [ "$DRY_RUN" -eq 1 ]; then
    # The same rule a real run applies, on the real summary of this slot and day.
    if [ "$STATUS" = "dry-run" ]; then RT="$REAL_SUMMARY"; else RT=$(summary_target "$REAL_SUMMARY"); fi
    log "a real run would write its summary to $RT"
  fi
  log "end: status=$STATUS reason=$REASON"
  exit "$rc"
}
trap cleanup EXIT

log "start: nightly-testflight --slot $SLOT $([ "$DRY_RUN" -eq 1 ] && echo '--dry-run') from $SCRIPT_DIR (repo $REPO)"

# --- 1. Lock, and nothing else release-shaped running -----------------------
take_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo $$ > "$LOCK_DIR/pid"; LOCK_HELD=1; return 0
  fi
  local other
  other=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
  if [ -n "$other" ] && kill -0 "$other" 2>/dev/null; then
    return 1
  fi
  log "lock: stale lock from pid ${other:-unknown}, taking it over"
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" && echo $$ > "$LOCK_DIR/pid" && LOCK_HELD=1
}
if ! take_lock; then
  # Not skip(): a second nightly must not write over the running one's summary.
  STATUS="skipped"; REASON="another nightly run holds $LOCK_DIR (pid $(cat "$LOCK_DIR/pid" 2>/dev/null))"
  SUMMARY="$SUMMARY.concurrent"; log "SKIP: $REASON"; exit 0
fi
# Read by process name and elapsed time only, never by command line: an xcodebuild
# export carries the API key's identifiers in its arguments, and nothing here may log
# them. A release in flight shows up through what it runs: upload-testflight.sh runs
# xcodebuild, then a long `asc builds upload`. Any xcodebuild counts (a build competes
# for the same CPU); an asc running past a minute is an upload or a wait, not a read.
BUSY=$(ps -axo etime=,ucomm= | awk '
  { n = split($1, a, /[-:]/); s = a[n] + 60 * a[n-1] + (n > 2 ? 3600 * a[n-2] : 0) + (n > 3 ? 86400 * a[n-3] : 0) }
  $2 == "xcodebuild" { x++ }
  $2 == "asc" && s > 60 { u++ }
  END { if (x) printf "%d xcodebuild running; ", x; if (u) printf "%d asc running for over a minute; ", u }')
if [ -n "$BUSY" ]; then
  skip "a build, archive or upload is in progress: $BUSY"
fi
log "1. lock held, no release or archive running"

# --- 2. Fetch; HEAD = origin/develop ----------------------------------------
run_timeout "$T_NET" "git fetch" git -C "$REPO" fetch --quiet --tags origin \
  || fail "git fetch origin failed (network, or an SSH/credential prompt)"
SHA=$(git -C "$REPO" rev-parse origin/develop)
SHORT=$(git -C "$REPO" rev-parse --short "$SHA")
VERSION=$(git -C "$REPO" show "$SHA:DictusApp/Info.plist" | plutil -extract CFBundleShortVersionString raw -)
log "2. HEAD = origin/develop = $SHA ($SHORT), marketing version $VERSION"

# --- 3. Already built? -------------------------------------------------------
# Every integer build/NN tag is considered, not only the newest: the newest can sit on a
# release branch while an older one already names develop's tip.
TAGS_AT_HEAD=$(git -C "$REPO" tag --points-at "$SHA" -l 'build/*' | grep -E '^build/[0-9]+$' || true)
HIGHEST_TAG_N=$(git -C "$REPO" tag -l 'build/*' | grep -E '^build/[0-9]+$' | sed 's#^build/##' | sort -n | tail -1)
HIGHEST_TAG_N=${HIGHEST_TAG_N:-0}
for n in $(git -C "$REPO" tag -l 'build/*' | grep -E '^build/[0-9]+$' | sed 's#^build/##' | sort -rn); do
  if git -C "$REPO" merge-base --is-ancestor "build/$n" "$SHA"; then PREV_TAG="build/$n"; break; fi
done
log "3. highest build tag: build/$HIGHEST_TAG_N; previous build on this line: ${PREV_TAG:-none}"
if [ -n "$TAGS_AT_HEAD" ]; then
  KEPT=$(summary_status "$REAL_SUMMARY")
  case "$KEPT" in
    built|uploaded) log "   $REAL_SUMMARY says $KEPT: it is kept, this skip goes to ${REAL_SUMMARY%.md}.retry.md" ;;
  esac
  skip "$(echo "$TAGS_AT_HEAD" | tr '\n' ' ')already points to $SHORT, nothing new on develop"
  # Only a dry run gets here. So that it still shows the What to Test of this commit,
  # count the PRs from the build before the one at HEAD.
  for n in $(git -C "$REPO" tag -l 'build/*' | grep -E '^build/[0-9]+$' | sed 's#^build/##' | sort -rn); do
    if [ "$(git -C "$REPO" rev-parse "build/$n^{commit}")" != "$SHA" ] \
       && git -C "$REPO" merge-base --is-ancestor "build/$n" "$SHA"; then PREV_TAG="build/$n"; break; fi
  done
  log "   DRY-RUN: PRs and What to Test below are counted from $PREV_TAG, the build before HEAD's"
fi

# PRs merged since the previous build: GitHub's merge commit carries the PR number in
# its subject and the PR title as the first line of its body. Read from git, no API.
# PR_TABLE: one line per PR, the number, a tab, the title.
if [ -n "$PREV_TAG" ]; then
  PR_TABLE=$(git -C "$REPO" log --first-parent --merges --format='%H%x1f%s%x1f%b%x1e' "$PREV_TAG..$SHA" \
    | awk 'BEGIN { RS = "\036"; FS = "\037" }
           match($2, /^Merge pull request #[0-9]+/) {
             n = substr($2, 21, RLENGTH - 20); t = ""
             k = split($3, L, "\n"); for (i = 1; i <= k; i++) if (L[i] != "") { t = L[i]; break }
             print n "\t" t
           }')
  PR_LINES=$(printf '%s\n' "$PR_TABLE" | awk -F '\t' 'NF { print $2 " (#" $1 ")" }')
fi
log "   PRs since ${PREV_TAG:-?}: $(printf '%s\n' "$PR_LINES" | grep -c . || true)"
printf '%s\n' "$PR_LINES" | sed '/^$/d; s/^/     - /'

# --- 4. CI of HEAD on develop: every job of CI_JOBS green -------------------
# Read only. A red or unfinished run is a skip, never a re-run.
RUNS=$(run_timeout "$T_READ" "gh run list" gh run list --repo "$GH_REPO" --workflow "$CI_WORKFLOW" \
  --branch develop --event push --commit "$SHA" --limit 1 \
  --json databaseId,status,conclusion,url) || fail "gh run list failed (auth, network or a prompt)"
RUN_ID=$(printf '%s' "$RUNS" | jq -r '.[0].databaseId // empty')
if [ -z "$RUN_ID" ]; then
  CI_STATE="no CI run found for $SHORT on develop"
  skip "$CI_STATE"
else
  RUN_URL=$(printf '%s' "$RUNS" | jq -r '.[0].url')
  JOBS=$(run_timeout "$T_READ" "gh run view" gh run view "$RUN_ID" --repo "$GH_REPO" --json jobs \
    --jq '.jobs[] | "\(.name)=\(.status)/\(.conclusion)"') || fail "gh run view $RUN_ID failed"
  CI_RED=""
  # Every |-separated name of CI_JOBS, however many: no array, for bash 3.2 under set -u.
  CI_REST="$CI_JOBS|"
  while [ -n "$CI_REST" ]; do
    j=${CI_REST%%|*}
    CI_REST=${CI_REST#*|}
    st=$(printf '%s\n' "$JOBS" | awk -v n="$j" 'index($0, n "=") == 1 { print substr($0, length(n) + 2) }' | tail -1)
    [ "$st" = "completed/success" ] || CI_RED="${CI_RED}${j}=${st:-missing}; "
  done
  CI_STATE="$RUN_URL : $(printf '%s' "$JOBS" | tr '\n' ';' | sed 's/;/; /g')"
  log "4. CI $RUN_URL"
  printf '%s\n' "$JOBS" | sed 's/^/     /'
  if [ -n "$CI_RED" ]; then skip "CI of $SHORT is not green: $CI_RED($RUN_URL)"; fi
fi

# --- 5. Marketing version still open? ----------------------------------------
MAIN_VERSION=$(git -C "$REPO" show origin/main:DictusApp/Info.plist | plutil -extract CFBundleShortVersionString raw -)
log "5. develop is $VERSION, main (App Store) is $MAIN_VERSION"
if [ "$VERSION" = "$MAIN_VERSION" ]; then
  skip "develop's version $VERSION is the one already on main; App Store Connect refuses new builds for it"
fi

# --- 6. Next build number ----------------------------------------------------
NBN=$(run_timeout "$T_READ" "asc builds next-build-number" asc builds next-build-number \
  --app "$ASC_APP_ID" --platform IOS --output json 2>>"$LOG") \
  || fail "asc builds next-build-number failed (auth, network or a keychain prompt)"
ASC_LATEST=$(printf '%s' "$NBN" | jq -r '.latestObservedBuildNumber // "0"')
case "$ASC_LATEST" in ''|*[!0-9]*) fail "App Store Connect returned a non-integer latest build '$ASC_LATEST'" ;; esac
LATEST_INFO=$(run_timeout "$T_READ" "asc builds info" asc builds info --app "$ASC_APP_ID" \
  --build-number "$ASC_LATEST" --platform IOS --output json 2>>"$LOG" || true)
ASC_LATEST_STATE=$(printf '%s' "$LATEST_INFO" | jq -r '.data.attributes.processingState // "unknown"' 2>/dev/null || echo unknown)
NN=$(( (ASC_LATEST > HIGHEST_TAG_N ? ASC_LATEST : HIGHEST_TAG_N) + 1 ))
ASC_STATE="latest build in App Store Connect: $ASC_LATEST ($ASC_LATEST_STATE)"
log "6. ASC latest build $ASC_LATEST ($ASC_LATEST_STATE), highest tag $HIGHEST_TAG_N -> next build $NN"

# --- What to Test, from each merged PR ---------------------------------------
# A PR may carry this block in its body (.github/pull_request_template.md):
#   ## TestFlight
#   fr: <one sentence for the tester>
#   en: <one sentence for the tester>
#   test: yes|no
#   switch: <switch name, or none>
# Read with `gh pr view N --json body`, read only, one call per PR under T_READ. A PR
# without the block, a line left empty or as its <placeholder>, or a gh error: the PR's
# title stands in. After one gh error the remaining PRs use their titles, so a dead
# network costs one timeout, not one per PR.

# parse_testflight_block — stdin: a PR body. Prints fr, en, test, switch, separated by \037.
parse_testflight_block() {
  tr -d '\r' | awk '
    /^##[ \t]+TestFlight[ \t]*$/ { inb = 1; next }
    inb && (/^#/ || /^[ \t]*<!--/) { inb = 0 }
    inb {
      line = $0; sub(/^[ \t]*([-*][ \t]+)?/, "", line)
      if (line ~ /^(fr|en|test|switch)[ \t]*:/) {
        k = line; sub(/[ \t]*:.*$/, "", k)
        v = line; sub(/^[^:]*:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
        if (v ~ /^</) v = ""
        val[k] = v
      }
    }
    END { printf "%s\037%s\037%s\037%s", val["fr"], val["en"], tolower(val["test"]), val["switch"] }'
}

FR_TEST=""; FR_NOTEST=""; EN_TEST=""; EN_NOTEST=""
GH_BODIES=1
while IFS=$'\t' read -r n t; do
  [ -n "$n" ] || continue
  block=""
  if [ "$GH_BODIES" -eq 1 ]; then
    if body=$(run_timeout "$T_READ" "gh pr view $n" gh pr view "$n" --repo "$GH_REPO" --json body --jq .body); then
      block=$(printf '%s\n' "$body" | parse_testflight_block)
    else
      GH_BODIES=0
      log "   gh pr view $n failed: this PR and the next ones use their titles"
    fi
  fi
  IFS=$'\037' read -r fr en tst sw <<EOF_BLOCK || true
$block
EOF_BLOCK
  src="block"
  if [ -z "$fr" ] && [ -z "$en" ] && [ -z "$tst" ]; then src="title"; fi
  fr=${fr:-$t}; en=${en:-$t}
  case "$sw" in ""|none|None|NONE|-) sw="" ;; esac
  if [ -n "$sw" ]; then
    fl="• $fr (#$n, réglage : $sw)"; el="• $en (#$n, switch: $sw)"
  else
    fl="• $fr (#$n)"; el="• $en (#$n)"
  fi
  if [ "$tst" = "no" ]; then
    FR_NOTEST="${FR_NOTEST:+$FR_NOTEST
}$fl"; EN_NOTEST="${EN_NOTEST:+$EN_NOTEST
}$el"
  else
    FR_TEST="${FR_TEST:+$FR_TEST
}$fl"; EN_TEST="${EN_TEST:+$EN_TEST
}$el"
  fi
  log "   #$n from its $src: test=${tst:-yes} switch=${sw:-none}"
done <<EOF_PRS
$PR_TABLE
EOF_PRS

FR_NOTES="$NOTES_HEAD_FR ($SHORT)"
EN_NOTES="$NOTES_HEAD_EN ($SHORT)"
if [ -n "$FR_TEST" ]; then
  FR_NOTES="$FR_NOTES

À tester :
$FR_TEST"
  EN_NOTES="$EN_NOTES

To test:
$EN_TEST"
fi
if [ -n "$FR_NOTEST" ]; then
  FR_NOTES="$FR_NOTES

Sans test (interne) :
$FR_NOTEST"
  EN_NOTES="$EN_NOTES

No test (internal):
$EN_NOTEST"
fi
# TestFlight caps What to Test at 4000 characters: cut the whole text, by character.
FR_NOTES=$(printf '%s' "$FR_NOTES" | perl -CSD -0777 -pe 'substr($_, 4000) = "" if length > 4000')
EN_NOTES=$(printf '%s' "$EN_NOTES" | perl -CSD -0777 -pe 'substr($_, 4000) = "" if length > 4000')

# --- Preflight for the real run: credentials and signing ---------------------
[ -n "$ASC_KEY_ID" ] && [ -n "$ASC_ISSUER_ID" ] \
  || fail "ASC_KEY_ID / ASC_ISSUER_ID: not exported and asc returned no default profile"
[ -r "$HOME/.asc/keys/AuthKey_${ASC_KEY_ID}.p8" ] || fail "the App Store Connect API key file is not readable under ~/.asc/keys"
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ { print $2; exit }')
[ -n "$IDENTITY" ] || fail "no valid 'Apple Development' signing identity in the keychain"
log "   preflight: API key readable, credentials $CRED_NOTE (not printed), signing identity present"

if [ "$DRY_RUN" -eq 1 ]; then
  would "sign a scratch file with the Apple Development identity (${T_PROBE}s timeout) to catch a keychain prompt before archiving"
  would "git worktree add --detach $CACHE_DIR/run-$DATE.XXXXXX/worktree $SHORT"
  would "set CFBundleVersion $NN in $PLISTS (no commit; git update-index --skip-worktree on those four)"
  would "create the local tag build/$NN at $SHORT (upload-testflight.sh requires it)"
  would "run <worktree>/scripts/upload-testflight.sh: archive $VERSION ($NN), export, upload, wait for processing (up to $ASC_PROCESSING_TIMEOUT, then ${T_PROCESS}s more if still processing; after that: status uploaded, tag and notes anyway)"
  would "check the IPA: CFBundleVersion $NN, DictusBuildInfo GitCommitSHA $SHORT in DictusApp and DictusKeyboard"
  would "git push origin refs/tags/build/$NN (the tag alone)"
  would "asc builds test-notes create, build $NN, fr-FR:"
  printf '%s\n' "$FR_NOTES" | sed 's/^/       | /'
  would "asc builds test-notes create, build $NN, en-GB:"
  printf '%s\n' "$EN_NOTES" | sed 's/^/       | /'
  would "add no TestFlight group, submit nothing to beta review (Team PIVI has access to all builds)"
  would "keep $KEEP_DIR/Dictus-$VERSION-$NN.ipa, delete the IPAs listed in $KEEP_MANIFEST by exact name"
  would "git worktree remove --force <worktree>; rm -rf <run dir>"
  if [ -n "$DRY_SKIPS" ]; then STATUS="skipped"; REASON="dry run; a real run would skip (see below)"
  else STATUS="dry-run"; REASON="dry run; a real run would build $NN"; fi
  exit 0
fi

# Keep the Mac awake for the length of the run; caffeinate exits with this script.
caffeinate -i -s -w $$ &

RUN_DIR=$(mktemp -d "$CACHE_DIR/run-$DATE.XXXXXX")
mkdir -p "$RUN_DIR/tmp"

# A keychain dialog blocks codesign with no output and no end. Sign a scratch file
# first, under a timeout, so that case fails here in seconds and not at archive time.
cp /usr/bin/true "$RUN_DIR/tmp/signing-probe"
run_timeout "$T_PROBE" "codesign probe" codesign --force --sign "$IDENTITY" --timestamp=none "$RUN_DIR/tmp/signing-probe" \
  || fail "signing probe failed or waited on a keychain prompt; unlock the login keychain or allow codesign"
log "   preflight: signing probe passed"

# --- 7. Worktree at HEAD, build number NN, nothing committed -----------------
WT="$RUN_DIR/worktree"
git -C "$REPO" worktree add --quiet --detach "$WT" "$SHA"
[ -z "$(git -C "$WT" status --porcelain --untracked-files=all)" ] || fail "fresh worktree is not clean"

# The plists hold a literal build number, so it cannot be passed as a build setting:
# it is written into the four files of this throwaway worktree. upload-testflight.sh
# refuses a dirty tree, which protects against archiving uncommitted code. Here the only
# difference from HEAD is that number, checked line by line below, so those four paths
# are marked skip-worktree in this worktree's own index (it dies with the worktree).
# DictusBuildInfo reads `git rev-parse --short HEAD`, which a working-tree edit does
# not change; step 9 checks it in the IPA.
for P in $PLISTS; do
  perl -0pi -e 's#(<key>CFBundleVersion</key>\n\t<string>)[0-9]+(</string>)#${1}'"$NN"'${2}#' "$WT/$P"
  [ "$(plutil -extract CFBundleVersion raw "$WT/$P")" = "$NN" ] || fail "could not set CFBundleVersion in $P"
done
CHANGED=$(git -C "$WT" diff --numstat | awk '{ print $1 "/" $2 " " $3 }' | sort | tr '\n' ' ')
EXPECTED=$(for P in $PLISTS; do echo "1/1 $P"; done | sort | tr '\n' ' ')
[ "$CHANGED" = "$EXPECTED" ] || fail "unexpected diff in the worktree: $CHANGED"
if git -C "$WT" diff -U0 | grep -E '^[-+][^-+]' | grep -vqE '^[-+]	<string>[0-9]+</string>$'; then
  fail "the worktree diff touches more than CFBundleVersion"
fi
# shellcheck disable=SC2086  # PLISTS is a space-separated list of plain paths
git -C "$WT" update-index --skip-worktree $PLISTS
[ -z "$(git -C "$WT" status --porcelain --untracked-files=all)" ] || fail "worktree still reports changes"
log "7. worktree $WT at $SHORT, CFBundleVersion $NN in the four plists (uncommitted)"

git -C "$REPO" tag "build/$NN" "$SHA"
TAG_CREATED=1

# --- 8. Archive, export, upload, wait ----------------------------------------
# TMPDIR points into the run dir so xcodebuild's and asc's scratch files go with it.
#
# Exit 75 from upload-testflight.sh means "Upload committed", then the processing wait
# ran out: build NN is in App Store Connect and Apple finishes it on its own. That is
# not a failure, and the run must not lose the build as it did on 2026-11-26 (build 46
# uploaded, wait timed out, the cleanup deleted the unpushed tag, no notes). So the run
# waits T_PROCESS more. Past that, it still checks the IPA, pushes the tag (the number
# is used and names this commit) and sets What to Test (App Store Connect accepts notes
# once the build is visible, before it is VALID), and reports status `uploaded`.
log "8. scripts/upload-testflight.sh (timeout ${T_UPLOAD}s, processing wait $ASC_PROCESSING_TIMEOUT)"
UPLOAD_RC=0
run_timeout "$T_UPLOAD" "upload-testflight.sh" env TMPDIR="$RUN_DIR/tmp/" /bin/sh "$WT/scripts/upload-testflight.sh" \
  || UPLOAD_RC=$?
case "$UPLOAD_RC" in
  0) PROCESSED=1; UPLOAD_STATE="uploaded and processed" ;;
  75)
    log "8. build $NN is uploaded, App Store Connect is still processing it; waiting up to ${T_PROCESS}s more"
    UPLOAD_STATE="uploaded; not processed after $ASC_PROCESSING_TIMEOUT"
    if run_timeout "$((T_PROCESS + 120))" "asc builds wait" asc builds wait --app "$ASC_APP_ID" \
         --build-number "$NN" --platform IOS --version "$VERSION" --timeout "${T_PROCESS}s" \
         --poll-interval 30s --fail-on-invalid --output json >/dev/null; then
      PROCESSED=1
      UPLOAD_STATE="uploaded and processed (after the extra wait)"
    else
      P_STATE=$(run_timeout "$T_READ" "asc builds info" asc builds info --app "$ASC_APP_ID" \
        --build-number "$NN" --platform IOS --output json 2>/dev/null \
        | jq -r '.data.attributes.processingState // empty' 2>/dev/null || true)
      case "$P_STATE" in
        FAILED|INVALID) fail "App Store Connect reports build $NN as $P_STATE" ;;
      esac
      UPLOAD_STATE="uploaded; still ${P_STATE:-processing} after $ASC_PROCESSING_TIMEOUT + ${T_PROCESS}s. To wait again: asc builds wait --app $ASC_APP_ID --build-number $NN --platform IOS"
      log "8. $UPLOAD_STATE"
    fi ;;
  *) fail "scripts/upload-testflight.sh failed for build $NN (see the log)" ;;
esac
IPA="$WT/.asc/artifacts/Dictus-$VERSION-$NN.ipa"
[ -f "$IPA" ] || fail "upload reported success but $IPA is missing"

# --- 9. What was uploaded -----------------------------------------------------
mkdir -p "$RUN_DIR/tmp/ipa"
APP=Payload/DictusApp.app
KB=$APP/PlugIns/DictusKeyboard.appex
unzip -q -o "$IPA" "$APP/Info.plist" "$APP/DictusBuildInfo.plist" "$KB/DictusBuildInfo.plist" -d "$RUN_DIR/tmp/ipa" \
  || fail "the uploaded IPA lacks Info.plist or DictusBuildInfo.plist in the app or the keyboard"
IPA_BUILD=$($PB -c "Print :CFBundleVersion" "$RUN_DIR/tmp/ipa/$APP/Info.plist")
BI_APP=$($PB -c "Print :GitCommitSHA" "$RUN_DIR/tmp/ipa/$APP/DictusBuildInfo.plist")
BI_KB=$($PB -c "Print :GitCommitSHA" "$RUN_DIR/tmp/ipa/$KB/DictusBuildInfo.plist")
BI_BRANCH=$($PB -c "Print :GitBranch" "$RUN_DIR/tmp/ipa/$APP/DictusBuildInfo.plist")
BUILD_INFO_STATE="app $BI_APP, keyboard $BI_KB, branch $BI_BRANCH (detached), IPA build $IPA_BUILD"
log "9. $BUILD_INFO_STATE"
[ "$IPA_BUILD" = "$NN" ] || fail "the IPA says build $IPA_BUILD, expected $NN"
[ "$BI_APP" = "$SHORT" ] && [ "$BI_KB" = "$SHORT" ] || fail "DictusBuildInfo does not name $SHORT"

# Keep tonight's IPA; drop the earlier ones this script made, by exact name only.
mv "$IPA" "$KEEP_DIR/"
IPA_KEPT="$KEEP_DIR/Dictus-$VERSION-$NN.ipa"
if [ -f "$KEEP_MANIFEST" ]; then
  while IFS= read -r old; do
    case "$old" in
      "Dictus-$VERSION-$NN.ipa") ;;
      Dictus-*-[0-9]*.ipa) [ -f "$KEEP_DIR/$old" ] && rm -f "$KEEP_DIR/$old" && log "   deleted earlier nightly IPA $old" ;;
      *) ;;
    esac
  done < "$KEEP_MANIFEST"
fi
echo "Dictus-$VERSION-$NN.ipa" > "$KEEP_MANIFEST"

# --- 10. The tag, alone -------------------------------------------------------
run_timeout "$T_NET" "git push tag" git -C "$REPO" push --quiet origin "refs/tags/build/$NN" \
  || fail "build $NN is uploaded but pushing the tag build/$NN failed"
TAG_PUSHED=1
log "10. pushed tag build/$NN"

# --- 11. What to Test ---------------------------------------------------------
# Build processed: any failure here is a failure. Still processing: a build App Store
# Connect does not show yet leaves the notes unset (the text is in the summary).
INFO=$(run_timeout "$T_READ" "asc builds info" asc builds info --app "$ASC_APP_ID" \
  --build-number "$NN" --platform IOS --output json 2>>"$LOG") \
  || { [ "$PROCESSED" -eq 0 ] || fail "could not read build $NN back from App Store Connect"; INFO=""; }
BUILD_ID=$(printf '%s' "$INFO" | jq -r '.data.id // empty' 2>/dev/null || true)
[ -n "$BUILD_ID" ] || [ "$PROCESSED" -eq 0 ] || fail "build $NN not found in App Store Connect after upload"
# create, or update when App Store Connect already made that locale for the build.
set_notes() {
  run_timeout "$T_NOTES" "test notes $1 create" asc builds test-notes create --build-id "$BUILD_ID" \
    --locale "$1" --whats-new "$2" --output json >/dev/null \
  || run_timeout "$T_NOTES" "test notes $1 update" asc builds test-notes update --build-id "$BUILD_ID" \
    --locale "$1" --whats-new "$2" --output json >/dev/null
}
NOTES_STATE="What to Test not set: build $NN not visible in App Store Connect yet (the text is below)"
if [ -n "$BUILD_ID" ]; then
  set_notes fr-FR "$FR_NOTES" || fail "What to Test fr-FR failed for build $NN"
  set_notes en-GB "$EN_NOTES" || fail "What to Test en-GB failed for build $NN"
  NOTES_STATE="What to Test fr-FR + en-GB"
  log "11. What to Test set in fr-FR and en-GB"
else
  log "11. $NOTES_STATE"
fi

# --- ASC state for the summary ------------------------------------------------
STATE=$(printf '%s' "$INFO" | jq -r '.data.attributes.processingState // "unknown"' 2>/dev/null || echo unknown)
BUILD_GROUPS="unread"
if [ -n "$BUILD_ID" ]; then
  BUILD_GROUPS=$(run_timeout "$T_READ" "asc builds groups list" asc builds groups list --build-id "$BUILD_ID" \
    --output json 2>>"$LOG" | jq -r '[.groups[]? | "\(.name) (\(.type))"] | join(", ")' || echo "unread")
fi
ASC_STATE="build $NN ${STATE:-unknown}, groups: ${BUILD_GROUPS:-none}, $NOTES_STATE"
case "$BUILD_GROUPS" in *"(external)"*) ASC_STATE="$ASC_STATE. WARNING: an external group has it; this script added none" ;; esac

if [ "$PROCESSED" -eq 1 ]; then
  STATUS="built"
  REASON="build $NN of $SHORT uploaded to internal TestFlight"
else
  STATUS="uploaded"
  REASON="build $NN of $SHORT uploaded, App Store Connect still processing it; Team PIVI gets it once it is VALID"
fi
log "done: $REASON"
