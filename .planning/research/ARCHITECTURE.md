# Architecture Patterns

**Domain:** Premium tier integration into existing two-process iOS keyboard app
**Researched:** 2026-04-08
**Focus:** How SubscriptionManager, Smart Mode LLM, transcription history, custom vocabulary, and paywall integrate with the existing DictusApp + DictusKeyboard + DictusCore architecture
**Overall Confidence:** MEDIUM-HIGH

---

## Current Architecture (Baseline)

```
DictusApp (Main Process, SwiftUI)       DictusKeyboard (Extension, ~50MB limit, UIKit)
+-----------------------------+          +-------------------------------------------+
| DictationCoordinator        |          | KeyboardViewController                    |
|   WhisperKit / Parakeet     |<-Darwin->|   DictusKeyboardBridge                    |
|   UnifiedAudioEngine        | Notifs   |   GiellaKeyboardView (UICollectionView)   |
|   TranscriptionService      |          |   KeyboardRootView (SwiftUI host)         |
|   LiveActivityManager       |<-AppGrp->|     SuggestionBarView                     |
|   ModelManager              | Defaults |     ToolbarView                           |
|   SoundFeedbackService      |          |     RecordingOverlay                      |
+-----------------------------+          |   TextPrediction/ (C++ trie + ngram)      |
                                         +-------------------------------------------+

DictusCore (Local SPM package, linked by both targets)
+-- AppGroup (identifier, defaults, containerURL)
+-- SharedKeys (all cross-process UserDefaults keys)
+-- DarwinNotifications (ping-only cross-process signals)
+-- DictationStatus (idle/requested/recording/transcribing/ready/failed)
+-- UserDictionary (learned words, App Group storage)
+-- ModelInfo, SpeechEngine, FrequencyDictionary
+-- Design/, Logger, HapticFeedback, PersistentLog
```

### Key Constraints Carried Forward
- Keyboard extension: ~50MB RAM hard limit (~35MB free after trie/ngram)
- No `UIApplication.shared` in keyboard extension
- Darwin notifications carry NO payload (ping-only, read data from App Group)
- All cross-process data via `AppGroup.defaults` (UserDefaults) or `AppGroup.containerURL` (files)
- StoreKit 2 APIs are unreliable in extension sandbox -- must cache state
- Minimum target: iOS 17.0, but Apple Foundation Models requires iOS 26 + iPhone 15 Pro+

---

## Recommended Architecture: Premium Integration

### New Components Overview

| Component | Target | New/Modified | Responsibility |
|-----------|--------|-------------|----------------|
| `ProStatus` | DictusCore | NEW | Lightweight struct: isPro, expiresAt, source. Read by both processes. |
| `FeatureGate` | DictusCore | NEW | `canUse(.smartMode)` checks. Single API for all gating. |
| `SubscriptionManager` | DictusApp | NEW | StoreKit 2 lifecycle: products, purchase, restore, Transaction.updates stream. Writes ProStatus to App Group. |
| `TranscriptionEntry` | DictusCore | NEW | SwiftData @Model for history records. |
| `TranscriptionStore` | DictusCore | NEW | SwiftData ModelContainer at App Group path. save/fetch/search/export. |
| `CustomVocabulary` | DictusCore | NEW | Personal terms as [String] in App Group. toInitialPrompt() for WhisperKit. |
| `SmartModeTemplate` | DictusCore | NEW | Enum: .email, .sms, .notes, .summary with prompt strings. |
| `SmartModeService` | DictusApp | NEW | Orchestrates Apple Foundation Models (iOS 26) or MLX fallback. |
| `PaywallView` | DictusApp | NEW | SwiftUI SubscriptionStoreView wrapper with Pro benefits. |
| `UpgradePrompt` | DictusKeyboard | NEW | Minimal UIKit banner: "Dictus Pro -- Tap to upgrade". Opens dictus://upgrade. |
| `HistoryListView` | DictusApp | NEW | SwiftUI list with free (10 items) vs Pro (unlimited + search + export). |
| `VocabularyEditorView` | DictusApp | NEW | Add/remove/edit custom terms. |
| `SharedKeys` | DictusCore | MODIFIED | 5 new keys for Pro status, Smart Mode, vocabulary. |
| `DarwinNotifications` | DictusCore | MODIFIED | 1 new notification: proStatusChanged. |
| `DictationCoordinator` | DictusApp | MODIFIED | After transcription: save history, apply Smart Mode, read custom vocabulary. |
| `DictusApp.swift` | DictusApp | MODIFIED | dictus://upgrade URL handler, ModelContainer injection, SubscriptionManager start. |
| `ToolbarView` | DictusKeyboard | MODIFIED | Smart Mode toggle (gated by FeatureGate). |

