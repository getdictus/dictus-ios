# Phase 20: Feature Reintegration - Research

**Researched:** 2026-03-30
**Domain:** iOS keyboard extension feature wiring (UIKit + SwiftUI hybrid)
**Confidence:** HIGH

## Summary

Phase 20 is a pure integration phase -- all code already exists. The work is wiring existing components (dictation, predictions, emoji picker, settings) into the Phase 18-19 UIKit keyboard architecture. No new libraries, no new architectural patterns. The risk is in the coordination between UIKit (GiellaKeyboardView) and SwiftUI (toolbar, overlays, emoji picker) components, not in any individual feature.

The primary integration point is `DictusKeyboardBridge`, which needs a `SuggestionState` reference to trigger prediction updates after each keystroke. Secondary integration points are: emoji button in `FrenchKeyboardLayouts`, emoji picker show/hide in `KeyboardViewController`, default layer setting in `viewWillAppear`, and post-transcription suggestion refresh in `KeyboardState.handleTranscriptionReady`.

**Primary recommendation:** Wire features incrementally -- predictions first (highest value, simplest integration), then dictation validation, then emoji button, then settings. Each feature should be validated on device before moving to the next.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- DictusKeyboardBridge gets a direct reference to SuggestionState (injected by KeyboardViewController)
- Bridge calls `suggestionState.updateAsync(context:)` after each keystroke (input, backspace, space, return)
- No NotificationCenter or Combine relay -- direct call from bridge for minimal latency
- Existing async coalescing (DispatchWorkItem cancel + background queue) handles rapid typing -- no extra debounce needed
- Autocorrect-on-space is ACTIVE: when user taps space, if current word is misspelled, auto-replace with best correction
- Undo-on-backspace: pressing backspace immediately after an autocorrection undoes it (restores original word)
- AutocorrectState struct already exists in SuggestionState -- wire it through the bridge
- Keep accent mode in suggestion bar: single vowel typed -> bar shows accented variants
- Three accent input methods coexist: suggestion bar accents, adaptive accent key (Phase 19), long-press accents (Phase 19)
- Full end-to-end dictation validation required (mic tap -> recording -> transcription -> text insert -> keyboard restore)
- After transcription is inserted, trigger SuggestionState update so bar shows completions for the last word
- Include UAT step to catch any regressions from Phase 19 touch pipeline changes
- Emoji button between 123 and spacebar: [123] [emoji] [SPACE] [RETURN]
- Tap emoji button -> hide GiellaKeyboardView -> show EmojiPickerView (SwiftUI) in same keyboard grid space
- Same show/hide pattern as recording overlay (toggle visibility, not destroy/recreate)
- Toolbar stays visible during emoji browsing (mic button accessible)
- ABC button in emoji picker returns to keyboard
- Keep mini search keyboard (French keywords) -- already built
- Default opening layer: read SharedKeys.defaultKeyboardLayer from App Group in viewWillAppear, set giellaKeyboard.page accordingly
- Verify ALL settings during UAT: haptic toggle, sound toggle, layout type, default layer, language preference

### Claude's Discretion
- How to inject SuggestionState reference into DictusKeyboardBridge (property injection vs init param)
- Emoji button key type in GiellaKeyboardView layout definition
- Emoji picker show/hide implementation details (hosting controller management)
- Post-transcription suggestion refresh timing
- UAT test case ordering and grouping

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DICT-01 | User can tap mic button in toolbar to start recording | Already wired: AnimatedMicButton in ToolbarView calls state.startRecording(). Validate end-to-end only. |
| DICT-02 | User sees recording overlay with waveform replacing keyboard during dictation | Already wired: RecordingOverlay in KeyboardRootView, giellaKeyboard.isHidden in handleDictationStatusChange. Validate only. |
| DICT-03 | User gets transcription auto-inserted at cursor after recording | Already wired: handleTranscriptionReady() in KeyboardState. Need to add post-insert SuggestionState update. |
| DICT-04 | User sees Full Access banner when permissions needed | Already wired: ToolbarView shows banner when hasFullAccess is false. Validate only. |
| PRED-01 | User sees 3-slot suggestion bar with French autocorrect suggestions | Wire SuggestionState into DictusKeyboardBridge. SuggestionBarView already renders in ToolbarView. |
| PRED-02 | User can tap suggestion to insert it | Already wired: handleSuggestionTap in KeyboardRootView. Validate that tapping inserts correctly. |
| PRED-03 | User can undo autocorrect by pressing backspace immediately after | Wire autocorrect-on-space in bridge handleSpace(). Wire undo in bridge handleBackspace(). |
| SET-01 | User can select default opening layer with live preview | Read DefaultKeyboardLayer.active in viewWillAppear, set giellaKeyboard.page. |
</phase_requirements>

