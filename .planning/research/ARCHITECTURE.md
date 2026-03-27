# Architecture: giellakbd-ios Integration with Dictus Two-Process System

**Domain:** iOS keyboard extension rebuild from giellakbd-ios (Divvun) base
**Researched:** 2026-03-27
**Focus:** Integration points, component mapping, data flow, build order
**Overall Confidence:** HIGH (based on direct source code analysis of both codebases)

---

## Executive Summary

The giellakbd-ios keyboard uses a UICollectionView with disabled interaction and direct `touchesBegan/Moved/Ended` interception on the parent UIView. This approach eliminates dead zones because touch hit-testing happens at the UIView level (where `point(inside:with:)` works) rather than relying on UICollectionView's internal gesture recognizers or SwiftUI's layout-bound hit areas. The Dictus two-process architecture (Darwin notifications, App Group IPC, KeyboardState observer, recording overlay) is entirely orthogonal to the key rendering layer and integrates cleanly by replacing only the keyboard grid while keeping all dictation infrastructure intact.

---

## Current Dictus Keyboard Architecture

```
KeyboardViewController (UIInputViewController)
  |
  +-- KeyboardInputView (UIInputView + audio feedback)
       |
       +-- UIHostingController<KeyboardRootView> (SwiftUI bridge)
            |
            +-- KeyboardRootView (SwiftUI)
                 |
                 +-- if recording: RecordingOverlay
                 |
                 +-- else:
                      +-- ToolbarView (mic pill, suggestion bar, gear)
                      +-- KeyboardView (SwiftUI VStack of KeyRows)
                      |    +-- KeyRow (HStack of key views)
                      |    |    +-- KeyButton (DragGesture touch handling)
                      |    |    +-- ShiftKey, DeleteKey, SpaceKey, etc.
                      |    +-- Dead zone catch-all gesture (PARTIALLY WORKING)
                      +-- EmojiPickerView (when emoji mode active)
```

**Problem:** SwiftUI DragGesture hit areas are clipped to layout bounds. 16 approaches failed to extend touch areas beyond view bounds. Dead zones persist between keys.

---

## giellakbd-ios Architecture (Source Analysis)

```
KeyboardViewController (UIInputViewController)
  |
  +-- keyboardContainer (UIView)
       |
       +-- BannerManager (suggestion/spell banner - UIView above keyboard)
       |
       +-- KeyboardView (UIView - OWNS ALL TOUCH HANDLING)
            |
            +-- UICollectionView (isUserInteractionEnabled = false)
            |    +-- KeyView cells (visual rendering only, no touch)
            |
            +-- touchesBegan/Moved/Ended on KeyboardView itself
            |    +-- collectionView.indexPathForItem(at:) to find touched key
            |    +-- activeKey tracking for highlight state
            |    +-- swipe gesture detection in touchesMoved
            |
            +-- UILongPressGestureRecognizer
                 +-- LongPressOverlayController (accent popup)
                 +-- LongPressCursorMovementController (spacebar trackpad)
```

**Key insight:** The UICollectionView is a **rendering engine only**. All touch handling is done by the parent KeyboardView via `touchesBegan/Moved/Ended`. Since these are UIView-level methods, `point(inside:with:)` with negative insets can extend touch areas beyond visual bounds -- solving dead zones.

### giellakbd-ios Key Components

| Component | Role | Dictus Equivalent |
|-----------|------|-------------------|
| `KeyboardView` (UIView) | Key grid + touch dispatcher | `KeyboardView.swift` (SwiftUI) |
| `KeyView` (UIView cell) | Visual key rendering | `KeyButton.swift`, `SpecialKeyButton.swift` |
| `KeyDefinition` (model) | Key type + size | `KeyDefinition.swift` (very similar) |
| `KeyboardDefinition` (model) | Layout pages (normal/shifted/symbols1/2) | `KeyboardLayout.swift` |
| `LongPressController` | Accent popup + cursor trackpad | `AccentPopup.swift` + `SpaceKey` trackpad |
| `BannerManager` | Spell suggestion banner | `ToolbarView` + `SuggestionBarView` |
| `DeadKeyHandler` | Diacritical composition | `AccentedCharacters.swift` (DictusCore) |
| `Theme` | Colors, appearance | `KeyMetrics`, `DictusColors` |
| `KeyboardHeightProvider` | Device-adaptive height | `computeKeyboardHeight()` in KBViewController |
| `Audio.swift` | Key click sounds | `KeySound` enum + AudioServicesPlaySystemSound |