---

## Component Boundaries & Data Flow

### 1. Subscription & Feature Gating

```
[App Store] --purchase/restore--> [DictusApp: SubscriptionManager]
                                       |
     Transaction.updates               | ProStatus(isPro, expiresAt, source).save()
     (async stream, real-time)         |
                                       v
                               [App Group UserDefaults]
                                 SharedKeys.proStatus
                                 (JSON: ~100 bytes)
                                       |
                                       v
                               [DictusKeyboard: FeatureGate]
                                 ProStatus.load() -> isPro: Bool
                                 (reads cached JSON, <1ms)
```

**Why this split:** StoreKit 2 `Transaction.currentEntitlements` and `Product.SubscriptionInfo.Status` require the full StoreKit runtime, which is only reliable in the main app process. Keyboard extensions run in a restricted sandbox where StoreKit 2 APIs may return empty results or fail silently. The correct pattern (confirmed by multiple Apple Developer Forum posts and community implementations) is: DictusApp resolves subscription state, serializes a simple struct to App Group, keyboard reads the cached struct.

**ProStatus struct (DictusCore):**

```swift
public struct ProStatus: Codable {
    public let isPro: Bool
    public let expiresAt: Date?
    public let source: Source
    
    public enum Source: String, Codable {
        case storekit   // Real StoreKit 2 entitlement
        case beta       // TestFlight/debug override
    }
    
    public static func load() -> ProStatus {
        guard let data = AppGroup.defaults.data(forKey: SharedKeys.proStatus),
              let status = try? JSONDecoder().decode(ProStatus.self, from: data)
        else {
            return ProStatus(isPro: false, expiresAt: nil, source: .storekit)
        }
        // Defend against stale cache: reject if expired
        if let expiry = status.expiresAt, expiry < Date() {
            return ProStatus(isPro: false, expiresAt: nil, source: .storekit)
        }
        return status
    }
}
```

**FeatureGate (DictusCore):**

```swift
public enum ProFeature {
    case smartMode
    case historySearch
    case historyExport
    case customVocabulary
    case unlimitedHistory
}

public enum FeatureGate {
    public static func canUse(_ feature: ProFeature) -> Bool {
        return ProStatus.load().isPro
    }
}
```

**Beta override:** During TestFlight, `SharedKeys.betaProOverride = true` from a debug menu in Settings. `ProStatus.load()` checks this flag first, returns `isPro: true` when set. Avoids needing sandbox StoreKit environment for every test. This follows the same pattern as the existing `SharedKeys.modelReady` flag.

**When does the keyboard learn about status changes?**
- New Darwin notification `proStatusChanged` posted by SubscriptionManager after writing ProStatus
- Keyboard observes this and refreshes its UI (show/hide Pro feature toggles)
- Also: keyboard reads ProStatus on every `viewWillAppear` (covers app restart, iOS killing the extension)

### 2. Transcription History

```
DictusApp                           DictusCore                        DictusKeyboard
  HistoryListView                   TranscriptionEntry (@Model)       (NO history access)
  - list (free: 10, Pro: all)       TranscriptionStore                (reads lastTranscription
  - search (Pro)                    - ModelContainer at                 via SharedKeys only,
  - export (Pro)                      AppGroup.containerURL/            as today)
  - swipe-to-delete                   transcriptions.store
  DictationCoordinator              - save(), fetchRecent(limit:),
  - calls store.save()               search(query:), export()
    after each transcription
```

