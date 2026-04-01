# Phase 19: Complex Touch Features - Research

**Researched:** 2026-03-28
**Domain:** UIKit touch handling, UICollectionView hit testing, gesture management in iOS keyboard extensions
**Confidence:** HIGH

## Summary

Phase 19 implements five distinct touch features on the existing giellakbd-ios UICollectionView keyboard: delete repeat with acceleration, accent long-press, spacebar trackpad, adaptive accent key, and double-space period fix. Additionally, it must fix the #1 UX issue from Phase 18 -- edge keys (a, q, p, m, etc.) firing haptic/popup on touchUp instead of touchDown -- and apply incremental responsiveness optimizations.

The research reveals that the edge key problem has TWO distinct root causes: (1) `UICollectionView.indexPathForItem(at:)` returns nil when the touch point lands outside cell bounds at screen edges, preventing activeKey from being set and thus preventing popup display; and (2) iOS system gesture recognizers (`UIScreenEdgePanGestureRecognizer`) at left/right/bottom screen edges delay touch delivery by ~150-300ms while iOS disambiguates between app touches and system gestures. Critically, `preferredScreenEdgesDeferringSystemGestures` does NOT work in keyboard extensions -- a nearest-cell fallback algorithm is the correct solution for the hit-testing issue, while the system gesture delay is a structural iOS limitation that can only be mitigated, not eliminated.

The double-space period bug has a clear root cause: `handleAutoFullStop()` checks for `text.suffix(2) == "  "` (two spaces already in buffer) but is called BEFORE inserting the second space, so only one space exists in the buffer at check time. Fix is straightforward.

**Primary recommendation:** Implement a nearest-cell fallback in `handleTouches()` when `indexPathForItem(at:)` returns nil, pre-warm haptic generators in `viewDidLoad`, wire accent data from existing `AccentedCharacters.mappings`, and leverage the existing giellakbd-ios infrastructure (LongPressOverlayController, LongPressCursorMovementController, keyRepeatTimer) for all complex touch features.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Accent character set: Use existing `AccentedCharacters.mappings` from DictusCore AS-IS, French-focused only
- Accent long-press UX: Use giellakbd-ios `LongPressOverlayController` as-is, data wiring only
- Adaptive accent key: Re-implement existing v1.1 behavior on UIKit keyboard
- Delete repeat: Use giellakbd-ios `keyRepeatTimer` infrastructure, accelerating speed pattern
- Spacebar trackpad: ~400ms hold activation, 8pt dead zone, haptic tick per character
- Edge key touchDown fix: PRIORITY -- #1 UX issue, needs deep research
- Double-space period: Quick fix, nice-to-have
- Responsiveness optimization: Incremental, never break zero dead zones
- Zero dead zones preservation: CRITICAL CONSTRAINT -- every change validated against dead zones

### Claude's Discretion
- Exact implementation approach for edge key touchDown fix (after research)
- Spacebar trackpad gesture arbitration with UICollectionView scroll
- Delete repeat timer integration with giellakbd-ios keyRepeatTimer
- Adaptive accent key placement in UIKit layout
- Order of implementation (suggest safest-first approach)
- Which report optimizations are safe to implement vs too risky
- OSSignposter measurement points for before/after comparison

