---
phase: 30-subscription-paywall
plan: 02
subsystem: payments
tags: [storekit, subscription, paywall, swiftui, in-app-purchase]

requires:
  - phase: 30-01
    provides: ProStatusManager, ProFeature, FeatureGate, ProConfig, SharedKeys Pro keys
provides:
  - SubscriptionManager with StoreKit 2 purchase/restore/transaction listener
  - StoreKit Configuration for Simulator testing
  - PaywallView with feature cards, beta banner, subscribe CTA, error handling
  - ProBannerView compact gradient card for HomeView
  - Settings Dictus Pro row with BETA pill + Pro Features section with toggles
  - SubscriptionManager + ProStatusManager wired into app lifecycle
affects: [phase-33-smart-mode, keyboard-extension, onboarding]

tech-stack:
  added: [StoreKit 2]
  patterns: [SubscriptionManager singleton via @StateObject, environmentObject injection]

key-files:
  created:
    - DictusApp/Subscription/SubscriptionManager.swift
    - DictusApp/Subscription/StoreKitConfig.storekit
    - DictusApp/Views/PaywallView.swift
    - DictusApp/Views/ProBannerView.swift
  modified:
    - DictusApp/DictusApp.swift
    - DictusApp/Views/SettingsView.swift
    - DictusApp/Views/HomeView.swift
    - DictusCore/Sources/DictusCore/LogEvent.swift

key-decisions:
  - "SubscriptionManager uses @MainActor for thread safety with SwiftUI observation"
  - "Transaction.updates listener starts at init, updateProStatus at launch (passive, no sign-in)"
  - "restorePurchases uses AppStore.sync which may prompt sign-in — only from explicit user tap"
  - "PaywallView uses onChange(of: purchaseState) for auto-dismiss after success"
  - "ProBannerView hidden via if !proStatus.isProActive (not opacity) to fully remove from layout"

patterns-established:
  - "Paywall access: NavigationLink pushing PaywallView() from Settings or Home banner"
  - "Pro UI gating: check proStatus.isProActive || ProConfig.isBeta for toggle vs lock display"
  - "EnvironmentObject injection: proStatus + subscriptionManager on MainTabView and OnboardingView"

requirements-completed: [SUB-01, SUB-03, SUB-04, PAY-01, PAY-02, PAY-03, PAY-04, PAY-05, PAY-06]

duration: 20min
completed: 2026-04-09
---

# Plan 30-02: StoreKit 2 Infrastructure + Paywall UI Summary

**StoreKit 2 SubscriptionManager, PaywallView with feature cards and beta banner, ProBannerView on Home, Settings Pro section with toggles**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3 (auto) + 1 (visual verification pending)
- **Files modified:** 9

## Accomplishments
- SubscriptionManager handles purchase, restore, transaction listener, and entitlement checking
- StoreKit Configuration enables local Simulator testing with monthly $4.99 subscription
- PaywallView shows 3 feature cards with Liquid Glass, beta banner when isBeta=true, localized CTA price
- ProBannerView on HomeView with gradient background, hidden when Pro active
- Settings has Dictus Pro row with BETA pill and Pro Features section with toggles/locks
- subscriptionError LogEvent case for subscription error tracking

## Task Commits

1. **Task 1: SubscriptionManager + StoreKit + App wiring** - `c31cc57` (feat)
2. **Task 2: PaywallView + ProBannerView** - `0955f1c` (feat)
3. **Task 3: Settings + Home integration** - `4d289e0` (feat)

## Files Created/Modified
- `DictusApp/Subscription/SubscriptionManager.swift` - StoreKit 2 purchase/restore/listen lifecycle
- `DictusApp/Subscription/StoreKitConfig.storekit` - Local testing configuration
- `DictusApp/Views/PaywallView.swift` - Full paywall with feature cards, CTA, beta variant
- `DictusApp/Views/ProBannerView.swift` - Compact gradient Pro banner for Home
- `DictusApp/DictusApp.swift` - Wired ProStatusManager + SubscriptionManager as @StateObject
- `DictusApp/Views/SettingsView.swift` - Added Dictus Pro row + Pro Features section
- `DictusApp/Views/HomeView.swift` - Added ProBannerView
- `DictusCore/Sources/DictusCore/LogEvent.swift` - Added subscriptionError case
- `Dictus.xcodeproj/project.pbxproj` - Added new files to Xcode project

## Decisions Made
- Used `diagnosticProbe` as fallback if LogEvent didn't support extensible pattern, but LogEvent enum was extensible so added proper `subscriptionError` case
- PaywallView uses `.lineLimit(2)` instead of plan's `.lineLimit(1)` for feature descriptions — longer French descriptions need 2 lines

## Deviations from Plan
None significant — followed plan as specified

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Task 4 (visual verification) pending user testing in Simulator
- Complete subscription + paywall flow ready for visual QA
- All existing app functionality preserved

---
*Phase: 30-subscription-paywall*
*Completed: 2026-04-09*
