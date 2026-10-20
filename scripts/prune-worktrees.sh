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
#   - nothing is uncommitted, except Localizable.xcstrings files whose only change is
#     the build noise Xcode writes (CLAUDE.md), proven by content and then discarded;
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

# True when the unstaged change to catalog $2 in worktree $1 is only what an Xcode build
# writes: `"extractionState" : "stale"` lines added and the final newline dropped
# (CLAUDE.md). Both versions are compared line by line, trailing comma and whitespace
# ignored; any removed line or any other added line is someone's edit.
is_catalog_build_noise() {
  local committed current edits
  committed=$(git -C "$1" show "HEAD:$2" | catalog_lines) || return 1
  current=$(catalog_lines <"$1/$2") || return 1
  edits=$(diff <(echo "$committed") <(echo "$current") | grep '^[<>]' \
    | grep -v '^> *"extractionState" : "stale"$' || true)
  [ -z "$edits" ]
}
catalog_lines() { sed -e 's/[[:space:]]*$//' -e 's/,$//'; }

# Prints, NUL-terminated, the worktree-relative path of every catalog in $1 whose only
# change is proven build noise (mode `noise`), or one line per other change (mode
# `real`). Fails when git status cannot run, so a caller never reads that as clean.
changes_in() {
  local path=$1 mode=$2 status entry file
  status=$(git -C "$path" status --porcelain -z | tr '\0' '\n') || return 1
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    file=${entry:3}
    if [ "${entry:0:3}" = " M " ] && [ "$(basename "$file")" = Localizable.xcstrings ] \
      && is_catalog_build_noise "$path" "$file"; then
      [ "$mode" = noise ] && printf '%s\0' "$file"
    else
      [ "$mode" = real ] && echo "$entry"
    fi
  done <<<"$status"
  return 0
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

  changes=$(changes_in "$path" real) || { echo "git status failed"; return; }
  if [ -n "$changes" ]; then
    echo "uncommitted changes, not proven build noise: $(echo "$changes" | tr '\n' ' ')"
    return
  fi
  if [ "$(git -C "$path" rev-list --count HEAD --not --remotes)" != 0 ]; then
    echo "unpushed commits"; return
  fi
}

retire() {
  local path=$1 branch=$2 udid dir file
  echo "RETIRE  $path [$branch]"
  echo "        worktree $(size "$path")"
  [ -d "$path/build/DerivedData" ] && echo "        build/DerivedData $(size "$path/build/DerivedData")"
  while IFS= read -r dir; do
    [ -n "$dir" ] && echo "        Xcode DerivedData $dir $(size "$dir")"
  done < <(xcode_derived_data_for "$path")
  while IFS= read -r udid; do
    [ -n "$udid" ] && echo "        simulator $udid $(size "$SIM_ROOT/$udid")"
  done < <(simulators_named "$branch")
  while IFS= read -r -d '' file; do
    echo "        build noise to discard: $file"
  done < <(changes_in "$path" noise)
  [ "$APPLY" = 1 ] || return 0

  while IFS= read -r udid; do
    [ -n "$udid" ] || continue
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid"
  done < <(simulators_named "$branch")
  while IFS= read -r dir; do
    case "$dir" in "$XCODE_DD"/?*) rm -rf "$dir" ;; esac
  done < <(xcode_derived_data_for "$path")
  rm -rf "${path:?}/build"
  # Only catalogs whose change was proven to be build noise, one path at a time.
  while IFS= read -r -d '' file; do
    git -C "$path" checkout -- ":(literal)$file"
  done < <(changes_in "$path" noise)
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
