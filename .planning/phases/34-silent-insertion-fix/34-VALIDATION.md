---
phase: 34
slug: silent-insertion-fix
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 15+, Swift Package Manager) |
| **Config file** | Dictus.xcodeproj (DictusCoreTests target) |
| **Quick run command** | `xcodebuild test -project Dictus.xcodeproj -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DictusCoreTests/InsertionClassifierTests` |
| **Full suite command** | `xcodebuild test -project Dictus.xcodeproj -scheme DictusCore -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds (unit tests only; integration is manual 50-run protocol) |

---

## Sampling Rate

- **After every task commit:** Run quick command (relevant test class only)
- **After every plan wave:** Run full DictusCore test suite
- **Before `/gsd:verify-work`:** Full suite must be green AND manual 50-run protocol executed on real device
- **Max feedback latency:** 60 seconds (unit); manual verification gated by real-device session

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD — planner fills during PLAN.md generation | — | — | STAB-01 | unit/manual | — | — | ⬜ pending |

*Planner will populate this table per plan. Each automated task MUST reference a concrete xcodebuild test invocation or a Wave 0 test stub. Manual verifications (50-run protocol, DI visual checks, real-device banner) go to the Manual-Only table below.*

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DictusCoreTests/InsertionClassifierTests.swift` — unit tests for delta classifier (success / empty-delta / partial / proxy-dead)
- [ ] `DictusCoreTests/LiveActivityStateMachineTests.swift` — extend existing file with new transition edge test (.standby → .failed and/or .ready → .failed)
- [ ] `DictusCoreTests/LogPrivacyTests.swift` — extend `allEvents` fixture to include new `.keyboardInsertProbe`, `.keyboardInsertRetry`, `.keyboardInsertFailed` cases; verify privacy predicate rejects raw strings

*Framework already present — no install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 50 consecutive dictations, zero silent drops | STAB-01 (success criterion #1) | Requires real device, real host apps, varied scenarios — cannot be automated without XCUITest harness (deferred) | Documented protocol: 50 dictations across Notes, Messages, Safari address bar; mix of warm/cold/chained; log review confirms probe reports insertion success on all 50 |
| #118 repro matrix | STAB-01 (success criterion #2) | Each scenario requires specific device state (cold start, background, chained) | Checklist in PR description: warm same-app, cold start, backgrounded keyboard, rapid chained — each marked pass with probe log evidence |
| Regression on 3 insertion paths | STAB-01 (success criterion #3) | Paths exercised only via real keyboard usage | Test-matrix.md in phase dir lists warm Darwin / cold start Audio Bridge / chained recording; each path tested manually against reference build |
| Loud-fail UX (banner + DI + home card) | STAB-01 (success criterion #4) | Requires forcing insertion failure on device (airplane mode proxy-dead simulation or controlled scenario) | Manual: induce proxy-dead state, verify banner copy, DI failure state, home card updates from App Group |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