## Architecture Patterns

### Current Architecture (Phase 18-19 Foundation)

```
KeyboardViewController (UIInputViewController)
  |
  +-- kbInputView (KeyboardInputView)
  |     +-- hostingController.view (SwiftUI: ToolbarView + RecordingOverlay)
  |     +-- giellaKeyboard (GiellaKeyboardView: UICollectionView UIKit keyboard)
  |
  +-- bridge (DictusKeyboardBridge: key event delegate)
  +-- hostingController (UIHostingController<KeyboardRootView>)
```

### Integration Pattern: Direct Property Injection

For the SuggestionState -> Bridge wiring, the established pattern in this codebase is property injection (not init params). Evidence:

- `bridge.controller = self` (line 73 of KeyboardViewController)
- `bridge.keyboardView = keyboard` (line 74)
- `state.controller = controller` (line 141 of KeyboardRootView)

**Recommendation:** Add `weak var suggestionState: SuggestionState?` to DictusKeyboardBridge. Set it in KeyboardViewController.viewDidLoad after creating both the bridge and the hosting controller.

**Challenge:** SuggestionState is currently owned by KeyboardRootView as `@StateObject`. The bridge needs a reference to the same instance. Two approaches:

1. **Extract SuggestionState creation to KeyboardViewController** -- create it there, pass it to both bridge and KeyboardRootView. This breaks `@StateObject` ownership (must use `@ObservedObject` in KeyboardRootView instead).
2. **Pass via callback** -- KeyboardRootView passes its SuggestionState reference back to the controller via `.onAppear`. The bridge reference would be nil until onAppear fires.

**Recommendation:** Option 1 (extract to controller). The controller already owns the bridge and the hosting controller. Making it also own SuggestionState centralizes ownership. Use `@ObservedObject` in KeyboardRootView since the instance lifetime is managed by the controller. This is safe because KeyboardViewController outlives KeyboardRootView.

### Integration Pattern: Emoji Show/Hide

The recording overlay pattern is the template:

```swift
// Recording: hides keyboard, expands hosting to full height
giellaKeyboard?.isHidden = isRecording
hostingHeightConstraint?.constant = isRecording ? fullHeight : toolbarHeight
```

For emoji, the same pattern applies:

```swift
// Emoji: hides keyboard, shows emoji picker in hosting area
giellaKeyboard?.isHidden = isShowingEmoji
// hostingHeightConstraint stays at toolbarHeight (toolbar visible during emoji)
// Emoji picker needs its OWN hosting controller or embed in existing one
```

**Key difference from recording:** The toolbar stays visible during emoji browsing. This means the hosting view height stays at toolbarHeight, and the emoji picker replaces the GiellaKeyboardView space below it. Two options:

1. **Add emoji picker to the existing hosting controller** by adding emoji state to KeyboardRootView -- if `showingEmoji`, render EmojiPickerView below ToolbarView instead of nothing. Expand hosting height to full keyboard height.
2. **Separate UIHostingController** for emoji picker, added as a sibling view to giellaKeyboard.

**Recommendation:** Option 1 (same hosting controller). KeyboardRootView already handles recording/toolbar switching. Adding emoji as a third state keeps the pattern consistent. The body becomes: if recording -> overlay, elif emoji -> toolbar + emoji picker, else -> toolbar only.

### Integration Pattern: Emoji Button in Layout

The KeyType enum has no dedicated emoji case. Two options:

1. **Reuse `.input(key: "emoji", alternate: "emoji")`** -- the bridge's `didTriggerKey` checks for this special alternate value and toggles emoji mode instead of inserting text.
2. **Add a new KeyType case** -- requires modifying the vendored KeyDefinition.swift.

**Recommendation:** Option 1 (reuse .input with special alternate). This avoids modifying vendored code. The bridge already checks `alternate == "accent"` for the adaptive accent key (line 69 of DictusKeyboardBridge). Same pattern: `alternate == "emoji"` triggers emoji toggle.

The visual rendering in GiellaKeyboardView will show the key text (a smiley emoji character) as-is, since it renders `.input` keys with their key string.

### Bottom Row Layout Change

