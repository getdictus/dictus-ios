---
phase: 30-subscription-paywall
plan: 01
subsystem: payments
tags: [storekit, subscription, app-group, feature-gate]

requires:
  - phase: none
    provides: first subscription phase
provides:
  - SharedKeys for Pro subscription status (proActive, smartModeEnabled, historyEnabled, vocabularyEnabled)
  - ProConfig beta flag with TESTFLIGHT compiler conditional
  - ProFeature enum (smartMode, history, vocabulary) with display metadata
  - FeatureGate static gating (isAvailable, isKeyboardFeatureAvailable)
  - ProStatusManager ObservableObject + static accessor for keyboard extension
affects: [30-02, phase-33-smart-mode, keyboard-extension]

tech-stack:
  added: []
  patterns: [App Group feature gating, static Pro status for keyboard extension, beta flag pattern]

key-files:
  created:
    - DictusCore/Sources/DictusCore/Subscription/ProConfig.swift
    - DictusCore/Sources/DictusCore/Subscription/ProFeature.swift
    - DictusCore/Sources/DictusCore/Subscription/ProStatusManager.swift
  modified:
    - DictusCore/Sources/DictusCore/SharedKeys.swift

key-decisions:
  - "Simple isBeta bool with TESTFLIGHT compiler flag rather than runtime TestFlight detection"
  - "ProStatusManager has both ObservableObject (for SwiftUI) and static accessor (for keyboard extension)"
  - "Per-feature toggles default to true via register(defaults:)"

patterns-established:
  - "Feature gating: FeatureGate.isAvailable(.feature) checks Pro status + per-feature toggle"
  - "Keyboard gating: FeatureGate.isKeyboardFeatureAvailable(.feature) for extension-specific checks"
  - "Pro status sync: ProStatusManager writes to App Group, keyboard reads via static method"

requirements-completed: [SUB-02, SUB-05, SUB-06]

duration: 10min
completed: 2026-04-09
---

# Plan 30-01: DictusCore Subscription Foundation Summary

**SharedKeys Pro keys, ProConfig beta flag, ProFeature enum with FeatureGate, and ProStatusManager for App Group cross-process sync**

## Performance

- **Duration:** ~10 min
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added 4 Pro subscription keys to SharedKeys (proActive, smartModeEnabled, historyEnabled, vocabularyEnabled)
- Created ProConfig with isBeta flag and TESTFLIGHT compiler conditional
- Created ProFeature enum with 3 cases and full display metadata (name, icon, descriptions FR/EN)
- Created FeatureGate with isAvailable() and isKeyboardFeatureAvailable() static methods
- Created ProStatusManager with ObservableObject for SwiftUI + static accessor for keyboard extension

## Task Commits

1. **Task 1: SharedKeys + ProConfig** - `85e3e4d` (feat)
2. **Task 2: ProFeature + FeatureGate + ProStatusManager** - `8815b4e` (feat)

## Files Created/Modified
- `DictusCore/Sources/DictusCore/SharedKeys.swift` - Added Pro subscription keys
- `DictusCore/Sources/DictusCore/Subscription/ProConfig.swift` - Beta flag with TESTFLIGHT conditional
- `DictusCore/Sources/DictusCore/Subscription/ProFeature.swift` - ProFeature enum + FeatureGate
- `DictusCore/Sources/DictusCore/Subscription/ProStatusManager.swift` - App Group Pro status sync

## Decisions Made
None - followed plan as specified

## Deviations from Plan
None - plan executed exactly as written

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All DictusCore subscription types ready for Plan 30-02 (SubscriptionManager, PaywallView, Settings)
- ProStatusManager and FeatureGate are importable by DictusApp and DictusKeyboard

---
*Phase: 30-subscription-paywall*
*Completed: 2026-04-09*
