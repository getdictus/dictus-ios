# Phase 18: Keyboard Base - Context

**Gathered:** 2026-03-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the SwiftUI keyboard grid with a UICollectionView-based keyboard vendored from giellakbd-ios. Users can type on AZERTY/QWERTY with zero dead zones, haptic feedback, key sounds, and key popup preview. This phase delivers the typing foundation only -- dictation, emoji, text prediction, and accent features are reintegrated in later phases (19-20).

Requirements: KBD-01, KBD-02, KBD-03, KBD-04, KBD-06, KBD-07, KBD-08, FEEL-01, FEEL-02, FEEL-03

</domain>

<decisions>
## Implementation Decisions

### Vendoring philosophy (CRITICAL)
- Use giellakbd-ios source files AS-IS with MINIMAL modifications
- The open source keyboard already looks nearly identical to Apple's keyboard -- that's the goal
- Do NOT customize key visual style, shadows, colors, or shapes beyond what giellakbd-ios provides
- Every style customization is a potential dead zone risk -- avoid them
- The priority is ZERO DEAD ZONES over visual customization
- Brand identity comes from the toolbar (mic button with Dictus blue), not from the keys themselves

### Key visual style
- iOS native adaptive: keys follow system light/dark mode automatically (giellakbd-ios default behavior)
- Special keys (shift, delete, 123, return) use giellakbd-ios default styling
- Dictus accent (#3D7EFF blue) only on the toolbar mic button -- not on keyboard keys
- Key shadows/depth: whatever giellakbd-ios provides out of the box

### Numbers & symbols layers
- Use giellakbd-ios French layout if available and close enough to iOS stock French keyboard
- If giellakbd-ios layout is 90%+ similar to iOS stock French, accept it as-is
- No manual tweaking to match iOS exactly -- close enough is fine
- Consistency with "use open source as-is" philosophy

### Key popup preview
- Use giellakbd-ios KeyOverlayView as-is, no color or style modifications
- No custom Dictus branding on popup

### Haptic & sound feedback
- Keep Dictus infrastructure: HapticFeedback.keyTapped() + 3-category AudioServicesPlaySystemSound
- Wire Dictus feedback into giellakbd-ios touch handling (touchesBegan/Moved/Ended)
- Zero dead zone risk: feedback is called AFTER touch detection, not part of the touch pipeline
- Respect existing user settings (haptic toggle, sound toggle, silent switch)
- giellakbd-ios has no built-in haptic feedback -- Dictus adds this

### Globe key & keyboard switching
- Globe key is NOT part of Dictus keyboard layout -- iOS provides it automatically below third-party keyboards
- No globe key in our layout data

### Emoji button
- DEFERRED to Phase 20 (Feature Reintegration)
- Phase 18 bottom row: 123 + space + return only
- Emoji button will be added between 123 and spacebar in Phase 20, wired to existing EmojiPickerView

### Bottom row layout (Phase 18)
- Row 4: [123] [SPACE] [RETURN]
- Simplified layout -- no emoji, no mic (mic is in toolbar, already SwiftUI)

### Claude's Discretion
- Exact giellakbd-ios files to vendor and any minimal adaptations needed for Dictus integration
- How to bridge UICollectionView keyboard into existing KeyboardViewController
- DeviceKit integration approach for keyboard height calculation
- How to wire Dictus haptic/sound calls into giellakbd-ios touch handlers
- Autocapitalization and double-space period implementation details
- Shift/caps lock state machine implementation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### giellakbd-ios research
- `.planning/codebase/ARCHITECTURE.md` -- Full architecture analysis: giellakbd-ios UICollectionView approach, component mapping, integration proposal, build order
- `.planning/codebase/STACK.md` -- Technical stack changes: DeviceKit dependency, vendored files list, memory impact, confidence assessment

### Current keyboard (to replace)
- `DictusKeyboard/KeyboardViewController.swift` -- UIInputViewController, hosting controller setup, height constraints
- `DictusKeyboard/KeyboardRootView.swift` -- SwiftUI root view (to be adapted for UIKit keyboard)
- `DictusKeyboard/Models/KeyboardLayout.swift` -- AZERTY/QWERTY layout definitions, KeyDefinition model
- `DictusKeyboard/Models/KeyDefinition.swift` -- Key type enum and properties
- `DictusKeyboard/Views/KeyboardView.swift` -- Current SwiftUI grid (TO BE REPLACED)
- `DictusKeyboard/Views/KeyButton.swift` -- Current SwiftUI letter key (TO BE REPLACED)
- `DictusKeyboard/Views/SpecialKeyButton.swift` -- Current SwiftUI special keys (TO BE REPLACED)
- `DictusKeyboard/Views/KeyRow.swift` -- Current SwiftUI row (TO BE REPLACED)

### Feedback infrastructure (to keep)
- `DictusCore/Sources/DictusCore/HapticFeedback.swift` -- Pre-allocated haptic generators, warmUp(), keyTapped(), settings cache
- `DictusKeyboard/Views/KeyboardView.swift` -- KeySound enum (letter=1104, delete=1155, modifier=1156) via AudioServicesPlaySystemSound

### Cross-process infrastructure (unchanged)
- `DictusKeyboard/KeyboardState.swift` -- Darwin notifications, App Group state, recording state management
- `DictusKeyboard/InputView.swift` -- UIInputView for audio feedback

### GitHub issues
- Issue #62 -- Keyboard rebuild tracking issue

### Requirements
- `.planning/REQUIREMENTS.md` -- KBD-01 through KBD-08, FEEL-01 through FEEL-03

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `HapticFeedback` (DictusCore): Pre-allocated generators, touchDown feedback, settings-aware -- wire into giellakbd-ios touch handlers
- `KeySound` enum: 3-category system sounds via AudioServicesPlaySystemSound -- call from new key cells
- `KeyboardLayout.swift`: AZERTY/QWERTY definitions with KeyDefinition model -- may need mapping to giellakbd-ios format
- `KeyboardState.swift`: Full cross-process state management -- unchanged, new keyboard reads same state
- `SharedKeys` (DictusCore): UserDefaults keys for haptics, sounds, layout type -- all reusable

### Established Patterns
- touchDown feedback (not touchUp) -- matches Apple keyboard, apply same in giellakbd-ios
- AudioServicesPlaySystemSound for key sounds -- respects silent switch natively
- Static pre-allocated generators -- avoids per-tap allocation overhead
- App Group UserDefaults for cross-process settings sync

### Integration Points
- `KeyboardViewController` hosts the keyboard view -- adapt from UIHostingController to UICollectionView
- `textDocumentProxy` for text insertion -- giellakbd-ios should call this for character output
- Darwin notifications for dictation (Phase 20) -- infrastructure stays, just not wired in Phase 18
- Toolbar (ToolbarView.swift) remains SwiftUI -- needs to coexist with UIKit keyboard below it

</code_context>

<specifics>
## Specific Ideas

- Pierre: "je veux vraiment utiliser les fichiers du repo open source au maximum" -- use giellakbd-ios files as-is, minimal changes
- Pierre: "en termes de design il me convenait, il est quasiment identique a celui d'Apple" -- the open source keyboard already looks like Apple's, that's good enough
- Pierre: "je veux eviter qu'on se retrouve avec un bug avec des dead zones et j'ai l'impression c'est en faisant toutes ces petites modifications de style qu'on peut y arriver" -- style modifications are the enemy of zero dead zones
- Pierre: "le seul probleme dans le clavier open source c'est vraiment les emojis uniquement" -- emoji is the only thing missing (deferred to Phase 20)
- The globe key is provided by iOS below all third-party keyboards -- not part of our layout

</specifics>

<deferred>
## Deferred Ideas

- Emoji button on bottom row (between 123 and spacebar) -- Phase 20
- Emoji picker integration (EmojiPickerView already exists) -- Phase 20
- Dictation mic button in toolbar -- Phase 20
- Text prediction / suggestion bar -- Phase 20
- Accent long-press (French accents) -- Phase 19
- Spacebar trackpad -- Phase 19
- Delete repeat acceleration -- Phase 19
- Adaptive accent key -- Phase 19

</deferred>

---

*Phase: 18-keyboard-base*
*Context gathered: 2026-03-27*
