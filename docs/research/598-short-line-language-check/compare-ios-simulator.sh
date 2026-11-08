#!/usr/bin/env bash
# Re-read every segment in readings.jsonl with the iOS Simulator's NaturalLanguage and
# compare with the macOS readings. Headless: creates its own simulator, boots it with
# simctl (no Simulator.app window), deletes it at the end. Drives no model.
#
#   docs/research/598-short-line-language-check/compare-ios-simulator.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

xcrun -sdk iphonesimulator swiftc -target arm64-apple-ios27.0-simulator \
  "$HERE/ios_read.swift" -o "$WORK/ios_read"

python3 - "$HERE/readings.jsonl" "$WORK/texts.json" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1]) if line.strip()]
texts = sorted({s["text"] for r in records for s in r["segments"]})
json.dump(texts, open(sys.argv[2], "w"), ensure_ascii=False)
PY

UDID="$(xcrun simctl create "598-langcheck" "iPhone 17" com.apple.CoreSimulator.SimRuntime.iOS-27-0)"
cleanup() { xcrun simctl shutdown "$UDID" 2>/dev/null || true; xcrun simctl delete "$UDID"; rm -rf "$WORK"; }
trap cleanup EXIT
xcrun simctl boot "$UDID"
xcrun simctl spawn "$UDID" "$WORK/ios_read" "$WORK/texts.json" "$WORK/ios.json"

python3 - "$HERE/readings.jsonl" "$WORK/texts.json" "$WORK/ios.json" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1]) if line.strip()]
mac = {s["text"]: (s["reading"].get("code") or "", s["reading"]["confidence"]) for r in records for s in r["segments"]}
texts, ios = json.load(open(sys.argv[2])), json.load(open(sys.argv[3]))
codes = sum(1 for t, (c, _) in zip(texts, ios) if c != mac[t][0])
drift = max(abs(float(v) - mac[t][1]) for t, (_, v) in zip(texts, ios))
print(f"segments: {len(texts)} distinct, top code differs on {codes}, largest confidence difference {drift:.6f}")
PY
