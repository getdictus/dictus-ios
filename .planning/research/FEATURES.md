# Feature Landscape

**Domain:** iOS Keyboard Extension - UICollectionView Rebuild + Public Beta (v1.3)
**Researched:** 2026-03-27
**Focus:** giellakbd-ios keyboard features, UICollectionView keyboard UX patterns, public beta requirements

## giellakbd-ios: What You Get Out of the Box

Features provided by the Divvun giellakbd-ios framework that Dictus can inherit directly.

| Feature | giellakbd-ios Implementation | Dictus Adaptation Needed | Complexity |
|---------|------------------------------|--------------------------|------------|
| UICollectionView key layout | FlowLayout with rows as sections, cells as keys | Minimal — use as-is, define French AZERTY/QWERTY layouts | Low |
| Touch handling on KeyboardView | touchesBegan/Moved/Ended on the collection view itself (NOT per-cell) — eliminates dead zones | None — this IS the reason we're adopting it | None |
| Key overlay/popup on press | KeyOverlayView shows enlarged key preview on tap | Restyle to match Dictus Liquid Glass theme | Low |
| Long press alternate characters | LongPressController with drag-to-select popup | Populate with French accents (e -> e,e,e,e,e) | Low |
| Dead key composition | DeadKeyHandler with transforming state machine | May not need for French (direct accent keys preferred), keep as fallback | Low |
| Keyboard page/layer switching | normal/shifted/capslock/symbols1/symbols2 pages | Map to Dictus layers (letters/numbers/symbols + shift states) | Med |
| Auto-capitalization | Sentence/word/allCharacters detection from textDocumentProxy | Use as-is, verify French punctuation rules | Low |
| Double-space period insertion | Built into KeyboardViewController | Use as-is | None |
| Key sizing via width ratios | KeyDefinition with CGSize(width: N, height: 1) relative sizing | Define French layout ratios (AZERTY has different key widths) | Low |
| Theme system | ThemeFactory with 17 color properties, font config, corner radii, margins | Replace entirely with Dictus Liquid Glass theme values | Med |
| Banner/suggestion bar slot | BannerManager with delegate protocol, SpellBanner plugin | Replace SpellBanner with Dictus SuggestionBarView logic | Med |
| Key sounds | Audio.swift controller | Replace with Dictus 3-category AudioServicesPlaySystemSound approach | Low |
| Split keyboard mode | SplitKeyboard.swift for iPad | Out of scope (iPhone-only) — ignore | None |
| Accessibility labels | Per-key accessibilityLabel(for page:) | Translate to French/English | Low |
| Device context adaptation | DeviceContext model for iPhone/iPad sizing | Extend with Dictus 3 device classes (compact/standard/large) | Low |
| Privacy manifest | PrivacyInfo.xcprivacy included | Merge with existing Dictus privacy manifest | Low |
| Keyboard height calculation | KeyboardHeightProvider per device/orientation | Adapt to Dictus toolbar + keyboard + overlay heights | Med |

## Table Stakes

Features users expect from a French dictation keyboard. Missing = product feels incomplete.

| Feature | Why Expected | Provided by giellakbd-ios? | Reintegration Complexity | Notes |
|---------|--------------|---------------------------|--------------------------|-------|
| Full AZERTY layout | French users' primary layout | Layout system yes, AZERTY data no | Med | Must define AZERTY key definitions in JSON/code |
| QWERTY option | International users, settings toggle | Layout system yes, QWERTY data no | Med | Second layout definition needed |
| Shift + caps lock | Standard keyboard behavior | Yes (page system) | Low | Map to giellakbd pages |
| Numbers + symbols layers | Standard keyboard behavior | Yes (symbols1/symbols2) | Low | Define French symbol layout |
| Backspace with repeat | Hold to delete continuously | Yes (supportsRepeatTrigger) | None | Built in |
| Space bar | Standard | Yes (spacebar key type) | Low | Custom width for French layout |
| Return key | Standard | Yes (returnkey key type) | None | Built in |
| Globe/next keyboard | iOS requirement for third-party keyboards | Yes (keyboard key type) | None | Built in, calls advanceToNextInputMode() |
| Autocapitalization | After period, new sentence | Yes (updateCapitalization) | Low | Verify French punctuation edge cases |
| Key press feedback (haptic) | Users expect tactile response | No (giellakbd uses basic highlight) | Med | Reintegrate Dictus pre-allocated UIImpactFeedbackGenerator system |
| Key press feedback (sound) | 3-category sounds matching Apple keyboard | Partial (has Audio.swift) | Low | Replace with Dictus AudioServicesPlaySystemSound approach |
| Accent characters via long press | Critical for French (e->e,e,e,e,e) | Yes (LongPressController) | Low | Populate French accent maps |
| Text prediction / suggestions | Expected from modern keyboards | Banner slot only, no prediction engine | Med | Reintegrate Dictus TextPredictionEngine + SuggestionBarView |
| Autocorrect with undo-on-backspace | Quality-of-life for typing | No | Med | Reintegrate from existing Dictus SuggestionState |
| Dictation via mic button | Core product value | No | High | Reintegrate full toolbar mic + Darwin notification + URL scheme pipeline |
| Recording overlay with waveform | Visual feedback during dictation | No | High | Reintegrate RecordingOverlay + KeyboardWaveformView |
| Full Access permission banner | iOS requirement when mic needed | No (has SpellerAvailableBanner) | Low | Reintegrate FullAccessBanner |

