# Phase 20: Feature Reintegration - Context

**Gathered:** 2026-03-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Reconnect all Dictus-specific features on the new UIKit keyboard: dictation (mic button, recording overlay, transcription insert), text prediction (suggestion bar with completions, accents, autocorrect), emoji button, and settings sync. No new features -- reintegrating existing code onto the Phase 18-19 UIKit keyboard architecture.

Requirements: DICT-01, DICT-02, DICT-03, DICT-04, PRED-01, PRED-02, PRED-03, SET-01

</domain>

<decisions>
## Implementation Decisions

### Prediction wiring
- DictusKeyboardBridge gets a direct reference to SuggestionState (injected by KeyboardViewController)
- Bridge calls `suggestionState.updateAsync(context:)` after each keystroke (input, backspace, space, return)
- No NotificationCenter or Combine relay -- direct call from bridge for minimal latency
- Existing async coalescing (DispatchWorkItem cancel + background queue) handles rapid typing -- no extra debounce needed
- Claude handles performance validation on device

### Autocorrect behavior
- Autocorrect-on-space is ACTIVE: when user taps space, if current word is misspelled, auto-replace with best correction
- Undo-on-backspace: pressing backspace immediately after an autocorrection undoes it (restores original word)
- AutocorrectState struct already exists in SuggestionState -- wire it through the bridge

### Accent suggestions
- Keep accent mode in suggestion bar: single vowel typed -> bar shows accented variants (e, a, u, i, o, c)
- Three accent input methods coexist: suggestion bar accents, adaptive accent key (Phase 19), long-press accents (Phase 19)
- All three serve different use cases -- no redundancy removal

### Dictation flow
- Full end-to-end validation required (mic tap -> recording -> transcription -> text insert -> keyboard restore)
- Most wiring exists from Phase 18 architecture (KeyboardRootView, KeyboardState, RecordingOverlay, handleDictationStatusChange)
- After transcription is inserted, trigger SuggestionState update so bar shows completions for the last word of transcription
- Include UAT step to catch any regressions from Phase 19 touch pipeline changes

### Emoji button
- Add emoji button to bottom row between 123 and spacebar: [123] [emoji] [SPACE] [RETURN]
- Tap emoji button -> hide GiellaKeyboardView -> show EmojiPickerView (SwiftUI) in the same keyboard grid space
- Same show/hide pattern as recording overlay (toggle visibility, not destroy/recreate)
- Toolbar stays visible during emoji browsing (mic button accessible)
- ABC button in emoji picker returns to keyboard
- Keep mini search keyboard (French keywords) -- already built, self-contained in EmojiPickerView
- EmojiPickerView, EmojiCategoryBar, EmojiData, EmojiSearchFR, RecentEmojis all exist -- wire into UIKit layout

### Settings sync
- Default opening layer: read SharedKeys.defaultKeyboardLayer from App Group in viewWillAppear, set giellaKeyboard.page accordingly
- Verify ALL settings explicitly during UAT:
  - Haptic feedback toggle (on/off)
  - Sound feedback toggle (on/off)
  - Layout type (AZERTY <-> QWERTY switch)
  - Default opening layer (letters/numbers)
  - Language preference (fr/en for predictions)

### Claude's Discretion
- How to inject SuggestionState reference into DictusKeyboardBridge (property injection vs init param)
- Emoji button key type in GiellaKeyboardView layout definition
- Emoji picker show/hide implementation details (hosting controller management)
- Post-transcription suggestion refresh timing
- UAT test case ordering and grouping

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Keyboard architecture (Phase 18-19 foundation)
- `.planning/phases/18-keyboard-base/18-CONTEXT.md` -- UIKit keys + SwiftUI chrome architecture, vendoring philosophy, hybrid layout
- `.planning/phases/19-complex-touch-features/19-CONTEXT.md` -- Touch pipeline decisions, edge key fix, zero dead zones constraint

### Text prediction (existing code to wire)
- `DictusKeyboard/TextPrediction/TextPredictionEngine.swift` -- Core prediction logic: completions, spell-check, accent suggestions
- `DictusKeyboard/TextPrediction/SuggestionState.swift` -- Observable state: @Published suggestions, async coalescing, autocorrect undo
- `DictusKeyboard/Views/SuggestionBarView.swift` -- 3-slot SwiftUI suggestion bar (already in ToolbarView)

