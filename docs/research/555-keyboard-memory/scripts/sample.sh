#!/bin/bash
# sample.sh <udid> <out.tsv>: appends "epoch pid footprint_bytes" every 2 s for the
# Dictus keyboard extension of that simulator, until killed.
UDID=$1; OUT=$2
while :; do
  PID=$(ps -axo pid,command | grep "$UDID" | grep 'DictusKeyboard.appex/DictusKeyboard' | grep -v grep | awk '{print $1}' | head -1)
  if [ -n "$PID" ]; then
    FP=$(footprint -p "$PID" -f bytes --noCategories 2>/dev/null | awk '/phys_footprint:/{print $2; exit}')
    echo -e "$(date +%s)\t$PID\t$FP" >> "$OUT"
  fi
  sleep 2
done
