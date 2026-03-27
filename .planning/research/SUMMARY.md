# Project Research Summary

**Project:** Dictus v1.3 Public Beta
**Domain:** iOS keyboard extension rebuild + public TestFlight distribution
**Researched:** 2026-03-27
**Confidence:** HIGH

## Executive Summary

Dictus v1.3 replaces the SwiftUI-based keyboard (which suffers from unfixable dead zones -- 16 approaches failed in Phase 15.4) with a UICollectionView-based keyboard derived from giellakbd-ios (Divvun, Apache-2.0). The giellakbd-ios architecture solves dead zones by design: the UICollectionView has `isUserInteractionEnabled = false` and all touch handling happens via `touchesBegan/Moved/Ended` on the parent UIView, where `point(inside:with:)` correctly participates in hit-testing. This is the exact solution identified in Phase 15.4/15.5 research.

The recommended approach is: vendor ~10 giellakbd-ios source files directly into DictusKeyboard (no CocoaPods, no framework dependency), add DeviceKit 5.8.x as the sole new SPM dependency, and rebuild the keyboard as **UIKit keys + SwiftUI chrome** (toolbar, recording overlay, emoji picker stay SwiftUI). The two-process dictation architecture (Darwin notifications, App Group IPC, KeyboardState, Audio Bridge) is completely orthogonal to the key rendering layer and requires zero modifications.

The highest risks are: (1) hybrid UIKit/SwiftUI touch conflicts at overlay boundaries, (2) memory budget pressure within the 50MB extension limit, and (3) Beta App Review rejection for privacy manifest gaps on the first external TestFlight submission. All are mitigable with the phased approach below.

## Key Findings

### Recommended Stack

One new SPM dependency: **DeviceKit 5.8.x** for device-specific keyboard height calculations. Everything else is vendored source files from giellakbd-ios (~10 Swift files) adapted for Dictus. No RxSwift, no DivvunSpell, no CocoaPods, no Sentry.

**Core technologies:**
- **giellakbd-ios source files (vendored):** UICollectionView keyboard grid with zero dead zones -- battle-tested on App Store (Divvun Keyboards app)
- **DeviceKit 5.8.x:** Pixel-perfect keyboard heights across 30+ iPhone models via screen diagonal lookup
- **Existing stack unchanged:** WhisperKit, FluidAudio, DictusCore, Swift 5.9+, iOS 17.0 minimum

**Net memory savings:** 4-8MB (UIKit keyboard is lighter than SwiftUI equivalent).

See: [STACK.md](STACK.md) for full details.

### Expected Features

**giellakbd-ios provides ~60% out of the box:**
- UICollectionView key layout with zero dead zones
- Touch handling via touchesBegan/Moved/Ended (centralized)
- Key overlay popup on press, long-press accent popups
- Page/layer switching (normal/shifted/caps/symbols1/symbols2)
- Auto-capitalization, double-space period insertion
- Key sizing via width ratios, device-adaptive heights
- Banner/suggestion bar slot

**Must reintegrate from Dictus (~40%):**
- French AZERTY + QWERTY layout definitions
- Spacebar trackpad (HIGH risk -- gesture arbitration with collection view touch handling)
- Recording overlay + waveform
- Mic toolbar (above keyboard, SwiftUI island)
- Text prediction engine + suggestion bar
- Haptic feedback (pre-allocated generators, touchDown timing)
- 3-category key sounds (AudioServicesPlaySystemSound)
- Adaptive accent key (context-aware apostrophe/accent)
- Liquid Glass theming (replace giellakbd-ios Theme.swift)

**Fully independent of rebuild (zero changes needed):**
- Dynamic Island live activity (DictusCore)
- Cold start Audio Bridge (KeyboardState + DictusCore)
- Export logs (DictusApp)

**Anti-features (do NOT build):**
- Full emoji picker in keyboard (memory-unsafe, use system cycling)
- iPad/split keyboard (out of scope)
- DivvunSpell integration (use existing UITextChecker)

See: [FEATURES.md](FEATURES.md) for feature dependency graph and risk assessment.

### Architecture Approach

