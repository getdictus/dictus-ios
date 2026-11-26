#!/usr/bin/env bash
# The swipe decoder bench (#948): builds in release on the Mac (no simulator) and prints
# the table. Arguments go to the bench, see main.swift's header:
#   tools/swipe-bench/run.sh                      # en, fr and es, the four finger styles
#   tools/swipe-bench/run.sh --memory --langs fr --styles typical
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --quiet
exec .build/release/swipe-bench "$@"
