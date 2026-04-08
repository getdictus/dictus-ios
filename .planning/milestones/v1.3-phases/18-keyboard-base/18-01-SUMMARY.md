---
phase: 18-keyboard-base
plan: 01
subsystem: keyboard
tags: [giellakbd-ios, UICollectionView, DeviceKit, vendoring, AZERTY, QWERTY, French]

requires:
  - phase: 17-bugfixes
    provides: stable codebase for keyboard architecture change
provides:
  - vendored giellakbd-ios UIKit keyboard foundation (13 source files)
  - GiellaKeyboardView UICollectionView class with direct touch handling
  - French AZERTY/QWERTY/numbers/symbols layout definitions in giellakbd-ios format
  - DeviceKit SPM dependency for per-device keyboard height calculation
  - LegacyCompat.swift compatibility stubs for migration period
affects: [18-keyboard-base, 19-keyboard-features, 20-keyboard-integration]

tech-stack:
  added: [DeviceKit 5.8+, giellakbd-ios vendored source]
  patterns: [UICollectionView keyboard with disabled user interaction and direct touch handling, programmatic KeyboardDefinition construction]

key-files:
  created:
    - DictusKeyboard/Vendored/Views/KeyboardView.swift
    - DictusKeyboard/Vendored/Views/KeyView.swift
    - DictusKeyboard/Vendored/Views/KeyOverlayView.swift
    - DictusKeyboard/Vendored/Models/KeyDefinition.swift
    - DictusKeyboard/Vendored/Models/KeyboardDefinition.swift
    - DictusKeyboard/Vendored/Models/Theme.swift
    - DictusKeyboard/Vendored/Models/DeviceContext.swift
    - DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift
    - DictusKeyboard/Vendored/Models/InputContext.swift
    - DictusKeyboard/Vendored/Models/SystemKeys.swift
    - DictusKeyboard/Vendored/Controllers/LongPressController.swift
    - DictusKeyboard/Vendored/Controllers/DeadKeyHandler.swift
    - DictusKeyboard/Vendored/Controllers/Audio.swift
    - DictusKeyboard/Vendored/GiellaUtils.swift
    - DictusKeyboard/FrenchKeyboardLayouts.swift
    - DictusKeyboard/LegacyCompat.swift
  modified:
    - Dictus.xcodeproj/project.pbxproj
    - DictusKeyboard/Models/KeyboardLayer.swift

key-decisions:
  - "Renamed vendored KeyboardView to GiellaKeyboardView to avoid Swift type collision with existing SwiftUI KeyboardView"
  - "Extracted GiellaUtils.swift with shared extensions instead of scattering helpers across vendored files"
  - "Added programmatic KeyboardDefinition initializer for direct layout construction without JSON parsing"
  - "Created LegacyCompat.swift with KeyMetrics/DeviceClass/KeySound/KeyPopup stubs to maintain compilation during migration"
  - "Removed old SwiftUI keyboard files from build phase (kept on disk for reference) rather than renaming their types"
  - "Renamed vendored Audio class to GiellaAudio and removed KeyboardSettings dependency"

patterns-established:
  - "Vendored files in DictusKeyboard/Vendored/ with Views/Models/Controllers subdirectories"
  - "GiellaUtils.swift contains all shared UIKit extensions used across vendored files"
  - "FrenchKeyboardLayouts enum constructs KeyboardDefinition programmatically with helper functions"

requirements-completed: [KBD-01, KBD-02, KBD-04, FEEL-03]

duration: 25min
completed: 2026-03-27
---

# Phase 18 Plan 01: Vendor giellakbd-ios and French Layouts Summary

**13 giellakbd-ios UIKit files vendored with all Sentry/DivvunSpell/RxSwift stripped, DeviceKit linked via SPM, French AZERTY/QWERTY/numbers/symbols layouts defined programmatically**

## Performance

- **Duration:** 25 min
- **Started:** 2026-03-27T23:13:30Z
- **Completed:** 2026-03-27T23:39:22Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments
- Vendored 13 giellakbd-ios source files covering the complete UICollectionView keyboard stack (views, models, controllers)
- Stripped all external dependencies (Sentry, DivvunSpell, RxSwift, SQLite) with zero remaining references
- Created French AZERTY and QWERTY layout definitions with numbers and symbols pages matching iOS stock French keyboard
- Added DeviceKit 5.8+ as SPM dependency linked to DictusKeyboard target for per-device height calculation
- Project compiles with zero errors (only deprecation warnings in emoji picker)

## Task Commits

Each task was committed atomically:

1. **Task 1: Vendor giellakbd-ios files and strip external dependencies** - `204f378` (feat)
2. **Task 2: Create French AZERTY/QWERTY layout definitions** - `cceee26` (feat)

