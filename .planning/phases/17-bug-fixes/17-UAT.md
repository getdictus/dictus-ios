---
status: complete
phase: 17-bug-fixes
source: [17-01-SUMMARY.md, 17-02-SUMMARY.md]
started: 2026-03-27T18:00:00Z
updated: 2026-03-27T21:32:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Dynamic Island stops showing REC after recording ends
expected: Start a dictation from the keyboard. The Dynamic Island shows "REC" state. Stop the recording. The DI transitions away from REC to transcribing, then to ready/standby. It never stays stuck on "REC" after recording has ended.
result: pass

### 2. Dynamic Island recovers after cancel
expected: Start a dictation, then cancel it (swipe down or tap cancel). The Dynamic Island returns to standby state. It does not stay stuck on "REC".
result: pass

### 3. Quick chain recording (stop then immediately re-record)
expected: Start a dictation, stop it, then immediately start another dictation before the first finishes transcribing. The Dynamic Island transitions correctly through the states without getting stuck. The second recording works normally.
result: pass

### 4. Export logs completes quickly
expected: Go to Settings > Export Logs. Tap export. The spinner appears briefly (under 2 seconds) and the share sheet opens with the log file. No long wait.
result: pass

### 5. Exported log file has recent entries only
expected: After exporting logs, open the exported file. It should not contain entries older than 7 days. Recent entries from today's dictation sessions should be present with timestamps.
result: pass

### 6. Export logs shows duration in logs
expected: After exporting logs, check the last few lines of the exported file. There should be a "log.exportCompleted" entry showing duration in ms and size in bytes.
result: pass

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