## Differentiators

Features that set Dictus apart. Not expected from a generic keyboard but core to Dictus identity.

| Feature | Value Proposition | Provided by giellakbd-ios? | Reintegration Complexity | Notes |
|---------|-------------------|---------------------------|--------------------------|-------|
| Spacebar trackpad | Cursor movement by dragging spacebar, with haptic ticks and line-based vertical movement | No | High | Fully custom — must reimplement on UICollectionView spacebar cell. giellakbd-ios touch handling is on the collection view level, so spacebar long-press -> trackpad mode needs careful gesture arbitration |
| Adaptive accent key | Apostrophe becomes accent key after vowels (context-aware) | No | Med | Reintegrate from KeyboardView logic, wire into giellakbd key press handler |
| Mic pill in toolbar | Wispr Flow-inspired mic button with 4 visual states | No | Med | Toolbar lives above the keyboard — can be kept as separate UIView/SwiftUI island |
| Dynamic Island live activity | Shows recording state in Dynamic Island | No | Low | Independent of keyboard rebuild — already works via DictusCore |
| 3-slot suggestion bar with French autocorrect | UITextChecker + FrequencyDictionary ranking | Banner slot only | Med | Replace SpellBanner with Dictus prediction engine |
| Liquid Glass design | iOS 26 premium visual identity | No (has its own Theme system) | Med | Override Theme with Dictus colors, gradients, blur effects |
| Cold start Audio Bridge | Keyboard captures audio when app was killed | No | Low | Independent of keyboard layout — lives in KeyboardState/DictusCore |
| Export logs | Debug capability for beta testers | No | None | Already in DictusApp, not keyboard |
| Keyboard default layer selection | User picks letters or numbers as default opening layer | No | Low | Read from App Group on appearance, set initial page |

## Anti-Features

Features to explicitly NOT build in v1.3.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Full emoji picker in keyboard | Memory-unsafe (emoji glyph cache blows 50MB limit) — discovered in v1.1 | Use system emoji cycling via globe key. Remove EmojiPickerView/EmojiData/EmojiSearchFR from new keyboard |
| iPad/split keyboard support | Out of scope, iPhone-first | Ignore SplitKeyboard.swift from giellakbd-ios |
| DivvunSpell integration | Dictus uses UITextChecker + FrequencyDictionary, not Divvun's speller | Strip DivvunSpell dependencies, use Dictus TextPredictionEngine |
| kbdgen layout generation | Dictus defines layouts in code, not via external toolchain | Define KeyboardDefinition directly, don't use kbdgen pipeline |
| Sentry error tracking | Dictus uses PersistentLog (privacy-safe, typed events) | Remove Sentry pod dependency from giellakbd-ios |
| CocoaPods | Dictus uses SPM exclusively | Convert any needed deps to SPM or inline |
| Smart modes / LLM post-processing | Deferred — focus on keyboard quality | None for v1.3 |
| Real-time streaming transcription | v2+ feature | Batch transcription works well |
| Auto-return to previous app | No reliable public API — confirmed in v1.2 research | Keep swipe-back overlay UX |

## Feature Dependencies

```
giellakbd-ios UICollectionView base
  |-> French AZERTY/QWERTY layout definitions (blocks everything)
  |-> Theme override (Liquid Glass) (blocks visual polish)
  |-> Key press haptics (independent, parallel)
  |-> Key press sounds (independent, parallel)
  |
  |-> Long press accent popups (needs layout definitions)
  |-> Adaptive accent key (needs key press handler wired)
  |
  |-> Suggestion bar in banner slot (needs TextPredictionEngine)
  |     |-> Autocorrect undo-on-backspace (needs suggestion bar)
  |
  |-> Spacebar trackpad (needs spacebar cell + gesture arbitration)
  |
  |-> Toolbar with mic button (independent — lives above keyboard)
  |     |-> Recording overlay (needs toolbar mic integration)
  |           |-> Waveform visualization (needs recording overlay)
  |
  |-> Keyboard page/layer switching (needs layout definitions)
  |     |-> Default layer selection from App Group (needs layer switching)
  |
  |-> Dynamic Island live activity (fully independent, already works)
  |-> Cold start Audio Bridge (fully independent, already works)
  |-> Export logs (fully independent, in DictusApp)
```

