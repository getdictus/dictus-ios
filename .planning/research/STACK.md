# Technology Stack — v1.3 Keyboard Rebuild from giellakbd-ios

**Project:** Dictus v1.3 Public Beta
**Researched:** 2026-03-27
**Scope:** Stack changes for rebuilding the keyboard from giellakbd-ios (Divvun). Existing stack (WhisperKit, FluidAudio, Swift 5.9+, DictusCore, two-process architecture) is validated and unchanged.

---

## Critical Finding: One New SPM Dependency (DeviceKit)

The giellakbd-ios keyboard engine uses 100% UIKit with `UICollectionView` for key layout. Most of its code can be vendored directly into Dictus. The only external dependency needed is **DeviceKit** for keyboard height calculations across the iPhone lineup.

**What we take from giellakbd-ios:** Pure Swift source files (no pods, no frameworks).
**What we do NOT take:** RxSwift, DivvunSpell, SQLite.swift, Sentry, PahkatClient, SwiftLint pod. None of these are used in the keyboard view layer.

---

## Recommended Stack Changes

### New Dependency

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| [DeviceKit](https://github.com/devicekit/DeviceKit) | 5.8.x | Device identification for keyboard height calculation | giellakbd's `KeyboardHeightProvider` uses `Device.current().diagonal` and `Device.current().hasSensorHousing` to compute pixel-perfect keyboard heights across 30+ iPhone models. Writing this from scratch is error-prone and requires constant updates for new devices. DeviceKit is mature (11 years, 66 releases), lightweight (<100KB), actively maintained, MIT-licensed, and supports SPM natively. |

### Vendored Source Files (from giellakbd-ios)

These are NOT dependencies. They are source files copied into `DictusKeyboard/` and adapted for Dictus. giellakbd-ios is Apache-2.0 licensed, compatible with Dictus's MIT license (attribution required in LICENSE/NOTICE).

| File | Purpose | Adaptation Needed |
|------|---------|-------------------|
| `KeyboardView.swift` | UICollectionView-based key grid with zero dead zones | Replace DivvunSpell references, remove RxSwift, adapt to Dictus key definitions |
| `KeyView.swift` | Individual key rendering (UIView + UILabel + UIImageView) | Apply Dictus theme (Liquid Glass colors), French key labels |
| `KeyOverlayView.swift` | Key preview popup on tap | Adapt styling to match Dictus design |
| `KeyboardViewController.swift` | Main UIInputViewController orchestrator | Heavy adaptation: merge with existing Dictus KeyboardViewController (dictation triggers, Darwin notifications, App Group reads) |
| `LongPressController.swift` | Long-press alternative character overlay | Adapt for French accented characters (existing `AccentedCharacters` data) |
| `KeyDefinition.swift` | Key type enum + size model | Map to existing Dictus `KeyDefinition` model or replace it |
| `KeyboardDefinition.swift` | Layout structure (rows, pages, modes) | Define AZERTY/QWERTY French layouts in this format |
| `Theme.swift` | Color/font/spacing factory | Replace entirely with Dictus Liquid Glass theme values |
| `KeyboardHeightProvider.swift` | Device-specific keyboard heights | Keep mostly as-is (this is why DeviceKit is needed) |
| `DeviceContext.swift` | Device type detection wrapper | Keep as-is, wraps DeviceKit |
| `SplitKeyboard.swift` | Split keyboard mode (iPad) | Skip for now (iPhone-first, iPad is v2+) |

### Unchanged Stack (validated, DO NOT modify)

| Technology | Version | Target | Notes |
|------------|---------|--------|-------|
| Swift | 5.9+ | All | Language version unchanged |
| SwiftUI | iOS 17+ | DictusApp, overlays | Still used for ToolbarView, RecordingOverlay, SuggestionBar, EmojiPicker, Settings, Onboarding |
| WhisperKit | 0.16.0+ | DictusApp | On-device French STT, unchanged |
| FluidAudio (Parakeet) | via SPM | DictusApp | Multi-engine STT, unchanged |
| DictusCore | local SPM | Shared | App Group, models, preferences, design tokens |
| iOS minimum | 17.0 | All | No change needed |

---

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| RxSwift | giellakbd uses it for banner/spell-check reactive bindings. Dictus has none of those features (no DivvunSpell, no reactive spell checker). Zero usage in the keyboard view/key layer. |
| DivvunSpell | Divvun's spell-check engine for indigenous languages. Dictus uses UITextChecker + FrequencyDictionary for French autocorrect. Completely unrelated. |
| SQLite.swift | Used by giellakbd for user dictionary storage. Dictus uses UserDefaults via App Group. No need. |
| Sentry | giellakbd uses it for crash reporting. Dictus has its own PersistentLog system with structured logging. Adding Sentry would bloat the keyboard extension. |
| KeyboardKit (third-party) | Commercial keyboard framework ($299/year). giellakbd already provides what we need for free (Apache-2.0). |
| CocoaPods | giellakbd uses CocoaPods. Dictus uses SPM exclusively. DeviceKit supports SPM natively. No reason to add a second package manager. |
| SwiftLint pod | giellakbd includes it as a pod. If needed, add as a build phase script or SPM plugin, not a pod. Not required for v1.3. |

---

## Integration Architecture

### Before (v1.2): SwiftUI keyboard keys via UIHostingController

```
KeyboardViewController (UIInputViewController)
  -> UIHostingController<KeyboardRootView>
       -> KeyboardRootView (SwiftUI)
            -> ToolbarView (SwiftUI)
            -> KeyboardView (SwiftUI) ← DEAD ZONES HERE
            -> RecordingOverlay (SwiftUI)
            -> EmojiPickerView (SwiftUI)
```

### After (v1.3): UICollectionView keys + SwiftUI overlays

```
KeyboardViewController (UIInputViewController)
  -> keyboardContainer (UIView)
       -> bannerView (UIView) — toolbar with mic button, suggestions
            -> UIHostingController<ToolbarView> OR native UIKit toolbar
       -> keyboardView (KeyboardView: UICollectionView) ← FROM GIELLAKBD
            -> KeyCell -> KeyView (UIView) ← ZERO DEAD ZONES
       -> overlayContainer (UIView) — conditionally shown
            -> UIHostingController<RecordingOverlay> (SwiftUI, stays as-is)
            -> UIHostingController<EmojiPickerView> (SwiftUI, stays as-is)
```

**Key architectural decision:** The keyboard keys become pure UIKit (UICollectionView cells). Features that overlay the keyboard (recording, emoji) stay SwiftUI hosted in UIHostingControllers that are added/removed as needed. This matches giellakbd's pattern of `keyboardContainer` containing the `keyboardView` with optional banner views.

### Why UICollectionView Solves Dead Zones

giellakbd uses `UICollectionViewFlowLayout` where cells are sized to fill 100% of the available width per row. Each `KeyCell` contains a `KeyView` (plain `UIView`). The collection view's cells tile edge-to-edge with zero spacing. Unlike SwiftUI views which have implicit padding/spacing that creates untouchable gaps, UICollectionView cells are contiguous. Additionally, `KeyView` can override `point(inside:with:)` for extended hit regions if needed (this is exactly the technique identified in Phase 15.4 research as the solution).

### Touch Handling

giellakbd handles ALL touch events at the `KeyboardView` level (not per-cell):
- `touchesBegan` / `touchesMoved` / `touchesEnded` on the UICollectionView
- Hit-tests to find the cell under each touch point
- Manages long-press timing, key repeat, and swipe-up detection centrally
- This avoids gesture recognizer conflicts that plagued the SwiftUI approach

---

## Installation

```bash
# Add DeviceKit via SPM in Xcode:
# File > Add Package Dependencies
# URL: https://github.com/devicekit/DeviceKit.git
# Version: Up to Next Major (5.8.0)
# Target: DictusKeyboard (keyboard extension only)
```

No other package changes needed. giellakbd source files are vendored (copied), not added as a dependency.

---

## Memory Budget Impact

| Component | Current (v1.2) | After Rebuild (v1.3) | Delta |
|-----------|----------------|----------------------|-------|
| UIHostingController + SwiftUI keyboard | ~8-12MB | Removed | -8-12MB |
| UICollectionView keyboard | N/A | ~3-5MB | +3-5MB |
| DeviceKit | N/A | <0.5MB | +0.5MB |
| **Net impact** | | | **-4 to -8MB saved** |

UIKit is significantly more memory-efficient than SwiftUI for keyboard rendering. This is important given the 50MB extension limit.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Keyboard engine | giellakbd-ios (vendored) | KeyboardKit (commercial) | $299/year, closed source Pro features, unnecessary abstraction layer for what we need |
| Keyboard engine | giellakbd-ios (vendored) | Custom UIKit from scratch | giellakbd is battle-tested on App Store (Divvun Keyboards app), handles edge cases (iPad split, rotation, height calculation) that would take weeks to discover |
| Keyboard engine | giellakbd-ios (vendored) | Keep SwiftUI + workarounds | 16 approaches tested in Phase 15.4, all failed. SwiftUI fundamentally cannot extend hit regions beyond view bounds |
| Device detection | DeviceKit | UIDevice + screen bounds | UIDevice doesn't expose screen diagonal, sensor housing type, or device model name. Manual screen-size tables are fragile and need updating for every new iPhone. DeviceKit handles this. |
| Device detection | DeviceKit | Remove height provider, use autolayout | giellakbd's height provider ensures pixel-perfect keyboard heights matching Apple's native keyboard. Autolayout alone produces inconsistent heights across devices. |
| Package manager | SPM (DeviceKit) | CocoaPods (match giellakbd) | Dictus is SPM-only. DeviceKit supports SPM. No reason to introduce CocoaPods. |

---

## Confidence Assessment

| Area | Confidence | Reasoning |
|------|------------|-----------|
| giellakbd architecture (UICollectionView, zero dead zones) | HIGH | Verified by reading actual source code from GitHub main branch |
| DeviceKit necessity | HIGH | `KeyboardHeightProvider` and `DeviceContext` directly import and use DeviceKit; cannot function without it |
| No RxSwift needed | HIGH | Verified by reading KeyboardView.swift, KeyView.swift, LongPressController.swift — zero RxSwift imports in keyboard view layer |
| Memory improvement | MEDIUM | Based on general UIKit vs SwiftUI overhead knowledge, not measured on Dictus specifically |
| DeviceKit version 5.8.x | MEDIUM | Per Swift Package Index; verify exact latest at install time |

---

## Sources

- [giellakbd-ios GitHub repository](https://github.com/divvun/giellakbd-ios) — Apache-2.0 license, source code reviewed
- [DeviceKit GitHub](https://github.com/devicekit/DeviceKit) — MIT license, v5.8.x, SPM compatible
- [DeviceKit on Swift Package Index](https://swiftpackageindex.com/devicekit/DeviceKit) — version verification
- [Phase 15.4 dead zones research](project_phase154_dead_zones_learnings.md) — 16 failed SwiftUI approaches, UIKit `point(inside:with:)` identified as solution
- [Issue #62](https://github.com/getdictus/dictus-ios/issues/62) — Rebuild keyboard from giellakbd-ios tracking issue
- [Divvun Keyboards on App Store](https://apps.apple.com/us/app/divvun-keyboards/id948386025) — Production validation of giellakbd engine