---

## Integration Architecture (Proposed)

```
KeyboardViewController (UIInputViewController) ........... KEEP (modify)
  |
  +-- KeyboardInputView (UIInputView + audio feedback) ... KEEP
       |
       +-- DictusKeyboardView (NEW UIView) ............... REPLACES SwiftUI keyboard grid
       |    |
       |    +-- UICollectionView (rendering only) ........ FROM giellakbd-ios
       |    |    +-- DictusKeyCell (UICollectionViewCell).. ADAPTED from giellakbd-ios KeyView
       |    |
       |    +-- touchesBegan/Moved/Ended ................. FROM giellakbd-ios
       |    +-- Long-press accent overlay ................ ADAPTED from giellakbd-ios
       |    +-- Spacebar trackpad handling ............... PORTED from SpaceKey
       |    +-- Delete repeat timer ...................... PORTED from DeleteKey
       |
       +-- UIHostingController<KeyboardChrome> (SwiftUI).. SLIMMED DOWN
            |
            +-- KeyboardChrome (NEW SwiftUI view) ........ Toolbar + overlay wrapper
                 |
                 +-- if recording: RecordingOverlay ...... KEEP AS-IS
                 +-- else:
                      +-- ToolbarView .................... KEEP AS-IS
                      +-- Color.clear spacer ............. Placeholder for UIKit keyboard area
                      +-- EmojiPickerView ................ KEEP AS-IS (shown/hidden)
```

### Why This Split

The giellakbd-ios touch system requires UIView-level touch methods (`touchesBegan` etc.). These cannot coexist with SwiftUI's gesture system in the same view hierarchy without conflicts. The solution: **UIKit owns the keyboard grid, SwiftUI owns everything else** (toolbar, recording overlay, emoji picker).

This matches the Phase 15.5 conclusion: "Only keyboard keys change -- ToolbarView, RecordingOverlay, EmojiPicker, KeyboardState, dictation, waveform all stay SwiftUI."

### Component Boundary

```
+------------------------------------------------------------------+
|  KeyboardInputView (UIInputView)                                  |
|                                                                    |
|  +--------------------------+  +-------------------------------+  |
|  | DictusKeyboardView       |  | UIHostingController           |  |
|  | (100% UIKit)             |  | (SwiftUI chrome)              |  |
|  |                          |  |                               |  |
|  | - Key grid rendering     |  | - ToolbarView (mic, suggest)  |  |
|  | - Touch hit-testing      |  | - RecordingOverlay            |  |
|  | - Accent popup overlay   |  | - EmojiPickerView             |  |
|  | - Spacebar trackpad      |  | - FullAccessBanner            |  |
|  | - Delete repeat          |  |                               |  |
|  | - Shift state visual     |  | Observes: KeyboardState       |  |
|  |                          |  | Observes: KeyboardTouchState   |  |
|  +--------------------------+  +-------------------------------+  |
|                                                                    |
|  Shared via protocols/delegates:                                   |
|  - KeyboardActionDelegate (character, delete, space, return...)    |
|  - KeyboardStateProvider (shift, layer, last typed char)           |
+------------------------------------------------------------------+
```

---

## Integration Points (Detailed)

### 1. KeyboardViewController Setup (MODIFY)

**Current:** Creates UIHostingController with KeyboardRootView, adds as child.
**New:** Creates DictusKeyboardView (UIKit) AND UIHostingController (slimmed SwiftUI). Both are subviews of KeyboardInputView. Z-order: UIKit keyboard behind, SwiftUI chrome in front.

```
// Pseudocode for new viewDidLoad
let kbInputView = KeyboardInputView(...)

// 1. UIKit keyboard grid (behind)
let keyboardGrid = DictusKeyboardView(delegate: self)
kbInputView.addSubview(keyboardGrid)
// Pin to bottom, height = keyboard rows area

// 2. SwiftUI chrome (in front, transparent over keyboard area)
let chrome = KeyboardChrome(controller: self, ...)
let hosting = UIHostingController(rootView: chrome)
kbInputView.addSubview(hosting.view)
// Pin to all edges, keyboard area is Color.clear
```

