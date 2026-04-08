---
phase: 19
slug: complex-touch-features
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-28
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing on physical device (keyboard extensions cannot run unit tests for touch pipeline) |
| **Config file** | none |
| **Quick run command** | `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Full suite command** | Build + install on device + manual UAT |
| **Estimated runtime** | ~60 seconds (build) + manual testing |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **After every plan wave:** Full manual test of all features + edge key dead zone validation
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | FEEL-04 | manual | Build + long-press "e" on device | N/A | ⬜ pending |
| 19-01-02 | 01 | 1 | KBD-08 | manual | Build + type word-space-space on device | N/A | ⬜ pending |
| 19-01-03 | 01 | 1 | FEEL-06 | manual | Build + pre-warm check at startup | N/A | ⬜ pending |
| 19-02-01 | 02 | 2 | FEEL-06 | manual | Build + tap all edge keys on device | N/A | ⬜ pending |
| 19-03-01 | 03 | 3 | KBD-05 | manual | Build + hold backspace on device | N/A | ⬜ pending |
| 19-04-01 | 04 | 4 | FEEL-05 | manual | Build + long-press spacebar + drag on device | N/A | ⬜ pending |
| 19-05-01 | 05 | 5 | FEEL-06 | manual | Build + type vowel, check adaptive key label on device | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Touch feature testing is inherently manual for keyboard extensions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Backspace hold deletes with acceleration | KBD-05 | Touch pipeline in keyboard extension, no unit test access | Hold backspace, verify accelerating deletion speed + haptic per deletion |
| Double-space inserts period+space | KBD-08 | Requires textDocumentProxy IPC | Type word, tap space twice, verify ". " insertion |
| Long-press vowel shows accent popup | FEEL-04 | Gesture timing + overlay rendering | Long-press "e", verify accent popup appears, drag to select accent |
| Spacebar drag moves cursor | FEEL-05 | Gesture tracking + haptic timing | Long-press spacebar, drag left/right, verify cursor movement + haptic ticks |
| Adaptive accent key shows correct label | FEEL-06 | Requires visual inspection of key state | Type vowel, check accent key shows accent; type consonant, check apostrophe |
| Edge keys fire on touchDown | N/A (Phase 18 regression fix) | System gesture delay, device-only | Tap edge keys (a, q, p, m), verify immediate haptic + popup |
| Zero dead zones preserved | N/A (critical constraint) | Full keyboard touch coverage | Tap every key on every row, verify all register |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
