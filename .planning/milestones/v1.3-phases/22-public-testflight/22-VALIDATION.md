---
phase: 22
slug: public-testflight
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-31
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Xcode Instruments (Allocations) + manual verification |
| **Config file** | N/A — Instruments profiling is manual |
| **Quick run command** | `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'` |
| **Full suite command** | Manual: Instruments profiling on device + App Store Connect upload verification |
| **Estimated runtime** | ~60 seconds (build), ~5 min (profiling) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusApp -destination 'generic/platform=iOS'`
- **After every plan wave:** Instruments memory profiling on device (emoji picker < 50 MiB)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | TF-01 | manual | Instruments memory profiling on device | N/A | ⬜ pending |
| 22-01-02 | 01 | 1 | TF-01 | smoke | `grep -q "NSPrivacyAccessedAPICategoryFileTimestamp" DictusApp/PrivacyInfo.xcprivacy` | ✅ | ⬜ pending |
| 22-02-01 | 02 | 2 | TF-01 | manual | Xcode Archive + Upload to App Store Connect | N/A | ⬜ pending |
| 22-02-02 | 02 | 2 | TF-02, TF-03 | manual | App Store Connect portal — external group + public link | N/A | ⬜ pending |
| 22-02-03 | 02 | 2 | TF-04 | smoke | `grep -q "testflight.apple.com" README.md` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework installation needed — this phase uses Instruments profiling and manual App Store Connect verification.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Emoji picker memory < 50 MiB | TF-01 | Requires Instruments on physical device | Open keyboard, navigate to emoji picker, scroll through categories, check Allocations in Instruments |
| Beta App Review passes | TF-01 | Human Apple review | Submit via App Store Connect, wait for approval notification |
| External testing group created | TF-02 | App Store Connect portal action | Verify group exists in TestFlight > External Testing sidebar |
| Public TestFlight link active | TF-03 | Portal action + browser test | Click the public link, verify TestFlight install prompt appears |
| README has working link | TF-04 | Link correctness | Visit README, click TestFlight link, verify it works |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