**Why SwiftData over Core Data:** SwiftData is the modern replacement (iOS 17+, matches minimum target). Uses `@Model` macro, integrates with SwiftUI via `@Query`, supports App Group shared containers natively. Less boilerplate than Core Data.

**Why NOT in the keyboard extension:** The keyboard only needs `SharedKeys.lastTranscription` (one string) to insert text. Adding a SwiftData ModelContainer in the keyboard would cost 2-5MB RAM overhead for zero user benefit. History is viewed and searched exclusively in DictusApp.

**SwiftData model (DictusCore):**

```swift
@Model
public class TranscriptionEntry {
    public var text: String
    public var date: Date
    public var duration: TimeInterval
    public var modelUsed: String
    public var smartModeTemplate: String?   // nil if raw, or template name
    public var originalText: String?        // Pre-Smart-Mode text, if reformulated
    
    public init(text: String, date: Date, duration: TimeInterval, modelUsed: String) {
        self.text = text
        self.date = date
        self.duration = duration
        self.modelUsed = modelUsed
    }
}
```

**Container setup (DictusApp only):**

```swift
let schema = Schema([TranscriptionEntry.self])
let config = ModelConfiguration(
    schema: schema,
    url: AppGroup.containerURL!.appendingPathComponent("transcriptions.store"),
    cloudKitDatabase: .none  // 100% local, no iCloud
)
let container = try ModelContainer(for: schema, configurations: [config])
```

**Free vs Pro tier logic:**
- `TranscriptionStore.fetchRecent(limit:)` -- free passes 10, Pro passes nil (unlimited)
- Search and export methods check `FeatureGate.canUse(.historySearch)` before executing
- All transcriptions are saved regardless of tier (data is there when user upgrades)

### 3. Smart Mode LLM

```
DictusApp                           DictusCore                        DictusKeyboard
  SmartModeService                  SmartModeTemplate (enum)          ToolbarView
  - Apple Foundation Models           .email, .sms, .notes, .summary  - Smart Mode toggle
    (iOS 26 + Apple Intelligence)     prompt strings per template       (gated: FeatureGate)
  - MLX Swift fallback                                                - Template picker
    (SmolLM2 1.7B 4-bit)           SmartModeResult (struct)            (stored in App Group)
  DictationCoordinator                .original, .reformulated
  - post-transcription hook                                           NO LLM runs here.
  - reads smartModeEnabled                                            Keyboard only sets
    + template from App Group                                         flags in App Group.
```

**Two-tier LLM strategy:**

| Tier | Engine | Devices | RAM | Latency | Storage |
|------|--------|---------|-----|---------|---------|
| Primary | Apple Foundation Models | iPhone 15 Pro+, iOS 26+, Apple Intelligence enabled | ~0 (system-managed) | <1s | 0 (system model) |
| Fallback | MLX Swift + SmolLM2-1.7B-Instruct 4-bit | iPhone 12+, iOS 17+ | ~1-2GB | 2-5s | ~800MB-1.2GB download |

**Why Apple Foundation Models first:** Zero model management, zero storage cost, native Swift API with `@Generable` macro for structured output. The on-device ~3B parameter model is the same one powering Apple Intelligence Writing Tools -- it handles text reformulation natively. Availability check: `SystemLanguageModel.default.isAvailable` (returns false on incompatible devices or when AI is disabled).

**Why MLX fallback:** Apple Foundation Models requires iPhone 15 Pro+ AND iOS 26 AND Apple Intelligence enabled. Dictus targets iOS 17+ and iPhone 12+. A significant user segment (iPhone 12-15 standard) needs a fallback. MLX Swift is Apple's official open-source ML framework (MIT license), runs on CPU+GPU+Neural Engine, and supports quantized models. SmolLM2-1.7B-Instruct at 4-bit quantization fits in ~800MB-1GB and handles text reformulation adequately.

**SmartModeService pattern:**