**Height management:** KeyboardInputView height constraint stays. DictusKeyboardView height = rows area only. SwiftUI chrome occupies full height but is transparent over the grid area.

### 2. Touch Flow (NEW)

**Current:** SwiftUI DragGesture per key -> callback chain -> KeyboardView -> KeyboardRootView.
**New:** UIView touchesBegan on DictusKeyboardView -> identify key via collectionView.indexPathForItem(at:) -> delegate callback to KeyboardViewController -> forwards to KeyboardState for IPC actions.

```
Touch flow:
  User finger -> DictusKeyboardView.touchesBegan
    -> collectionView.indexPathForItem(at: touchPoint)
    -> keyDefinition = layout[section][item]
    -> switch keyDefinition.type:
         .character -> delegate.didTapCharacter("a")
         .shift     -> delegate.didTapShift()
         .delete    -> delegate.didTapDelete()
         .space     -> delegate.didTapSpace()
         .return    -> delegate.didTapReturn()
         .globe     -> delegate.didTapGlobe()
         .emoji     -> delegate.didTapEmoji()
         .layerSwitch -> delegate.didTapLayerSwitch()
         .accentAdaptive -> delegate.didTapAccent(char)
```

### 3. KeyboardState (NO CHANGE)

KeyboardState remains the cross-process observer singleton. It does not care how keys are rendered. It:
- Triggers recording via Darwin notifications (startRecording, requestStop, requestCancel)
- Observes dictation status changes
- Auto-inserts transcription via textDocumentProxy
- Manages the watchdog timer

**Zero modifications needed.** The UIKit keyboard calls the same delegate methods that currently flow through SwiftUI callbacks.

### 4. Recording Overlay (MINIMAL CHANGE)

**Current:** KeyboardRootView conditionally renders RecordingOverlay OR KeyboardView.
**New:** KeyboardChrome (SwiftUI) conditionally renders RecordingOverlay (full area) OR ToolbarView + transparent spacer. When recording, DictusKeyboardView.isHidden = true.

```swift
// In KeyboardChrome
if showsOverlay {
    RecordingOverlay(...)  // Full height, covers everything
} else {
    ToolbarView(...)
    Color.clear  // Transparent spacer over UIKit grid
        .allowsHitTesting(false)
        .frame(height: keyboardGridHeight)
}
```

DictusKeyboardView visibility is toggled by the KeyboardViewController based on dictation status:
```swift
keyboardGrid.isHidden = (state.dictationStatus != .idle && state.dictationStatus != .ready)
```

### 5. Suggestion Bar / Toolbar (NO CHANGE)

ToolbarView + SuggestionBarView stay in SwiftUI. They live above the keyboard grid and have no touch conflict. The mic button still triggers `KeyboardState.shared.startRecording()`.

TextPredictionEngine + SuggestionState continue to be updated from the keyboard action delegate (same flow, different caller -- UIKit delegate instead of SwiftUI closure).

### 6. Emoji Picker (MINIMAL CHANGE)

EmojiPickerView stays SwiftUI. When emoji mode activates:
1. DictusKeyboardView.isHidden = true
2. SwiftUI chrome shows EmojiPickerView instead of transparent spacer
3. On dismiss: DictusKeyboardView.isHidden = false

### 7. Haptic + Audio Feedback (NO CHANGE)

HapticFeedback (DictusCore) and AudioServicesPlaySystemSound work identically from UIKit. The existing pre-allocated generators, touchDown timing, and 3-sound categories (letter/delete/modifier) are called from DictusKeyboardView's touch handlers instead of SwiftUI gesture handlers.

### 8. Accent System (ADAPT)

**Current Dictus:** Long-press timer in KeyButton (400ms Task.sleep), AccentPopup as SwiftUI overlay.
**giellakbd-ios:** UILongPressGestureRecognizer + LongPressOverlayController with UICollectionView popup.
**Recommended:** Use giellakbd-ios approach (UIKit accent popup) because it participates in the same touch handling chain. The accent popup is a UIView overlay on DictusKeyboardView, positioned relative to the pressed key cell.

