---
phase: 14
slug: model-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing on device/simulator (no unit test framework configured) |
| **Config file** | none |
| **Quick run command** | `xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Full suite command** | Xcode build + manual verification on device |
| **Estimated runtime** | ~60 seconds (build) + manual verification |

---

## Sampling Rate

- **After every task commit:** Xcode build succeeds (no compiler errors)
- **After every plan wave:** Manual device test of model download + prewarm flow
- **Before `/gsd:verify-work`:** Full flow: onboarding with dynamic recommendation, model download, prewarm spinner, Parakeet routing
- **Max feedback latency:** 60 seconds (build time)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | MODEL-01 | manual | Build, verify `ModelInfo.all` does not contain "openai_whisper-large-v3_turbo" | N/A | ⬜ pending |
| 14-01-02 | 01 | 1 | MODEL-02 | manual | Download model, observe UI during prewarm phase — spinner not 0% | N/A | ⬜ pending |
| 14-01-03 | 01 | 1 | MODEL-05 | manual | Force-kill during download, verify retry cleans up and re-attempts | N/A | ⬜ pending |
| 14-02-01 | 02 | 1 | MODEL-07 | manual | Select Parakeet model, record, verify transcription uses Parakeet | N/A | ⬜ pending |
| 14-02-02 | 02 | 1 | MODEL-08 | manual | Grep codebase + visual check: name shows "Parakeet v3" | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No test framework to install — this phase is pure code modification with manual verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Large Turbo v3 not in catalog | MODEL-01 | Requires visual check of model list UI | Build app, open model manager, verify Large Turbo v3 absent |
| Spinner during compilation | MODEL-02 | Requires observing real-time UI during CoreML compilation | Download any model, verify indeterminate spinner shows during prewarm |
| Retry cleans up and re-attempts | MODEL-05 | Requires force-killing app mid-download | Start download, kill app, relaunch, verify retry option works |
| Parakeet routing correct | MODEL-07 | Requires actual transcription test | Select Parakeet v3, record speech, verify output comes from Parakeet |
| Display name "Parakeet v3" | MODEL-08 | Visual UI check + code grep | Check model manager UI, model card, onboarding — name should be "Parakeet v3" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
