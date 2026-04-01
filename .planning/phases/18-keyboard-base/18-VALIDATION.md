---
phase: 18
slug: keyboard-base
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | DictusKeyboard target in Xcode project |
| **Quick run command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DictusCoreTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 \| tail -30` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DictusCoreTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 | tail -30`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 18-01-01 | 01 | 1 | KBD-01 | manual (Simulator) | Tap every key on AZERTY, verify character output | N/A | ⬜ pending |
| 18-01-02 | 01 | 1 | KBD-02 | manual (Simulator) | Switch to QWERTY, verify keys appear correctly | N/A | ⬜ pending |
| 18-02-01 | 02 | 1 | KBD-03 | manual (Simulator) | Tap shift (single/double), verify key label changes | N/A | ⬜ pending |
| 18-02-02 | 02 | 1 | KBD-04 | manual (Simulator) | Tap 123, #+=, ABC, verify layers | N/A | ⬜ pending |
| 18-02-03 | 02 | 2 | KBD-06 | manual (Simulator) | Type space, return, verify text output | N/A | ⬜ pending |
| 18-02-04 | 02 | 2 | KBD-07 | manual (Simulator) | Type ". " then check shift activates | N/A | ⬜ pending |
| 18-02-05 | 02 | 2 | KBD-08 | manual (Simulator) | Type "hello  " verify ". " replaces double space | N/A | ⬜ pending |
| 18-03-01 | 03 | 2 | FEEL-01 | manual (Device) | Feel haptic on device touchDown | N/A | ⬜ pending |
| 18-03-02 | 03 | 2 | FEEL-02 | manual (Device) | Listen for 3-category key sounds | N/A | ⬜ pending |
| 18-03-03 | 03 | 2 | FEEL-03 | manual (Simulator) | Press key, verify popup appears above key | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Unit tests for layout data (AZERTY/QWERTY row counts, key definitions) in DictusCoreTests
- [ ] Verify build succeeds with vendored giellakbd-ios files

*Keyboard extension UI testing is primarily manual (Simulator + device). Unit tests verify layout data correctness.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AZERTY typing zero dead zones | KBD-01 | Keyboard extension touch handling requires Simulator interaction | Tap every key position on AZERTY, verify each produces correct character |
| QWERTY layout switch | KBD-02 | Layout switch requires Simulator UI interaction | Switch layout in settings, verify QWERTY keys appear |
| Shift/caps lock toggle | KBD-03 | Visual state changes require Simulator verification | Single tap shift, double tap caps, verify key labels change |
| Layer switching | KBD-04 | Layer transitions require Simulator UI | Tap 123, #+=, ABC, verify correct layers |
| Space/return insertion | KBD-06 | Text insertion requires textDocumentProxy in Simulator | Type space, return, verify output |
| Autocapitalization | KBD-07 | Requires typing flow in Simulator | Type ". " then verify shift activates automatically |
| Double-space period | KBD-08 | Requires typing flow in Simulator | Type "hello  " and verify ". " replaces double space |
| Haptic feedback | FEEL-01 | Haptics only work on physical device | Test on device, feel haptic on each key touchDown |
| 3-category key sounds | FEEL-02 | Audio output requires device/Simulator with sound | Listen for distinct sounds on letter/delete/modifier keys |
| Key popup preview | FEEL-03 | Visual popup requires Simulator verification | Press and hold key, verify popup appears above pressed key |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
