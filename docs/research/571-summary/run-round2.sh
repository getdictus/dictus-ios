#!/bin/sh
# Round 2 of the Résumé bench (#571). Run from anywhere; writes runs/r2-*.
set -e
cd "$(dirname "$0")/../../../DictusCore"
R=../docs/research/571-summary/runs
F=Sources/polish-harness/fixtures
for set in fr en device-r1 i18n; do
  swift run -q polish-harness summary $F/summary-$set.json --mode summary --runs 5 --json $R/r2-$set.json > $R/r2-$set.txt 2>&1
done
swift run -q polish-harness summary $F/summary-compare.json --mode summary --runs 3 --json $R/r2-compare-summary.json > $R/r2-compare-summary.txt 2>&1
echo DONE