```swift
@MainActor
class SmartModeService {
    func reformulate(text: String, template: SmartModeTemplate) async throws -> String {
        if #available(iOS 26, *), isFoundationModelsAvailable() {
            return try await reformulateWithFoundationModels(text: text, template: template)
        }
        return try await reformulateWithMLX(text: text, template: template)
    }
}
```

**Keyboard interaction -- no new IPC needed:**
1. User taps Smart Mode toggle in keyboard toolbar (Pro-gated)
2. User selects template; keyboard writes `SharedKeys.smartModeEnabled = true` + `SharedKeys.smartModeTemplate = "email"` to App Group
3. Normal dictation flow: keyboard triggers recording via Darwin/URL, app records and transcribes
4. After transcription, `DictationCoordinator.stopDictation()` reads `smartModeEnabled` + template from App Group
5. If enabled: passes text through `SmartModeService.reformulate()` before writing to `SharedKeys.lastTranscription`
6. Keyboard receives reformulated text via existing `transcriptionReady` Darwin notification
7. History saves both `originalText` and reformulated `text`

Smart Mode is transparent to the keyboard -- it just receives better text through the existing channel.

**MLX model download:** Same UX pattern as existing WhisperKit model download in ModelManager. Add a "Smart Mode model" card in Settings. Download is Pro-only. Store in App Group containerURL for persistence across app updates.

### 4. Custom Vocabulary

```
DictusApp                           DictusCore                        DictusKeyboard
  VocabularyEditorView              CustomVocabulary                  (NO direct access)
  - add/remove/edit terms           - terms: [String]                 (vocabulary used by
  - import from contacts?           - stored in App Group defaults      WhisperKit in app
                                    - toInitialPrompt() -> String       process only)
  DictationCoordinator
  - reads CustomVocabulary.shared
    before each transcription
  - passes toInitialPrompt()
    to WhisperKit DecodingOptions
```

**How it works:** WhisperKit's `DecodingOptions` accepts an `initialPrompt` parameter. This is the standard Whisper technique for context biasing -- providing contextual sentences containing target vocabulary terms biases the model toward recognizing those words during transcription. Research confirms this approach improves domain-specific recognition without fine-tuning.

**CustomVocabulary (DictusCore):**

```swift
public final class CustomVocabulary {
    public static let shared = CustomVocabulary()
    private static let storageKey = "dictus.customVocabulary"
    private static let maxTerms = 500  // Cap to prevent initialPrompt from being too long
    
    public var terms: [String] {
        didSet { save() }
    }
    
    public func toInitialPrompt() -> String? {
        guard !terms.isEmpty else { return nil }
        return "Termes importants: \(terms.joined(separator: ", "))."
    }
    
    private init() {
        terms = AppGroup.defaults.stringArray(forKey: Self.storageKey) ?? []
    }
    
    private func save() {
        AppGroup.defaults.set(terms, forKey: Self.storageKey)
        AppGroup.defaults.synchronize()
    }
}
```

**Integration in DictationCoordinator (3 lines):**

```swift
// In stopDictation(), before transcription:
let customPrompt = CustomVocabulary.shared.toInitialPrompt()
// Pass customPrompt to WhisperKit DecodingOptions.initialPrompt
```

This follows the same singleton + App Group pattern as the existing `UserDictionary` class.

### 5. Paywall & Upgrade Prompts

```
DictusApp                                    DictusKeyboard
  PaywallView (SwiftUI)                      UpgradePrompt (UIKit)
  - SubscriptionStoreView (StoreKit 2)       - "Dictus Pro -- Tap to open app"
  - Pro benefits showcase                    - Opens dictus://upgrade URL
  - Restore purchases                        - Minimal: UILabel + UIButton
  - Handles dictus://upgrade URL             - Memory cost: <1KB
```

**Why SubscriptionStoreView:** StoreKit 2 provides a built-in SwiftUI view that handles the entire purchase flow -- pricing, terms, restore, loading states. One line of SwiftUI. No custom payment UI needed. Fewer App Store review issues.

**Keyboard upgrade prompt:** When user taps a Pro feature and `FeatureGate.canUse()` returns false, show a minimal UIKit banner. Tapping opens `dictus://upgrade` via the existing URL scheme pattern (same as `dictus://dictate` for cold start). DictusApp handles this URL by presenting PaywallView.