### Deferred Ideas (OUT OF SCOPE)
- International accent variants (not needed for French)
- Dictation mic button reintegration (Phase 20)
- Text prediction / suggestion bar (Phase 20)
- Emoji button on bottom row (Phase 20)
- Full latency profiling with MetricKit (Phase 21)
- Accessibility audit (future phase)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| KBD-05 | User can delete characters with backspace, with accelerating repeat on hold | Existing keyRepeatTimer + increaseKeyRepeatRateIfNeeded() in GiellaKeyboardView. Needs acceleration stages (char-by-char -> word-level) and haptic per deletion. |
| KBD-08 | User gets double-space period insertion | Bug identified in handleAutoFullStop() -- checks for 2 spaces but only 1 exists when called. Simple logic fix. |
| FEEL-04 | User can long-press vowels to access French accent characters with drag-to-select | LongPressOverlayController fully functional. Only needs frenchLongPress dictionary populated from AccentedCharacters.mappings. |
| FEEL-05 | User can drag spacebar to move cursor (trackpad) with haptic ticks | LongPressCursorMovementController exists with 20pt delta. Needs refinement: 8pt dead zone, haptic ticks, acceleration curve from SwiftUI reference. |
| FEEL-06 | User sees adaptive accent key (apostrophe after consonants, accent after vowels) | AccentedCharacters.adaptiveKeyLabel() and shouldReplace() already implemented. Needs UIKit key wiring and state tracking in bridge. |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UIKit | iOS 17+ | Touch handling, UICollectionView, gesture recognizers | Native framework, zero overhead |
| DictusCore | internal | AccentedCharacters, HapticFeedback, KeyTapSignposter | Already contains all accent logic and haptic infrastructure |
| giellakbd-ios (vendored) | custom | GiellaKeyboardView, LongPressOverlayController, LongPressCursorMovementController | Already handles long-press overlay system, cursor movement, key repeat |
| os.signpost | iOS 17+ | OSSignposter for latency measurement | Apple's recommended performance instrumentation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AudioToolbox | system | Key click sounds (AudioServicesPlaySystemSound) | Already in use for 3-category sounds |
| CoreHaptics | system | Backup for fine-grained haptic control | Only if UIImpactFeedbackGenerator insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| keyRepeatTimer (Timer) | Task.sleep (async) | Timer is already working in giellakbd-ios; Task.sleep was used in SwiftUI version but Timer is more appropriate for UIKit touch pipeline |
| LongPressCursorMovementController | Custom spacebar tracking | Controller already handles baseline tracking and delta calculation; extend rather than replace |

**Installation:** No new dependencies needed. All required code exists in the project.

## Architecture Patterns

### Recommended Implementation Order (safest-first)

```
Wave 1: Data wiring (zero dead-zone risk)
├── Populate frenchLongPress from AccentedCharacters.mappings
├── Fix double-space period bug
└── Pre-warm haptic generators in viewDidLoad

Wave 2: Edge key fix (highest UX impact, moderate risk)
├── Nearest-cell fallback in handleTouches()
└── Validate zero dead zones after

Wave 3: Delete repeat enhancement (uses existing infra)
├── Add acceleration stages to keyRepeatTimer
├── Add word-level deletion
└── Add haptic per deletion

Wave 4: Spacebar trackpad refinement (moderate risk)
├── Enhance LongPressCursorMovementController
├── Add dead zone, acceleration, haptic ticks
└── Validate no dead zones from gesture changes

Wave 5: Adaptive accent key (new UI element)
├── Wire adaptive key into layout
├── State tracking in bridge
└── Replace-previous-character logic
```

### Pattern 1: Nearest-Cell Fallback for Edge Touches

**What:** When `collectionView.indexPathForItem(at:)` returns nil, iterate `visibleCells` to find the cell whose frame center is closest to the touch point, then use that cell's indexPath.

**When to use:** In `handleTouches()` when the standard indexPath lookup fails.

**Why this works:** `indexPathForItem(at:)` does strict bounds checking -- if the touch point is even 1pt outside a cell's frame, it returns nil. Edge keys have their outer edge flush with the screen, but the user's finger center may land slightly outside the cell bounds. The nearest-cell fallback finds the intended key without requiring any changes to cell sizing or collection view layout (which would risk dead zones).

