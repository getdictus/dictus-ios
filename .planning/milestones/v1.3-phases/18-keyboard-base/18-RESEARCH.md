# Phase 18: Keyboard Base - Research

**Researched:** 2026-03-27
**Domain:** UICollectionView-based keyboard (giellakbd-ios vendoring) + Dictus integration
**Confidence:** HIGH

## Summary

Phase 18 replaces the current SwiftUI keyboard grid with vendored UIKit files from giellakbd-ios (divvun/giellakbd-ios). The open-source project implements a UICollectionView-based keyboard with custom touch handling that bypasses the collection view's user interaction entirely -- touches are processed directly by the parent KeyboardView via touchesBegan/Moved/Ended, which is what eliminates dead zones. The giellakbd-ios architecture maps cleanly to Dictus's needs: it has a KeyboardView (UIView with UICollectionView), KeyView (individual key cell rendering), KeyOverlayView (popup preview), and a KeyboardViewController with delegate callbacks for key actions.

Critical finding: giellakbd-ios's KeyboardDefinitions.json only contains a Sami ("se") layout, not French. The French AZERTY/QWERTY layouts must be created either by writing a JSON definition or by programmatically constructing KeyboardDefinition objects using the existing Dictus KeyboardLayout data. The giellakbd-ios codebase depends on DeviceKit (for screen diagonal-based height calculation), DivvunSpell, Sentry, RxSwift, and SQLite -- of these, only DeviceKit is needed for Dictus. All other dependencies (DivvunSpell, Sentry, RxSwift, SQLite) must be stripped from vendored files.

The integration approach is: vendor ~10 source files from giellakbd-ios Keyboard/ directory, strip external dependencies (Sentry, DivvunSpell, RxSwift), create French keyboard layout definitions, adapt KeyboardViewController to delegate key actions to Dictus's existing infrastructure (textDocumentProxy, HapticFeedback, KeySound), and bridge the UIKit KeyboardView into the existing SwiftUI KeyboardRootView hierarchy (toolbar stays SwiftUI, keyboard below becomes UIKit).

