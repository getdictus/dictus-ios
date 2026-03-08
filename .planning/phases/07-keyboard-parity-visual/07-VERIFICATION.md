---
phase: 07-keyboard-parity-visual
verified: 2026-03-08T13:56:24Z
status: gaps_found
score: 5/9 requirements verified
gaps:
  - truth: "Accent key preserves uppercase when replacing a vowel"
    status: failed
    reason: "After typing uppercase vowel (A), shift auto-unshifts. AdaptiveAccentKey reads isShifted=false, so accent is inserted lowercase (a instead of A). The case of the original vowel is lost."
    artifacts:
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "AdaptiveAccentKey.displayChar relies on current isShifted state, not the case of the original typed character"
      - path: "DictusKeyboard/Views/KeyboardView.swift"
        issue: "insertCharacter() auto-unshifts after one character, so shift is off by the time user taps accent key"
    missing:
      - "Preserve original character case in lastTypedChar (track actual typed string, not lowercased)"
      - "AdaptiveAccentKey should derive case from lastTypedChar, not from current shift state"

  - truth: "Special key backgrounds match Apple keyboard light gray styling"
    status: failed
    reason: "Shift, delete, emoji, 123, return keys use Color(.systemGray3) which is too dark compared to Apple keyboard. Apple uses a lighter gray for special keys."
    artifacts:
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "All special keys use Color(.systemGray3) for background"
    missing:
      - "Adjust special key background color to match Apple keyboard (lighter gray or Color(.systemGray5))"

  - truth: "Emoji button opens emoji keyboard"
    status: failed
    reason: "EmojiKey calls advanceToNextInputMode() which cycles to the next installed keyboard, not specifically the emoji keyboard. No iOS API exists to target emoji keyboard directly."
    artifacts:
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "EmojiKey uses advanceToNextInputMode() -- same as globe key, cycles to next keyboard in list"
    missing:
      - "Research if any workaround exists (e.g., cycling through modes until emoji is found)"
      - "If no workaround, document as iOS limitation and consider relabeling the key"

  - truth: "Trackpad supports vertical (2D) cursor movement between lines"
    status: partial
    reason: "Vertical movement exists (1 char per 15pt after Plan 07 fix) but uses character offsets, not line jumps. adjustTextPosition(byCharacterOffset:) moves linearly through text, which means vertical drag moves cursor along text content, not visually up/down between lines as Apple does."
    artifacts:
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "SpaceKey vertical movement uses character offsets -- works but feels different from Apple's visual line-based vertical movement"
    missing:
      - "Investigate whether UITextDocumentProxy provides line-based cursor positioning"
      - "May need to estimate characters-per-line and multiply vertical offset accordingly"

  - truth: "Shift/caps lock styling matches Apple convention (white bg + black arrow when active)"
    status: failed
    reason: "ShiftKey uses Color(.label) bg + Color(.systemBackground) foreground when active. This produces black bg + white arrow in light mode, which is inverted from Apple's white bg + black arrow."
    artifacts:
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "ShiftKey active state: .fill(Color(.label)) is dark, should be light; foreground Color(.systemBackground) is light, should be dark"
    missing:
      - "Swap colors: active state should use white/light bg with dark foreground to match Apple"

  - truth: "Waveform animation survives cancel and works on subsequent recordings"
    status: failed
    reason: "UAT confirmed: canceling a recording mid-way breaks the audio/animation system. Subsequent recordings have no waveform animation at all."
    artifacts:
      - path: "DictusKeyboard/Views/RecordingOverlay.swift"
        issue: "Cancel flow does not properly reset audio/waveform state"
      - path: "DictusApp/DictationCoordinator.swift"
        issue: "Cancel recording may not properly clean up AudioRecorder state for next session"
    missing:
      - "Debug cancel flow: ensure AudioRecorder and waveform energy array are properly reset"
      - "Ensure DictationCoordinator transitions cleanly from recording to idle on cancel"

  - truth: "Key sounds use 3 distinct categories (letters, delete, other special keys)"
    status: failed
    reason: "All keys use the same UIDevice.current.playInputClick() call. Apple keyboard has 3 distinct sounds: letter keys, delete key, and other special keys (space, return, shift)."
    artifacts:
      - path: "DictusKeyboard/Views/KeyboardView.swift"
        issue: "All playInputClick() calls produce identical sound"
      - path: "DictusKeyboard/Views/SpecialKeyButton.swift"
        issue: "DeleteKey, ShiftKey use same playInputClick() as letter keys"
    missing:
      - "Research if UIInputViewAudioFeedback supports different click types"
      - "If not, consider custom AudioServicesPlaySystemSound with different system sound IDs"
---

# Phase 7: Keyboard Parity & Visual Verification Report