---

## New SharedKeys

```swift
// Add to DictusCore/Sources/DictusCore/SharedKeys.swift
public static let proStatus = "dictus.proStatus"              // JSON-encoded ProStatus
public static let betaProOverride = "dictus.betaProOverride"  // Bool, TestFlight debug
public static let smartModeEnabled = "dictus.smartModeEnabled" // Bool
public static let smartModeTemplate = "dictus.smartModeTemplate" // String (template rawValue)
public static let customVocabulary = "dictus.customVocabulary" // [String] array
```

## New Darwin Notifications

```swift
// Add to DictusCore/Sources/DictusCore/DarwinNotifications.swift
/// Posted by DictusApp when Pro status changes (purchase, expiry, restore).
public static let proStatusChanged = "com.pivi.dictus.proStatusChanged" as CFString
```

Only one new Darwin notification. Smart Mode and Custom Vocabulary do not need notifications because they are consumed by DictusApp (same process). The keyboard only sets flags in App Group for the app to read.

---

## Patterns to Follow

### Pattern 1: App Group Cache for Cross-Process State
**What:** DictusApp owns the source of truth, writes serialized cache to App Group. Keyboard reads the cache.
**When:** Subscription state, dictation status, waveform energy, transcription results.
**Why:** This is the established IPC pattern in Dictus. Darwin notifications ping, App Group carries data. Keep cached values small (<1KB) and call `synchronize()` after writes.
**Existing precedent:** `DictationStatus`, `lastTranscription`, `waveformEnergy` all follow this pattern.

### Pattern 2: Feature Gating at the UI Layer
**What:** Check `FeatureGate.canUse(.feature)` at the point where the user interacts, not inside business logic.
**When:** Every Pro-only UI element in keyboard and app.
**Why:** Prevents half-executed Pro flows. User sees a clear upgrade message. Business logic stays clean of subscription checks. If the user upgrades mid-session, features unlock immediately on next `viewWillAppear`.

### Pattern 3: Same-Process LLM (No Cross-Process LLM)
**What:** Smart Mode LLM runs only in DictusApp process. Keyboard sets flags, receives results.
**When:** Always. Apple Foundation Models and MLX both require 1-2GB+ RAM.
**Why:** Keyboard has ~35MB free. Even Apple Foundation Models runs in the host app process, not in extensions. The keyboard's role is limited to: set `smartModeEnabled` + `smartModeTemplate` in App Group, then receive reformulated text through the existing `lastTranscription` channel.

### Pattern 4: Singleton + App Group for Shared Domain Objects
**What:** Classes like `CustomVocabulary`, `UserDictionary` use `static let shared` with App Group storage.
**When:** Domain objects that both processes might read (even if only one writes).
**Why:** Established pattern in the codebase (`UserDictionary.shared`). Simple, predictable, low memory. The singleton loads from App Group on init, saves on mutation.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: StoreKit 2 in Keyboard Extension
**What:** Calling `Transaction.currentEntitlements` or `Product.products(for:)` from DictusKeyboard.
**Why bad:** Keyboard extensions run in a restricted sandbox. StoreKit 2 APIs may return empty results or fail silently. Apple docs do not guarantee StoreKit works in extensions.
**Instead:** Cache `ProStatus` to App Group from DictusApp. Keyboard reads the cached struct (<1ms).

### Anti-Pattern 2: SwiftData ModelContainer in Keyboard
**What:** Opening a SwiftData container in DictusKeyboard for history access.
**Why bad:** ModelContainer init costs 2-5MB RAM + I/O. The keyboard never displays history. Wasting memory for zero benefit.
**Instead:** Keyboard reads `SharedKeys.lastTranscription` (one string). History lives in DictusApp only.

### Anti-Pattern 3: Downloading LLM Models from Keyboard
**What:** Triggering MLX model download from the keyboard process.
**Why bad:** Keyboard extensions have no reliable background execution. iOS kills them aggressively. Model files are 800MB-1.2GB.
**Instead:** Model download in DictusApp (same pattern as WhisperKit model download). Keyboard just toggles flags.