Current lettersBottomRow (10 units total):
```
[123 2.5w] [space 5.0w] [return 2.5w]
```

New lettersBottomRow with emoji:
```
[123 2.0w] [emoji 1.5w] [space 4.5w] [return 2.0w]
```

The exact widths need tuning on device but should total 10 units to match the grid.

### Post-Transcription Suggestion Update

In `KeyboardState.handleTranscriptionReady()`, after `controller?.textDocumentProxy.insertText(transcription)`, the bridge needs to trigger a SuggestionState update. Two approaches:

1. **Direct call** -- KeyboardState has a reference to controller, but not to bridge or SuggestionState.
2. **NotificationCenter** -- post a notification that the bridge or controller listens to.

**Recommendation:** Add a `var onTranscriptionInserted: (() -> Void)?` closure to KeyboardState, set by KeyboardViewController. When transcription is inserted, call the closure. The controller reads proxy context and calls `suggestionState.updateAsync(context:)`. This keeps KeyboardState decoupled from SuggestionState.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Spell checking | Custom dictionary lookup | `SuggestionState.performSpellCheck()` via `UITextChecker` | Apple's UITextChecker handles French morphology, accent normalization |
| Autocorrect undo | Custom undo stack | `AutocorrectState` struct in SuggestionState | Already tracks original/corrected/insertedSpace |
| Emoji dataset | Manual emoji list | `EmojiStore` / `EmojiData` | Already built with categories, French search keywords |
| Async suggestion coalescing | Custom debounce | `DispatchWorkItem` cancel pattern in `updateAsync()` | Already handles rapid typing with cancellation |

## Common Pitfalls

### Pitfall 1: SuggestionState ownership race
**What goes wrong:** If SuggestionState is created in KeyboardRootView (@StateObject) but the bridge also needs a reference, passing it back via .onAppear creates a window where the bridge has no reference (between viewDidLoad and onAppear).
**Why it happens:** SwiftUI view body evaluation is async relative to UIKit lifecycle.
**How to avoid:** Create SuggestionState in KeyboardViewController (viewDidLoad). Pass to both bridge and KeyboardRootView. Use @ObservedObject in KeyboardRootView.
**Warning signs:** Suggestions not appearing for the first few keystrokes after keyboard opens.

### Pitfall 2: Autocorrect-on-space + double-space-period conflict
**What goes wrong:** User types "helo " (space) -- autocorrect fires and replaces "helo" with "hello", then immediately types another space expecting double-space-period. But the autocorrect replacement changed the text context.
**Why it happens:** handleAutoFullStop() reads documentContextBeforeInput, which now has "hello " instead of "helo ".
**How to avoid:** Autocorrect-on-space should insert the replacement + space as one operation. The double-space detection should work correctly since the buffer will have "[corrected word] " after the first space.
**Warning signs:** Double-space period not working after autocorrections.

### Pitfall 3: Emoji picker height mismatch
**What goes wrong:** Emoji picker height doesn't match the keyboard grid height, causing visual jump when switching.
**Why it happens:** The hosting view height constraint needs to expand to cover both toolbar + keyboard grid area when emoji picker is active.
**How to avoid:** Use the same `computeKeyboardHeight()` value for emoji picker hosting height expansion, same as recording overlay.
**Warning signs:** Visual jump or gap when toggling emoji picker.

### Pitfall 4: Emoji picker touch conflicts with toolbar
**What goes wrong:** Emoji picker SwiftUI touches conflict with the toolbar SwiftUI hosting above it.
**Why it happens:** Both are in the same UIHostingController. SwiftUI manages hit testing internally.
**How to avoid:** Structure the body as VStack(toolbar, emojiPicker) so SwiftUI handles hit testing naturally.

### Pitfall 5: Default layer setting not applying
**What goes wrong:** User sets default layer to "numbers" but keyboard always opens on letters.
**Why it happens:** `giellaKeyboard.page` is set in viewDidLoad (before App Group is read) or the page property doesn't trigger a layout update.
**How to avoid:** Set `giellaKeyboard.page` in `viewWillAppear` (after viewDidLoad, when App Group is accessible). Map `DefaultKeyboardLayer.numbers` to `KeyboardPage.symbols1`.
**Warning signs:** Keyboard always opens on letters regardless of setting.

