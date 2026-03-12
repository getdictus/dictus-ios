---
status: complete
phase: 14-model-pipeline
source: [14-01-SUMMARY.md, 14-02-SUMMARY.md, 14-03-SUMMARY.md]
started: 2026-03-12T22:40:00Z
updated: 2026-03-12T22:50:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Large Turbo v3 Removed from Catalog
expected: In the model manager screen, Large Turbo v3 should NOT appear. Only 6 models visible: Tiny, Base, Small, Small 216MB, Medium, Parakeet v3.
result: pass

### 2. RAM-Based Model Recommendation Badge
expected: In the model manager, one model should show a "Recommande" badge. On devices with >=6GB RAM, Parakeet v3 gets the badge. On devices with <=4GB RAM, Whisper Small gets it.
result: pass

### 3. Prewarm Progress Label
expected: When a model is being optimized after download, the card should show "Optimisation en cours..." with a spinner (not just "Optimisation...").
result: issue
reported: "Pendant le prewarm, une barre de progression reste bloquee a zero alors qu'elle ne bouge pas. Il faudrait soit la supprimer pendant le prewarm, soit la faire avancer."
severity: minor

### 4. Retry Cleans Up Corrupted Files
expected: If a model download fails (error state), tapping the retry button should work cleanly — no leftover corrupted files causing repeated failures. The trash button should NOT appear (retry handles cleanup).
result: skipped
reason: Can't trigger error state to test

### 5. Onboarding Dynamic Model Recommendation
expected: During onboarding on the model download page, the recommended model should match your device RAM (Parakeet v3 on >=6GB, Whisper Small on <=4GB). The card should show the model's real name, size, and description from the catalog — not hardcoded "Whisper Small / ~500 Mo".
result: pass

## Summary

total: 5
passed: 3
issues: 1
pending: 0
skipped: 1

## Gaps

- truth: "Prewarm state shows spinner with 'Optimisation en cours...' and no misleading progress bar"
  status: failed
  reason: "User reported: Pendant le prewarm, une barre de progression reste bloquee a zero alors qu'elle ne bouge pas. Il faudrait soit la supprimer pendant le prewarm, soit la faire avancer."
  severity: minor
  test: 3
  artifacts: []
  missing: []
