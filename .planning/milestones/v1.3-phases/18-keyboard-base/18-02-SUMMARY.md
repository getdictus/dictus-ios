---
phase: 18-keyboard-base
plan: 02
subsystem: keyboard
tags: [giellakbd-ios, UICollectionView, delegate-bridge, haptic-feedback, key-sounds, AZERTY, textDocumentProxy]

requires:
  - phase: 18-keyboard-base
    provides: vendored giellakbd-ios UIKit keyboard foundation and French layouts
provides:
  - DictusKeyboardBridge delegate adapter translating key events to textDocumentProxy operations
  - Hybrid UIKit keyboard + SwiftUI toolbar architecture in KeyboardViewController
  - Haptic feedback and 3-category key sounds wired into all key types
  - Shift/capslock double-tap detection and auto-unshift after character input
  - Auto-full-stop (double-space to period) matching iOS native behavior
  - Recording state observation to hide/show UIKit keyboard during dictation
affects: [18-keyboard-base, 19-keyboard-features, 20-keyboard-integration]

tech-stack:
  added: []
  patterns: [delegate bridge pattern for vendored keyboard integration, hybrid UIKit+SwiftUI keyboard architecture, Combine observation of @Published state for UIKit/SwiftUI sync]

key-files:
  created:
    - DictusKeyboard/DictusKeyboardBridge.swift
  modified:
    - DictusKeyboard/KeyboardViewController.swift
    - DictusKeyboard/KeyboardRootView.swift
    - Dictus.xcodeproj/project.pbxproj

key-decisions:
  - "Bridge pattern: separate DictusKeyboardBridge class instead of making KeyboardViewController the delegate -- single responsibility and testability"
  - "Hybrid layout: UIKit keyboard as direct subview + SwiftUI hosting for toolbar only -- avoids SwiftUI recreation issues with UIViewRepresentable"
  - "Combine for recording state: subscribe to KeyboardState.$dictationStatus instead of custom notifications -- cleaner, type-safe observation"
  - "KeyboardHeightProvider for height: replaced old KeyMetrics-based height calculation with giellakbd-ios per-device height lookup table"

patterns-established:
  - "DictusKeyboardBridge as single point of translation between vendored keyboard events and Dictus text/feedback actions"
  - "Auto Layout stacking: SwiftUI hosting view (toolbar) pinned at top, UIKit keyboard fills remaining space below"
  - "Recording overlay toggle: hide UIKit keyboard via isHidden, expand hosting view height for full-area overlay"

requirements-completed: [KBD-01, KBD-03, KBD-04, KBD-06, FEEL-01, FEEL-02]

duration: 6min
completed: 2026-03-27
---

# Phase 18 Plan 02: Bridge and Wire Keyboard Summary

**DictusKeyboardBridge delegate adapter wiring giellakbd-ios key events to textDocumentProxy with haptic/sound feedback, hosted as UIKit subview alongside SwiftUI toolbar**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-27T23:43:07Z
- **Completed:** 2026-03-27T23:49:29Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created DictusKeyboardBridge implementing GiellaKeyboardViewDelegate with handlers for all key types (input, backspace, space, return, shift, symbols, tab, comma, fullStop, globe)
- Rewired KeyboardViewController to host GiellaKeyboardView as direct UIKit subview with SwiftUI toolbar above via Auto Layout
- Stripped KeyboardRootView to toolbar + recording overlay only (no SwiftUI keyboard grid)
- Wired haptic feedback (10 HapticFeedback.keyTapped calls) and 3-category key sounds throughout the bridge

## Task Commits

Each task was committed atomically:

1. **Task 1: Create DictusKeyboardBridge and wire key actions** - `d40ee9b` (feat)
2. **Task 2: Adapt KeyboardViewController to host UIKit keyboard + SwiftUI toolbar** - `2afaefb` (feat)

## Files Created/Modified
- `DictusKeyboard/DictusKeyboardBridge.swift` - Delegate bridge translating GiellaKeyboardView events to textDocumentProxy operations with haptic/sound feedback
- `DictusKeyboard/KeyboardViewController.swift` - Hybrid UIKit+SwiftUI hosting: GiellaKeyboardView subview + SwiftUI toolbar, Combine recording state observation
- `DictusKeyboard/KeyboardRootView.swift` - Simplified to toolbar + recording overlay (no keyboard grid, no emoji mode, no defaultLayer state)
- `Dictus.xcodeproj/project.pbxproj` - Added DictusKeyboardBridge.swift to DictusKeyboard target

## Decisions Made
- Used a separate DictusKeyboardBridge class (not KeyboardViewController as delegate) for single responsibility and future testability
- Used Combine subscription to KeyboardState.$dictationStatus for recording state observation, avoiding custom notification names
- Replaced KeyMetrics-based height calculation with KeyboardHeightProvider.height(for:traitCollection:) for accurate per-device keyboard sizing
- Kept LegacyCompat.swift (KeyMetrics, KeySound, etc.) on disk since EmojiPickerView still references KeySound and KeyMetrics -- will be cleaned up in Phase 20

## Deviations from Plan

None -- plan executed exactly as written.

## Issues Encountered
- iPhone 16 Pro simulator not available (only iPhone 17 series in Xcode 26.2) -- used iPhone 17 Pro for verification builds. No impact on code.

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
- UIKit keyboard is wired and produces text via the bridge
- Plan 18-03 will handle autocapitalization state machine and shift persistence
- Phase 19 will add long-press accents, key popup styling, and Liquid Glass theming
- Phase 20 will reintegrate emoji picker, suggestion bar updates from bridge, and spacebar trackpad

---
*Phase: 18-keyboard-base*
*Completed: 2026-03-27*