### Pitfall 6: Bridge lastInsertedCharacter state after autocorrect
**What goes wrong:** After autocorrect replaces a word, bridge's `lastInsertedCharacter` still holds the last typed character, not the last character of the corrected word. Adaptive accent key shows wrong label.
**Why it happens:** Autocorrect replaces text via proxy.deleteBackward + proxy.insertText, but bridge's tracking variables aren't updated.
**How to avoid:** After autocorrect replacement, update `lastInsertedCharacter` to the last character of the corrected word (or space if space was appended).

## Code Examples

### Wiring SuggestionState into Bridge (main integration)

```swift
// In DictusKeyboardBridge.swift -- add property
weak var suggestionState: SuggestionState?

// In handleInputKey, after insertText:
private func handleInputKey(_ character: String) {
    // ... existing code ...
    controller?.textDocumentProxy.insertText(character)
    // Trigger suggestion update
    let context = controller?.textDocumentProxy.documentContextBeforeInput
    suggestionState?.updateAsync(context: context)
}
```

### Autocorrect-on-space in Bridge

```swift
// In handleSpace(), before inserting space:
private func handleSpace() {
    AudioServicesPlaySystemSound(KeySound.modifier)
    secondToLastInsertedCharacter = lastInsertedCharacter

    // Autocorrect check before space insertion
    if let state = suggestionState, state.autocorrectEnabled,
       !state.currentWord.isEmpty,
       let correction = state.performSpellCheck(state.currentWord),
       correction.lowercased() != state.currentWord.lowercased() {
        // Replace misspelled word with correction
        let proxy = controller?.textDocumentProxy
        for _ in 0..<state.currentWord.count {
            proxy?.deleteBackward()
        }
        proxy?.insertText(correction)
        proxy?.insertText(" ")
        lastInsertedCharacter = " "

        // Store for undo
        state.lastAutocorrect = AutocorrectState(
            originalWord: state.currentWord,
            correctedWord: correction,
            insertedSpace: true
        )
        state.clear()
        updateCapitalization()
        updateAccentKeyDisplay()
        return
    }

    // Normal space handling (existing code)
    if !handleAutoFullStop() {
        controller?.textDocumentProxy.insertText(" ")
        lastInsertedCharacter = " "
    } else {
        lastInsertedCharacter = " "
    }
    // Trigger suggestion update after space
    suggestionState?.clear() // Space ends current word
    updateCapitalization()
    updateAccentKeyDisplay()
}
```

### Undo-on-backspace in Bridge

```swift
// In handleBackspace(), before deleteBackward:
private func handleBackspace() {
    AudioServicesPlaySystemSound(KeySound.delete)

    // Check for autocorrect undo
    if let autocorrect = suggestionState?.lastAutocorrect {
        let proxy = controller?.textDocumentProxy
        // Delete the correction + optional space
        let deleteCount = autocorrect.correctedWord.count + (autocorrect.insertedSpace ? 1 : 0)
        for _ in 0..<deleteCount {
            proxy?.deleteBackward()
        }
        proxy?.insertText(autocorrect.originalWord)
        suggestionState?.lastAutocorrect = nil
        lastInsertedCharacter = autocorrect.originalWord.last.map(String.init)
        secondToLastInsertedCharacter = nil
        updateCapitalization()
        updateAccentKeyDisplay()
        // Update suggestions for restored word
        let context = proxy?.documentContextBeforeInput
        suggestionState?.updateAsync(context: context)
        return
    }

    // Normal backspace (existing code)
    controller?.textDocumentProxy.deleteBackward()
    // ...
}
```

### Emoji Button in Layout

```swift
// In FrenchKeyboardLayouts.swift -- new lettersBottomRow
private static let lettersBottomRow: [KeyDefinition] = [
    KeyDefinition(type: .symbols, size: CGSize(width: 2.0, height: 1)),
    KeyDefinition(type: .input(key: "\u{1F600}", alternate: "emoji"), size: CGSize(width: 1.5, height: 1)),
    KeyDefinition(type: .spacebar(name: "espace"), size: CGSize(width: 4.5, height: 1)),
    KeyDefinition(type: .returnkey(name: "retour"), size: CGSize(width: 2.0, height: 1)),
]
```

### Default Layer in viewWillAppear

