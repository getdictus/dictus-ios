---
phase: 18-keyboard-base
plan: 03
subsystem: keyboard
tags: [autocapitalization, double-space-period, shift-state-machine, caps-lock, textDocumentProxy, haptic-touchDown]

requires:
  - phase: 18-keyboard-base
    provides: DictusKeyboardBridge delegate adapter and hybrid UIKit+SwiftUI keyboard architecture
provides:
  - Autocapitalization state machine respecting textDocumentProxy.autocapitalizationType
  - Double-space period insertion matching iOS native behavior
  - Shift/capslock double-tap detection with isManualShift tracking
  - Auto-unshift after single character input from manual shift
  - Haptic feedback on touchDown (moved from touchUp)
  - Apple-matched keyboard heights (216-226pt iPhone range)
  - QWERTY row 2 centering with spacer units
affects: [19-keyboard-features, 20-keyboard-integration]

tech-stack:
  added: []
  patterns: [autocapitalization state machine with sentence/word/allCharacters modes, isManualShift flag for distinguishing autocap from user shift]

key-files:
  created: []
  modified:
    - DictusKeyboard/DictusKeyboardBridge.swift
    - DictusKeyboard/KeyboardViewController.swift
    - DictusKeyboard/Vendored/Views/KeyboardView.swift
    - DictusKeyboard/FrenchKeyboardLayouts.swift

key-decisions:
  - "Autocapitalization checks documentContextBeforeInput for sentence-ending punctuation (.!?) followed by space"
  - "isManualShift boolean distinguishes user-initiated shift from autocap shift for correct auto-unshift"
  - "handleAutoFullStop returns Bool to prevent double space insertion after period substitution"
  - "Haptic moved from bridge delegate (touchUp) to GiellaKeyboardView.touchesBegan (touchDown) for Apple-matching feel"
  - "iPhone keyboard heights reduced from 262-272pt to 216-226pt to match Apple keyboard proportions"

patterns-established:
  - "updateCapitalization() called after every text mutation (insert, delete, return, textDidChange, viewWillAppear)"
  - "Shift state machine: single tap toggles, double tap within 300ms activates capslock, capslock persists until explicit shift tap"

requirements-completed: [KBD-07, KBD-08, KBD-03]

duration: 12min
completed: 2026-03-28
---

# Phase 18 Plan 03: Autocapitalization, Double-Space Period, and Shift State Machine Summary

**Autocapitalization after sentence-ending punctuation, double-space period insertion, and shift/capslock state machine with touchDown haptics and Apple-matched key heights**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-28T00:07:00Z
- **Completed:** 2026-03-28T00:19:15Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Implemented autocapitalization state machine respecting textDocumentProxy.autocapitalizationType (.sentences, .words, .allCharacters, .none)
- Added double-space period insertion with Bool return to prevent redundant space after substitution
- Refined shift state machine with isManualShift tracking and 300ms double-tap capslock detection
- Wired updateCapitalization() into all text mutation points (insertText, deleteBackward, return, textDidChange, viewWillAppear)
- User verified all 12 test scenarios on iOS Simulator -- 10 passed immediately, 2 issues fixed post-verification

## Task Commits

Each task was committed atomically:

1. **Task 1: Autocapitalization, double-space period, and shift state machine** - `f4c845f` (feat)
2. **Task 2: User verification on iOS Simulator** - checkpoint, fixes applied:
   - `7bd155d` (fix) - Haptic on touchDown, reduce key height to match Apple keyboard
   - `241e993` (fix) - QWERTY row 2 spacers for proper centering

## Files Created/Modified
- `DictusKeyboard/DictusKeyboardBridge.swift` - Added updateCapitalization(), handleAutoFullStop() returning Bool, isManualShift tracking, lastShiftTapTime for capslock double-tap
- `DictusKeyboard/KeyboardViewController.swift` - Added bridge?.updateCapitalization() in textDidChange and viewWillAppear
- `DictusKeyboard/Vendored/Views/KeyboardView.swift` - Moved HapticFeedback.keyTapped() to touchesBegan, reduced iPhone heights from 262-272pt to 216-226pt
- `DictusKeyboard/FrenchKeyboardLayouts.swift` - Added 0.5-unit spacers to QWERTY row 2 for proper key centering

## Decisions Made
- Moved haptic feedback from bridge delegate callback (touchUp timing) to GiellaKeyboardView.touchesBegan (touchDown timing) to match Apple keyboard feel -- user reported touchUp felt wrong
- Reduced keyboard heights by ~46pt to match Apple keyboard proportions -- user reported keys were too tall
- Added QWERTY row 2 spacers (0.5 units each side) to center the 9-key row within the 10-unit grid -- QWERTY layout was causing oversized keys and crashes

## Deviations from Plan

### Post-Verification Fixes

**1. [Rule 1 - Bug] Haptic feedback on touchUp instead of touchDown**
- **Found during:** Task 2 (user verification)
- **Issue:** User reported haptic feedback felt wrong -- it fired on key release (touchUp via delegate callback) instead of key press (touchDown)
- **Fix:** Moved HapticFeedback.keyTapped() from DictusKeyboardBridge delegate method to GiellaKeyboardView.touchesBegan() for immediate touchDown feedback
- **Files modified:** DictusKeyboard/Vendored/Views/KeyboardView.swift, DictusKeyboard/DictusKeyboardBridge.swift
- **Committed in:** 7bd155d

**2. [Rule 1 - Bug] Keyboard keys too tall compared to Apple keyboard**
- **Found during:** Task 2 (user verification)
- **Issue:** iPhone keyboard heights (262-272pt) were significantly taller than Apple's native keyboard
- **Fix:** Reduced heights to 216-226pt range matching Apple keyboard proportions
- **Files modified:** DictusKeyboard/Vendored/Views/KeyboardView.swift
- **Committed in:** 7bd155d

**3. [Rule 1 - Bug] QWERTY row 2 keys oversized causing crash**
- **Found during:** Task 2 (user verification)
- **Issue:** QWERTY row 2 has 9 keys in a 10-unit grid, causing keys to stretch and eventually crash
- **Fix:** Added 0.5-unit spacers on each side of QWERTY row 2 for correct centering
- **Files modified:** DictusKeyboard/FrenchKeyboardLayouts.swift
- **Committed in:** 241e993

---

**Total deviations:** 3 auto-fixed (3 bugs found during user verification)
**Impact on plan:** All fixes necessary for correct keyboard feel and QWERTY stability. No scope creep.

## Known Limitations
- Edge key popup delay: popup preview on edge keys (a, p, backspace) may appear slightly delayed due to iOS keyboard extension rendering constraints. This is a known limitation of the platform, not a fix target.

## Issues Encountered
- iPhone 16 Pro simulator not available in Xcode 26.2 -- used iPhone 17 Pro for verification. No impact on code.

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
- Phase 18 (Keyboard Base) is complete -- all 10 requirements verified
- Phase 19 will add delete repeat, spacebar trackpad, accent long-press, and adaptive accent key
- Phase 20 will reintegrate dictation, text prediction, suggestions, and settings onto the new UIKit keyboard

## Self-Check: PASSED

All 3 task commits verified (f4c845f, 7bd155d, 241e993). Summary file exists.

---
*Phase: 18-keyboard-base*
*Completed: 2026-03-28*
