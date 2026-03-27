# Domain Pitfalls

**Domain:** iOS keyboard extension rebuild (giellakbd-ios integration) + Public TestFlight Beta
**Researched:** 2026-03-27
**Confidence:** HIGH (based on giellakbd-ios source analysis, Dictus project history, Apple documentation, community reports, and v1.0-v1.2 lessons learned)

**Context:** Dictus v1.3 replaces the SwiftUI-based keyboard (DragGesture, dead zones) with a UICollectionView-based keyboard derived from giellakbd-ios (Divvun). The existing app has a two-process architecture (keyboard extension + main app), 25+ custom features to reintegrate, and must pass Beta App Review for public TestFlight distribution.

---

## Critical Pitfalls

Mistakes that cause rewrites, App Store rejection, or multi-day stalls.

### Pitfall 1: Hybrid UIKit/SwiftUI Touch Conflict in Reintegrated Overlays

**What goes wrong:**
giellakbd-ios uses raw `touchesBegan/Moved/Ended/Cancelled` on its `KeyboardView` (a UICollectionView) for all key input. Dictus features like the RecordingOverlay, EmojiPickerView, SuggestionBarView, AccentPopup, and ToolbarView are all SwiftUI views. When a SwiftUI view is hosted (via UIHostingController) above or alongside a UIView that handles touches directly, the gesture recognizer systems collide:

- SwiftUI's gesture system (DragGesture, TapGesture) competes with UIKit's `touchesBegan` for first-responder hit testing
- UIHostingController adds its own gesture recognizers that can intercept touches before they reach the UICollectionView
- The recording overlay needs to block ALL keyboard touches when visible, but UIKit touch methods bypass SwiftUI's `.disabled()` modifier
- AccentPopup (SwiftUI) shows above keys (UIKit) -- touches on the popup that miss a button fall through to the UICollectionView and type a letter

This is exactly the class of problem that caused the Phase 15.4 dead zones. The difference: now the UIKit layer is the keyboard (correct), but the overlaid features are still SwiftUI (risky).

**Why it happens:**
Dictus has 13 SwiftUI view files in the keyboard extension. Rewriting them all in UIKit is prohibitively expensive. The natural approach is to keep them as SwiftUI hosted above the UIKit keyboard. But UIKit and SwiftUI have fundamentally different touch delivery pipelines.

**Consequences:**
Ghost taps on keys during recording overlay. Accent popup selects wrong character. Emoji picker closes unexpectedly. Dead zones return at SwiftUI/UIKit boundary.

**Prevention:**
1. **Use a single UIKit view hierarchy with SwiftUI islands**: The giellakbd-ios KeyboardView should be the root touch handler. SwiftUI overlays (RecordingOverlay, EmojiPicker) should be presented as child UIHostingControllers with `view.isUserInteractionEnabled = true` and the keyboard's `isUserInteractionEnabled = false` when overlays are active
2. **Block touches at the UIKit level, not SwiftUI level**: When RecordingOverlay is visible, set `keyboardView.isUserInteractionEnabled = false`. Do NOT rely on SwiftUI's `.allowsHitTesting(false)` -- it does not propagate down to UIKit siblings
3. **Test touch boundary at every overlay edge**: Specifically test: (a) tapping the 1px gap between suggestion bar and keyboard, (b) tapping AccentPopup's triangle pointer, (c) swiping from keyboard area into the recording overlay, (d) tapping emoji picker dismiss area
4. **Consider pure UIKit for AccentPopup**: This is the highest-risk overlay because it appears directly on top of keys. A simple UIView with UIButtons is safer than a SwiftUI overlay bridged through UIHostingController

**Warning signs:**
Tapping a key produces no character. Tapping the recording overlay types a letter underneath. Long-press accent popup shows but selecting an accent also triggers the key below.

**Phase to address:**
Keyboard rebuild phase (feature reintegration sub-phase). Build the keyboard base first, then integrate ONE overlay at a time, testing touch delivery after each.

---

### Pitfall 2: giellakbd-ios Height Constraint Flicker on First Appearance

