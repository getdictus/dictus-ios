---
status: complete
phase: 23-bug-fixes-license-compliance
source: [23-01-SUMMARY.md]
started: 2026-04-01T20:00:00Z
updated: 2026-04-01T20:05:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Autocorrect Undo After New Typing
expected: Type a word that gets autocorrected, then type more characters, then press backspace. Backspace should delete the last typed character normally — it should NOT undo the earlier autocorrect.
result: pass

### 2. Licenses Screen — All Dependencies Listed
expected: Open the app > Settings > Licenses. You should see 5 entries listed alphabetically: DeviceKit, Dictus, FluidAudio, giellakbd-ios, WhisperKit. Each shows author name and license type.
result: pass

### 3. Dictus License URL
expected: On the Licenses screen, tap the Dictus entry. The URL should point to github.com/getdictus/dictus-ios (not the old Pivii/dictus URL).
result: pass

### 4. FluidAudio Apache 2.0 License
expected: On the Licenses screen, the FluidAudio entry should show "Apache License 2.0" as its license type, with the correct copyright notice.
result: pass

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0

## Gaps

[none]