AccentedCharacters.swift (DictusCore) provides the accent data -- no change. The adaptive accent key behavior (vowel context, apostrophe default) is Dictus-specific and must be ported into the UIKit layer.

### 9. Spacebar Trackpad (ADAPT)

**Current Dictus:** SpaceKey with DragGesture, 400ms activation, cosine acceleration, dead zone, 60fps rate limiting.
**giellakbd-ios:** LongPressCursorMovementController with 20pt delta threshold.
**Recommended:** Use giellakbd-ios's long-press detection mechanism but port Dictus's superior trackpad tuning (cosine acceleration curve, 8pt dead zone, haptic ticks per character). The giellakbd-ios approach uses `touchesMoved` delta tracking which is more precise than SwiftUI DragGesture for sub-pixel movements.

### 10. Key Metrics / Layout (ADAPT)

**Current Dictus:** KeyMetrics enum (device-adaptive heights), KeyboardLayout (static arrays of KeyDefinition).
**giellakbd-ios:** KeyboardHeightProvider (screen-diagonal lookup), KeyboardDefinition (JSON-loaded layouts).

**Recommended:** Keep Dictus's KeyMetrics (simpler, already tuned for Dictus device classes) and KeyboardLayout (hardcoded AZERTY/QWERTY, no need for JSON). Adapt giellakbd-ios's row/column sizing formula for the UICollectionView cell layout:
```
cellWidth = key.size.width * (boundsWidth / rowTotalUnits)
cellHeight = boundsHeight / numberOfRows
```

---

## Data Flow Changes

### Before (SwiftUI-only)

```
User touch -> SwiftUI DragGesture.onChanged
  -> KeyButton.handleTouchDown() [haptic + audio]
  -> DragGesture.onEnded
  -> KeyButton.handleTouchUp()
  -> onTap(char) closure
  -> KeyRow.onCharacter(char)
  -> KeyboardView.insertCharacter(char)
  -> controller.textDocumentProxy.insertText(char)
  -> suggestionState.updateAsync()
```

### After (UIKit grid + SwiftUI chrome)

```
User touch -> DictusKeyboardView.touchesBegan
  -> collectionView.indexPathForItem(at:) [find key]
  -> highlight cell, play haptic + audio
  -> DictusKeyboardView.touchesEnded
  -> delegate.didTapCharacter(char)
  -> KeyboardViewController.didTapCharacter(char)
  -> textDocumentProxy.insertText(char)
  -> suggestionState.updateAsync()
```

**Net change:** The touch entry point moves from SwiftUI gesture to UIView touch methods. Everything downstream (textDocumentProxy, suggestion engine, dictation IPC) is unchanged.

### IPC Flow (NO CHANGE)

```
Keyboard mic tap -> KeyboardState.startRecording()
  -> Darwin notification + 500ms URL fallback
  -> DictusApp records in background
  -> Darwin notifications for status updates
  -> KeyboardState.refreshFromDefaults()
  -> RecordingOverlay shows/hides (SwiftUI)
  -> Transcription auto-inserted via textDocumentProxy
```

This flow is completely independent of how keys are rendered.

---

## New Components to Create

| File | Type | Source | Purpose |
|------|------|--------|---------|
| `DictusKeyboardView.swift` | UIView | **Adapted** from giellakbd-ios KeyboardView | Key grid + touch dispatcher |
| `DictusKeyCell.swift` | UICollectionViewCell | **Adapted** from giellakbd-ios KeyView | Visual key rendering |
| `KeyboardActionDelegate.swift` | Protocol | **New** | Bridge UIKit actions to ViewController |
| `KeyboardChrome.swift` | SwiftUI View | **Refactored** from KeyboardRootView | Toolbar + overlay wrapper |
| `AccentOverlayView.swift` | UIView | **Adapted** from giellakbd-ios LongPressOverlayController | UIKit accent popup |
| `TrackpadController.swift` | Class | **Ported** from SpaceKey + giellakbd-ios LongPressCursorMovementController | Spacebar trackpad |

## Existing Components to Modify

| File | Change | Scope |
|------|--------|-------|
| `KeyboardViewController.swift` | New viewDidLoad layout (UIKit + SwiftUI side-by-side), implement KeyboardActionDelegate | Medium |
| `KeyboardRootView.swift` | **Replace** with KeyboardChrome (thinner: toolbar + overlay only, no keyboard grid) | Medium |
| `InputView.swift` | Add hitTest override to route touches to UIKit grid vs SwiftUI chrome | Small |