**What goes wrong:**
giellakbd-ios uses `viewDidLayoutSubviews()` to initialize its height constraint and `NSLayoutConstraint` with priority 999. On first keyboard appearance, iOS calls layout multiple times as the input view transitions from zero-height to full-height. This produces a visible "bounce" or "double-height" effect documented in [giellakbd-ios issue #28](https://github.com/divvun/giellakbd-ios/issues/28) -- the keyboard height effectively doubles before settling.

Dictus compounds this because it adds a ToolbarView (mic button + suggestion bar) above the keyboard rows, increasing total height. If the height constraint is set before the toolbar is measured, the keyboard appears too short, then jumps to correct height. If set after, iOS may have already committed the animation and the jump is visible.

Additionally, Dictus currently manages its own `heightConstraint` in KeyboardViewController (line 15) for recording overlay sizing. Introducing giellakbd-ios's separate height management creates two competing constraints.

**Why it happens:**
In keyboard extensions, `inputView.frame` is zero in `viewDidLoad`. Height must be set in `viewWillAppear` or `viewDidLayoutSubviews`, but iOS calls these multiple times during the initial presentation animation. The system's own height constraint (default keyboard height) fights with the custom constraint until the priority-999 constraint wins.

**Consequences:**
Keyboard flickers or bounces on first appearance. Users see a brief flash of incorrect height. On some devices (iPhone SE), the keyboard may appear cut off if the initial constraint is wrong.

**Prevention:**
1. **Set height constraint in viewWillAppear, not viewDidLayoutSubviews**: Use `viewWillAppear` for initial constraint setup. Use a `Bool` flag to ensure it only runs once per appearance cycle
2. **Single source of truth for height**: Remove Dictus's existing `heightConstraint` and use only giellakbd-ios's `KeyboardHeightProvider.height()` pattern, extended to include toolbar height
3. **Disable the system's default constraint**: Set `inputView?.translatesAutoresizingMaskIntoConstraints = false` immediately after assigning the custom inputView (but ONLY on the inputView subviews -- the inputView itself must keep autoresizing masks as noted in Dictus's existing code comment on line 42-44 of KeyboardViewController.swift)
4. **Pre-calculate total height**: Compute `keyboardRowsHeight + toolbarHeight + safeAreaInset` BEFORE layout, using giellakbd-ios's `KeyboardHeightProvider` extended with Dictus toolbar dimensions
5. **Test on iPhone SE (compact class) specifically**: This device has the smallest keyboard and is most sensitive to height calculation errors

**Warning signs:**
Keyboard appears, shrinks, then grows. Keyboard height is different on first appearance vs subsequent appearances. Toolbar overlaps the text field above.

**Phase to address:**
Keyboard rebuild phase (base integration). This must be solid before adding toolbar or overlays.

---

### Pitfall 3: Memory Budget Exceeded by UICollectionView Cell Allocation

**What goes wrong:**
The keyboard extension has a ~50MB memory limit (iOS kills it silently above this). The current SwiftUI keyboard is lightweight because SwiftUI manages view lifecycle automatically. UICollectionView with dequeued cells has different memory characteristics:

- giellakbd-ios's `KeyView` creates multiple UILabels and a UIImageView per cell. A 4-row AZERTY keyboard with 10-11 keys per row = ~42 cells. Each `KeyView` has 3-5 subviews with Auto Layout constraints
- Cell reuse only helps when scrolling. A keyboard shows ALL cells simultaneously -- no reuse occurs. Every cell is fully allocated in memory at once
- giellakbd-ios's `KeyOverlayView` (the long-press popup) creates additional views on demand
- Dictus adds: SuggestionBarView (~3 suggestion cells), EmojiPickerView (potentially hundreds of emoji glyphs -- this was already identified as memory-unsafe in PROJECT.md), TextPredictionEngine (~5MB), and RecordingOverlay with Canvas waveform

Total: keyboard cells + overlay views + text prediction + suggestion bar + waveform. If this exceeds ~35-40MB (leaving room for WhisperKit IPC and system overhead), iOS terminates the extension with no crash log -- the keyboard simply disappears and the system keyboard takes over.

