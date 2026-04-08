# Phase 19: Complex Touch Features - Context

**Gathered:** 2026-03-28
**Status:** Ready for research

<domain>
## Phase Boundary

Implement all advanced touch interactions on the giellakbd-ios UICollectionView keyboard: delete repeat, spacebar trackpad, accent long-press, adaptive accent key. Fix two Phase 18 UAT regressions (edge key touchDown, double-space period). Add incremental responsiveness optimizations based on Apple keyboard latency analysis -- without breaking zero dead zones.

Requirements: KBD-05, KBD-08, FEEL-04, FEEL-05, FEEL-06

</domain>

<decisions>
## Implementation Decisions

### Accent character set (LOCKED)
- Use existing `AccentedCharacters.mappings` from DictusCore AS-IS
- French-focused only: e(4), a(3), u(3), i(2), o(2), c(1), y(1), n(1)
- Do NOT add international variants (ē, ė, ę, etc.) -- current set is sufficient
- Populate `FrenchKeyboardLayouts.frenchLongPress` by mapping from `AccentedCharacters.mappings`
- Case handling: accents are stored lowercase, keyboard applies shift-state transformation

### Accent long-press UX
- Use giellakbd-ios `LongPressOverlayController` as-is for popup display and drag-to-select
- Data wiring only: populate `frenchLongPress` dictionary, controller handles the rest
- Accent selection returns through existing delegate chain: `longpress(didSelectKey:)` -> `didTriggerKey()`

