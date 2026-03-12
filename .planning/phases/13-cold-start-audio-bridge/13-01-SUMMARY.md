---
phase: 13-cold-start-audio-bridge
plan: 01
subsystem: ui, ipc
tags: [url-scheme, cold-start, swiftui, app-group, shared-keys]

# Dependency graph
requires:
  - phase: 12-animation-state-fixes
    provides: "Stable recording overlay and animation state"
provides:
  - "SharedKeys.coldStartActive and sourceAppScheme for cross-process cold start detection"
  - "KnownAppSchemes registry with top 10 messaging app URL schemes"
  - "KnownAppSchemesTests verifying scheme list integrity"
  - "MainTabView conditional rendering: swipe-back placeholder vs normal tabs"
  - "Cold start flag cleanup on scenePhase .background"
affects: [13-02-PLAN, 13-03-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns: ["URL query parameter parsing for launch mode detection", "Dual onOpenURL pattern (DictusApp + MainTabView) for cross-process + local state"]

key-files:
  created:
    - "DictusCore/Sources/DictusCore/KnownAppSchemes.swift"
    - "DictusCore/Tests/DictusCoreTests/KnownAppSchemesTests.swift"
  modified:
    - "DictusCore/Sources/DictusCore/SharedKeys.swift"
    - "DictusApp/DictusApp.swift"
    - "DictusApp/Views/MainTabView.swift"

key-decisions:
  - "onOpenURL in both DictusApp and MainTabView: App Group flag for cross-process, @State for local SwiftUI reactivity"
  - "Cold start state cleared on .background, not .inactive, to avoid premature cleanup during app transitions"
  - "DictationCoordinator left untouched -- cold start log added in DictusApp.handleIncomingURL instead"

patterns-established:
  - "URL query parameter source=keyboard as cold start signal from keyboard to app"
  - "App Group flag + local @State dual-write pattern for cross-process + SwiftUI state"

requirements-completed: [COLD-02, COLD-05, COLD-06, COLD-07]

# Metrics
duration: 4min
completed: 2026-03-12
---

# Phase 13 Plan 01: Cold Start Infrastructure Summary

**Cold start launch detection via URL query param, KnownAppSchemes registry with 10 messaging apps, and conditional MainTabView rendering (placeholder vs tabs)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-12T10:04:42Z
- **Completed:** 2026-03-12T10:08:33Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- SharedKeys extended with coldStartActive and sourceAppScheme for cross-process cold start detection
- KnownAppSchemes registry created with AppScheme struct and 10 messaging app URL schemes, accessible from both DictusApp and DictusKeyboard
- MainTabView conditionally renders swipe-back placeholder (for Plan 02) vs normal tabs based on cold start mode
- Cold start flag properly cleaned up on background transition to prevent stale state

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SharedKeys + KnownAppSchemes contracts + unit tests** - `a4c10b0` (feat)
2. **Task 2: Wire cold start detection in DictusApp + MainTabView** - `287138f` (feat)

## Files Created/Modified
- `DictusCore/Sources/DictusCore/SharedKeys.swift` - Added coldStartActive and sourceAppScheme keys
- `DictusCore/Sources/DictusCore/KnownAppSchemes.swift` - New file: AppScheme struct + KnownAppSchemes enum with 10 app URL schemes
- `DictusCore/Tests/DictusCoreTests/KnownAppSchemesTests.swift` - New file: 5 unit tests for scheme integrity
- `DictusApp/DictusApp.swift` - URL query param parsing in handleIncomingURL, cold start cleanup in .background
- `DictusApp/Views/MainTabView.swift` - Conditional rendering with isColdStartMode, onOpenURL + scenePhase handlers

## Decisions Made
- onOpenURL registered in both DictusApp (sets App Group flag for cross-process) and MainTabView (drives local @State for SwiftUI reactivity). Both fire on the same URL event.
- Cold start state cleared on .background (not .inactive) to avoid premature cleanup during rapid app transitions triggered by URL scheme opening.
- DictationCoordinator left completely untouched -- cold start detection log placed in DictusApp.handleIncomingURL where the URL parsing happens. This preserves COLD-06 (direct recording from HomeView mic unaffected).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- DictusCoreTests cannot run via `swift test` or `xcodebuild test -scheme DictusApp` because the DictusApp scheme has no test action configured and SPM builds fail for iOS-only package on macOS. This is a pre-existing limitation (documented in Phase 11 summaries). Tests verified structurally; xcodebuild build confirms compilation of all targets.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Cold start infrastructure ready for Plan 02 (SwipeBackOverlayView replaces the placeholder)
- KnownAppSchemes data ready for Plan 03 (auto-return logic uses schemes to navigate back)
- SharedKeys.coldStartActive contract established for keyboard extension to read in Plan 03
- URL format dependency noted: keyboard needs to send `dictus://dictate?source=keyboard` (Plan 03 will update KeyboardState)

---
*Phase: 13-cold-start-audio-bridge*
*Completed: 2026-03-12*