## Files Created/Modified
- `DictusKeyboard/Vendored/Views/KeyboardView.swift` - UICollectionView keyboard with direct touch handling (renamed to GiellaKeyboardView)
- `DictusKeyboard/Vendored/Views/KeyView.swift` - Individual key cell rendering with theme-based styling
- `DictusKeyboard/Vendored/Views/KeyOverlayView.swift` - Bezier path key popup preview with edge handling
- `DictusKeyboard/Vendored/Models/KeyDefinition.swift` - Key type enum and sizing model
- `DictusKeyboard/Vendored/Models/KeyboardDefinition.swift` - Layout structure with programmatic initializer
- `DictusKeyboard/Vendored/Models/Theme.swift` - iOS 26 Liquid Glass + legacy theming with ThemeFactory
- `DictusKeyboard/Vendored/Models/DeviceContext.swift` - DeviceKit-based device detection
- `DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift` - Per-device height lookup table
- `DictusKeyboard/Vendored/Models/InputContext.swift` - Word extraction from UITextDocumentProxy
- `DictusKeyboard/Vendored/Models/SystemKeys.swift` - Bottom row generation for platform
- `DictusKeyboard/Vendored/Controllers/LongPressController.swift` - Long-press overlay and cursor movement
- `DictusKeyboard/Vendored/Controllers/DeadKeyHandler.swift` - Dead key transformations for accents
- `DictusKeyboard/Vendored/Controllers/Audio.swift` - 3-category system sound playback
- `DictusKeyboard/Vendored/GiellaUtils.swift` - Shared extensions (UIView.fill, NSLayoutConstraint.enable, etc.)
- `DictusKeyboard/FrenchKeyboardLayouts.swift` - AZERTY/QWERTY/numbers/symbols layout definitions
- `DictusKeyboard/LegacyCompat.swift` - Compatibility stubs for migration period
- `DictusKeyboard/Models/KeyboardLayer.swift` - Removed KeyboardLayer struct, kept KeyboardLayerType enum
- `Dictus.xcodeproj/project.pbxproj` - Added vendored files, DeviceKit SPM, updated build phases

## Decisions Made
- Renamed vendored `KeyboardView` to `GiellaKeyboardView` to avoid type collision with the existing SwiftUI `KeyboardView` that is still used by `KeyboardRootView`. This is the minimal change approach -- the SwiftUI view will be fully replaced in plan 18-02.
- Created `LegacyCompat.swift` with stubs for `KeyMetrics`, `DeviceClass`, `KeySound`, `KeyPopup`, and a placeholder `KeyboardView` struct. This keeps compilation working during the migration without modifying the existing SwiftUI files.
- Removed old SwiftUI keyboard files from the Xcode build phase (KeyButton.swift, SpecialKeyButton.swift, KeyRow.swift, KeyboardView.swift, KeyDefinition.swift, KeyboardLayout.swift, AccentPopup.swift) but kept them on disk. Plan 18-02 will decide which to delete.
- Added a programmatic `init` to `KeyboardDefinition` for constructing layouts without JSON, since giellakbd-ios only provides a Sami layout in JSON.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Type name collision between vendored and existing files**
- **Found during:** Task 1 (vendoring files)
- **Issue:** Vendored `KeyboardView` (UIKit class) and `KeyDefinition` type names clash with existing Dictus SwiftUI types in the same module
- **Fix:** Renamed vendored KeyboardView to GiellaKeyboardView. Removed old conflicting files from build phase and created LegacyCompat.swift with compatibility stubs.
- **Files modified:** DictusKeyboard/Vendored/Views/KeyboardView.swift, DictusKeyboard/LegacyCompat.swift, Dictus.xcodeproj/project.pbxproj
- **Verification:** xcodebuild succeeds with zero errors
- **Committed in:** 204f378 (Task 1 commit)

**2. [Rule 3 - Blocking] Audio.swift references non-existent KeyboardSettings**
- **Found during:** Task 1 (dependency stripping)
- **Issue:** giellakbd-ios Audio.swift depends on KeyboardSettings.isKeySoundEnabled which doesn't exist in Dictus
- **Fix:** Renamed class to GiellaAudio, removed KeyboardSettings dependency. Sound always plays (existing Dictus behavior), silent switch respected by AudioServicesPlaySystemSound.
- **Files modified:** DictusKeyboard/Vendored/Controllers/Audio.swift
- **Verification:** Build succeeds
- **Committed in:** 204f378 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both auto-fixes necessary for compilation. No scope creep -- vendored files work as intended.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Vendored UIKit keyboard files compile and are ready for integration
- GiellaKeyboardView can be instantiated with FrenchKeyboardLayouts.current() and a Theme
- Plan 18-02 will bridge the vendored keyboard into KeyboardViewController, wire delegates for text input/haptics/sounds
- Plan 18-03 will handle shift/capslock state and autocapitalization

---
*Phase: 18-keyboard-base*
*Completed: 2026-03-27*