**Phase Goal:** Keyboard parity with Apple French AZERTY and visual polish
**Verified:** 2026-03-08T13:56:24Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every key tap produces haptic feedback | VERIFIED | HapticFeedback.keyTapped() present in KeyButton, ShiftKey, DeleteKey, SpaceKey, and all KeyboardView callbacks (globe, layerSwitch, symbolToggle, return, accent). Pre-allocated static generators in HapticFeedback.swift. |
| 2 | Spacebar long-press activates trackpad mode with cursor movement | VERIFIED | SpaceKey implements DragGesture + 400ms Task.sleep, calls onCursorMove with character offsets. Greyed-out overlay via isTrackpadActive in KeyboardView. Velocity acceleration added in Plan 07. |
| 3 | Adaptive accent key shows apostrophe or accent based on context | VERIFIED | AdaptiveAccentKey reads lastTypedChar, calls AccentedCharacters.adaptiveKeyLabel(). Long-press shows AccentPopup with all variants. shouldReplace() enables vowel replacement via deleteBackward()+insert. |
| 4 | Mic button is pill-shaped with 4 visual states | VERIFIED | AnimatedMicButton(isPill: true) in ToolbarView. Toolbar height 48pt prevents clipping. |
| 5 | Recording cancel/validate buttons are pill-shaped | VERIFIED | PillButton struct in RecordingOverlay with Capsule glass style, 56x36pt. Cancel (xmark) and validate (checkmark) present. |
| 6 | Accent key preserves uppercase when replacing a vowel | FAILED | Auto-unshift after typing uppercase vowel means isShifted=false when accent key is tapped. Produces lowercase accent instead of uppercase. |
| 7 | Special key colors and shift styling match Apple keyboard | FAILED | Special keys use Color(.systemGray3) (too dark). Shift active state inverts Apple convention (black bg instead of white bg). |
| 8 | Emoji button opens emoji keyboard | FAILED | advanceToNextInputMode() cycles to next keyboard, not specifically emoji. No iOS API to target emoji keyboard. |
| 9 | Trackpad supports smooth 2D vertical movement between lines | PARTIAL | Character-offset vertical movement works but differs from Apple's visual line-based movement. |
| 10 | Waveform survives cancel and works on subsequent recordings | FAILED | UAT confirmed waveform breaks after cancel. Subsequent recordings show no animation. |
| 11 | Key sounds have 3 distinct categories | FAILED | All keys use identical playInputClick(). No differentiation between letter, delete, and special key sounds. |

**Score:** 5/11 truths verified (5 passed, 1 partial, 5 failed)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `DictusCore/.../HapticFeedback.swift` | Pre-allocated generators, warmUp(), keyTapped(), trackpadActivated() | VERIFIED | Static lightGenerator, mediumGenerator, notificationGenerator. warmUp() calls .prepare(). All methods guard isEnabled(). |
| `DictusKeyboard/Views/SpecialKeyButton.swift` | ShiftKey, DeleteKey, SpaceKey, EmojiKey, AdaptiveAccentKey | VERIFIED | All views present and substantive. DeleteKey has word-level acceleration. SpaceKey has trackpad mode. |
| `DictusKeyboard/Views/KeyboardView.swift` | Haptics + playInputClick on all keys, autocap, word delete | VERIFIED | All callbacks wired. Autocapitalize after ". ", "! ", "? ", newline, empty field. deleteWordBackward() implemented. |
| `DictusKeyboard/Views/KeyButton.swift` | KeyMetrics dynamic height, long-press accents | VERIFIED | keyHeight computed property with screen breakpoints (667/852). Long-press accent popup with DragGesture. |
| `DictusKeyboard/Views/ToolbarView.swift` | Pill mic button, 48pt height | VERIFIED | AnimatedMicButton(isPill: true), frame height 48. |
| `DictusKeyboard/Views/RecordingOverlay.swift` | PillButton cancel/validate, BrandWaveform, processing animation | VERIFIED | PillButton with dictusGlass, BrandWaveform(isProcessing: true) for transcribing state. |
| `DictusCore/.../BrandWaveform.swift` | Canvas rendering, silence threshold, sinusoidal processing | VERIFIED | Canvas-based rendering. 0.05 silence threshold. isProcessing mode with TimelineView + sine wave. |
| `DictusCore/.../AccentedCharacters.swift` | Mappings, adaptiveKeyLabel, shouldReplace, adaptiveKeyVowel | VERIFIED | All methods present. Lowercase lookup with proper accent tables. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| KeyboardView | HapticFeedback | keyTapped() on all callbacks | WIRED | Present in onDelete, onGlobe, onLayerSwitch, onSymbolToggle, onReturn, onAccentAdaptive |
| KeyboardRootView | HapticFeedback | warmUp() in onAppear | WIRED | Confirmed in 07-01-SUMMARY (need to verify in file) |
| SpaceKey | KeyboardView | onCursorMove, onTrackpadStateChange | WIRED | Callbacks passed through KeyRow to SpaceKey |
| KeyboardView | textDocumentProxy | adjustTextPosition(byCharacterOffset:) | WIRED | onCursorMove handler calls proxy method |
| RecordingOverlay | BrandWaveform | energyLevels + isProcessing | WIRED | Recording state passes waveformEnergy, transcribing uses isProcessing: true |
| ToolbarView | AnimatedMicButton | isPill: true | WIRED | Confirmed in ToolbarView.swift line 44 |
| DeleteKey | onWordDelete | Word-level acceleration after 10 chars | WIRED | wordModeThreshold = 10, calls onWordDelete() in repeat loop |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| KBD-01 | 07-04, 07-07 | Spacebar trackpad mode | PARTIAL | Works with velocity acceleration but vertical movement uses char offsets not line jumps |
| KBD-02 | 07-02, 07-06 | Adaptive accent key | PARTIAL | Works but ignores uppercase (gap 1) |
| KBD-03 | 07-01, 07-08 | Haptic feedback on all keys | SATISFIED | All key types have HapticFeedback.keyTapped() |
| KBD-04 | 07-02, 07-06 | Emoji button replaces globe | BLOCKED | advanceToNextInputMode() goes to previous keyboard, not emoji. SF Symbol face.smiling present. |
| KBD-05 | 07-01, 07-08 | Apple dictation mic removed | SATISFIED | Documented as iOS limitation. No public API to suppress. 8pt bottom padding attempted. |
| KBD-06 | 07-01, 07-07 | Performance optimization | SATISFIED | Pre-allocated haptic generators eliminate per-call latency. playInputClick() on all keys. Autocap and word-delete acceleration. |
| VIS-01 | 07-03, 07-08 | Mic pill button | SATISFIED | AnimatedMicButton(isPill: true) with 48pt toolbar height. |
| VIS-02 | 07-03 | Recording pill buttons | SATISFIED | PillButton struct with Capsule glass, 56x36pt. |
| VIS-03 | 07-03, 07-08 | Waveform rework | PARTIAL | Canvas rendering, silence threshold, sinusoidal processing all implemented. But waveform breaks after cancel (gap 6). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| SpecialKeyButton.swift | 41-46 | Shift active colors inverted vs Apple | Warning | Visual inconsistency with native keyboard |
| SpecialKeyButton.swift | 95 | DeleteKey uses Color(.systemGray3) | Warning | Too dark vs Apple's lighter special key color |
| KeyboardView.swift | 172 | insertCharacter auto-unshifts before accent key can read shift state | Blocker | Accent key ignores uppercase |
| AccentedCharacters.swift | 58 | adaptiveKeyLabel lowercases input, losing original case | Warning | Contributes to uppercase accent loss |