**UIKit owns the keyboard grid, SwiftUI owns the chrome.** DictusKeyboardView (adapted from giellakbd-ios KeyboardView) renders keys via UICollectionView and handles all touch events. SwiftUI views (ToolbarView, RecordingOverlay, EmojiPickerView) are hosted in UIHostingControllers alongside the UIKit grid. When recording or emoji mode activates, the UIKit grid is hidden and the SwiftUI overlay takes over.

**Major components:**
1. **DictusKeyboardView** (NEW, UIKit) -- key grid + touch dispatcher, adapted from giellakbd-ios
2. **DictusKeyCell** (NEW, UIKit) -- visual key rendering, adapted from giellakbd-ios KeyView
3. **KeyboardChrome** (NEW, SwiftUI) -- slim wrapper for toolbar + recording overlay + emoji picker
4. **KeyboardActionDelegate** (NEW, protocol) -- bridges UIKit touch actions to KeyboardViewController
5. **AccentOverlayView** (NEW, UIKit) -- long-press accent popup, adapted from giellakbd-ios
6. **TrackpadController** (NEW) -- spacebar trackpad, ported from SpaceKey + giellakbd-ios cursor controller

**Unchanged:** KeyboardState, ToolbarView, RecordingOverlay, SuggestionBarView, TextPredictionEngine, all DictusCore files.

**Deleted after migration:** KeyButton, KeyRow, KeyboardView (SwiftUI), SpecialKeyButton, AccentPopup (SwiftUI).

See: [ARCHITECTURE.md](ARCHITECTURE.md) for full component mapping, data flow, and build order.

### Critical Pitfalls

1. **Hybrid UIKit/SwiftUI touch conflict** -- SwiftUI overlays above UIKit keyboard can intercept or drop touches at boundaries. Prevention: clean boundary (UIKit owns grid area, SwiftUI owns above), toggle `isUserInteractionEnabled` when overlays are active, test touch boundaries after each overlay integration.

