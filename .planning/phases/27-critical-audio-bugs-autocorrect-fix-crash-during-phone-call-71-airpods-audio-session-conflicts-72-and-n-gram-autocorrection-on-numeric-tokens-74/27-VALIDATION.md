---
phase: 27
slug: critical-audio-bugs-autocorrect-fix
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-07
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode build + manual device testing |
| **Config file** | Dictus.xcodeproj |
| **Quick run command** | `xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5` |
| **Full suite command** | `xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command
- **After every plan wave:** Run full build command
- **Before `/gsd:verify-work`:** Full build must succeed + manual device checks
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 27-01-01 | 01 | 1 | BUG-71 | build + grep | `grep -r "CXCallObserver" Dictus/` | ❌ W0 | ⬜ pending |
| 27-01-02 | 01 | 1 | BUG-71 | build + grep | `grep -r "interruptionNotification" Dictus/` | ❌ W0 | ⬜ pending |
| 27-02-01 | 02 | 1 | BUG-72 | build + grep | `grep -r "notifyOthersOnDeactivation\|setActive.*false" Dictus/` | ❌ W0 | ⬜ pending |
| 27-03-01 | 03 | 1 | BUG-74 | build + grep | `grep -r "decimalDigits\|containsDigit" DictusKeyboard/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — this is a bug-fix phase with build verification and manual device testing.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No crash during phone call dictation | BUG-71 | Requires real phone call + keyboard activation | 1. Start phone call 2. Open keyboard 3. Tap mic — should show "call active" message, not crash |
| AirPods routing restored after recording | BUG-72 | Requires AirPods hardware + media playback | 1. Play music via AirPods 2. Record dictation 3. Stop — music should resume on AirPods |
| Numeric tokens not autocorrected | BUG-74 | Can verify via grep but device UX matters | 1. Type "test123" 2. Tap space — word should NOT be replaced |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