**Example:**
```swift
// In GiellaKeyboardView.handleTouches()
private func handleTouches(_ touches: Set<UITouch>) {
    for touch in touches {
        let point = touch.location(in: collectionView)
        let indexPath: IndexPath?

        if let directPath = collectionView.indexPathForItem(at: point) {
            indexPath = directPath
        } else {
            // Fallback: find nearest visible cell
            indexPath = nearestIndexPath(to: point)
        }

        guard let indexPath = indexPath else { continue }
        // ... rest of existing logic unchanged
    }
}

/// Find the indexPath of the visible cell closest to the given point.
/// Only considers cells within a reasonable distance (half a key width)
/// to avoid phantom hits on distant keys.
private func nearestIndexPath(to point: CGPoint) -> IndexPath? {
    let maxDistance: CGFloat = bounds.width / CGFloat(currentPage.first?.count ?? 10) / 2.0
    var bestPath: IndexPath?
    var bestDistance: CGFloat = .greatestFiniteMagnitude

    for cell in collectionView.visibleCells {
        guard let path = collectionView.indexPath(for: cell) else { continue }
        let key = currentPage[path.section][path.row]
        // Skip spacers -- they're not tappable
        if case .spacer = key.type { continue }

        let center = cell.center
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance < bestDistance && distance < maxDistance {
            bestDistance = distance
            bestPath = path
        }
    }
    return bestPath
}
```

**CRITICAL:** This same fallback pattern must also be applied in `touchesFoundLongpress()` where `indexPathForItem(at:)` is used for long-press detection.

### Pattern 2: Delete Repeat with Acceleration Stages

**What:** Enhance the existing `keyRepeatTimer` to support three stages: initial delay, character-by-character, and word-by-word deletion.

**When to use:** For backspace key repeat behavior.

**Example:**
```swift
// Track deletion count for acceleration
private var deleteRepeatCount: Int = 0
private static let wordModeThreshold = 10

// In activeKey willSet, reset counter when key changes
if newValue == nil {
    deleteRepeatCount = 0
}

@objc func keyRepeatTimerDidTrigger() {
    if let activeKey = activeKey, activeKey.key.type.supportsRepeatTrigger {
        deleteRepeatCount += 1
        if deleteRepeatCount > Self.wordModeThreshold {
            delegate?.didTriggerHoldKey(activeKey.key)  // Word-level delete
        } else {
            delegate?.didTriggerKey(activeKey.key)       // Char-level delete
        }
        HapticFeedback.keyTapped()  // Haptic per deletion
        increaseKeyRepeatRateIfNeeded()
    }
}
```

### Pattern 3: Spacebar Trackpad Enhancement

**What:** Enhance the existing `LongPressCursorMovementController` with dead zone, acceleration, and haptic feedback. The current implementation uses a fixed 20pt delta -- enhance to match the SwiftUI reference implementation.

**When to use:** When the long-press gesture fires on spacebar.

**Key integration point:** The `LongPressCursorMovementController` already handles touch tracking and calls `delegate?.longpress(movedCursor:)`. The GiellaKeyboardView already fades the collection view to 0.4 alpha. Enhancements go inside the controller itself.

### Pattern 4: Double-Space Period Bug Fix

**What:** Fix the off-by-one error in `handleAutoFullStop()`.

**Root cause:** The function is called BEFORE inserting the second space. At call time, the buffer contains `[word_char][space]` -- only ONE trailing space. But the check requires `text.suffix(2) == "  "` (two spaces), which never matches.

**Fix:**
```swift
// BEFORE (broken): checks for 2 spaces but only 1 exists
guard let text = proxy.documentContextBeforeInput?.suffix(3),
      text.count == 3,
      text.suffix(2) == "  " else { return false }

// AFTER (fixed): check for 1 trailing space + word character before it
// Called before inserting second space, so buffer has: [char][space]
guard let text = proxy.documentContextBeforeInput,
      text.count >= 2,
      text.hasSuffix(" ") else { return false }
let beforeSpace = text[text.index(text.endIndex, offsetBy: -2)]
guard beforeSpace != " " && beforeSpace != "." else { return false }
// Delete the trailing space and insert ". "
proxy.deleteBackward()
proxy.insertText(". ")
return true
```

