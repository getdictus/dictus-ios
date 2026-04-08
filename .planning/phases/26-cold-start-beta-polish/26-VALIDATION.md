---
phase: 26
slug: cold-start-beta-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Build + manual device testing |
| **Config file** | Dictus.xcodeproj |
| **Quick run command** | `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS' -quiet` |
| **Full suite command** | `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS' -quiet`
- **After every plan wave:** Run `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'`
- **Before `/gsd:verify-work`:** Full build must succeed
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 26-01-01 | 01 | 1 | COLD-01 | manual | Device test: check sourceApplication API returns | N/A | ⬜ pending |
| 26-01-02 | 01 | 1 | COLD-02 | manual | Device test: auto-return flow (if viable) | N/A | ⬜ pending |
| 26-01-03 | 01 | 1 | COLD-03 | build | `xcodebuild build` compiles overlay redesign | ✅ | ⬜ pending |
| 26-02-01 | 02 | 2 | BETA-01 | manual | Verify reported bugs are fixed on device | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed — this phase is primarily investigation (COLD-01), SwiftUI UI work (COLD-03), and bug fixes (BETA-01), all validated by build + device testing.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| sourceApplication returns bundle ID cross-team | COLD-01 | iOS API behavior must be tested on real device with real apps | Open Messages, tap Dictus keyboard mic, check if sourceApplication is non-nil in DictusApp |
| Auto-return to source app after dictation | COLD-02 | Requires real app switching on device | Complete dictation flow, verify app opens source app URL scheme |
| Swipe-back overlay teaches gesture visually | COLD-03 | Visual/UX validation requires human review | Cold start dictation, view overlay, confirm iPhone mockup + animated swipe + localized text renders correctly |
| Beta bug fixes work as expected | BETA-01 | Bug-specific — depends on what's reported | Reproduce each reported bug, verify fix |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
