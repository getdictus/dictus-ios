---
phase: 23
slug: bug-fixes-license-compliance
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build + Manual UI verification |
| **Config file** | Dictus.xcodeproj |
| **Quick run command** | `xcodebuild build -project Dictus.xcodeproj -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` |
| **Full suite command** | `xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet && xcodebuild build -project Dictus.xcodeproj -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick build command (DictusKeyboard target)
- **After every plan wave:** Run full suite command (both targets)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | FIX-01 | manual | Build + simulator test | N/A | ⬜ pending |
| 23-01-02 | 01 | 1 | FIX-02 | grep | `grep -q "getdictus/dictus-ios" DictusApp/Views/LicensesView.swift` | ✅ | ⬜ pending |
| 23-01-03 | 01 | 1 | FIX-03 | grep | `grep -q "FluidAudio" DictusApp/Views/LicensesView.swift && grep -q "DeviceKit" DictusApp/Views/LicensesView.swift && grep -q "giellakbd" DictusApp/Views/LicensesView.swift` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Backspace after autocorrect deletes last typed char, not undo | FIX-01 | Requires keyboard interaction in simulator | 1. Open Messages, type "teh" → autocorrects to "the". 2. Type "re" → "there". 3. Press backspace → should delete "e" not undo "the"→"teh". |
| Licenses screen shows correct repo URL | FIX-02 | UI navigation test | 1. Open Dictus app. 2. Go to Settings → Licenses. 3. Verify "getdictus/dictus-ios" link present. |
| Parakeet/NVIDIA attribution visible | FIX-03 | UI navigation test | 1. Open Dictus app. 2. Go to Settings → Licenses. 3. Scroll to FluidAudio entry with Apache 2.0 license. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
