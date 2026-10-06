#!/usr/bin/env bash
# Re-take every language-check reading #598 is scored on, into readings.jsonl.
# Drives no model. Run from anywhere; macOS only (NLLanguageRecognizer).
#
#   docs/research/598-short-line-language-check/run-readings.sh
#   python3 docs/research/598-short-line-language-check/summarise.py
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
cd "$REPO/DictusCore"

inputs=(../docs/research/413-414-guardrail/*.json)
inputs+=(../docs/research/587-*/capture*.json ../docs/research/587-*/round*/capture*.json)
inputs+=(../docs/research/571-summary/runs/*.json ../docs/research/571-summary/step2/run-*.json)

fixtures=()
for file in Sources/polish-harness/fixtures/*.json ../docs/research/571-summary/step2/fixtures-*.json; do
  fixtures+=(--fixtures "$file")
done

swift run -q polish-harness langcheck "${inputs[@]}" "${fixtures[@]}" \
  --out ../docs/research/598-short-line-language-check/readings.jsonl