### Adaptive accent key
- Re-implement existing v1.1 behavior on UIKit keyboard
- After vowel: show most common accent (é after e, à after a, etc.)
- After consonant/other: show apostrophe (')
- Tap replaces previous vowel with accented version (deleteBackward + insertText)
- Logic already in `AccentedCharacters.adaptiveKeyLabel()` and `shouldReplace()` -- reuse

### Delete repeat
- Use giellakbd-ios `keyRepeatTimer` infrastructure (already supports backspace via `supportsRepeatTrigger`)
- Accelerating speed: initial delay ~400ms, then character-by-character at ~100ms, word-level after ~10 chars
- Match the feel of the previous SwiftUI implementation (SpecialKeyButton.swift had this working well)
- Haptic feedback on each deletion

### Spacebar trackpad
- Implement cursor movement on spacebar long-press + drag
- Activation: ~400ms hold to enter trackpad mode
- Dead zone: ~8pt to absorb jitter after activation
- X-axis drag moves cursor character-by-character via `textDocumentProxy.adjustTextPosition(byCharacterOffset:)`
- Haptic tick on each character movement
- Previous SwiftUI implementation in SpecialKeyButton.swift is the reference for feel/sensitivity

### Edge key touchDown fix (PRIORITY -- UX critical)
- Phase 18 UAT: edge keys (a, q, p, m, 1, -, 0, etc.) fire haptic/popup on touchUp instead of touchDown
- Root cause hypothesis: `collectionView.indexPathForItem(at:)` returns nil for touches near screen edges because touch point is outside cell bounds
- Haptic itself fires on touchDown unconditionally (line 463) -- but popup/overlay requires activeKey which needs valid indexPath
- This is the #1 UX issue: creates perceived latency on ~20% of keys
- Pierre: "c'est vraiment important de corriger ce probleme parce que ca vient vraiment degrader l'experience utilisateur de saisie"
- Pierre: "on a deja essaye de faire des fixes sur la phase precedente mais sans vraiment faire une recherche approfondie"
- Phase 19 research MUST investigate this deeply: UICollectionView edge hit testing, contentInset approaches, point(inside:with:) overrides, nearest-cell fallback
- Previous attempts failed -- need a fundamentally different approach

### Double-space period fix (quick fix)
- Phase 18 UAT: double-space period insertion doesn't work
- Pierre: "c'est pas tres grave" but include as quick fix since some users expect it
- Logic exists in DictusKeyboardBridge (lines 296-311) -- likely a timing or state issue

### Responsiveness optimization (NEW -- incremental)
- Pierre reports the keyboard feels "un tout petit peu moins rapide que le clavier Apple"
- Specifically: haptic feedback feels slightly delayed, startup is a bit slow
- Reference: `assets/reference/report-ios-opti-keyboard.md` -- Apple keyboard optimization analysis
- Key findings from comparing report with our code:
  1. `prepare()` not called at keyboard startup (only in touchesBegan) -- first tap has higher latency
  2. Edge key delay creates global perception of slowness
  3. textDocumentProxy IPC is structurally slower than native keyboard (known limit, not fixable)
- Optimizations to investigate:
  - Pre-warm haptic generators in viewDidLoad (not just touchesBegan)
  - Measure actual latencies with OSSignposter/KeyTapSignposter
  - Profile on real device to identify bottlenecks
- CRITICAL CONSTRAINT: all optimizations must be incremental, never break zero dead zones
- Pierre: "il faudra qu'on fasse les choses petit a petit pour pas qu'on casse ce qu'on vient de faire"

### Zero dead zones preservation (CRITICAL CONSTRAINT)
- Phase 18 solved the long-standing dead zone problem -- this is the #1 achievement to protect
- Every change in Phase 19 must be validated against dead zones after implementation
- If any optimization introduces dead zones, revert immediately
- Touch pipeline modifications are the highest risk area -- test exhaustively

### Claude's Discretion
- Exact implementation approach for edge key touchDown fix (after research)
- Spacebar trackpad gesture arbitration with UICollectionView scroll
- Delete repeat timer integration with giellakbd-ios keyRepeatTimer
- Adaptive accent key placement in UIKit layout
- Order of implementation (suggest safest-first approach)
- Which report optimizations are safe to implement vs too risky
- OSSignposter measurement points for before/after comparison

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Apple keyboard optimization report
- `assets/reference/report-ios-opti-keyboard.md` -- Full analysis of Apple keyboard pipeline, latency budgets, haptic pre-warming, touch pipeline architecture, measurement methodology

### Phase 18 context and results
- `.planning/phases/18-keyboard-base/18-CONTEXT.md` -- Vendoring philosophy, key visual style, architecture decisions
- `.planning/phases/18-keyboard-base/18-UAT.md` -- 9/11 passed, 2 issues: edge key touchDown (test 10) and double-space period (test 7)

### Accent data
- `DictusCore/Sources/DictusCore/AccentedCharacters.swift` -- French accent mappings, adaptive key logic, case handling

### Keyboard architecture (current)
- `DictusKeyboard/Vendored/Views/KeyboardView.swift` -- UICollectionView keyboard, touch pipeline (touchesBegan/Moved/Ended), overlay system, long-press handling
- `DictusKeyboard/Vendored/Controllers/LongPressController.swift` -- LongPressOverlayController (accent popup) + LongPressCursorMovementController
- `DictusKeyboard/Vendored/Models/KeyDefinition.swift` -- KeyType enum, supportsRepeatTrigger, triggersOnTouchDown/Up
- `DictusKeyboard/Vendored/Models/KeyboardDefinition.swift` -- longPress dictionary structure
- `DictusKeyboard/DictusKeyboardBridge.swift` -- Delegate implementation, didTriggerKey, didSwipeKey, didMoveCursor
- `DictusKeyboard/FrenchKeyboardLayouts.swift` -- AZERTY/QWERTY definitions, empty frenchLongPress (to populate)

### Previous implementations (reference for behavior, not for code reuse)
- `DictusKeyboard/Views/SpecialKeyButton.swift` -- SwiftUI delete repeat (lines 79-155) and spacebar trackpad (lines 157-357) -- behavior reference only, UIKit reimplementation needed
- `DictusKeyboard/Views/AccentPopup.swift` -- SwiftUI accent popup component (may or may not be reusable)

### Feedback infrastructure
- `DictusCore/Sources/DictusCore/HapticFeedback.swift` -- Pre-allocated generators, warmUp(), keyTapped()
- `DictusKeyboard/TouchHandling/KeyTapSignposter.swift` -- OSSignposter instrumentation for latency measurement

### Requirements
- `.planning/REQUIREMENTS.md` -- KBD-05, KBD-08, FEEL-04, FEEL-05, FEEL-06

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AccentedCharacters` (DictusCore): Complete French accent mappings + adaptive key logic -- wire directly into frenchLongPress
- `LongPressOverlayController` (Vendored): Full accent popup with drag-to-select -- just needs data
- `LongPressCursorMovementController` (Vendored): Spacebar trackpad framework -- needs integration
- `keyRepeatTimer` (KeyboardView): Timer infrastructure for key repeat -- backspace already flagged
- `HapticFeedback` (DictusCore): Pre-allocated generators -- add viewDidLoad pre-warming
- `KeyTapSignposter`: OSSignposter for latency measurement -- use for before/after optimization comparison

### Established Patterns
- touchDown haptic (not touchUp) -- maintain this pattern
- Delegate chain: KeyboardView -> DictusKeyboardBridge -> textDocumentProxy
- ActiveKey + overlay system for popup display
- UICollectionView with static constraints (no Auto Layout churn)

### Integration Points
- `frenchLongPress` dictionary: empty, ready for AccentedCharacters.mappings data
- `didSwipeKey()` in bridge: currently calls didTriggerKey (no-op) -- needs accent handling
- `longpressKeys(for:)` in KeyboardView: returns nil when frenchLongPress is empty -- will work once populated
- `keyRepeatTimer` in KeyboardView: already triggers for keys with supportsRepeatTrigger = true

### Risk Areas
- Edge key hit testing: UICollectionView.indexPathForItem(at:) returns nil at screen edges
- Spacebar trackpad gesture vs UICollectionView built-in scroll/touch handling
- Any touch pipeline modification risks introducing dead zones

</code_context>

<specifics>
## Specific Ideas

- Pierre: accent character set from AccentedCharacters.swift is sufficient -- no international variants needed
- Pierre: edge key fix is the top priority -- "ca vient vraiment degrader l'experience utilisateur de saisie"
- Pierre: previous edge key fix attempts in Phase 18 were superficial -- Phase 19 needs deep research
- Pierre: double-space period is nice-to-have, include only if quick fix
- Pierre: keyboard feels slightly slower than Apple keyboard, especially haptic timing
- Pierre: report-ios-opti-keyboard.md should guide optimization research
- Pierre: all changes must be incremental -- zero dead zones is the #1 achievement to protect
- Pierre: "il faudra qu'on fasse les choses petit a petit pour pas qu'on casse ce qu'on vient de faire"

</specifics>

<deferred>
## Deferred Ideas

- International accent variants (ē, ė, ę, etc.) -- not needed for French, revisit if multilingual support requested
- Dictation mic button reintegration -- Phase 20
- Text prediction / suggestion bar -- Phase 20
- Emoji button on bottom row -- Phase 20
- Full latency profiling with MetricKit -- Phase 21 (Memory Profiling)
- Accessibility audit (VoiceOver labels on all keys) -- future phase

</deferred>

---

*Phase: 19-complex-touch-features*
*Context gathered: 2026-03-28*