## Existing Components Unchanged

| File | Why No Change |
|------|---------------|
| `KeyboardState.swift` | IPC layer, orthogonal to rendering |
| `ToolbarView.swift` | Stays SwiftUI, above grid |
| `RecordingOverlay.swift` | Stays SwiftUI, replaces grid when active |
| `SuggestionBarView.swift` | Stays SwiftUI, inside ToolbarView |
| `EmojiPickerView.swift` | Stays SwiftUI, replaces grid when active |
| `EmojiCategoryBar.swift` | Part of emoji picker |
| `EmojiData.swift`, `EmojiSearchFR.swift`, `RecentEmojis.swift` | Data models |
| `TextPredictionEngine.swift`, `SuggestionState.swift` | Prediction logic, called from delegate |
| `KeyTapSignposter.swift` | Performance instrumentation, works from UIKit |
| `KeyboardWaveformView.swift` | Part of recording overlay |
| `MicButtonDisabled.swift`, `FullAccessBanner.swift` | UI components in SwiftUI chrome |
| All DictusCore files | Shared framework, no rendering code |

## Components to Delete (after migration)

| File | Reason |
|------|--------|
| `KeyButton.swift` | Replaced by DictusKeyCell |
| `KeyRow.swift` | Replaced by UICollectionView rows |
| `KeyboardView.swift` | Replaced by DictusKeyboardView |
| `SpecialKeyButton.swift` | Special keys rendered by DictusKeyCell + touch handler |
| `AccentPopup.swift` | Replaced by AccentOverlayView (UIKit) |

---

## Suggested Build Order

Build order is driven by dependencies: the UIKit grid must exist before features can be layered on top.

### Phase 1: Skeleton Grid (Foundation)

**Goal:** UIKit keyboard grid renders keys and responds to taps. No features, just character insertion.

1. **DictusKeyboardView** -- UICollectionView setup, layout delegate, cell sizing from KeyboardLayout data
2. **DictusKeyCell** -- Render key label (text or SF Symbol), background, press highlight
3. **KeyboardActionDelegate** protocol -- didTapCharacter, didTapDelete, didTapSpace, didTapReturn, didTapShift, didTapGlobe, didTapLayerSwitch, didTapEmoji, didTapAccent
4. **KeyboardViewController** -- New viewDidLoad with UIKit grid + SwiftUI chrome
5. **KeyboardChrome** -- Slimmed SwiftUI wrapper (toolbar + overlay + emoji mode)
6. **InputView hitTest** -- Route keyboard area touches to UIKit, toolbar/overlay to SwiftUI

**Validation:** Type characters in any text field. Keys highlight on touch. No dead zones between keys.

### Phase 2: Touch Polish (Native Feel)

**Goal:** Match Apple keyboard feel -- haptic on touchDown, 3-sound categories, key popup preview.

7. **touchDown haptic + audio** -- Fire in touchesBegan (not touchesEnded)
8. **Key popup preview** -- UIView overlay above pressed key (replaces SwiftUI KeyPopup)
9. **Shift state** -- Single tap shift, double-tap caps lock, visual icon updates
10. **Layer switching** -- 123/ABC/#+= transitions with UICollectionView reloadData

**Validation:** Typing feels identical to v1.2. All shift states work. Layer switching works.

### Phase 3: Complex Touch Features

**Goal:** Port Dictus-specific touch features that go beyond basic key taps.

11. **Delete repeat** -- touchDown immediate delete, 400ms delay, 100ms repeat, word-mode acceleration after 10 chars
12. **Spacebar trackpad** -- 400ms long-press activation, cosine acceleration, 8pt dead zone, haptic ticks, 60fps rate limit
13. **Accent long-press** -- AccentOverlayView (UIKit popup), 400ms timer, drag-to-select, accent data from AccentedCharacters.swift
14. **Adaptive accent key** -- Context-sensitive apostrophe/accent based on last typed char

**Validation:** Long-press "e" shows accent popup. Delete accelerates. Spacebar trackpad moves cursor.

