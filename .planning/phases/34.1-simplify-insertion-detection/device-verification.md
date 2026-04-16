---
phase: 34.1
type: device-verification
created: 2026-04-16
device: TBD (fill with iPhone model + iOS version)
build: TBD (fill with CFBundleVersion)
---

# Phase 34.1 Device Verification — Simplified Insertion Detection

## Protocol

15-run sanity verification. Each run must:
1. Dictate via Dictus keyboard in a host app.
2. Confirm inserted text appears exactly once in the host field (no duplicates).
3. Confirm no red banner appears in the Dictus toolbar.
4. Export log and record the probe line.

Mix of scenarios:
- 5 runs in a short Notes field (≤100 chars pre-cursor).
- 5 runs in a long Notes field (≥500 chars pre-cursor — build one up across runs 1-5 if needed, then continue in same field).
- 3 runs in Messages (new or existing thread).
- 2 runs in Safari address bar or web form.

Include at least:
- One empty-field insertion (cursor in brand new text field).
- One cold-start insertion (background Dictus before dictating).
- One chained dictation (two back-to-back in the same field without leaving the app).

## Results Log

| #  | Host app  | Scenario                 | transcriptionCount | beforeCount | afterCount | Classifier outcome | Duplicate? | Banner? |
|----|-----------|--------------------------|--------------------|-------------|------------|--------------------|------------|---------|
| 1  |           |                          |                    |             |            |                    |            |         |
| 2  |           |                          |                    |             |            |                    |            |         |
| 3  |           |                          |                    |             |            |                    |            |         |
| 4  |           |                          |                    |             |            |                    |            |         |
| 5  |           |                          |                    |             |            |                    |            |         |
| 6  |           |                          |                    |             |            |                    |            |         |
| 7  |           |                          |                    |             |            |                    |            |         |
| 8  |           |                          |                    |             |            |                    |            |         |
| 9  |           |                          |                    |             |            |                    |            |         |
| 10 |           |                          |                    |             |            |                    |            |         |
| 11 |           |                          |                    |             |            |                    |            |         |
| 12 |           |                          |                    |             |            |                    |            |         |
| 13 |           |                          |                    |             |            |                    |            |         |
| 14 |           |                          |                    |             |            |                    |            |         |
| 15 |           |                          |                    |             |            |                    |            |         |

## Privacy Audit

After runs complete, export full log and run:

```
grep -iE "message=|text=|transcription=|result=|content=" dictus-logs-34.1-verify.txt
```

Also grep for 2-3 distinctive words from the runs (e.g. a name, an unusual French word dictated). Both must return ZERO hits from probe/retry/failed lines.

## Pass Criteria

- [ ] ≥15 runs recorded
- [ ] Zero entries in "Duplicate?" column are "yes"
- [ ] Zero entries in "Banner?" column are "yes"
- [ ] At least one row has outcome = emptyFieldSuccess
- [ ] At least one row has beforeCount ≥ 500 with outcome = windowedSuccess (proves truncation no longer triggers false-positive)
- [ ] Privacy audit passes (zero raw text in probe lines)

## Observations

(Populate after runs.)