### Anti-Patterns to Avoid

- **Modifying UICollectionView contentInset to "expand" edge cells:** This changes the layout geometry and WILL introduce dead zones. The nearest-cell fallback is zero-risk to layout.
- **Using preferredScreenEdgesDeferringSystemGestures:** Does NOT work in keyboard extensions (UIInputViewController). Documented as non-functional in extensions.
- **Replacing Timer with async Task.sleep for key repeat:** Timer.scheduledTimer is already wired into the giellakbd-ios infrastructure and runs correctly on the main RunLoop. Switching to Task.sleep would require restructuring the touch pipeline.
- **Modifying cell frames or sizes to make edge keys larger:** Changes the UICollectionViewFlowLayout geometry and risks dead zones.
- **Adding gesture recognizers that conflict with the existing long-press recognizer:** The keyboard already has a UILongPressGestureRecognizer. Adding more recognizers creates arbitration complexity.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Accent popup display | Custom popup UIView | LongPressOverlayController | Already handles positioning, drag-to-select, multi-row layout, edge clamping |
| Cursor movement tracking | Custom drag handler | LongPressCursorMovementController | Already handles baseline, delta calculation, delegate callbacks |
| Key repeat timer | Custom Timer/Task logic | Existing keyRepeatTimer in GiellaKeyboardView | Already wired into activeKey lifecycle, handles invalidation on release |
| Haptic feedback | Direct UIImpactFeedbackGenerator calls | HapticFeedback enum (DictusCore) | Pre-allocated generators, caching, prepare() calls, enabled state check |
| Accent character data | Hardcoded dictionaries | AccentedCharacters.mappings | Already has French accents, case handling, adaptive key logic |
| Word-level deletion | Character-counting loops | deleteWordBackward() pattern from SwiftUI KeyboardView | Already handles trailing spaces, word boundary detection |
| Latency measurement | print(Date()) timestamps | KeyTapSignposter (OSSignposter) | Zero overhead when not profiling, Instruments integration |

**Key insight:** Phase 18 and the giellakbd-ios vendored code already contain 80% of the infrastructure needed. Phase 19 is primarily about wiring, enhancing, and fixing -- not building from scratch.

## Common Pitfalls

### Pitfall 1: Breaking Zero Dead Zones
**What goes wrong:** Any modification to the UICollectionView layout, cell sizes, content insets, or touch pipeline routing can re-introduce dead zones that took 4+ phases to eliminate.
**Why it happens:** The zero-dead-zone solution relies on precise cell sizing where cells fill the entire collection view bounds with zero inter-item spacing. Any geometric change breaks this invariant.
**How to avoid:** Never modify cell sizes, content insets, or collection view layout. Use the nearest-cell fallback pattern (overlay on top of existing geometry) rather than expanding cells. Test every change by tapping all edge keys and corner keys.
**Warning signs:** `indexPathForItem(at:)` starts returning nil for previously-working interior cells.