**Why it happens:**
giellakbd-ios was designed for standalone keyboard extensions without heavy companion features. Dictus loads substantially more into the same 50MB budget. The UICollectionView approach trades dead-zone-free touch handling for higher baseline memory usage compared to SwiftUI's lazy rendering.

**Consequences:**
Keyboard crashes silently (no crash log, just disappears). Users see the system keyboard replace Dictus without warning. Crash frequency varies by device (4GB RAM devices hit the limit sooner).

**Prevention:**
1. **Profile memory on device immediately after base keyboard works**: Use Instruments > Allocations with the keyboard extension target. Establish baseline before adding any Dictus features
2. **Budget allocation**: Keyboard base (UICollectionView + cells) target <10MB. Toolbar + suggestions <5MB. Text prediction <5MB. Recording overlay + waveform <5MB. Leaves ~25MB for system overhead and IPC
3. **Do NOT build EmojiPickerView into the keyboard**: PROJECT.md already notes this is memory-unsafe. Use system emoji cycling (globe key) instead. The existing emoji picker was a v1.1 feature that should not survive the rebuild
4. **Lazy-load overlays**: RecordingOverlay and AccentPopup should be created on demand and destroyed when dismissed, not kept in the view hierarchy
5. **Reuse KeyView instances**: Even though UICollectionView doesn't scroll, consider a custom layout that reuses cells when switching between keyboard layers (letters/numbers/symbols) rather than maintaining separate cell sets for each layer
6. **Use `os_proc_available_memory()` at startup**: Log available memory. If below 30MB at launch, skip non-essential features (disable text prediction, simplify waveform)

