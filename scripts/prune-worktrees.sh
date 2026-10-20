#!/bin/bash
# prune-worktrees.sh — retire the worktrees of merged or closed PRs (#735).
#
# A worktree whose PR is done still holds gigabytes: its own build/DerivedData, an Xcode
# DerivedData folder if it was ever opened in Xcode, and the simulator created for that
# PR. Nothing retired them, so they piled up until the disk filled (2026-10-13).
#
# For each worktree of this repository, the script removes, in this order:
#   1. the simulator created for the PR: the one named exactly like the branch
#      (docs/agents/simulator.md, section 1), shut down then `xcrun simctl delete`d;
#   2. every Xcode DerivedData folder whose WorkspacePath lies inside the worktree;
#   3. the worktree's build/ directory;
#   4. the worktree itself, with `git worktree remove` (never --force).
# It does so only when ALL of these hold, and lists every other worktree with the reason
# it was kept:
#   - it is not the main checkout, nor the worktree running the script, nor `device`;
#   - it is on a branch, and that branch is neither main nor develop;
#   - the branch has at least one PR, and none of its PRs is open;
#   - nothing is uncommitted, ignoring the build noise in Localizable.xcstrings;
#   - every commit is reachable from a remote branch.
# Its local branch is left in place: it costs nothing and a closed PR may be reopened.
#
# Dry run by default. Running it again after --apply finds nothing left to do.
#
# Usage:
#   scripts/prune-worktrees.sh [--apply] [<worktree path>...]
#
# With paths, only those worktrees are considered. Requires gh (authenticated), python3.
set -euo pipefail

APPLY=0
TARGETED=0
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    -*) echo "error: unknown option $arg" >&2; exit 2 ;;
    *)
      # A target that no longer exists was retired by an earlier run: nothing to do.
      # It still counts as a target, so the run never widens to every worktree.
      TARGETED=1
      if [ -d "$arg" ]; then
        TARGETS+=("$(cd "$arg" && pwd -P)")
      else
        echo "GONE    $arg: no such directory, nothing to do"
      fi
      ;;
  esac
done

SELF=$(git rev-parse --show-toplevel)
SELF=$(cd "$SELF" && pwd -P)
XCODE_DD="$HOME/Library/Developer/Xcode/DerivedData"
SIM_ROOT="$HOME/Library/Developer/CoreSimulator/Devices"

# The PR and push checks below compare against the remote, so it must be current.
git fetch --quiet --prune origin

size() { du -sh "$1" 2>/dev/null | cut -f1; }

# UDIDs of the simulators named exactly $1, one per line.
simulators_named() {
  xcrun simctl list devices -j | python3 -c '
import json, sys
name = sys.argv[1]
for devices in json.load(sys.stdin)["devices"].values():
    for d in devices:
        if d["name"] == name:
            print(d["udid"])
' "$1"
}

# Xcode DerivedData folders whose workspace lies inside $1, one per line.
xcode_derived_data_for() {
  [ -d "$XCODE_DD" ] || return 0
  for plist in "$XCODE_DD"/*/info.plist; do
    [ -f "$plist" ] || continue
    workspace=$(/usr/libexec/PlistBuddy -c "Print :WorkspacePath" "$plist" 2>/dev/null || true)
    case "$workspace" in
      "$1"/*) dirname "$plist" ;;
    esac
  done
}

# Prints the reason a worktree must be kept, or nothing when it can go.
keep_reason() {
  local path=$1 branch=$2 states changes
  if [ "$path" = "$MAIN" ]; then echo "main checkout"; return; fi
  if [ "$path" = "$SELF" ]; then echo "worktree running this script"; return; fi
  if [ "$(basename "$path")" = "device" ]; then echo "build machine checkout"; return; fi
  if [ -z "$branch" ]; then echo "detached HEAD, no PR to check"; return; fi
  case "$branch" in main|develop) echo "long-lived branch $branch"; return ;; esac
  if [ ! -d "$path" ]; then echo "directory missing (run git worktree prune)"; return; fi

  states=$(gh pr list --head "$branch" --state all --json state --jq '.[].state') \
    || { echo "could not read PR state"; return; }
  if [ -z "$states" ]; then echo "no PR for $branch"; return; fi
  case "$states" in *OPEN*) echo "PR still open"; return ;; esac

  # Captured first: with pipefail, `grep -q` closing the pipe early would fail it.
  changes=$(git -C "$path" status --porcelain | grep -v 'Localizable\.xcstrings$' || true)
  if [ -n "$changes" ]; then echo "uncommitted changes"; return; fi
  if [ "$(git -C "$path" rev-list --count HEAD --not --remotes)" != 0 ]; then
    echo "unpushed commits"; return
  fi
}

retire() {
  local path=$1 branch=$2 udid dir
  echo "RETIRE  $path [$branch]"
  echo "        worktree $(size "$path")"
  [ -d "$path/build/DerivedData" ] && echo "        build/DerivedData $(size "$path/build/DerivedData")"
  for dir in $(xcode_derived_data_for "$path"); do
    echo "        Xcode DerivedData $dir $(size "$dir")"
  done
  for udid in $(simulators_named "$branch"); do
    echo "        simulator $udid $(size "$SIM_ROOT/$udid")"
  done
  [ "$APPLY" = 1 ] || return 0

  for udid in $(simulators_named "$branch"); do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid"
  done
  for dir in $(xcode_derived_data_for "$path"); do
    rm -rf "${dir:?}"
  done
  rm -rf "${path:?}/build"
  # Xcode rewrites this file on every build; it is noise, never work (CLAUDE.md).
  if [ -n "$(git -C "$path" status --porcelain -- '*Localizable.xcstrings')" ]; then
    git -C "$path" checkout -- '*Localizable.xcstrings'
  fi
  git worktree remove "$path"
  echo "        removed"
}

MAIN=""
free_gb() { df -k / | awk 'NR==2 {printf "%.2f GiB", $4 / 1048576}'; }
FREE_BEFORE=$(free_gb)
path="" branch=""
# A blank line ends each record of `git worktree list --porcelain`; the extra echo
# terminates the last one.
while IFS= read -r line; do
  case "$line" in
    "worktree "*) path=$(cd "${line#worktree }" 2>/dev/null && pwd -P || echo "${line#worktree }") ;;
    "branch "*) branch=${line#branch refs/heads/} ;;
    "")
      [ -n "$path" ] || continue
      [ -n "$MAIN" ] || MAIN=$path
      selected=1
      if [ "$TARGETED" = 1 ]; then
        selected=0
        for t in ${TARGETS[@]+"${TARGETS[@]}"}; do [ "$t" = "$path" ] && selected=1; done
      fi
      if [ "$selected" = 1 ]; then
        reason=$(keep_reason "$path" "$branch")
        if [ -n "$reason" ]; then
          echo "KEEP    $path [${branch:-detached}]: $reason"
        else
          retire "$path" "$branch"
        fi
      fi
      path="" branch=""
      ;;
  esac
done < <(git worktree list --porcelain; echo)

if [ "$APPLY" = 1 ]; then
  echo "Free space on /: $FREE_BEFORE before, $(free_gb) after."
else
  echo "Dry run: nothing removed. Re-run with --apply to retire the RETIRE lines."
fi