### Anti-Pattern 4: Real-Time Subscription Validation in Keyboard
**What:** Checking StoreKit receipt or calling Apple servers from keyboard on every key press.
**Why bad:** Adds latency, requires network (keyboard may not have), wastes battery.
**Instead:** Cached `ProStatus` with expiry date. DictusApp refreshes on launch and via `Transaction.updates` stream. Keyboard trusts the cache. Worst case: user keeps Pro for hours after lapse (acceptable tradeoff).

### Anti-Pattern 5: Putting Smart Mode Logic in DictusCore
**What:** Making DictusCore depend on Foundation Models or MLX frameworks.
**Why bad:** DictusCore is linked by DictusKeyboard. Foundation Models framework is only available on iOS 26+. MLX is ~100MB+ framework. Either would bloat the keyboard extension or cause link errors on iOS 17-25.
**Instead:** Smart Mode service lives only in DictusApp. DictusCore only has the `SmartModeTemplate` enum (plain Swift, no framework dependency).

---

## Suggested Build Order (Dependency-Based)

### Phase 1: Subscription Infrastructure
1. `ProStatus` + `FeatureGate` in DictusCore
2. `SubscriptionManager` in DictusApp (StoreKit 2 Transaction.updates + Product.subscription)
3. New `SharedKeys` for proStatus, betaProOverride
4. `proStatusChanged` Darwin notification
5. Beta override flag for TestFlight testing

**Rationale:** Every other Pro feature depends on `FeatureGate.canUse()`. Build and validate first. With beta override, all subsequent features can be developed and tested without a real subscription or StoreKit sandbox.

### Phase 2: Paywall UI
1. `PaywallView` in DictusApp wrapping SubscriptionStoreView
2. `UpgradePrompt` in DictusKeyboard (UIKit banner, <1KB memory)
3. `dictus://upgrade` URL scheme handler in DictusApp
4. Restore purchases flow
5. Pro benefits showcase

**Rationale:** Users need a way to purchase before Pro features become visible. Paywall depends only on Phase 1.

### Phase 3: Transcription History
1. `TranscriptionEntry` SwiftData model in DictusCore
2. `TranscriptionStore` with App Group container path
3. Save hook in `DictationCoordinator.stopDictation()`
4. `HistoryListView` in DictusApp
5. Free tier limit (10) vs Pro (unlimited) via FeatureGate
6. Search (Pro) + export (Pro)

**Rationale:** Self-contained feature with high perceived value. No new IPC, no keyboard changes beyond what Phase 1 already provides. Depends on Phase 1 for gating.

### Phase 4: Custom Vocabulary
1. `CustomVocabulary` class in DictusCore (follows UserDictionary pattern)
2. `VocabularyEditorView` in DictusApp
3. Integration: `DictationCoordinator` reads `toInitialPrompt()` before WhisperKit transcription
4. Feature gate for Pro

**Rationale:** Simple data model (string array), single integration point (3 lines in DictationCoordinator). Depends on Phase 1 for gating. Can validate vocabulary impact by comparing transcription accuracy with and without terms.

### Phase 5: Smart Mode LLM
1. `SmartModeTemplate` enum in DictusCore (plain Swift)
2. Apple Foundation Models integration (iOS 26 code path)
3. MLX Swift fallback: model download flow, inference pipeline
4. `SmartModeService` orchestrator in DictusApp
5. Integration: post-transcription hook in `DictationCoordinator`
6. Smart Mode toggle + template picker in keyboard ToolbarView (gated)
7. History integration: save originalText + reformulated text
8. Model download UI in Settings (MLX fallback, Pro-only)

**Rationale:** Most complex feature with most unknowns: Apple Foundation Models device availability, MLX model performance on iPhone, RAM usage on older devices. Build last. Benefits from Phase 1 (gating), Phase 3 (history stores original + reformulated), Phase 4 (vocabulary improves base transcription before reformulation).

### Build Order Dependency Graph