**Warning signs:**
Keyboard disappears during emoji picker scroll. Keyboard disappears after third or fourth recording. Memory warnings in Instruments (but NOT in console -- keyboard extensions don't always log memory warnings before termination).

**Phase to address:**
Keyboard rebuild phase. Memory profiling must happen BEFORE feature reintegration begins. If the base keyboard + giellakbd-ios already uses >15MB, the approach needs revision.

---

### Pitfall 4: Beta App Review Rejection for Full Access + Privacy Manifest Gaps

**What goes wrong:**
Public TestFlight requires Beta App Review. Beta App Review is lighter than full App Store review but still checks for:
- Privacy Manifest completeness (required since Spring 2024)
- Full Access justification (keyboard extensions requesting Open Access face extra scrutiny)
- Obvious guideline violations (5.1.1 data collection, 2.5.1 software requirements)

Dictus has `RequestsOpenAccess = true` because the microphone requires Full Access. Beta App Review will verify:
1. The Privacy Manifest (`PrivacyInfo.xcprivacy`) in BOTH the app AND the keyboard extension target declares all required API usage reasons
2. The `NSMicrophoneUsageDescription` explains WHY a keyboard needs the microphone
3. No user-typed text is persisted to disk (guideline 5.1.1 specifically targets keyboard extensions)
4. The "What's New" or test notes explain the keyboard's Full Access need

If any of these are missing or vague, the build is rejected. Rejection cycle is 24-48 hours per attempt, and each resubmission goes to the back of the queue.

**Why it happens:**
The v1.2 private beta skipped Beta App Review (internal testers only -- no review required for up to 100 internal testers). Moving to external/public TestFlight triggers the first-ever Beta App Review for Dictus. Privacy requirements that were invisible for internal distribution suddenly become blockers.

**Consequences:**
Build rejected, 24-48 hour delay per cycle. Multiple rejections possible if issues are found incrementally (Apple sometimes reports one issue at a time). Public beta launch delayed by days or weeks.

**Prevention:**
1. **Audit PrivacyInfo.xcprivacy in BOTH targets**: The keyboard extension AND the main app each need their own Privacy Manifest. Check that `NSPrivacyAccessedAPITypes` lists all required-reason APIs:
   - `NSPrivacyAccessedAPICategoryFileTimestamp` (if using file modification dates in logging)
   - `NSPrivacyAccessedAPICategoryUserDefaults` (App Group UserDefaults)
   - `NSPrivacyAccessedAPICategoryDiskSpace` (if checking available space for models)
2. **Write detailed Beta App Review notes**: Explain "This keyboard uses Full Access solely for microphone access to provide on-device speech-to-text dictation. No keystroke data is transmitted off-device. All speech processing uses WhisperKit running locally."
3. **Verify no transcription text hits PersistentLog**: Run `grep -r "lastTranscription\|transcriptionResult\|documentContext\|textDocumentProxy.documentContext" DictusKeyboard/` and verify zero matches in any log call
4. **Include a privacy policy URL**: App Store Connect requires a privacy policy URL for public TestFlight. This was noted as pending in Phase 16. It MUST be live before submission
5. **Test the review flow with a dry-run build first**: Upload a build, add it to an external test group with just 1 email, and let it go through review before announcing the public link

**Warning signs:**
Email from App Store Connect: "Your build has been rejected." Resolution Center message citing guideline 5.1.1 or missing privacy manifest entries. Binary rejected before review (automated check) for missing `NSMicrophoneUsageDescription`.

**Phase to address:**
Public TestFlight phase. Complete ALL privacy and manifest work BEFORE the first external build submission. Do a dry-run review cycle at least 1 week before planned public launch.

---

### Pitfall 5: CocoaPods-to-SPM Dependency Conflict When Integrating giellakbd-ios

**What goes wrong:**
giellakbd-ios uses CocoaPods (has a `Podfile`). Dictus uses Swift Package Manager exclusively (WhisperKit, FluidAudio, DictusCore all via SPM). Naively adding giellakbd-ios's dependencies via Pods while keeping existing SPM packages creates:

- Duplicate symbol errors at link time if any Pod and SPM package share transitive dependencies
- Two different dependency resolution systems that don't coordinate versions
- `Pods/` directory and `xcworkspace` that conflicts with Dictus's existing `xcodeproj`-based build
- CI/CD breakage if GitHub Actions expects `xcodebuild -project` but CocoaPods requires `xcodebuild -workspace`

Additionally, giellakbd-ios has a `Keyboard-Bridging-Header.h` for Objective-C interop. Keyboard extensions in Dictus currently have no bridging header. Adding one requires Xcode build settings changes that affect ALL targets.

**Why it happens:**
giellakbd-ios is a template project designed to be consumed by `kbdgen` (their build tool), not directly integrated into another app. Its dependency management assumes it IS the project, not a component of one.

**Consequences:**
Build failures. Hours spent resolving symbol conflicts. Risk of breaking existing WhisperKit/FluidAudio SPM resolution.

**Prevention:**
1. **Do NOT add CocoaPods to Dictus**: Copy giellakbd-ios source files directly into the DictusKeyboard target. The keyboard view code (KeyboardView.swift, KeyView.swift, KeyOverlayView.swift) plus controllers and models are what you need -- not the Pod dependencies
2. **Cherry-pick, don't wholesale import**: giellakbd-ios has features Dictus doesn't need (SplitKeyboard, BannerManager, UserDictionaryService, localization infrastructure). Import only: KeyboardView, KeyView, KeyOverlayView, KeyDefinition, KeyboardDefinition, KeyboardHeightProvider, Theme, LongPressController, DeadKeyHandler, Audio
3. **Adapt the bridging header only if Obj-C code is needed**: Check if any giellakbd-ios code actually uses the bridging header. If the Swift files don't reference Obj-C, skip it entirely
4. **Rename imported types to avoid confusion**: giellakbd-ios has `KeyDefinition` and Dictus has `KeyDefinition`. They are NOT the same model. Either namespace them (DivvunKeyDefinition vs DictusKeyDefinition) or merge the models explicitly
5. **Keep the import in a single commit**: Import all giellakbd-ios files in one atomic commit so it's easy to revert if the approach fails

**Warning signs:**
`duplicate symbol` linker errors. `No such module 'Sentry'` or other Pod-specific errors. Xcode can't resolve package graph after adding files.

**Phase to address:**
Keyboard rebuild phase (first step -- base import). Must be resolved before any feature work begins.

---

## Moderate Pitfalls

Issues that cause days of debugging or subtle UX regressions.

### Pitfall 6: KeyDefinition Model Collision Between giellakbd-ios and Dictus

**What goes wrong:**
Both projects define a `KeyDefinition` model. Dictus's version (in `DictusKeyboard/Models/KeyDefinition.swift`) defines key types, sizes, and behaviors for AZERTY/QWERTY layouts with Dictus-specific keys (.mic, .emoji, .layerSwitch, .adaptiveAccent). giellakbd-ios's `KeyDefinition` has different properties, different enums, and different size calculations. Importing both without resolving the conflict means:

- Compiler errors from ambiguous type references
- Silent behavior differences if one model is shadowed by the other
- Layout definitions (AZERTY rows) that reference the wrong KeyDefinition

**Prevention:**
1. Use giellakbd-ios's KeyDefinition as the base (it's designed for UICollectionView cell sizing)
2. Extend it with Dictus-specific key types (.mic, .adaptiveAccent, .emoji)
3. Delete or archive Dictus's KeyDefinition after migration
4. Update `KeyboardLayout.swift` (the AZERTY/QWERTY row definitions) to use the new model

