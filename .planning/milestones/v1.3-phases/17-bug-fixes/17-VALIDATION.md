---
phase: 17
slug: bug-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in, already configured) |
| **Config file** | `DictusCore/Package.swift` (testTarget: DictusCoreTests) |
| **Quick run command** | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` |
| **Full suite command** | `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 17-01-01 | 01 | 0 | FIX-01 | unit | `xcodebuild test ... -only-testing:DictusCoreTests/LiveActivityStateMachineTests` | ❌ W0 | ⬜ pending |
| 17-01-02 | 01 | 0 | FIX-01 | unit | same as above | ❌ W0 | ⬜ pending |
| 17-01-03 | 01 | 0 | FIX-01 | unit | same as above | ❌ W0 | ⬜ pending |
| 17-02-01 | 02 | 1 | FIX-02 | unit | `xcodebuild test ... -only-testing:DictusCoreTests/PersistentLogTests` | ✅ | ⬜ pending |
| 17-02-02 | 02 | 0 | FIX-02 | unit | same as above | ❌ W0 | ⬜ pending |
| 17-02-03 | 02 | 0 | FIX-02 | unit | same as above | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift` — extracted testable state machine from LiveActivityManager
- [ ] `DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift` — covers FIX-01 transition paths and watchdog
- [ ] `DictusCore/Tests/DictusCoreTests/PersistentLogTests.swift` — extend with retention + size-based trim tests for FIX-02
- [ ] Fix `maxLines` discrepancy: code says 1000, existing test asserts 500 — reconcile before adding new tests

*Existing infrastructure partially covers phase requirements. Wave 0 fills gaps.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DI visual state matches internal state during real recording flow | FIX-01 | ActivityKit rendering requires real device + Live Activity UI | 1. Start recording 2. Stop recording 3. Verify DI clears within 2s 4. Cancel mid-recording 5. Verify DI clears |
| Export shows spinner and completes in <2s | FIX-02 | UI timing requires real device observation | 1. Record several sessions 2. Tap export logs 3. Verify spinner appears 4. Verify completion <2s |
| Cold start overlay never shows grayed-out dead state | FIX-03 | Timing-dependent cold start scenario | 1. Force-kill app 2. Tap mic from keyboard 3. Observe overlay state on app launch |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