## MVP Recommendation for v1.3

### Phase 1: Core Keyboard (must ship first)
1. **giellakbd-ios integration** — fork/vendor BaseKeyboard + Keyboard into Dictus project
2. **French AZERTY + QWERTY layout definitions** — key definitions with correct widths
3. **Theme override** — Liquid Glass colors, fonts, corner radii
4. **Key press haptics + sounds** — reintegrate pre-allocated generators + 3-category sounds
5. **Keyboard page/layer switching** — letters/numbers/symbols with shift states
6. **Long press French accents** — populate accent maps for all French vowels

### Phase 2: Dictus Features Reintegration
7. **Toolbar with mic button** — above keyboard, SwiftUI island or pure UIKit
8. **Recording overlay + waveform** — replace keyboard view during recording
9. **Suggestion bar** — TextPredictionEngine in banner slot
10. **Autocorrect undo-on-backspace** — wire into suggestion bar
11. **Adaptive accent key** — context-aware apostrophe/accent switching
12. **Spacebar trackpad** — long-press gesture on spacebar cell

### Phase 3: Polish + Public Beta
13. **Default layer selection** — read from App Group
14. **Fix Dynamic Island REC desync** — issue #60
15. **Fix export logs performance** — issue #61
16. **Full Access banner** — when mic permissions needed
17. **Beta App Review submission** — privacy manifest, screenshots, description

### Defer to v1.4+
- Smart modes / LLM post-processing
- iPad support
- Streaming transcription
- Emoji picker (system cycling sufficient)

## Reintegration Risk Assessment

| Existing Dictus Feature | Risk Level | Why |
|------------------------|------------|-----|
| Spacebar trackpad | HIGH | giellakbd-ios handles ALL touches at collection view level. Spacebar trackpad needs to intercept long-press on one specific cell and switch to cursor-movement mode. Requires careful gesture state machine to avoid conflicting with normal key taps and long-press accents. |
| Recording overlay | MEDIUM | Overlay replaces entire keyboard during recording. With UICollectionView, need to either hide the collection view and show overlay, or use a separate container. Simpler than SwiftUI conditional rendering but needs height management. |
| Suggestion bar | MEDIUM | giellakbd-ios has a banner slot with BannerManager delegate protocol. Must adapt Dictus TextPredictionEngine to feed this slot. Protocol mismatch likely — giellakbd uses CursorContext, Dictus uses textDocumentProxy directly. |
| Haptic feedback | LOW | Independent of layout. Pre-allocate UIImpactFeedbackGenerator instances, fire on touchesBegan in KeyboardView. Only risk: giellakbd touchesBegan already does key detection — must add haptic call at the right point. |
| Adaptive accent key | LOW | Pure logic — check lastTypedChar, swap key definition. giellakbd-ios supports dynamic key content updates via collection view reload. |
| Key sounds | LOW | Replace Audio.swift with AudioServicesPlaySystemSound calls. Straightforward. |
| Cold start Audio Bridge | NONE | Completely independent of keyboard layout, lives in KeyboardState + DictusCore. |
| Dynamic Island | NONE | Independent, lives in DictusCore. Only needs bug fix for state desync. |

## Sources

- [giellakbd-ios GitHub repository](https://github.com/divvun/giellakbd-ios) — PRIMARY source for architecture analysis
- [giellakbd-ios KeyboardView.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Views/KeyboardView.swift) — UICollectionView layout, touch handling
- [giellakbd-ios KeyView.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Views/KeyView.swift) — individual key rendering
- [giellakbd-ios KeyboardViewController.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Controllers/KeyboardViewController.swift) — text input, page management, banner system
- [giellakbd-ios KeyDefinition.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Models/KeyDefinition.swift) — key types and sizing
- [giellakbd-ios Theme.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Models/Theme.swift) — theming system
- [giellakbd-ios LongPressController.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Controllers/LongPressController.swift) — long press accents
- [giellakbd-ios DeadKeyHandler.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Controllers/DeadKeyHandler.swift) — accent composition
- [giellakbd-ios BannerManager.swift](https://github.com/divvun/giellakbd-ios/blob/main/Keyboard/Controllers/BannerManager.swift) — suggestion bar slot
- [Apple Custom Keyboard Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — extension constraints
- [UICollectionView in keyboard extensions — Apple Developer Forums](https://developer.apple.com/forums/thread/24032) — viewDidAppear timing requirement
- [TestFlight overview — Apple Developer](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) — public beta requirements
- [iOS app distribution guide 2026](https://foresightmobile.com/blog/ios-app-distribution-guide-2026) — SDK requirements, review timelines