### Phase 4: Dictus Feature Reintegration

**Goal:** Reconnect all Dictus-specific features to the new UIKit grid.

15. **Recording overlay** -- Toggle DictusKeyboardView.isHidden on dictation status changes
16. **Suggestion bar** -- Wire SuggestionState.updateAsync() from KeyboardActionDelegate callbacks
17. **Autocorrect** -- Space tap triggers performAutocorrectIfNeeded() before insertion
18. **Autocapitalize** -- Check sentence boundaries after space, return, delete
19. **Emoji mode** -- Hide UIKit grid, show SwiftUI EmojiPickerView, restore on dismiss
20. **Dead zone elimination** -- Verify with point(inside:with:) negative insets on DictusKeyboardView or cells

**Validation:** Full dictation flow works (mic -> recording -> transcription insert). Suggestions appear. Autocorrect undo works. Emoji picker works.

### Phase 5: Cleanup

21. **Delete old SwiftUI keyboard files** -- KeyButton, KeyRow, KeyboardView, SpecialKeyButton, AccentPopup
22. **Update KeyboardRootView** references -- Ensure KeyboardChrome is the sole SwiftUI entry point
23. **Signposter instrumentation** -- Wire KeyTapSignposter from UIKit touch handlers
24. **Regression testing** -- Full test pass against v1.2 feature set

---

## Scalability Considerations

| Concern | Impact | Notes |
|---------|--------|-------|
| Memory (~50MB limit) | UICollectionView uses less memory than SwiftUI VStack (cell reuse) | Positive change |
| Key count | 10 keys/row * 4 rows = 40 cells max | Well within UICollectionView comfort zone |
| Layout changes | reloadData() is O(n) where n=~40 | Negligible, <1ms |
| Accent popup | UIView overlay, not SwiftUI rebuild | More predictable frame timing |
| Recording overlay | SwiftUI conditional still works | No change in memory pattern |
| Theme/dark mode | UICollectionView cells update via traitCollectionDidChange | Standard UIKit pattern |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mixing UIKit touches with SwiftUI gestures in same region
**What:** Adding SwiftUI gesture recognizers that overlap with UIKit touch area.
**Why bad:** UIKit and SwiftUI gesture systems fight for touch ownership, causing dropped touches.
**Instead:** Clean boundary -- UIKit owns keyboard grid touch area, SwiftUI owns everything above.

### Anti-Pattern 2: Using UIStackView for key rows
**What:** Previous Phase 15.5 attempt used UIStackView, which bypasses point(inside:with:).
**Why bad:** UIStackView.hitTest uses subview.frame.contains(point), never calls point(inside:with:) on subviews.
**Instead:** UICollectionView with custom layout, or manual frame layout with overridden hitTest.

### Anti-Pattern 3: Bridging UIKit state to SwiftUI via @Published
**What:** Making DictusKeyboardView an ObservableObject with @Published properties for every key state.
**Why bad:** Causes full SwiftUI re-render on every touch event (60+ times/second during trackpad).
**Instead:** UIKit manages its own visual state. Only bridge layer/mode changes (infrequent) to SwiftUI via delegate.

### Anti-Pattern 4: Re-creating UICollectionView on layer switch
**What:** Destroying and recreating the collection view when switching letters/numbers/symbols.
**Why bad:** Expensive allocation + layout pass, visible flicker.
**Instead:** Call reloadData() with new layout data. Collection view cells update in-place.

---

## Sources

- [giellakbd-ios repository](https://github.com/divvun/giellakbd-ios) -- Full source code analysis (HIGH confidence)
- giellakbd-ios KeyboardView.swift -- UICollectionView + touchesBegan architecture (HIGH confidence)
- giellakbd-ios LongPressController.swift -- Accent popup + cursor movement (HIGH confidence)
- giellakbd-ios KeyboardViewController.swift -- Entry point, banner, delegate pattern (HIGH confidence)
- Dictus Phase 15.4 dead zones learnings (project memory) -- 16 failed SwiftUI approaches (HIGH confidence)
- Dictus Phase 15.5 UIKit keyboard attempt (project memory) -- UIStackView hitTest bypass discovery (HIGH confidence)
- Apple `point(inside:with:)` documentation -- UIView hit-testing extension mechanism (HIGH confidence)
