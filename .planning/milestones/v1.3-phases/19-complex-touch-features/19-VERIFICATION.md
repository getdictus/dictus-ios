---
phase: 19-complex-touch-features
verified: 2026-03-28T12:00:00Z
status: human_needed
score: 6/6 must-haves verified
human_verification:
  - test: "Long-press vowels on physical device (e, a, u, i, o, c, y, n) on normal page"
    expected: "Accent popup appears with drag-to-select. Releasing on an accented character inserts it."
    why_human: "UICollectionView popup behavior and touch tracking require device rendering; cannot verify in simulator."
  - test: "Long-press shifted vowels (E, A, etc.) on physical device"
    expected: "Accent popup shows UPPERCASE accented variants."
    why_human: "Case transformation branch requires live touch on device."
  - test: "Type a word then press space twice"
    expected: "Double-space inserts '. ' (period + space) replacing the single space."
    why_human: "textDocumentProxy.documentContextBeforeInput behavior varies by text field; must confirm on device."
  - test: "Tap 'a', 'q', 'p', 'm', '1', '0' edge keys on physical device"
    expected: "Haptic feedback and popup fire immediately on touchDown (finger contact), not on touchUp."
    why_human: "UIWindow gesture delay override cannot be validated in simulator; requires device."
  - test: "Hold backspace for several seconds"
    expected: "Deletion starts at ~2chars/sec, accelerates to ~5chars/sec, then switches to word-level deletion after ~10 chars."
    why_human: "Timer acceleration stages and feel require physical device testing."
  - test: "Long-press spacebar then drag left/right"
    expected: "Keyboard dims; dragging moves cursor character-by-character with haptic tick per position."
    why_human: "LongPressCursorMovementController dead zone and haptic require live touch events."
  - test: "Type 'e' then observe accent key label, tap accent key"
    expected: "Accent key shows 'e' (or e-acute). Tapping replaces 'e' with the accented version."
    why_human: "Label update cycle via updateAccentKeyLabel and replace behavior require live text proxy."
  - test: "Type a consonant ('l', 't', etc.) then observe accent key label, tap accent key"
    expected: "Accent key shows apostrophe \"'\". Tapping inserts an apostrophe."
    why_human: "Adaptive branching in handleAdaptiveAccentKey requires live lastInsertedCharacter state."
---

# Phase 19: Complex Touch Features Verification Report

