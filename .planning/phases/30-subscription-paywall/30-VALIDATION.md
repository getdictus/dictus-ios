---
phase: 30
slug: subscription-paywall
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-09
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) + StoreKit Testing |
| **Config file** | DictusApp/Subscription/StoreKitConfig.storekit (Wave 0) |
| **Quick run command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing DictusTests/SubscriptionTests` |
| **Full suite command** | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **After every plan wave:** Manual walkthrough of paywall flow + StoreKit Testing purchase
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 30-01-01 | 01 | 1 | SUB-01 | unit (StoreKit Testing) | StoreKit Config + Simulator test | ❌ W0 | ⬜ pending |
| 30-01-02 | 01 | 1 | SUB-02 | unit | Read SharedKeys.proActive after mock purchase | ❌ W0 | ⬜ pending |
| 30-01-03 | 01 | 1 | SUB-03 | unit (StoreKit Testing) | AppStore.sync() + verify entitlements | ❌ W0 | ⬜ pending |
| 30-01-04 | 01 | 1 | SUB-04 | unit (StoreKit Testing) | Simulate renewal in StoreKit Config | ❌ W0 | ⬜ pending |
| 30-01-05 | 01 | 1 | SUB-05 | unit | Assert ProStatusManager.isProActive when isBeta=true | ❌ W0 | ⬜ pending |
| 30-01-06 | 01 | 1 | SUB-06 | unit | FeatureGate.isAvailable(.smartMode) with mock status | ❌ W0 | ⬜ pending |
| 30-02-01 | 02 | 2 | PAY-01 | manual | Navigate to paywall from Settings and Home | N/A | ⬜ pending |
| 30-02-02 | 02 | 2 | PAY-02 | manual | Visual inspection of paywall UI | N/A | ⬜ pending |
| 30-02-03 | 02 | 2 | PAY-03 | manual | Tap restore, verify Pro unlocks | N/A | ⬜ pending |
| 30-02-04 | 02 | 2 | PAY-04 | manual | Build with isBeta=true, inspect paywall | N/A | ⬜ pending |
| 30-02-05 | 02 | 2 | PAY-05 | manual | Disable Pro, check keyboard has no Pro UI | N/A | ⬜ pending |
| 30-02-06 | 02 | 2 | PAY-06 | manual | Verify links on paywall | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DictusApp/Subscription/StoreKitConfig.storekit` — StoreKit Configuration file for local testing
- [ ] SharedKeys additions (`proActive`, `smartModeEnabled`, `historyEnabled`, `vocabularyEnabled`)
- [ ] ProConfig.isBeta flag setup

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Paywall screen shows on tap | PAY-01 | Navigation + UI rendering | Tap "Dictus Pro" in Settings → paywall appears |
| Paywall displays benefits + pricing | PAY-02 | Visual layout inspection | Verify 3 feature cards, price in CTA, cancel text |
| Restore purchases works | PAY-03 | StoreKit sandbox interaction | Tap restore → verify Pro unlocks |
| Beta banner shows during beta | PAY-04 | Conditional UI state | Build with isBeta=true → verify banner, no purchase flow |
| Keyboard hides Pro features when free | PAY-05 | Cross-process UI state | Disable Pro, open keyboard → no Pro buttons visible |
| ToS + Privacy links present | PAY-06 | Link presence + navigation | Verify links at bottom of paywall |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