```swift
// In KeyboardViewController.viewWillAppear:
// Set default opening layer from user preference
let defaultLayer = DefaultKeyboardLayer.active
if defaultLayer == .numbers {
    giellaKeyboard?.page = .symbols1
}
// (letters is .normal which is the default, no action needed)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SwiftUI keyboard keys | UIKit UICollectionView keys | Phase 18 (2026-03-28) | Zero dead zones, proven touch pipeline |
| KeyboardMode 3-mode system | DefaultKeyboardLayer 2-option | Phase 18 | Simpler, no layout duplication |
| SuggestionState in SwiftUI only | SuggestionState shared with UIKit bridge | Phase 20 (now) | Predictions work with new keyboard |

## Open Questions

1. **Emoji key visual rendering in GiellaKeyboardView**
   - What we know: GiellaKeyboardView renders `.input` keys by drawing the key string as text. A smiley emoji character should render correctly.
   - What's unclear: Whether the emoji character renders at the right size in the collection view cell, whether it gets `isSpecialKeyStyle` treatment.
   - Recommendation: Use `.input(key: "\u{1F600}", alternate: "emoji")` and test. If the emoji renders too small, the cell's label font size may need adjustment for this specific key. Alternatively, use a globe emoji or a simpler symbol.

2. **EmojiPickerView known issues from feature branch**
   - What we know: MEMORY.md lists remaining issues -- search bar pill shape, key popup z-index, space bar clipping.
   - What's unclear: Whether these issues persist after integration into the Phase 18 UIKit architecture.
   - Recommendation: Integrate first, then fix issues encountered. The mini search keyboard height (40pt) may conflict with the full keyboard's height calculations.

3. **SuggestionState @StateObject vs @ObservedObject**
   - What we know: Changing from @StateObject to @ObservedObject means SwiftUI won't auto-create the instance. The controller must manage its lifecycle.
   - What's unclear: Whether @ObservedObject causes extra re-renders or lifecycle issues in keyboard extension context.
   - Recommendation: This is a standard SwiftUI pattern. @ObservedObject is correct when the instance is created externally. Test that suggestions still update reactively.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (DictusCore SPM package) |
| Config file | DictusCore/Package.swift |
| Quick run command | `cd /Users/pierreviviere/dev/dictus/DictusCore && swift test --filter DictusCoreTests` |
| Full suite command | `cd /Users/pierreviviere/dev/dictus/DictusCore && swift test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DICT-01 | Mic button starts recording | manual-only | On-device UAT (requires keyboard extension + mic) | N/A |
| DICT-02 | Recording overlay with waveform | manual-only | On-device UAT (requires recording state) | N/A |
| DICT-03 | Transcription auto-insert | manual-only | On-device UAT (requires WhisperKit) | N/A |
| DICT-04 | Full Access banner | manual-only | On-device UAT (requires permission state) | N/A |
| PRED-01 | Suggestion bar shows suggestions | manual-only | On-device UAT (requires keyboard extension context) | N/A |
| PRED-02 | Tap suggestion to insert | manual-only | On-device UAT (requires textDocumentProxy) | N/A |
| PRED-03 | Undo autocorrect with backspace | manual-only | On-device UAT (requires textDocumentProxy) | N/A |
| SET-01 | Default opening layer | manual-only | On-device UAT (requires App Group + keyboard extension) | N/A |

**Justification for manual-only:** All Phase 20 requirements involve keyboard extension runtime behavior (textDocumentProxy, UIInputViewController lifecycle, Darwin notifications, AVAudioSession). These cannot be unit tested in the DictusCore SPM package. They require on-device testing in the keyboard extension context.

### Sampling Rate
- **Per task commit:** Build + install on simulator, manual smoke test
- **Per wave merge:** Full UAT checklist on physical device
- **Phase gate:** All UAT items green on device before verify

### Wave 0 Gaps
None -- existing test infrastructure covers DictusCore unit tests. Phase 20 features are integration-level (keyboard extension runtime) and require manual validation.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: DictusKeyboardBridge.swift, KeyboardViewController.swift, KeyboardRootView.swift, SuggestionState.swift, FrenchKeyboardLayouts.swift, KeyDefinition.swift, KeyboardState.swift, SharedKeys.swift, KeyboardMode.swift, ToolbarView.swift, EmojiPickerView.swift
- Phase 18-19 CONTEXT.md architecture decisions
- REQUIREMENTS.md requirement definitions

### Secondary (MEDIUM confidence)
- MEMORY.md project history and known issues

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new libraries, all existing code
- Architecture: HIGH - patterns established in Phase 18-19, well-documented in codebase
- Pitfalls: HIGH - identified from actual code analysis, not speculation

**Research date:** 2026-03-30
**Valid until:** 2026-04-30 (stable codebase, no external dependencies changing)