**Phase Goal:** Users have access to all advanced touch interactions -- delete repeat, spacebar trackpad, accent selection, and adaptive accent key
**Verified:** 2026-03-28T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                   | Status      | Evidence                                                                              |
|----|-----------------------------------------------------------------------------------------|-------------|---------------------------------------------------------------------------------------|
| 1  | User can hold backspace and characters delete with accelerating repeat speed            | VERIFIED    | `deleteRepeatCount`, `wordModeThreshold=10`, 3-stage timer in `increaseKeyRepeatRateIfNeeded` (KeyboardView.swift:444,763) |
| 2  | User can long-press vowels to see French accent characters and drag to select one       | VERIFIED    | `frenchLongPress` wired to `AccentedCharacters.mappings`, case-insensitive lookup with `key.lowercased()`, uppercase transformation for shifted page (FrenchKeyboardLayouts.swift:188, KeyboardView.swift:774) |
| 3  | User can drag the spacebar to move the cursor with haptic ticks at each character       | VERIFIED    | `LongPressCursorMovementController` with `deadZone=8.0`, `baseDelta=12.0`, `minMoveInterval`, `HapticFeedback.trackpadActivated()` (LongPressController.swift:36-115) |
| 4  | User sees adaptive accent key that shows apostrophe after consonants, accent after vowels | VERIFIED  | `alternate: "accent"` sentinel in AZERTY row 3, `handleAdaptiveAccentKey()` routes via `AccentedCharacters.adaptiveKeyLabel` and `shouldReplace` (FrenchKeyboardLayouts.swift:74,90; DictusKeyboardBridge.swift:64,280) |
| 5  | Double-space inserts a period followed by a space                                       | VERIFIED    | `handleAutoFullStop()` checks `text.hasSuffix(" ")` (not the broken `suffix(2)=="  "`) before inserting ". " (DictusKeyboardBridge.swift:402,409) |
| 6  | Edge keys produce haptic feedback and popup on touchDown, not touchUp                   | VERIFIED    | `clampedPoint()` replaces nil-returning `indexPathForItem`, `disableWindowGestureDelay()` sets `delaysTouchesBegan=false` on UIWindow gesture recognizers (KeyboardView.swift:581, KeyboardViewController.swift:150,301) |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DictusKeyboard/FrenchKeyboardLayouts.swift` | French accent data from AccentedCharacters.mappings | VERIFIED | Line 188: computed property iterates `AccentedCharacters.mappings`; lines 74,90: `alternate: "accent"` sentinel in AZERTY normal and shifted row 3 |
| `DictusKeyboard/DictusKeyboardBridge.swift` | Fixed double-space, lastInsertedCharacter, word delete, adaptive accent key | VERIFIED | `hasSuffix(" ")` at line 409; `lastInsertedCharacter` at line 57; `handleWordDelete()` at line 205; `handleAdaptiveAccentKey()` at line 280 |
| `DictusKeyboard/Vendored/Views/KeyboardView.swift` | Point clamping for edge keys, delete acceleration, accent key label update | VERIFIED | `clampedPoint()` at line 581; `deleteRepeatCount` at line 444; `updateAccentKeyLabel()` at line 169; `accentKeyLabel` at line 158 |
| `DictusKeyboard/Vendored/Controllers/LongPressController.swift` | Enhanced trackpad with dead zone, acceleration, haptic, rate limiter | VERIFIED | `deadZone=8.0` at line 36; `baseDelta=12.0` at line 40; `minMoveInterval` at line 57; `HapticFeedback.trackpadActivated()` at line 77 |
| `DictusKeyboard/KeyboardViewController.swift` | UIWindow gesture delay override | VERIFIED | `disableWindowGestureDelay()` called in `viewWillAppear` (line 150); implementation sets `delaysTouchesBegan=false` on window gesture recognizers (lines 301-326) |
| `DictusCore/Sources/DictusCore/AccentedCharacters.swift` | mappings, adaptiveKeyLabel, shouldReplace | VERIFIED | All three static members present: `mappings` at line 15, `adaptiveKeyLabel` at line 57, `shouldReplace` at line 71 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `FrenchKeyboardLayouts.swift` | `DictusCore/AccentedCharacters.swift` | `AccentedCharacters.mappings` | WIRED | Line 190: `for (baseKey, accents) in AccentedCharacters.mappings` populates `frenchLongPress` |
| `KeyboardView.swift` | touch handling | `clampedPoint()` in handleTouches, touchesMoved, touchesFoundLongpress | WIRED | Lines 532, 618, 688 all call `clampedPoint()` before `indexPathForItem` lookup |
| `KeyboardView.swift` | `DictusKeyboardBridge.swift` | `delegate?.didTriggerHoldKey` for word-level delete | WIRED | Line 742: `delegate?.didTriggerHoldKey(activeKey.key)` when `deleteRepeatCount > wordModeThreshold` |
| `LongPressController.swift` | `DictusKeyboardBridge.swift` | `delegate?.longpress(movedCursor:)` for cursor movement | WIRED | Line 100: `delegate?.longpress(movedCursor: charsToMove)` with accumulated movement |
| `DictusKeyboardBridge.swift` | `AccentedCharacters.swift` | `adaptiveKeyLabel` and `shouldReplace` | WIRED | Lines 283,285: both methods called in `handleAdaptiveAccentKey()`; line 310: called in `updateAccentKeyDisplay()` |
| `FrenchKeyboardLayouts.swift` | `KeyboardView.swift` | `alternate: "accent"` sentinel routing | WIRED | DictusKeyboardBridge line 64 checks `alternate == "accent"`; KeyboardView line 865 reads `accentKeyLabel` in `cellForItemAt` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| KBD-05 | 19-02-PLAN.md | User can delete characters with backspace, with accelerating repeat on hold | SATISFIED | `deleteRepeatCount`, 3-stage timer, `handleWordDelete()` wired via `didTriggerHoldKey` |
| KBD-08 | 19-01-PLAN.md | User gets double-space period insertion | SATISFIED | `handleAutoFullStop()` uses `hasSuffix(" ")` — the correct single-space check before second space |
| FEEL-04 | 19-01-PLAN.md | User can long-press vowels to access French accent characters with drag-to-select | SATISFIED | `AccentedCharacters.mappings` wired, case-insensitive lookup, uppercase transform for shifted page |
| FEEL-05 | 19-02-PLAN.md | User can drag spacebar to move cursor (trackpad) with haptic ticks | SATISFIED | Enhanced `LongPressCursorMovementController` with dead zone, accumulated movement, `HapticFeedback.trackpadActivated()` |
| FEEL-06 | 19-03-PLAN.md | User sees adaptive accent key (apostrophe after consonants, accent after vowels) | SATISFIED | `alternate: "accent"` in AZERTY row 3, `handleAdaptiveAccentKey()`, `updateAccentKeyDisplay()` called after every keystroke |

No orphaned requirements — all 5 IDs declared across plans and all covered in REQUIREMENTS.md.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `DictusKeyboard/Vendored/Views/KeyboardView.swift` | 763 | Stale comment: "speed up to 0.05s" but code uses `0.1` | Info | Comment was not updated when UAT tuned the stage 3 timer from 0.05 to 0.1 (UAT commit `03ab852`). Behavior is correct — the comment is wrong. |

### Build Verification

Build result: **BUILD SUCCEEDED** (zero errors, zero warnings blocking compilation).

### Human Verification Required

The following features were already human-tested on physical device during Plan 03 Task 2 (UAT). The device verification gate in Plan 03 was blocking and was marked complete. These items are listed for confirmation rather than as unverified gaps.

**1. French accent long-press (vowels + c, y, n)**

**Test:** Long-press "e", "a", "u", "i", "o", "c" on AZERTY normal page. Then shift and long-press "E".
**Expected:** Popup shows accented variants. Drag-to-select works. Shifted page shows uppercase accents.
**Why human:** CollectionView popup rendering and drag gesture tracking require live device.

**2. Double-space period**

**Test:** Type "hello" then press space twice quickly.
**Expected:** Result is "hello. " (period + space), not "hello  " (two spaces).
**Why human:** `textDocumentProxy.documentContextBeforeInput` behavior may vary per text field type.

**3. Edge key touchDown immediacy**

**Test:** Tap "a" (far left), "q", "p" (far right), "m" on AZERTY.
**Expected:** Haptic and popup fire the instant the finger contacts the screen.
**Why human:** UIWindow `delaysTouchesBegan=false` override cannot be confirmed in simulator; requires device with real touch hardware.

**4. Backspace hold acceleration**

**Test:** Type a long sentence, then hold backspace for 3+ seconds.
**Expected:** Slow character-by-character at first, accelerating to word-level deletion with haptic on each event.
**Why human:** Timer intervals (0.5s -> 0.2s -> 0.1s) and haptic feel require physical device.

**5. Spacebar trackpad**

**Test:** Long-press spacebar (~400ms), then drag left/right.
**Expected:** Keyboard dims to 0.4 alpha; cursor moves character-by-character with haptic tick; releases restore to full alpha.
**Why human:** Dead zone, accumulated movement precision, and alpha animation require live touch events.

**6. Adaptive accent key**

**Test:** Type "e" — observe accent key; tap it. Then type "l" — observe accent key; tap it.
**Expected:** After "e", key shows e-acute; tap replaces "e" with accented version. After "l", key shows "'"; tap inserts apostrophe.
**Why human:** `lastInsertedCharacter` tracking and label update cycle (cell reload) require live keyboard integration.

**7. Zero dead zones across all pages**

**Test:** Tap every key on AZERTY normal, shifted, and symbols pages, including all edge and corner keys.
**Expected:** Every key registers on first tap with no misses.
**Why human:** Dead zone presence is a tactile/visual observation requiring device.

### Note on UAT Completion

Plan 03 Task 2 was a blocking human-verify checkpoint. The summary documents that all 6 Phase 19 features were verified on physical device with zero dead zones, and 6 bug fixes were applied during that session. The verification above establishes automated evidence that all code changes are correct and wired. The human items above are listed for completeness — they correspond to the already-completed UAT gate.

---

_Verified: 2026-03-28T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