```
Phase 1: Subscription   (foundation -- everything depends on this)
    |
    +-> Phase 2: Paywall   (purchase mechanism)
    |
    +-> Phase 3: History   (independent of 2, needs 1 for gating)
    |
    +-> Phase 4: Vocabulary (independent of 2/3, needs 1 for gating)
    |
    +-> Phase 5: Smart Mode (benefits from 3+4, needs 1 for gating)
```

Phases 2, 3, 4 can run in parallel after Phase 1 is complete. Phase 5 should be last.

---

## Modified Existing Files Summary

| File | Change | Lines Est. |
|------|--------|-----------|
| `DictusCore/SharedKeys.swift` | +5 new keys | +10 |
| `DictusCore/DarwinNotifications.swift` | +1 notification name | +4 |
| `DictusApp/DictationCoordinator.swift` | Post-transcription: save history, read Smart Mode flags, read custom vocabulary, apply reformulation | +40-60 |
| `DictusApp/DictusApp.swift` | `dictus://upgrade` URL handler, ModelContainer injection, start SubscriptionManager | +30 |
| `DictusKeyboard/Views/ToolbarView.swift` | Smart Mode toggle (gated), template picker | +30-50 |
| `DictusCore/Package.swift` | No change (SwiftData is system framework) | 0 |

---

## Scalability Considerations

| Concern | At launch | At 10K users | At 100K users |
|---------|-----------|--------------|---------------|
| Subscription validation | StoreKit 2 local only | Same | Same (Apple handles scale) |
| History storage | SwiftData local, ~1MB | ~10MB per user | Consider auto-prune >1 year |
| Custom vocabulary | App Group defaults, <10KB | Same | Same (500-term cap) |
| Smart Mode model | On-device, no server | Same | Same |
| Paywall | SubscriptionStoreView | Same | Same |

No server infrastructure needed. Everything runs 100% on-device. Scales to any user count at zero marginal cost, consistent with Dictus's privacy-first identity.

---

## Sources

### HIGH Confidence
- Codebase analysis: AppGroup.swift, SharedKeys.swift, DarwinNotifications.swift, DictationCoordinator.swift, UserDictionary.swift, DictationStatus.swift, Package.swift
- [Apple Foundation Models documentation](https://developer.apple.com/documentation/FoundationModels) -- official framework reference, iOS 26+
- [StoreKit 2 currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements) -- Apple official docs
- [MLX Swift on GitHub](https://github.com/ml-explore/mlx-swift) -- Apple's official ML framework, MIT license
- [WWDC25: Explore LLM on Apple silicon with MLX](https://developer.apple.com/videos/play/wwdc2025/298/) -- MLX on iOS reference

### MEDIUM Confidence
- [SwiftData App Group shared container setup](https://developer.apple.com/forums/thread/732986) -- Apple Developer Forums, confirmed approach for extensions
- [StoreKit 2 subscription sharing with extensions via App Group](https://medium.com/@aisultanios/implement-inn-app-subscriptions-using-swift-and-storekit2-serverless-and-share-active-purchases-7d50f9ecdc09) -- community pattern, consistent with Apple's recommended approach
- [Foundation Models code-along](https://developer.apple.com/events/resources/code-along-205/) -- Apple's reference implementation
- [AnyLanguageModel Swift package](https://huggingface.co/blog/anylanguagemodel) -- drop-in Foundation Models API replacement for older devices
- [LocalLLMClient Swift package](https://dev.to/tattn/localllmclient-a-swift-package-for-local-llms-using-llamacpp-and-mlx-1bcp) -- unified llama.cpp + MLX Swift API

### LOW Confidence
- [Contextual biasing for Whisper via initialPrompt](https://arxiv.org/html/2410.18363v1) -- research validates the technique, but WhisperKit-specific behavior with French initialPrompt needs on-device testing
- MLX model RAM on iPhone (~1-2GB for 1.7B 4-bit quantized) -- based on desktop benchmarks, iPhone profiling required
- Apple Foundation Models French quality -- model is optimized for English, French reformulation quality unknown until tested