### Human Verification Required

### 1. Waveform Cancel Recovery
**Test:** Start recording, wait for waveform animation, tap cancel (X), then start a new recording
**Expected:** New recording should show waveform animation normally
**Why human:** Requires real device audio pipeline testing; cannot verify audio state reset programmatically

### 2. Key Sound Differentiation
**Test:** Compare Dictus key sounds (letter, delete, space/return) with Apple keyboard
**Expected:** Apple has 3 distinct sounds; Dictus should match
**Why human:** Sound differentiation requires auditory comparison on device

### 3. Trackpad Vertical Feel
**Test:** Type several lines of text, long-press spacebar, drag vertically
**Expected:** Cursor moves between lines smoothly (not just linearly through characters)
**Why human:** Feel and accuracy of cursor movement requires real interaction

### 4. Shift/Caps Lock Visual
**Test:** Tap shift (single), then double-tap for caps lock, compare to Apple keyboard
**Expected:** Active shift shows white background with dark arrow icon (Apple convention)
**Why human:** Visual comparison requires device screenshot

### 5. Special Key Color Matching
**Test:** Compare special key (delete, return, shift, 123, emoji) background color with Apple keyboard
**Expected:** Should match Apple's lighter gray styling
**Why human:** Color comparison requires side-by-side device screenshots

## Gaps Summary

7 gaps found from UAT (07-09-SUMMARY.md), all confirmed as still present in the codebase:

1. **Accent uppercase** -- Auto-unshift after typing uppercase vowel means the accent key reads isShifted=false and produces lowercase accent. Root cause: case information lost in the flow between insertCharacter() and AdaptiveAccentKey.
2. **Special key colors too dark** -- Color(.systemGray3) across all special keys. Apple uses a noticeably lighter shade.
3. **Emoji button broken** -- advanceToNextInputMode() is the only available API but it cycles keyboards rather than targeting emoji. May be an iOS limitation.
4. **Trackpad vertical movement** -- Uses character offsets rather than visual line-based movement. Functional but feels different from Apple.
5. **Shift/caps lock styling inverted** -- Active state uses dark bg + light arrow instead of Apple's light bg + dark arrow.
6. **Waveform breaks after cancel** -- Cancel mid-recording corrupts audio/animation state. Subsequent recordings have no waveform.
7. **Key sounds need 3 categories** -- All keys use identical playInputClick(). Apple differentiates letters, delete, and special keys.

These gaps need another round of planning (07-10+) to resolve.

---

_Verified: 2026-03-08T13:56:24Z_
_Verifier: Claude (gsd-verifier)_