2. **Height constraint flicker on first appearance** -- giellakbd-ios known issue (#28), compounded by Dictus toolbar height. Prevention: single height source of truth, set constraint in viewWillAppear with once-flag, pre-calculate total height.

3. **Memory budget exceeded** -- 50MB limit with no reuse benefit (all ~42 cells visible simultaneously) plus Dictus features. Prevention: profile on device BEFORE adding features, budget <10MB for base keyboard, lazy-load overlays, kill emoji picker.

4. **Beta App Review rejection** -- first external TestFlight triggers review. Full Access justification, Privacy Manifests, privacy policy URL all required. Prevention: audit both targets' PrivacyInfo.xcprivacy, write detailed review notes, do a dry-run review 1 week before planned launch.

5. **CocoaPods conflict** -- giellakbd-ios uses Pods, Dictus uses SPM. Prevention: copy source files directly, never add CocoaPods to Dictus.

See: [PITFALLS.md](PITFALLS.md) for all 14 pitfalls with prevention strategies.

## Implications for Roadmap

### Phase 1: Bug Fixes (v1.2 beta issues)
**Rationale:** Fix existing bugs BEFORE the architecture change -- debugging state issues in a new architecture is harder (Pitfall #10).
**Delivers:** Dynamic Island REC desync fix (#60), export logs spinner (#61), any additional beta bugs.
**Avoids:** Pitfall #10 (state desync worsened by architecture change).

### Phase 2: Keyboard Base (giellakbd-ios integration)
**Rationale:** Foundation that everything else depends on. Import source files, get UICollectionView rendering AZERTY keys, basic character insertion working.
**Delivers:** UIKit keyboard grid with zero dead zones, French AZERTY/QWERTY layouts, basic character insertion.
**Addresses:** Table stakes (layout, shift, symbols, backspace, return, globe key).
**Avoids:** Pitfalls #2 (height flicker), #5 (CocoaPods conflict), #6 (KeyDefinition collision), #11 (frame-zero layout), #13 (pbxproj conflicts).

### Phase 3: Touch Polish (native feel)
**Rationale:** Must feel like Apple keyboard before adding complex features.
**Delivers:** touchDown haptics + 3-category sounds, key popup preview, shift states, layer switching.
**Avoids:** Pitfall #8 (wrong lifecycle point for haptics/audio).

### Phase 4: Complex Touch Features
**Rationale:** Dictus-specific touch behaviors that go beyond basic key taps, need the base to be solid.
**Delivers:** Delete repeat with acceleration, spacebar trackpad, accent long-press popup, adaptive accent key.
**Avoids:** Pitfall #7 (spacebar trackpad gesture lost in UICollectionView).

### Phase 5: Feature Reintegration
**Rationale:** Reconnect all Dictus-specific features to the new UIKit grid.
**Delivers:** Recording overlay, suggestion bar, autocorrect, autocapitalize, emoji mode, Full Access banner.
**Avoids:** Pitfall #1 (UIKit/SwiftUI touch conflict -- integrate ONE overlay at a time).

### Phase 6: Cleanup + Memory Profiling
**Rationale:** Delete old SwiftUI keyboard files, verify memory budget, regression test.
**Delivers:** Clean codebase, memory-verified keyboard, Signposter instrumentation.
**Avoids:** Pitfall #3 (memory budget exceeded).

### Phase 7: Public TestFlight
**Rationale:** Only after keyboard rebuilt, bugs fixed, and memory verified.
**Delivers:** Beta App Review submission, external test group, public TestFlight link, README update.
**Avoids:** Pitfalls #4 (Beta App Review rejection), #14 (missing test info).

### Phase Ordering Rationale

- **Bug fixes first** because debugging in the old (known) architecture is easier than in the new one.
- **Keyboard base before features** because every feature depends on the UICollectionView grid existing.
- **Touch polish before complex features** because haptics/sounds need to work from first keystroke.
- **Feature reintegration after complex touch** because overlays layer on top of the touch system.
- **Memory profiling before public beta** because silent keyboard crashes would kill the beta experience.
- **Public TestFlight last** because it requires everything else to be stable.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Keyboard Base):** giellakbd-ios source files need detailed review during planning to identify exact files to vendor and adaptation points.
- **Phase 4 (Complex Touch):** Spacebar trackpad gesture arbitration needs prototype validation -- the interaction between UICollectionView-level touch handling and per-cell long-press is the highest-risk integration point.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Bug Fixes):** Known issues with existing codebase, standard debugging.
- **Phase 3 (Touch Polish):** Well-understood patterns (haptics, sounds, shift state), straightforward port.
- **Phase 7 (Public TestFlight):** Apple documentation is clear on requirements.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | giellakbd-ios source code verified, DeviceKit confirmed as sole new dependency |
| Features | HIGH | Both codebases analyzed file-by-file, feature mapping comprehensive |
| Architecture | HIGH | Integration points traced through code, matches Phase 15.4/15.5 conclusions |
| Pitfalls | HIGH | Based on project history (16 failed approaches), giellakbd-ios issues, Apple docs |

**Overall confidence:** HIGH

### Gaps to Address

- **Spacebar trackpad gesture arbitration:** Needs prototype during Phase 4 to validate approach before committing to full implementation.
- **Liquid Glass in UIKit cells:** `.dictusGlass()` is SwiftUI-only. Need UIKit equivalent (UIVisualEffectView or custom CALayer). Investigate during Phase 2 theming.
- **Exact memory footprint:** Unknown until profiled on device. Base keyboard must be <10MB to leave room for features.
- **giellakbd-ios Objective-C bridging header:** Check if any vendored Swift files require it during Phase 2 import.
- **DeviceKit exact version:** Verify latest at `swift package resolve` time (5.8.x or newer).

## Sources

### Primary (HIGH confidence)
- [giellakbd-ios GitHub repository](https://github.com/divvun/giellakbd-ios) -- full source code analysis
- [DeviceKit GitHub](https://github.com/devicekit/DeviceKit) -- dependency verification
- [Apple Custom Keyboard Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) -- extension constraints
- Dictus Phase 15.4/15.5 dead zones research -- 16 failed SwiftUI approaches
- Dictus PROJECT.md, MILESTONES.md -- project history and constraints

### Secondary (MEDIUM confidence)
- [giellakbd-ios issue #28](https://github.com/divvun/giellakbd-ios/issues/28) -- height constraint flicker
- [Apple Developer Forums: UICollectionView in keyboard extension](https://developer.apple.com/forums/thread/24032) -- layout timing
- [Apple TestFlight documentation](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/) -- public beta requirements
- Community reports on keyboard extension memory limits (30-50MB range)

---
*Research completed: 2026-03-27*
*Ready for roadmap: yes*