**Primary recommendation:** Vendor giellakbd-ios Views (KeyboardView, KeyView, KeyOverlayView) + Models (KeyDefinition, KeyboardDefinition, Theme, DeviceContext, KeyboardHeightProvider, InputContext, SystemKeys) + Controllers (LongPressController, Audio, DeadKeyHandler). Strip all Sentry/DivvunSpell/RxSwift/SQLite references. Create French AZERTY/QWERTY layout definitions. Wire Dictus HapticFeedback + KeySound into the delegate callbacks.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Use giellakbd-ios source files AS-IS with MINIMAL modifications
- The open source keyboard already looks nearly identical to Apple's keyboard -- that's the goal
- Do NOT customize key visual style, shadows, colors, or shapes beyond what giellakbd-ios provides
- Every style customization is a potential dead zone risk -- avoid them
- Priority is ZERO DEAD ZONES over visual customization
- Brand identity comes from toolbar mic button with Dictus blue, not from keys
- iOS native adaptive: keys follow system light/dark mode automatically (giellakbd-ios default)
- Special keys use giellakbd-ios default styling
- Dictus accent (#3D7EFF blue) only on toolbar mic button
- Key popup preview: use giellakbd-ios KeyOverlayView as-is
- Haptic & sound: keep Dictus HapticFeedback.keyTapped() + 3-category AudioServicesPlaySystemSound, wire into giellakbd-ios touch handling
- Globe key is NOT part of layout -- iOS provides it below third-party keyboards
- Bottom row Phase 18: [123] [SPACE] [RETURN] only (no emoji, no mic in layout)
- Use giellakbd-ios French layout if available and 90%+ similar to iOS stock

### Claude's Discretion
- Exact giellakbd-ios files to vendor and any minimal adaptations needed
- How to bridge UICollectionView keyboard into existing KeyboardViewController
- DeviceKit integration approach for keyboard height calculation
- How to wire Dictus haptic/sound calls into giellakbd-ios touch handlers
- Autocapitalization and double-space period implementation details
- Shift/caps lock state machine implementation

### Deferred Ideas (OUT OF SCOPE)
- Emoji button on bottom row -- Phase 20
- Emoji picker integration -- Phase 20
- Dictation mic button in toolbar -- Phase 20
- Text prediction / suggestion bar -- Phase 20
- Accent long-press (French accents) -- Phase 19
- Spacebar trackpad -- Phase 19
- Delete repeat acceleration -- Phase 19
- Adaptive accent key -- Phase 19
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| KBD-01 | UICollectionView-based AZERTY keyboard with zero dead zones | giellakbd-ios KeyboardView uses UICollectionView with touch handling that bypasses collection view interaction -- touches go through KeyboardView.touchesBegan/Moved/Ended directly, eliminating dead zones |
| KBD-02 | QWERTY layout switch in settings | KeyboardDefinition supports multiple layouts via JSON or programmatic construction; Dictus already has QWERTY data in KeyboardLayout.swift |
| KBD-03 | Shift toggle (single tap) and caps lock (double tap) with visual feedback | giellakbd-ios KeyboardPage enum has .normal/.shifted/.capslock; KeyboardViewController handles shift via page switching; double-tap detected via KeyTriggerTiming |
| KBD-04 | Switch between letters, numbers, symbols layers | KeyboardPage has .symbols1/.symbols2; alternatePage() toggles between character and symbol pages |
| KBD-06 | Space, return, globe key for switching keyboards | SystemKeys generates bottom row with spacebar + return; globe key handled by iOS automatically below third-party keyboards |
| KBD-07 | Autocapitalization after sentence-ending punctuation | giellakbd-ios updateCapitalization() reads textDocumentProxy.autocapitalizationType and InputContext; Dictus already has checkAutocapitalize() logic |
| KBD-08 | Double-space period insertion | giellakbd-ios handleAutoFullStop() detects double-space and replaces with ". " -- proven implementation |
| FEEL-01 | Haptic feedback on touchDown matching Apple feel | Dictus HapticFeedback.keyTapped() uses pre-allocated UIImpactFeedbackGenerator(.light); wire into giellakbd-ios delegate callback |
| FEEL-02 | 3-category key sounds respecting silent switch | Dictus KeySound enum (1104/1155/1156) via AudioServicesPlaySystemSound; giellakbd-ios Audio class uses same sound IDs |
| FEEL-03 | Key popup preview on press | giellakbd-ios KeyOverlayView + LongPressController provide popup preview using bezier path rendering + GhostKeyView positioning |
</phase_requirements>

## Standard Stack

### Core (Vendored from giellakbd-ios)
| File | Source | Purpose | Modifications Needed |
|------|--------|---------|---------------------|
| KeyboardView.swift | Keyboard/Views/ | UICollectionView-based keyboard with touch handling | Remove Sentry imports, adapt delegate to Dictus controller |
| KeyView.swift | Keyboard/Views/ | Individual key cell rendering (UIView) | No changes expected -- styling via Theme |
| KeyOverlayView.swift | Keyboard/Views/ | Key popup preview (bezier path, GhostKeyView) | No changes expected |
| KeyDefinition.swift | Keyboard/Models/ | Key type enum + sizing model | No changes expected |
| KeyboardDefinition.swift | Keyboard/Models/ | Layout structure (rows, pages, locale) | Add French AZERTY/QWERTY layout data |
| Theme.swift | Keyboard/Models/ | Color/font/metric theming, light/dark mode | No changes -- provides iOS-native adaptive appearance |
| DeviceContext.swift | Keyboard/Models/ | Device detection via DeviceKit | Keep as-is, add DeviceKit SPM dependency |
| KeyboardHeightProvider.swift | Keyboard/Models/ | Per-device keyboard height lookup | No changes -- proven height table |
| InputContext.swift | Keyboard/Models/ | Word extraction from textDocumentProxy | Remove DivvunSpell import if present |
| SystemKeys.swift | Keyboard/Models/ | Bottom row generation (symbols, space, return) | Adapt for Phase 18 simplified bottom row |
| LongPressController.swift | Keyboard/Controllers/ | Long-press overlay positioning + selection | No changes expected |
| DeadKeyHandler.swift | Keyboard/Controllers/ | Multi-step dead key transformations | Keep for future accent support (Phase 19) |
| Audio.swift | Keyboard/Controllers/ | Sound playback (3 categories) | Replace with Dictus KeySound calls or adapt |

### New SPM Dependency
| Library | Version | Purpose | Why Needed |
|---------|---------|---------|------------|
| DeviceKit | ~> 5.8 | Screen diagonal detection for keyboard height | giellakbd-ios KeyboardHeightProvider + DeviceContext depend on it; proven per-device height tables |

### Files NOT to Vendor (Dependencies We Don't Need)
| File | Reason |
|------|--------|
| CursorContext.swift | Depends on DivvunSpell |
| UserDictionary*.swift | Depends on SQLite.swift |
| UserDictionaryService.swift | Depends on SQLite.swift |
| WordContext.swift | May depend on DivvunSpell |
| IPC.swift | Divvun-specific inter-process communication |
| FolderWatcher.swift | Divvun-specific file watching |
| DownloadSimulator.swift | Test utility |
| ViewDebugger.swift | Debug utility |
| SplitKeyboard.swift | iPad split keyboard (out of scope) |
| BannerManager.swift | Divvun banner (out of scope) |
| EntryPoint.swift | Divvun-specific subclass |
| KeyboardLocale*.swift | Divvun locale system (we define layouts directly) |
| init.m | Objective-C init (not needed) |
| Keyboard-Bridging-Header.h | Not needed without ObjC |

### Existing Dictus Files to KEEP
| File | Purpose |
|------|---------|
| HapticFeedback.swift (DictusCore) | Pre-allocated haptic generators, cached enabled state |
| InputView.swift | KeyboardInputView (UIInputViewAudioFeedback) |
| KeyboardState.swift | Cross-process state, Darwin notifications |
| KeyboardRootView.swift | SwiftUI root (toolbar + recording overlay) -- ADAPT |
| KeyboardViewController.swift | UIInputViewController -- ADAPT significantly |
| ToolbarView.swift | SwiftUI toolbar (stays as-is) |
| RecordingOverlay.swift | Recording UI (stays as-is) |
| KeyboardLayout.swift | AZERTY/QWERTY layout DATA -- map to giellakbd-ios format |

### Existing Dictus Files to REMOVE (replaced by giellakbd-ios)
| File | Replaced By |
|------|-------------|
| Views/KeyboardView.swift (SwiftUI) | giellakbd-ios KeyboardView (UIKit) |
| Views/KeyButton.swift | giellakbd-ios KeyView |
| Views/SpecialKeyButton.swift | giellakbd-ios KeyView (all key types) |
| Views/KeyRow.swift | giellakbd-ios KeyboardView (rows via UICollectionView sections) |
| Views/AccentPopup.swift | giellakbd-ios KeyOverlayView (Phase 19) |
| Models/KeyDefinition.swift | giellakbd-ios KeyDefinition (different model) |
| Models/KeyboardLayer.swift | giellakbd-ios KeyboardPage enum |
| KeyMetrics + DeviceClass (in KeyButton.swift) | giellakbd-ios Theme + DeviceContext + KeyboardHeightProvider |

**Installation:**
```
# Add DeviceKit to Xcode project via SPM:
# https://github.com/devicekit/DeviceKit.git
# Version: Up to Next Major from 5.8.0
# Add to DictusKeyboard target
```

## Architecture Patterns

### Recommended Project Structure
```
DictusKeyboard/
├── KeyboardViewController.swift     # ADAPT: host UIKit keyboard instead of SwiftUI
├── KeyboardRootView.swift           # ADAPT: embed UIKit keyboard in SwiftUI hierarchy
├── KeyboardState.swift              # KEEP: cross-process state (unchanged)
├── InputView.swift                  # KEEP: UIInputViewAudioFeedback
├── Vendored/                        # NEW: giellakbd-ios vendored files
│   ├── Views/
│   │   ├── KeyboardView.swift       # UICollectionView keyboard
│   │   ├── KeyView.swift            # Key cell rendering
│   │   └── KeyOverlayView.swift     # Popup preview
│   ├── Models/
│   │   ├── KeyDefinition.swift      # Key type + sizing
│   │   ├── KeyboardDefinition.swift # Layout structure
│   │   ├── Theme.swift              # Visual theming
│   │   ├── DeviceContext.swift      # Device detection
│   │   ├── KeyboardHeightProvider.swift # Height calculation
│   │   ├── InputContext.swift       # Word extraction
│   │   └── SystemKeys.swift         # Bottom row keys
│   └── Controllers/
│       ├── LongPressController.swift # Long-press overlay
│       ├── DeadKeyHandler.swift      # Dead key transforms
│       └── Audio.swift               # Sound playback
├── DictusKeyboardBridge.swift       # NEW: adapter between giellakbd-ios delegates and Dictus
├── FrenchKeyboardLayouts.swift      # NEW: AZERTY/QWERTY definitions for giellakbd-ios format
├── Models/
│   ├── KeyboardLayout.swift         # KEEP temporarily for data reference during migration
│   └── RecentEmojis.swift           # KEEP for Phase 20
├── Views/
│   ├── ToolbarView.swift            # KEEP: SwiftUI toolbar
│   ├── RecordingOverlay.swift       # KEEP: recording UI
│   ├── EmojiPickerView.swift        # KEEP for Phase 20
│   └── ... (emoji views)            # KEEP for Phase 20
├── TextPrediction/                  # KEEP for Phase 20
└── TouchHandling/                   # May be replaceable by giellakbd-ios touch handling
```

### Pattern 1: UIKit Keyboard Embedded in SwiftUI Chrome
**What:** The keyboard grid is a UIKit UIView (giellakbd-ios KeyboardView) while the toolbar and recording overlay remain SwiftUI views. The UIKit keyboard is wrapped in UIViewRepresentable for embedding in the SwiftUI hierarchy.
**When to use:** When SwiftUI cannot deliver zero dead zones but UIKit can (proven by 16 failed SwiftUI attempts).
**Example:**
```swift
// UIViewRepresentable wrapper for giellakbd-ios KeyboardView
struct GiellaKeyboardWrapper: UIViewRepresentable {
    let definition: KeyboardDefinition
    let theme: Theme
    weak var delegate: KeyboardViewDelegate?

    func makeUIView(context: Context) -> KeyboardView {
        let view = KeyboardView(definition: definition, theme: theme)
        view.delegate = delegate
        return view
    }

    func updateUIView(_ uiView: KeyboardView, context: Context) {
        // Update page/shift state if needed
    }
}
```

### Pattern 2: Delegate Bridge (giellakbd-ios -> Dictus Actions)
**What:** A bridge object implements giellakbd-ios's KeyboardViewDelegate and translates callbacks into Dictus actions (textDocumentProxy operations, haptics, sounds).
**When to use:** Always -- this is how vendored keyboard communicates with Dictus.
**Example:**
```swift
class DictusKeyboardBridge: NSObject, KeyboardViewDelegate, KeyboardViewKeyboardKeyDelegate {
    weak var controller: UIInputViewController?
    private var lastInput: String = ""

    func didTriggerKey(_ key: KeyType) {
        switch key {
        case .input(let char, _):
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.letter)
            controller?.textDocumentProxy.insertText(char)
            handleAutoCapitalization()

        case .backspace:
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.delete)
            controller?.textDocumentProxy.deleteBackward()

        case .spacebar:
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.modifier)
            handleAutoFullStop()
            controller?.textDocumentProxy.insertText(" ")
            handleAutoCapitalization()

        case .returnkey:
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.modifier)
            controller?.textDocumentProxy.insertText("\n")
            handleAutoCapitalization()

        // ... other key types
        }
    }
}
```

### Pattern 3: French Layout Definition
**What:** Since giellakbd-ios only includes a Sami layout, create French AZERTY/QWERTY KeyboardDefinition objects programmatically using the data from existing KeyboardLayout.swift.
**When to use:** At keyboard initialization.
**Example:**
```swift
// Map existing Dictus layout data to giellakbd-ios KeyDefinition format
static func frenchAZERTY() -> KeyboardDefinition {
    let normal: [[KeyDefinition]] = [
        // Row 1
        ["a","z","e","r","t","y","u","i","o","p"].map {
            KeyDefinition(type: .input(key: $0, alternate: nil), size: CGSize(width: 1, height: 1))
        },
        // Row 2
        ["q","s","d","f","g","h","j","k","l","m"].map {
            KeyDefinition(type: .input(key: $0, alternate: nil), size: CGSize(width: 1, height: 1))
        },
        // Row 3 with shift + delete
        [
            KeyDefinition(type: .shift, size: CGSize(width: 1.5, height: 1)),
            // ... letter keys ...
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: system keys (generated by SystemKeys)
    ]
    // ... shifted, symbols1, symbols2 variants
}
```

### Pattern 4: Touch-Based Feedback (touchDown, not touchUp)
**What:** Haptic and audio feedback fires on touchesBegan (touchDown), not on touchesEnded. This matches Apple's native keyboard feel.
**When to use:** Always -- the giellakbd-ios KeyboardView.touchesBegan is where feedback should be triggered.
**Why:** giellakbd-ios already handles touch detection and triggers keys via delegate. The delegate callback for keys with `triggersOnTouchDown = true` (shift, backspace, symbols) fires immediately on touch. For input keys, touch triggers on touchUp. Haptic/sound should fire on the same event as the key trigger.

### Anti-Patterns to Avoid
- **Customizing KeyView colors/shadows:** Every visual modification risks breaking touch area calculations. The Theme handles all styling -- use it as-is.
- **Adding SwiftUI overlays on UIKit keys:** Mixed SwiftUI/UIKit touch handling causes dead zones. Only the toolbar and recording overlay are SwiftUI.
- **Creating a new UICollectionView layout:** giellakbd-ios uses UICollectionViewFlowLayout with manual cell sizing via sizeForItemAt. Do not switch to UICollectionViewCompositionalLayout.
- **Disabling `collectionView.isUserInteractionEnabled`:** giellakbd-ios explicitly sets this to false because touches are handled by the parent KeyboardView. Do not re-enable it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Key popup preview | Custom CALayer or SwiftUI overlay | giellakbd-ios KeyOverlayView | Bezier path rendering with GhostKeyView positioning handles edge cases (left/right screen edges, top row clipping) |
| Keyboard height per device | Screen bounds heuristic | giellakbd-ios KeyboardHeightProvider + DeviceKit | Tested height lookup table for all iPhone models from 4.7" to 6.9" |
| Touch-to-key mapping | Hit testing on individual views | giellakbd-ios KeyboardView touch handling | Direct touch coordinate math against collection view layout eliminates dead zones between cells |
| Key styling (light/dark) | Custom Color/UIColor definitions | giellakbd-ios Theme + ThemeFactory | Handles legacy/modern iOS styles, device-specific metrics, light/dark mode automatically |
| Double-space period | Custom string manipulation | giellakbd-ios handleAutoFullStop() | Proven 3-character lookback implementation |
| Device type detection | UIScreen.main.bounds heuristic | DeviceKit Device.current | Reliable device identification including notch/Dynamic Island detection |

## Common Pitfalls

### Pitfall 1: Stripping Dependencies Incompletely
**What goes wrong:** Vendored files fail to compile because of lingering imports (Sentry, DivvunSpell, RxSwift).
**Why it happens:** giellakbd-ios imports these throughout the codebase, not just in obvious places. Sentry is used for logging/breadcrumbs in KeyboardView and KeyboardViewController.
**How to avoid:** After vendoring, do a project-wide search for `import Sentry`, `import DivvunSpell`, `import RxSwift`, `import SQLite`, `SentrySDK`, `SentryBreadcrumb`. Replace Sentry logging calls with PersistentLog equivalents or remove them.
**Warning signs:** Build errors mentioning missing modules after adding vendored files.

### Pitfall 2: French Layout Not Matching iOS Stock
**What goes wrong:** Numbers/symbols layers don't match what French users expect.
**Why it happens:** giellakbd-ios has no French layout. Creating one from scratch may miss iOS-specific key placements (e.g., Euro sign position, French punctuation).
**How to avoid:** Use existing Dictus KeyboardLayout.swift data (numbersRows, symbolsRows) which was already designed to match iOS stock French. Map this data to giellakbd-ios KeyDefinition format.
**Warning signs:** User complaints about key positions feeling "wrong" compared to Apple keyboard.

### Pitfall 3: Height Mismatch Between UIKit Keyboard and SwiftUI Chrome
**What goes wrong:** Toolbar overlaps keyboard or gap appears between them.
**Why it happens:** giellakbd-ios KeyboardHeightProvider calculates total keyboard height including all rows. Dictus needs to split this into toolbar height (SwiftUI) + key grid height (UIKit). The heights must add up to the constraint on inputView.
**How to avoid:** Use KeyboardHeightProvider for key grid height only. Add toolbar height separately in KeyboardViewController.computeKeyboardHeight(). Test on multiple device sizes.
**Warning signs:** Visual gap or overlap at toolbar/keyboard boundary.

### Pitfall 4: KeyboardInputView (Audio Feedback) Not Connected
**What goes wrong:** Key click sounds don't play via playInputClick().
**Why it happens:** giellakbd-ios's Audio class uses AudioServicesPlaySystemSound (same as Dictus KeySound), which works independently. But if someone tries to use UIDevice.playInputClick(), it requires the inputView to conform to UIInputViewAudioFeedback and return true from enableInputClicksWhenVisible.
**How to avoid:** Keep using AudioServicesPlaySystemSound (KeySound enum) for key sounds. The existing KeyboardInputView stays as the controller's inputView. Do NOT switch to playInputClick().
**Warning signs:** Silent key presses.

### Pitfall 5: Shift State Machine Out of Sync
**What goes wrong:** Visual shift indicator shows "shifted" but keys output lowercase, or vice versa.
**Why it happens:** giellakbd-ios manages shift via KeyboardPage (.normal/.shifted/.capslock), while Dictus had a separate ShiftState enum. If both systems exist, they can desync.
**How to avoid:** Use ONLY giellakbd-ios's page-based shift management. Remove Dictus ShiftState enum. The KeyboardView.page property is the single source of truth for shift state.
**Warning signs:** Shift key appears pressed but typed characters are lowercase.

### Pitfall 6: UIViewRepresentable Lifecycle Issues
**What goes wrong:** KeyboardView doesn't resize on rotation, or gets recreated unnecessarily by SwiftUI.
**Why it happens:** SwiftUI may recreate UIViewRepresentable views when parent state changes (e.g., recording overlay toggle). The UICollectionView loses its scroll position/state.
**How to avoid:** Use Coordinator pattern in UIViewRepresentable. Consider making the KeyboardView a persistent UIView added directly to the inputView hierarchy (not via SwiftUI), while keeping only the toolbar in SwiftUI. This is actually the recommended approach -- add UIKit keyboard as a sibling of the SwiftUI hosting view, not embedded within it.
**Warning signs:** Keyboard flickers or resets when toggling recording overlay.

### Pitfall 7: Memory Budget Exceeded
**What goes wrong:** Keyboard extension gets killed by iOS jetsam.
**Why it happens:** DeviceKit adds ~1-2MB. giellakbd-ios UICollectionView + key cells add memory. If not careful with cell reuse, memory grows.
**How to avoid:** UICollectionView with cell reuse (dequeueReusableCell) keeps memory bounded. giellakbd-ios KeyCell is lightweight. DeviceKit impact is minimal. Monitor with Instruments.
**Warning signs:** Keyboard crashes after extended use or rapid layer switching.

## Code Examples

### Auto-Capitalization (from giellakbd-ios, verified)
```swift
// Source: giellakbd-ios KeyboardViewController
func updateCapitalization() {
    let proxy = textDocumentProxy
    guard let autocapType = proxy.autocapitalizationType else { return }

    switch autocapType {
    case .words:
        // Shift after space
        if InputContext.from(proxy: proxy).currentWord.isEmpty {
            keyboardView.page = .shifted
        }
    case .sentences:
        // Shift after sentence-ending punctuation
        let context = InputContext.from(proxy: proxy)
        if context.currentWord.isEmpty && context.previousWord?.last?.isSentenceEnding == true {
            keyboardView.page = .shifted
        } else if proxy.documentContextBeforeInput?.isEmpty ?? true {
            keyboardView.page = .shifted
        }
    case .allCharacters:
        keyboardView.page = .capslock
    default:
        break
    }
}
```

### Double-Space Period Insertion (from giellakbd-ios, verified)
```swift
// Source: giellakbd-ios KeyboardViewController.handleAutoFullStop()
private func handleAutoFullStop() {
    let proxy = textDocumentProxy
    if let text = proxy.documentContextBeforeInput?.suffix(3),
       text.count == 3 && text.suffix(2) == "  " {
        let first = text.prefix(1)
        if first != "." && first != " " {
            proxy.deleteBackward()
            proxy.deleteBackward()
            proxy.insertText(". ")
        }
    }
}
```

### giellakbd-ios Touch Handling Architecture (verified)
```swift
// Source: giellakbd-ios KeyboardView
// The collection view has user interaction DISABLED.
// All touches are handled by the parent KeyboardView directly.
collectionView.isUserInteractionEnabled = false

override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let point = touch.location(in: collectionView)

    // Find which cell contains this point
    if let indexPath = collectionView.indexPathForItem(at: point),
       let cell = collectionView.cellForItem(at: indexPath) as? KeyCell {
        // Track active key, trigger if triggersOnTouchDown
        activeKey = ActiveKey(indexPath: indexPath, key: cell.key)
        if cell.key.type.triggersOnTouchDown {
            delegate?.didTriggerKey(cell.key.type)
        }
    }
}

override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let active = activeKey else { return }
    if !active.key.type.triggersOnTouchDown {
        delegate?.didTriggerKey(active.key.type)
    }
    activeKey = nil
}
```

### KeyboardView Page Switching (shift/layer management)
```swift
// Source: giellakbd-ios KeyboardView
enum KeyboardPage {
    case normal
    case shifted
    case capslock
    case symbols1
    case symbols2

    func alternatePage() -> KeyboardPage {
        switch self {
        case .normal, .shifted, .capslock:
            return .symbols1
        case .symbols1, .symbols2:
            return .normal
        }
    }
}

// Setting page triggers collection view reload with new key definitions
var page: KeyboardPage {
    didSet {
        collectionView.reloadData()
    }
}
```

## State of the Art

| Old Approach (Dictus v1.2) | Current Approach (Phase 18) | Why Changed |
|----|----|----|
| SwiftUI VStack + HStack keyboard grid | UICollectionView with direct touch handling | 16 SwiftUI approaches failed to eliminate dead zones between keys |
| DeviceClass enum (screen height heuristic) | DeviceKit + KeyboardHeightProvider | Tested per-device height tables are more reliable than screen bounds heuristics |
| Custom ShiftState enum + @State | giellakbd-ios KeyboardPage enum | Single source of truth for shift/layer state, integrated with collection view reload |
| Dead zone catch-all DragGesture | No dead zones (UICollectionView cells are contiguous) | UICollectionView cells tile without gaps; touch coordinate math maps every point to a key |

## Open Questions

1. **UIViewRepresentable vs Direct UIView Hierarchy**
   - What we know: giellakbd-ios KeyboardView is a UIView. The toolbar + recording overlay are SwiftUI. They need to coexist.
   - What's unclear: Whether wrapping KeyboardView in UIViewRepresentable (embedded in SwiftUI) or adding it directly as a sibling UIView to the inputView hierarchy performs better and avoids lifecycle issues.
   - Recommendation: Start with direct UIView hierarchy (UIKit keyboard added as subview of inputView alongside the SwiftUI hosting view for toolbar). This avoids UIViewRepresentable recreation issues. If the toolbar needs to communicate with the keyboard, use delegate/notification pattern.

2. **giellakbd-ios Internal Sentry/Logging Calls**
   - What we know: giellakbd-ios uses SentrySDK.addBreadcrumb throughout for debugging.
   - What's unclear: Exactly how many Sentry calls exist across all vendored files.
   - Recommendation: Find-and-remove all Sentry references. Replace critical ones with PersistentLog calls.

3. **KeyboardDefinition JSON vs Programmatic**
   - What we know: giellakbd-ios loads layouts from KeyboardDefinitions.json. But the JSON only has Sami. The KeyboardDefinition struct is also constructable programmatically.
   - What's unclear: Whether it's easier to create a French JSON file or construct KeyboardDefinition in code.
   - Recommendation: Construct programmatically using existing KeyboardLayout.swift data. This avoids JSON parsing overhead and keeps layout definitions in Swift (more maintainable, type-safe).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | DictusKeyboard target in Xcode project |
| Quick run command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DictusCoreTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro' 2>&1 \| tail -30` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| KBD-01 | AZERTY typing with zero dead zones | manual (Simulator) | Tap every key position on Simulator, verify character output | N/A - manual |
| KBD-02 | QWERTY layout switch | manual (Simulator) | Switch layout in settings, verify QWERTY keys appear | N/A - manual |
| KBD-03 | Shift/caps lock toggle | manual (Simulator) | Tap shift (single, double), verify key labels change | N/A - manual |
| KBD-04 | Letters/numbers/symbols layers | manual (Simulator) | Tap 123, #+=, ABC, verify correct layers appear | N/A - manual |
| KBD-06 | Space, return insertion | manual (Simulator) | Type space, return, verify text output | N/A - manual |
| KBD-07 | Autocapitalization | manual (Simulator) | Type ". " then check shift activates | N/A - manual |
| KBD-08 | Double-space period | manual (Simulator) | Type "hello  " and verify ". " replaces double space | N/A - manual |
| FEEL-01 | Haptic on touchDown | manual (Device only) | Feel haptic on device -- cannot test in Simulator | N/A - manual |
| FEEL-02 | 3-category key sounds | manual (Device) | Listen for distinct sounds on letter/delete/modifier | N/A - manual |
| FEEL-03 | Key popup preview | manual (Simulator) | Press key, verify popup appears above key | N/A - manual |

### Sampling Rate
- **Per task commit:** Build and run on Simulator, verify no dead zones on AZERTY layout
- **Per wave merge:** Full Simulator walkthrough of all layers + Xcode unit tests
- **Phase gate:** Device testing for haptics/sounds + Simulator for all keyboard interactions

### Wave 0 Gaps
- Keyboard extension testing is primarily manual (Simulator + device)
- Unit tests can verify layout data (French AZERTY/QWERTY row counts, key definitions)
- No existing test infrastructure for keyboard UI -- this is expected for keyboard extensions

## Sources

### Primary (HIGH confidence)
- giellakbd-ios source code (GitHub divvun/giellakbd-ios) -- KeyboardView.swift, KeyView.swift, KeyOverlayView.swift, KeyboardViewController.swift, KeyDefinition.swift, KeyboardDefinition.swift, Theme.swift, DeviceContext.swift, KeyboardHeightProvider.swift, InputContext.swift, SystemKeys.swift, LongPressController.swift, DeadKeyHandler.swift, Audio.swift
- Existing Dictus codebase -- KeyboardViewController.swift, KeyboardRootView.swift, KeyboardView.swift, KeyboardLayout.swift, HapticFeedback.swift, InputView.swift, KeyboardState.swift

### Secondary (MEDIUM confidence)
- giellakbd-ios Podfile -- dependency list (DeviceKit ~> 5.7, Sentry ~> 8, DivvunSpell, RxSwift, SQLite.swift)
- giellakbd-ios KeyboardDefinitions.json -- only Sami locale available (no French)

### Tertiary (LOW confidence)
- None -- all findings verified from source code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- verified all giellakbd-ios source files directly, understand vendoring scope
- Architecture: HIGH -- clear delegate pattern, UICollectionView approach proven, integration points identified
- Pitfalls: HIGH -- based on direct code reading + project history (16 failed SwiftUI attempts)

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable -- giellakbd-ios architecture is mature)