**Phase to address:**
Keyboard rebuild phase (model migration sub-step, before view integration).

---

### Pitfall 7: Spacebar Trackpad Gesture Lost in UICollectionView Touch Handling

**What goes wrong:**
Dictus's spacebar has a long-press trackpad feature (move cursor left/right/up/down). In SwiftUI, this was a `DragGesture` on the spacebar view. In giellakbd-ios's UICollectionView, ALL touches are handled by `KeyboardView.touchesBegan/Moved/Ended`. The spacebar is just another cell -- there's no per-cell gesture recognizer.

giellakbd-ios does have swipe detection (`touchesMoved` calculates percentage offset from center for alternate characters), but this is a horizontal-only swipe, not a 2D trackpad. Adapting this for full cursor trackpad (horizontal AND vertical movement) requires modifying the touch pipeline to:

- Detect which cell the touch started on (spacebar specifically)
- Switch from character-input mode to trackpad mode after a long-press threshold
- Move the cursor via `textDocumentProxy.adjustTextPosition(byCharacterOffset:)` in response to drag deltas
- Handle line-based vertical movement (Dictus's existing implementation uses character counting)

**Prevention:**
1. Add a `UILongPressGestureRecognizer` specifically on the spacebar cell (giellakbd-ios already adds one for long-press overlays on letter keys -- follow the same pattern)
2. On long-press recognized, switch `KeyboardView`'s touch handling to "trackpad mode" that interprets `touchesMoved` as cursor movement instead of key selection
3. Port the existing cursor movement logic from Dictus's SwiftUI `DragGesture` handler

**Phase to address:**
Feature reintegration phase (after base keyboard works).

---

### Pitfall 8: Key Sounds and Haptics Fire at Wrong Lifecycle Point

**What goes wrong:**
Dictus fires haptics and audio on `touchDown` (not `touchUp`) to match Apple's native keyboard feel. This was carefully tuned in Phase 15.3. giellakbd-ios fires key triggers in `touchesEnded` (which is character insertion) but has separate audio handling in `Audio.swift` that may fire at a different point.

If haptics/audio fire on `touchesEnded` instead of `touchesBegan`, the keyboard feels sluggish -- there's a perceptible delay between finger touching glass and feedback. If they fire on `touchesBegan` but character insertion happens on `touchesEnded`, the feedback doesn't match the action on cancelled touches (finger slides off key).

Additionally, Dictus uses `AudioServicesPlaySystemSound` (respects silent switch) while giellakbd-ios's `Audio.swift` may use a different audio API.

**Prevention:**
1. Move audio/haptic triggers to `touchesBegan` in `KeyboardView`, not in `touchesEnded`
2. Keep using `AudioServicesPlaySystemSound` with the existing 3-category system (letter: 1104, delete: 1155, modifier: 1156)
3. Keep using pre-allocated `UIImpactFeedbackGenerator` instances (static property pattern from v1.1)
4. Test on device with `OSSignposter` to measure touch-to-feedback latency (<10ms target)

**Phase to address:**
Feature reintegration phase (immediate after base keyboard -- this is perceptible from first keystroke).

---

### Pitfall 9: Theme/Dark Mode Mismatch Between giellakbd-ios and Dictus Design System

**What goes wrong:**
giellakbd-ios has its own `Theme.swift` that defines key colors, backgrounds, fonts, and active states. It supports dark mode via `checkDarkMode()` in the controller. Dictus has its own design system in DictusCore (Liquid Glass, brand colors, custom gradients). These two color systems will clash:

- giellakbd-ios themes use system colors and standard key styling
- Dictus uses custom brand colors (#0A1628 background, #3D7EFF accent, etc.)
- giellakbd-ios's iOS 26 theme update (mentioned in App Store) may or may not match Dictus's Liquid Glass approach
- The `.dictusGlass()` modifier is SwiftUI-only -- cannot be applied to UIKit cells

**Prevention:**
1. Replace giellakbd-ios's `Theme.swift` entirely with a UIKit-compatible version of Dictus's design tokens
2. Define colors as `UIColor` constants in a shared file, not SwiftUI `Color`
3. Apply Liquid Glass effects using `UIVisualEffectView` where needed (but keep it minimal in cells for memory/performance)
4. Test dark mode explicitly -- the keyboard extension inherits the HOST app's appearance, not Dictus app's appearance

**Phase to address:**
Keyboard rebuild phase (theming sub-step, after layout works but before feature reintegration).

---

### Pitfall 10: Dynamic Island State Desync Worsened by Architecture Change

**What goes wrong:**
Issue #60 documents that the Dynamic Island gets stuck on "REC" state. The current state machine relies on `KeyboardState.shared` (an ObservableObject) observed by SwiftUI views. After the rebuild, the keyboard is UIKit -- it won't automatically react to `@Published` property changes on `KeyboardState`.

If `KeyboardState.isRecording` changes but the UIKit keyboard doesn't observe it (no Combine subscription), the toolbar/overlay won't update. The Dynamic Island (which is in the main app target, still SwiftUI) and the keyboard (now UIKit) can desync even further.

**Prevention:**
1. Add `Combine` subscriptions in the UIKit KeyboardViewController to observe `KeyboardState.shared` changes
2. Specifically subscribe to: `isRecording`, `isOverlayVisible`, `waveformAmplitudes`
3. Use `sink` with `[weak self]` to update UIKit views when state changes
4. Fix the Dynamic Island state machine bug (#60) BEFORE the keyboard rebuild, not after -- debugging state issues in a new architecture is harder

**Warning signs:**
Recording starts but keyboard doesn't show overlay. Recording ends but "stop" button stays visible. Dynamic Island shows "REC" indefinitely.

**Phase to address:**
Bug fix phase (fix #60 first), then keyboard rebuild phase (add Combine bindings).

---

## Minor Pitfalls

Issues that cause hours of confusion but are quickly fixable once identified.

### Pitfall 11: `inputView` Frame Zero in viewDidLoad Causes Collection View Layout Failure

**What goes wrong:**
UICollectionView needs a non-zero frame to calculate its layout. In `viewDidLoad`, the keyboard extension's `inputView` has frame `.zero`. If the UICollectionView is created and added to the hierarchy in `viewDidLoad` with constraints that reference `inputView.bounds`, the initial layout pass produces zero-width cells.

**Prevention:**
Create the UICollectionView in `viewDidLoad` but trigger `collectionView.reloadData()` in `viewWillAppear` (or `viewDidLayoutSubviews` with a once-flag) after the frame is established.

**Phase to address:** Keyboard rebuild phase (base setup).

---

### Pitfall 12: `textDocumentProxy` Becomes Nil or Stale After App Switch

**What goes wrong:**
After the user switches to the Dictus app (for recording) and returns, `textDocumentProxy` may point to a stale text field or return nil for `documentContextBeforeInput`. Inserting text via a stale proxy does nothing -- the transcription is lost.

This already happens in the current architecture but is masked by the Darwin notification + retry pattern. After the rebuild, if the transcription insertion path changes, the stale proxy bug resurfaces.

**Prevention:**
1. Always call `textDocumentProxy.documentContextBeforeInput` as a staleness check before inserting text
2. If nil and text should have been inserted, retry after a 100ms `Task.sleep`
3. Keep the existing Darwin notification pattern for transcription delivery

**Phase to address:** Feature reintegration phase (transcription insertion).

---

### Pitfall 13: Xcode Project File Merge Conflicts from Wholesale File Import

**What goes wrong:**
Adding 15-20 new Swift files to the DictusKeyboard target means 15-20 new PBXFileReference, PBXBuildFile, and PBXGroup entries in `project.pbxproj`. If done across multiple commits or branches, the pbxproj merge conflicts are nightmarish (binary-like conflict markers in XML-ish format).

**Prevention:**
1. Import ALL giellakbd-ios files in a single commit on a feature branch
2. Use `xcodebuild` to verify the project compiles immediately after import
3. Do not split the import across multiple PRs

**Phase to address:** Keyboard rebuild phase (first commit).

---

### Pitfall 14: Beta App Review Requires "What to Test" and Contact Info

**What goes wrong:**
When creating an external test group in App Store Connect, Apple requires: beta app description, feedback email, privacy policy URL, and "What to Test" notes. Missing any field blocks the submission. The privacy policy URL must be a live, accessible webpage (not a GitHub raw file or localhost).

**Prevention:**
1. Prepare a simple privacy policy page on the Dictus website or GitHub Pages before submission
2. Write clear "What to Test" notes: "Test the AZERTY keyboard in various apps (Messages, Notes, WhatsApp). Test dictation via the microphone button. Report dead zones or unresponsive keys."
3. Use Pierre's developer email for feedback contact
4. Fill in ALL fields before clicking "Submit for Review"

**Phase to address:** Public TestFlight phase. Prepare these artifacts BEFORE the build is ready.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Base keyboard import | CocoaPods conflict (#5), KeyDefinition collision (#6), pbxproj conflicts (#13) | Copy source files directly, rename conflicting types, single-commit import |
| Height & layout | Height flicker (#2), frame-zero layout (#11) | viewWillAppear constraint, once-flag for reloadData |
| Touch handling integration | UIKit/SwiftUI touch conflict (#1), spacebar trackpad (#7) | Single UIKit root, UIHostingController islands, per-key gesture recognizer |
| Memory profiling | 50MB budget exceeded (#3) | Profile BEFORE features, kill emoji picker, lazy-load overlays |
| Audio/haptic/theme | Wrong lifecycle point (#8), theme mismatch (#9) | touchesBegan triggers, replace Theme.swift with Dictus design tokens |
| State management | Dynamic Island desync (#10), stale proxy (#12) | Fix #60 first, add Combine subscriptions in UIKit |
| Public TestFlight | Beta App Review rejection (#4), missing test info (#14) | Privacy audit, dry-run review, prepare all metadata in advance |

## Sources

- [giellakbd-ios GitHub repository](https://github.com/divvun/giellakbd-ios) -- source architecture analysis (HIGH confidence)
- [giellakbd-ios issue #28: keyboard height doubles](https://github.com/divvun/giellakbd-ios/issues/28) -- height constraint flicker (HIGH confidence)
- [Apple: Custom Keyboard programming guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) -- extension limitations (HIGH confidence)
- [Apple: Configuring open access for a custom keyboard](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard) -- Full Access requirements (HIGH confidence)
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) -- guideline 5.1.1 keyboard data (HIGH confidence)
- [Apple Developer Forums: UICollectionView in keyboard extension](https://developer.apple.com/forums/thread/24032) -- frame-zero and constraint issues (MEDIUM confidence)
- [Apple Developer Forums: Keyboard extension memory](https://developer.apple.com/forums/thread/85478) -- 30-50MB limit behavior (MEDIUM confidence)
- [Apple: TestFlight test information requirements](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/) -- Beta App Review fields (HIGH confidence)
- [iOS App Store Review Guidelines 2026](https://theapplaunchpad.com/blog/app-store-review-guidelines) -- privacy manifest requirements (MEDIUM confidence)
- [KeyboardKit: iOS 17.1 extension crashes](https://keyboardkit.com/blog/2023/12/10/critical-extension-crashes-in-ios-17-1) -- extension crash patterns (MEDIUM confidence)
- Dictus project history: Phase 15.4 dead zones research, v1.2 retrospective, PROJECT.md constraints (HIGH confidence)