### Dictation infrastructure (already wired, validate)
- `DictusKeyboard/KeyboardState.swift` -- Darwin notifications, dictationStatus, recording lifecycle, transcription auto-insert
- `DictusKeyboard/KeyboardRootView.swift` -- SwiftUI root: RecordingOverlay display logic, SuggestionState ownership, suggestion tap handling
- `DictusKeyboard/Views/RecordingOverlay.swift` -- Full recording UI with waveform, cancel/stop buttons
- `DictusKeyboard/Views/ToolbarView.swift` -- AnimatedMicButton + SuggestionBarView + Full Access banner

### Keyboard bridge (main integration point)
- `DictusKeyboard/DictusKeyboardBridge.swift` -- Key event handler: didTriggerKey, handleInputKey, handleBackspace, handleSpace -- needs SuggestionState calls
- `DictusKeyboard/KeyboardViewController.swift` -- View lifecycle, UIKit keyboard + SwiftUI hosting, recording state observation

### Emoji picker (existing code to integrate)
- `DictusKeyboard/Views/EmojiPickerView.swift` -- Full emoji picker with categories, search, recent emojis
- `DictusKeyboard/Views/EmojiCategoryBar.swift` -- Category navigation bar
- `DictusKeyboard/Models/EmojiData.swift` -- Emoji dataset
- `DictusKeyboard/Models/EmojiSearchFR.swift` -- French keyword search dictionary
- `DictusKeyboard/Models/RecentEmojis.swift` -- Recent emoji tracking via App Group

### Keyboard layouts (emoji button placement)
- `DictusKeyboard/FrenchKeyboardLayouts.swift` -- AZERTY/QWERTY layout definitions, bottom row structure
- `DictusKeyboard/Vendored/Models/KeyDefinition.swift` -- KeyType enum (may need emoji type or reuse existing type)

### Settings
- `DictusCore/Sources/DictusCore/SharedKeys.swift` -- App Group UserDefaults keys for all settings
- `DictusCore/Sources/DictusCore/KeyboardMode.swift` -- DefaultKeyboardLayer enum

### Requirements
- `.planning/REQUIREMENTS.md` -- DICT-01 through DICT-04, PRED-01 through PRED-03, SET-01

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SuggestionState` (KeyboardRootView owns it as @StateObject): Complete prediction state management with async coalescing -- just needs bridge calls
- `TextPredictionEngine`: UITextChecker + FrequencyDictionary, accent suggestions -- fully functional, no changes needed
- `RecordingOverlay` + `KeyboardWaveformDriver`: Complete recording UI -- wired and working from Phase 18
- `EmojiPickerView` + supporting files: Full emoji picker with French search -- needs integration into UIKit layout
- `AnimatedMicButton`: 4-state mic button (idle/recording/transcribing/success) -- already in ToolbarView
- `FullAccessBanner` logic: Already in ToolbarView (disabled mic + "Acces complet requis" text)

### Established Patterns
- UIKit keyboard hide/show: `giellaKeyboard?.isHidden = isRecording` + hosting height expansion (KeyboardViewController:269-283)
- SwiftUI in keyboard extension: UIHostingController as child of KeyboardViewController, view added to kbInputView
- Settings read: `AppGroup.defaults.string(forKey: SharedKeys.xxx)` in viewWillAppear or onAppear
- Key event flow: GiellaKeyboardView touch -> delegate -> DictusKeyboardBridge -> textDocumentProxy

### Integration Points
- `DictusKeyboardBridge` needs `SuggestionState` reference (new dependency injection)
- `FrenchKeyboardLayouts` bottom row needs emoji key definition (new key in row 4)
- `KeyboardViewController` or `KeyboardRootView` needs emoji picker state management (new boolean flag)
- `KeyboardViewController.viewWillAppear` needs default layer read (new settings call)
- Post-transcription hook: `KeyboardState` transcription insert callback -> trigger suggestion update

</code_context>

<specifics>
## Specific Ideas

- Phase 18 CONTEXT.md explicitly deferred emoji button to Phase 20: "between 123 and spacebar"
- Suggestion bar already renders in ToolbarView -- the gap is purely the trigger call from the bridge
- EmojiPickerView was built on a feature branch (commit 531955c) with known issues (search bar pill shape, key popup z-index) -- may need fixes during integration
- Three accent input methods (bar, adaptive key, long-press) is intentional -- each serves different speed/discovery needs

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 20-feature-reintegration*
*Context gathered: 2026-03-30*