### Pitfall 2: System Gesture Delay at Screen Edges
**What goes wrong:** iOS system gesture recognizers (for swipe-to-go-back, Control Center, etc.) delay touch delivery to the keyboard by 150-300ms at left, right, and bottom screen edges. This creates perceived latency that CANNOT be fully eliminated.
**Why it happens:** iOS must disambiguate between the user tapping a key and performing a system gesture. `preferredScreenEdgesDeferringSystemGestures` does NOT work in keyboard extensions.
**How to avoid:** Accept this as a structural iOS limitation. Mitigate by ensuring haptic fires in touchesBegan (already done) and popup appears as soon as activeKey is set (nearest-cell fallback ensures this works for edge keys). The user perceives the delay as shorter when visual/haptic feedback is immediate.
**Warning signs:** Edge keys feel laggy on device but work fine in simulator (simulator doesn't have system gesture recognizers).

### Pitfall 3: Spacebar Trackpad Gesture Conflict
**What goes wrong:** The spacebar long-press gesture needs to coexist with: (1) the existing UILongPressGestureRecognizer on the view, (2) normal spacebar taps, and (3) potential scroll gestures.
**Why it happens:** UICollectionView has `isScrollEnabled = false` and `isUserInteractionEnabled = false`, which helps. But the long-press recognizer is on the GiellaKeyboardView itself, and it already handles spacebar (see `touchesFoundLongpress` spacebar case). The existing code already creates a LongPressCursorMovementController for spacebar.
**How to avoid:** Build on the existing spacebar case in `touchesFoundLongpress` rather than adding new gesture recognizers. The infrastructure already works -- just enhance the controller.
**Warning signs:** Space insertion stops working, or trackpad mode activates on every space tap.

### Pitfall 4: Key Repeat Timer Lifecycle
**What goes wrong:** Key repeat timer keeps firing after finger lifts, or doesn't reset between rapid backspace taps.
**Why it happens:** Timer invalidation in `activeKey.willSet` may race with `keyRepeatTimerDidTrigger()` on the RunLoop.
**How to avoid:** The existing pattern already handles this (timer is invalidated when activeKey becomes nil, which happens in touchesEnded). The deleteRepeatCount must be reset in the same willSet block.
**Warning signs:** Haptic keeps firing after finger lift, or word-mode deletion triggers on the first hold.

### Pitfall 5: Double-Space Period Timing with textDocumentProxy
**What goes wrong:** `documentContextBeforeInput` returns stale data, or IPC delay causes the check to see pre-previous state.
**Why it happens:** `textDocumentProxy` communicates via IPC with the host app. In rapid typing, the buffer may not reflect the most recent insertion.
**How to avoid:** Track the last inserted character locally in the bridge (e.g., `private var lastInsertedChar: String?`) as a supplement to proxy reads. This eliminates IPC latency for the double-space check.
**Warning signs:** Double-space period works in Notes but not in Messages (different IPC timing).

### Pitfall 6: Accent Long-Press Data Not Case-Aware
**What goes wrong:** Long-pressing "E" on shifted page shows lowercase accents (e, e, e, e) instead of uppercase (E, E, E, E).
**Why it happens:** `frenchLongPress` dictionary uses lowercase keys from `AccentedCharacters.mappings`, but shifted page has uppercase key labels.
**How to avoid:** The `longpressKeys(for:)` function in GiellaKeyboardView takes a string key. Populate `frenchLongPress` with lowercase keys, and in `touchesFoundLongpress`, use `string.lowercased()` for the lookup. The longpress overlay should apply case transformation based on current page state.
**Warning signs:** Long-press works on normal page but not on shifted page, or shows wrong case.

## Code Examples

### Populating frenchLongPress from AccentedCharacters

```swift
// In FrenchKeyboardLayouts.swift
// Replace empty dictionary with data from AccentedCharacters
private static let frenchLongPress: [String: [String]] = {
    var longPress: [String: [String]] = [:]
    for (baseKey, accents) in AccentedCharacters.mappings {
        longPress[baseKey] = accents
    }
    return longPress
}()
```

The `longpressKeys(for:)` method in GiellaKeyboardView already handles prepending the original key to the accent list (line 691-699). No changes needed there.

### Haptic Pre-warming in viewDidLoad

```swift
// In KeyboardContainerView or wherever the GiellaKeyboardView is set up
// Currently hapticFeedback.prepare() is called in touchesBegan (line 462)
// Add pre-warming at keyboard load:
override func viewDidLoad() {
    super.viewDidLoad()
    // Pre-warm all haptic generators so first tap has zero latency
    HapticFeedback.warmUp()
    // ... rest of setup
}
```

### Adaptive Accent Key State Tracking

```swift
// In DictusKeyboardBridge
private var lastTypedCharacter: String?

private func handleInputKey(_ character: String) {
    // ... existing logic ...
    controller?.textDocumentProxy.insertText(character)
    lastTypedCharacter = character
    // ... rest of existing logic ...
}

// New method for adaptive key press
func handleAdaptiveAccentKey() {
    let label = AccentedCharacters.adaptiveKeyLabel(afterTyping: lastTypedCharacter)
    if AccentedCharacters.shouldReplace(afterTyping: lastTypedCharacter) {
        // Replace previous vowel with accented version
        controller?.textDocumentProxy.deleteBackward()
        controller?.textDocumentProxy.insertText(label)
    } else {
        // Insert apostrophe
        controller?.textDocumentProxy.insertText(label)
    }
    lastTypedCharacter = label
    updateCapitalization()
}
```

### Word-Level Deletion for Delete Repeat

```swift
// In DictusKeyboardBridge, add word-level deletion method
private func handleWordDelete() {
    AudioServicesPlaySystemSound(KeySound.delete)
    guard let proxy = controller?.textDocumentProxy,
          let before = proxy.documentContextBeforeInput, !before.isEmpty else {
        proxy?.deleteBackward()
        return
    }

    // Trim trailing spaces
    var trimmed = before
    var trailingSpaces = 0
    while trimmed.hasSuffix(" ") {
        trimmed = String(trimmed.dropLast())
        trailingSpaces += 1
    }

    // Find word boundary
    let charsInWord: Int
    if let lastSpace = trimmed.lastIndex(of: " ") {
        charsInWord = trimmed.distance(from: trimmed.index(after: lastSpace), to: trimmed.endIndex)
    } else {
        charsInWord = trimmed.count
    }

    // Delete trailing spaces + word
    let total = trailingSpaces + charsInWord
    for _ in 0..<max(1, total) {
        proxy.deleteBackward()
    }
    updateCapitalization()
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SwiftUI keyboard with DragGesture | UIKit UICollectionView keyboard (giellakbd-ios) | Phase 18 (2026-03-28) | Eliminated dead zones, better touch handling |
| Custom accent popup (AccentPopup.swift) | LongPressOverlayController (vendored) | Phase 18 | Production-proven overlay system with drag-to-select |
| Task.sleep for key repeat | Timer.scheduledTimer | Phase 18 | More reliable in UIKit touch pipeline |

**Deprecated/outdated:**
- SwiftUI keyboard approach: 16 attempts failed, UIKit rebuild succeeded
- preferredScreenEdgesDeferringSystemGestures for keyboard extensions: Does not work
- Custom gesture recognizers for trackpad: Existing LongPressCursorMovementController is sufficient

## Open Questions

1. **System gesture delay magnitude on device**
   - What we know: iOS delays touch at screen edges by 150-300ms for gesture disambiguation
   - What's unclear: Exact delay on iPhone 15/16/17 with iOS 17+; whether it's consistent across edges (left vs right vs bottom)
   - Recommendation: Measure with OSSignposter on physical device during Phase 19 implementation. Accept as structural limitation, mitigate with immediate haptic on touchesBegan.

2. **Adaptive accent key placement in AZERTY layout**
   - What we know: v1.1 had it on row 3; current UIKit layout has shift + 6 letters + backspace on row 3
   - What's unclear: Where exactly to place it without disrupting existing layout balance
   - Recommendation: Place as rightmost key before backspace on row 3 (replacing "n" position or as additional key). Or add to bottom row. Leave to implementation discretion.

3. **LongPressCursorMovementController delta sensitivity**
   - What we know: Current delta is 20pt (hardcoded). SwiftUI reference used 12pt base with cosine acceleration.
   - What's unclear: Whether the enhanced algorithm (dead zone + acceleration + rate limiting) should go in the controller or in the view.
   - Recommendation: Enhance the controller itself to keep the separation of concerns. Add configurable parameters.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing on physical device (keyboard extensions cannot run unit tests for touch pipeline) |
| Config file | none |
| Quick run command | `xcodebuild build -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Full suite command | Build + install on device + manual UAT |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| KBD-05 | Backspace hold deletes with acceleration | manual | Build + hold backspace on device | N/A |
| KBD-08 | Double-space inserts period+space | manual | Build + type word-space-space on device | N/A |
| FEEL-04 | Long-press vowel shows accent popup | manual | Build + long-press "e" on device | N/A |
| FEEL-05 | Spacebar drag moves cursor | manual | Build + long-press spacebar + drag on device | N/A |
| FEEL-06 | Adaptive accent key shows correct label | manual | Build + type vowel, check key label on device | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme DictusKeyboard` (compilation check)
- **Per wave merge:** Full manual test of all features + edge key dead zone validation
- **Phase gate:** Full UAT covering all 5 requirements + edge key fix + zero dead zones

### Wave 0 Gaps
None -- existing build infrastructure covers compilation. Touch feature testing is inherently manual for keyboard extensions.

## Sources

### Primary (HIGH confidence)
- GiellaKeyboardView.swift source code -- touch pipeline, overlay system, key repeat timer, long-press handling
- LongPressController.swift source code -- LongPressOverlayController and LongPressCursorMovementController
- DictusKeyboardBridge.swift source code -- delegate implementation, double-space bug
- AccentedCharacters.swift source code -- French accent mappings, adaptive key logic
- HapticFeedback.swift source code -- pre-allocated generators, warmUp(), all feedback methods
- SpecialKeyButton.swift source code -- reference delete repeat and trackpad implementations
- KeyDefinition.swift source code -- KeyType enum, triggersOnTouchDown, supportsRepeatTrigger

### Secondary (MEDIUM confidence)
- [Apple Developer: indexPathForItem(at:)](https://developer.apple.com/documentation/uikit/uicollectionview/1618030-indexpathforitem) -- returns nil when point is outside any cell bounds
- [Apple Developer: preferredScreenEdgesDeferringSystemGestures](https://developer.apple.com/documentation/uikit/uiviewcontroller/preferredscreenedgesdeferringsystemgestures) -- does not work in keyboard extensions
- [Igor Kulman: Why iOS gestures lag at screen edges](https://blog.kulman.sk/why-ios-gestures-lag-at-the-screen-edges/) -- system gesture disambiguation delay explanation
- [iOS Questions: preferredScreenEdgesDeferringSystemGestures in keyboard extension doesn't work](https://iosquestions.com/preferredscreenedgesdeferringsystemgestures-in-keyboard-extension-doesnt-work/) -- confirmed non-functional in extensions
- [Apple Developer Forums: Custom keyboard extension left edge detecting touch after delay](https://developer.apple.com/forums/thread/654645) -- known issue with edge touch delay
- [Apple: UITextDocumentProxy](https://developer.apple.com/documentation/uikit/uitextdocumentproxy) -- adjustTextPosition(byCharacterOffset:) for cursor movement
- assets/reference/report-ios-opti-keyboard.md -- Apple keyboard optimization analysis, haptic pre-warming, pipeline architecture

### Tertiary (LOW confidence)
- [Khanlou: Hacking Hit Tests](https://khanlou.com/2018/09/hacking-hit-tests/) -- hitTest/pointInside override patterns (general iOS, not keyboard-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all libraries already in project, just need wiring
- Architecture: HIGH -- existing infrastructure covers 80% of needs, patterns well-understood from source code analysis
- Edge key fix: MEDIUM -- nearest-cell fallback is sound approach but system gesture delay is structural limitation
- Pitfalls: HIGH -- identified from real Phase 18 UAT issues and code analysis
- Double-space bug: HIGH -- root cause identified directly from code analysis

**Research date:** 2026-03-28
**Valid until:** 2026-04-28 (stable -- no external dependencies, all code is vendored/internal)
