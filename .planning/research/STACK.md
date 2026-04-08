# Technology Stack -- v1.5 Dictus Pro (Premium Features)

**Project:** Dictus v1.5
**Researched:** 2026-04-08
**Scope:** Stack additions for premium tier: StoreKit 2 subscriptions, on-device LLM Smart Mode (Apple Foundation Models + open-source fallback), transcription history with full-text search, custom vocabulary injection. Existing stack (Swift 5.9+, SwiftUI, WhisperKit, FluidAudio, giellakbd-ios, AOSP trie, n-gram engine, DictusCore) is validated and unchanged.

---

## Critical Finding: 4 New Capabilities, 2 New SPM Dependencies

The v1.5 premium tier requires:
1. **StoreKit 2** (system framework, no dependency) for subscription management
2. **Apple Foundation Models** (system framework, iOS 26+) for Smart Mode LLM on new devices
3. **mlx-swift** (SPM) for open-source LLM inference on older Apple Intelligence-ineligible devices
4. **GRDB.swift** (SPM) for transcription history with FTS5 full-text search

WhisperKit's existing `promptTokens` parameter in `DecodingOptions` handles custom vocabulary injection -- no new dependency needed.

---

## Recommended Stack Additions

### 1. StoreKit 2 (System Framework -- No Dependency)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| StoreKit 2 | iOS 15.0+ (system) | Subscription management, entitlement verification | Native async/await API, JWS-signed transactions, no third-party SDK needed. Free. Already ships with iOS. Transaction.currentEntitlements provides serverless entitlement checking. |

**Architecture for keyboard extension sync:**

StoreKit 2's `Transaction.currentEntitlements` runs in the main app. The keyboard extension (50MB limit, no StoreKit overhead) reads a boolean flag from App Group UserDefaults:

```
Main app: Transaction.currentEntitlements -> verify -> write isPro=true to UserDefaults(suiteName: "group.solutions.pivi.dictus")
Keyboard: read isPro from shared UserDefaults -> gate Pro features
```

This is the documented best practice for extensions. The keyboard never imports StoreKit.

**Why NOT RevenueCat:** Dictus is iOS-only, open-source (MIT), and targets <$2,500/month initially. RevenueCat adds a cloud dependency (contradicts privacy identity), costs 1% of revenue above free tier, and the cross-platform dashboard is unnecessary for iOS-only. StoreKit 2's async/await API is straightforward for a single subscription tier. If Dictus later ships Android or needs A/B paywall testing, revisit.

**Confidence:** HIGH -- StoreKit 2 is mature (shipped iOS 15, 4+ years stable). App Group UserDefaults sync for extensions is a well-documented Apple pattern.

---

### 2. Apple Foundation Models (System Framework -- iOS 26+)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Foundation Models | iOS 26+ (system) | On-device LLM for Smart Mode text reformulation | Apple's ~3B parameter model, runs on Neural Engine + GPU. Free, no API key, no download needed (ships with Apple Intelligence). Privacy-preserving. Native Swift API with structured output (@Generable). |

**Key API surface:**

```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "Reformulate this text as a formal email: ...")
// response.content is String

// Structured output:
@Generable struct SmartModeResult {
    @Guide(description: "The reformulated text")
    var text: String
    @Guide(description: "A brief explanation of changes made")
    var summary: String
}
let structured = try await session.respond(to: prompt, generating: SmartModeResult.self)
```

**Device requirements (Apple Intelligence):**
- iPhone 15 Pro / 15 Pro Max (A17 Pro)
- iPhone 16 / 16 Plus / 16 Pro / 16 Pro Max
- iPhone 17 series
- iPad mini (A17 Pro), iPad/Mac with M1+
- Apple Intelligence must be enabled in Settings
- 7 GB free storage required

**Runtime availability check:**
```swift
let model = SystemLanguageModel.default
if model.availability == .available {
    // Use Foundation Models
} else {
    // Fall back to mlx-swift open-source model
}
```

**Confidence:** HIGH -- Foundation Models is a first-party Apple framework with official documentation and WWDC25 sessions. The API is simple and well-documented.

---

### 3. mlx-swift + MLXLLM (SPM -- Open-Source LLM Fallback)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | 0.21.x | Apple's ML framework for LLM inference on Apple Silicon | Official Apple open-source project. 20-50% faster than llama.cpp on Apple Silicon. Native Swift, Metal GPU acceleration, unified memory architecture. |
| [mlx-swift-examples/MLXLLM](https://github.com/ml-explore/mlx-swift-examples) | latest | LLM loading, tokenization, generation pipeline | Provides `LLMModel`, `generate()`, streaming, Hugging Face model loading. Used by Apple's own LLMEval example app. |

**Recommended fallback model: Gemma 3N E2B (4-bit quantized)**

| Model | Parameters | Disk Size | RAM Usage | Why |
|-------|-----------|-----------|-----------|-----|
| Gemma 3N E2B (Q4) | ~2B effective | ~1.5 GB | ~1.5-2 GB | Smallest viable model for text reformulation. "Effectively 2B" via MatFormer architecture (5B total, loads 2B). Runs on iPhone 14 Pro+ (6GB RAM). Good at French. |

**Alternative models (if Gemma insufficient):**

| Model | Parameters | Disk Size | RAM Usage | Notes |
|-------|-----------|-----------|-----------|-------|
| Phi-4 Mini (Q4) | 3.8B | ~2.2 GB | ~2.5 GB | Microsoft, strong instruction following, but heavier |
| Mistral 7B (Q4) | 7B | ~4 GB | ~5 GB | Excellent French, but needs 8GB+ RAM devices only |

**Critical constraint:** LLM inference runs ONLY in DictusApp (main app), never in the keyboard extension. The 50MB keyboard memory limit makes LLM inference impossible in-extension. Flow:
1. User taps Smart Mode in keyboard
2. Keyboard sends transcribed text to DictusApp via URL scheme / Darwin notification
3. DictusApp runs LLM inference (Foundation Models or mlx-swift)
4. Result written to App Group
5. Keyboard reads reformulated text from App Group, inserts at cursor

**Model download/management:** Models are downloaded on-demand from Hugging Face Hub (same UX pattern as WhisperKit model downloads). Stored in App Group shared container so both app and keyboard can reference status. Use `com.apple.developer.kernel.increased-memory-limit` entitlement for DictusApp.

**Why NOT llama.cpp:** mlx-swift is Apple's own framework, specifically optimized for Apple Silicon unified memory. 20-50% faster inference than llama.cpp on same hardware. Native Swift (no C++ bridging). Apple actively maintains it and presented it at WWDC25.

**Why NOT Core ML conversion:** Core ML requires pre-conversion of models (coremltools). MLX loads Hugging Face models directly, supports more model architectures, and updates faster when new models release. Core ML is better for fixed models; MLX is better for a model catalog that evolves.

**Why NOT LocalLLMClient or AnyLanguageModel:** Both are experimental/young (API subject to change). mlx-swift is maintained by Apple's ML team with stable releases. For a production app, depend on the stable upstream rather than an abstraction layer.

**Confidence:** MEDIUM -- mlx-swift is stable and Apple-maintained, but iOS LLM inference is still early. Memory pressure on 6GB devices (iPhone 14 Pro, 15, 15 Plus) is a real concern. The 4-bit Gemma 3N E2B model (~1.5GB RAM) should fit, but needs on-device profiling. iPhone 12/13 (4GB RAM) likely cannot run any LLM -- these users get Smart Mode only via Foundation Models (if they upgrade to iPhone 15 Pro+).

---

### 4. GRDB.swift (SPM -- Transcription History + FTS5)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | 7.10.0 | SQLite database with FTS5 full-text search for transcription history | Mature (8+ years, 7K+ stars), actively maintained, iOS 13+. Native FTS5 support with `unicode61` tokenizer (handles French accents). Swift 6.1+ compatible. No Core Data/SwiftData overhead. |

**Why GRDB over SwiftData:**
- SwiftData has NO built-in full-text search. FTS requires dropping to SQLite anyway.
- SwiftData requires iOS 17+ minimum (fine for us) but adds Core Data overhead for a simple use case.
- GRDB gives direct SQLite access with FTS5, which is purpose-built for text search.
- Transcription history is a simple schema (timestamp, text, duration, language, app) -- no complex relationships that would benefit from SwiftData.

**Why GRDB over raw SQLite:**
- GRDB provides Swift-native query builder, Codable record mapping, database observation (for live UI updates), and built-in FTS5 API.
- Raw SQLite via `sqlite3_*` C API is error-prone and verbose.

**FTS5 schema for transcription history:**

```swift
// Regular table
try db.create(table: "transcription") { t in
    t.autoIncrementedPrimaryKey("id")
    t.column("text", .text).notNull()
    t.column("date", .datetime).notNull()
    t.column("duration", .double).notNull()  // seconds
    t.column("language", .text).notNull()     // "fr" or "en"
    t.column("sourceApp", .text)              // bundle ID of app where dictated
    t.column("wordCount", .integer).notNull()
    t.column("isPro", .boolean).notNull().defaults(to: false)  // was Pro active
}

// FTS5 virtual table (synced with content table)
try db.create(virtualTable: "transcription_ft", using: FTS5()) { t in
    t.synchronize(withTable: "transcription")
    t.tokenizer = .unicode61(removeDiacritics: false)  // Keep accents for French
    t.column("text")
}
```

**Key detail -- `removeDiacritics: false`:** By default, FTS5's `unicode61` tokenizer strips diacritics (e becomes e, so "ete" matches "ete"). For French, we want accent-aware search: searching "ete" should find "ete" but NOT "ete". Set `removeDiacritics: false`.

**Database location:** App Group shared container (`group.solutions.pivi.dictus`). The main app writes transcriptions after dictation. The keyboard reads history count for Pro feature gating. Both targets can access.

**Confidence:** HIGH -- GRDB is the most mature Swift SQLite library (v7.10.0, 8+ years, used in production by Signal and others). FTS5 is a proven SQLite extension. French accent handling is explicitly supported via `unicode61` tokenizer options.

---

### 5. Custom Vocabulary via WhisperKit `promptTokens` (No New Dependency)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| WhisperKit `DecodingOptions.promptTokens` | 0.16.0+ (existing) | Inject custom vocabulary to bias Whisper transcription | Already in WhisperKit API. Whisper's prompt mechanism conditions the decoder on previous context, biasing it toward specific words/spellings. No new dependency. |

**How it works:**

WhisperKit's `DecodingOptions` has a `promptTokens: [Int]?` property. These token IDs are prepended to the decoder's context, biasing transcription toward those words. This is the same mechanism as OpenAI Whisper's `--initial_prompt`.

**Implementation approach:**

```swift
// 1. User adds custom words in Settings: ["Dictus", "PIVI Solutions", "WhisperKit"]
// 2. Convert to natural sentence for better Whisper conditioning:
let promptText = "Some context words: Dictus, PIVI Solutions, WhisperKit."
// 3. Tokenize using WhisperKit's tokenizer:
let tokens = try await whisperKit.tokenizer?.encode(text: promptText)
// 4. Pass to DecodingOptions:
var options = DecodingOptions()
options.promptTokens = tokens
let result = try await whisperKit.transcribe(audioPath: path, decodeOptions: options)
```

**Key insight from OpenAI Whisper research:** Prompt works best as natural sentences, not flat word lists. "Contexte: Dictus est une application de PIVI Solutions qui utilise WhisperKit." works better than "Dictus PIVI Solutions WhisperKit". The model uses the prompt as conversational context.

**Storage:** Custom vocabulary stored in App Group UserDefaults as `[String]`. Main app manages the list (add/remove/edit). Before each transcription, vocabulary is converted to prompt tokens.

**Limitations:**
- Prompt window is ~224 tokens (Whisper constraint). With French sentences, this accommodates ~30-50 custom words.
- Does not guarantee the word appears in output -- it biases probability, not forces it.
- Works best for proper nouns, brand names, and technical terms that Whisper would otherwise misspell.

**Confidence:** HIGH -- This is the standard Whisper vocabulary injection mechanism, documented by OpenAI and used in production by numerous apps. WhisperKit exposes it via `promptTokens` in `DecodingOptions`.

---

## Integration Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                    DictusApp                         │
│                                                      │
│  StoreKit 2 ─── Transaction.currentEntitlements     │
│       │                                              │
│       ▼                                              │
│  App Group UserDefaults ◄──── isPro: Bool           │
│       │                                              │
│  Foundation Models (iOS 26+)                        │
│       │    OR                                        │
│  mlx-swift + Gemma 3N E2B (fallback)               │
│       │                                              │
│  GRDB (transcription_history.sqlite)                │
│       │                                              │
│  WhisperKit + promptTokens (custom vocab)           │
└──────────────────┬──────────────────────────────────┘
                   │ App Group (shared container)
                   │ Darwin notifications / URL scheme
┌──────────────────▼──────────────────────────────────┐
│               DictusKeyboard                         │
│                                                      │
│  Reads isPro from shared UserDefaults               │
│  Reads reformulated text from App Group             │
│  Reads transcription count from App Group           │
│  NO StoreKit, NO LLM, NO GRDB imports              │
│  (stays within 50MB memory limit)                   │
└─────────────────────────────────────────────────────┘
```

---

## New SPM Dependencies

| Package | URL | Version | Target | License |
|---------|-----|---------|--------|---------|
| mlx-swift | https://github.com/ml-explore/mlx-swift | 0.21.x | DictusApp only | MIT |
| mlx-swift-examples (MLXLLM) | https://github.com/ml-explore/mlx-swift-examples | latest | DictusApp only | MIT |
| GRDB.swift | https://github.com/groue/GRDB.swift | 7.10.0 | DictusApp + DictusCore | MIT |

**Total new SPM dependencies: 2** (mlx-swift ecosystem counts as one logical dependency, GRDB is the other)

---

## Installation

```bash
# Add via SPM in Xcode (File > Add Package Dependencies):

# 1. GRDB.swift
#    URL: https://github.com/groue/GRDB.swift.git
#    Version: Up to Next Major (7.10.0)
#    Target: DictusApp, DictusCore

# 2. mlx-swift
#    URL: https://github.com/ml-explore/mlx-swift.git
#    Version: Up to Next Minor (0.21.x)
#    Target: DictusApp only

# 3. mlx-swift-examples (for MLXLLM library)
#    URL: https://github.com/ml-explore/mlx-swift-examples.git
#    Version: main branch (tracks mlx-swift releases)
#    Target: DictusApp only

# System frameworks (no install needed):
# - StoreKit (DictusApp only)
# - FoundationModels (DictusApp only, iOS 26+)
```

### Entitlements

```xml
<!-- DictusApp.entitlements (add these) -->
<key>com.apple.developer.kernel.increased-memory-limit</key>
<true/>
<!-- Already present: App Group, audio background mode -->
```

### StoreKit Configuration

```
# Create in Xcode: File > New > StoreKit Configuration File
# Add subscription group: "dictus_pro"
# Add product: "dictus_pro_monthly" (auto-renewable, ~4-5 EUR/month)
# Configure in App Store Connect before release
```

---

## Unchanged Stack (validated, DO NOT modify)

| Technology | Version | Target | Notes |
|------------|---------|--------|-------|
| Swift | 5.9+ | All | No change |
| SwiftUI | iOS 17+ | DictusApp, overlays | No change |
| UIKit (giellakbd-ios) | Vendored | DictusKeyboard | No change |
| WhisperKit | 0.16.0+ | DictusApp | No change (promptTokens already available) |
| FluidAudio (Parakeet) | via SPM | DictusApp | No change |
| DeviceKit | 5.8.x | DictusKeyboard | No change |
| DictusCore | Local SPM | Shared | Add GRDB dependency for shared DB access |
| AOSP Trie (C++) | Vendored | DictusKeyboard | No change |
| N-gram engine (C++) | Vendored | DictusKeyboard | No change |
| iOS minimum | 17.0 | All | No change (Foundation Models gated by availability check, not deployment target) |

---

## What NOT to Add

| Temptation | Why Not |
|------------|---------|
| RevenueCat | Cloud dependency contradicts privacy identity. iOS-only app. StoreKit 2 is sufficient for single subscription tier. Free tier covers Dictus's scale. |
| SwiftData for history | No built-in FTS. Would need to drop to SQLite anyway for full-text search. GRDB is more direct and lighter. |
| Core Data for history | Same FTS problem as SwiftData, plus heavier migration/schema management overhead for a simple table. |
| llama.cpp | C++ bridging, slower than mlx-swift on Apple Silicon. Apple maintains mlx-swift specifically for this use case. |
| Core ML model conversion | Requires offline coremltools conversion per model. MLX loads Hugging Face models directly, easier to update model catalog. |
| LocalLLMClient | Experimental, API unstable. Depend on upstream mlx-swift directly. |
| AnyLanguageModel | Young project (Nov 2025). Abstraction layer over mlx-swift adds indirection without clear benefit for a single-platform app. |
| Argmax SDK (commercial) | Paid SDK for custom vocabulary/streaming. WhisperKit's promptTokens already handles vocabulary injection. Not needed. |
| Any cloud LLM API | Contradicts 100% on-device privacy identity. |
| Realm / Firebase | Cloud-oriented databases. Overkill and wrong philosophy for local-only storage. |
| Mistral 7B as default | 4GB download, 5GB+ RAM. Too heavy for most iPhones. Gemma 3N E2B is 1/3 the size and runs on more devices. |

---

## Memory Budget Impact (DictusApp)

| Component | Current (v1.4) | After v1.5 | Notes |
|-----------|----------------|------------|-------|
| WhisperKit model | ~150-300MB | ~150-300MB | No change |
| GRDB + SQLite | N/A | ~2-5MB | Depends on history size |
| LLM model (loaded) | N/A | ~1.5-2GB | Gemma 3N E2B Q4. Only loaded during Smart Mode. Unloaded after use. |
| Foundation Models | N/A | ~0MB (system) | OS manages memory, not app |
| StoreKit | N/A | ~0MB (system) | Negligible |
| **Peak during Smart Mode** | ~300MB | ~2.0-2.5GB | With increased-memory-limit entitlement |

**DictusKeyboard memory:** No change. Keyboard reads booleans and strings from App Group. No new imports.

---

## Minimum Device Matrix for Pro Features

| Feature | Minimum Device | Minimum iOS | RAM Required | Notes |
|---------|---------------|-------------|-------------|-------|
| Subscription | iPhone 12 | iOS 17.0 | 4GB | StoreKit 2 works everywhere |
| Transcription History | iPhone 12 | iOS 17.0 | 4GB | GRDB/SQLite is lightweight |
| Custom Vocabulary | iPhone 12 | iOS 17.0 | 4GB | WhisperKit promptTokens, no extra RAM |
| Smart Mode (AFM) | iPhone 15 Pro | iOS 26.0 | 8GB | Apple Intelligence required |
| Smart Mode (MLX) | iPhone 14 Pro | iOS 17.0 | 6GB | 4-bit Gemma 3N E2B needs ~1.5GB free |
| Smart Mode | iPhone 12-14 | iOS 17.0 | 4GB | NOT available -- insufficient RAM for any LLM |

**Key implication:** Smart Mode is a premium feature that requires premium hardware. iPhone 12/13/14 (non-Pro) users can subscribe for history + vocabulary but cannot use Smart Mode. This should be clearly communicated in the paywall UI.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Subscriptions | StoreKit 2 (native) | RevenueCat | Cloud dependency, cost, unnecessary for iOS-only single tier |
| LLM (new devices) | Foundation Models | OpenAI API | Cloud, cost, privacy violation |
| LLM (older devices) | mlx-swift + Gemma 3N E2B | llama.cpp | Slower on Apple Silicon, C++ bridging needed |
| LLM (older devices) | mlx-swift + Gemma 3N E2B | Core ML converted model | Harder to update model catalog, requires offline conversion |
| History storage | GRDB.swift + FTS5 | SwiftData | No full-text search built in |
| History storage | GRDB.swift + FTS5 | Core Data + manual FTS | More complex, GRDB handles it natively |
| History search | FTS5 (unicode61) | NSPredicate CONTAINS | FTS5 is orders of magnitude faster for text search, handles tokenization |
| Custom vocabulary | WhisperKit promptTokens | Argmax SDK | Paid, promptTokens already works |
| Custom vocabulary | WhisperKit promptTokens | Fine-tuned Whisper model | Massive complexity for marginal gain. Prompt conditioning is sufficient. |

---

## Confidence Assessment

| Area | Confidence | Reasoning |
|------|------------|-----------|
| StoreKit 2 + App Group sync | HIGH | Mature API (4+ years), well-documented pattern for extensions, multiple tutorial sources confirm approach |
| Foundation Models API | HIGH | First-party Apple framework, official docs + WWDC25 sessions, simple API surface |
| Foundation Models availability | HIGH | Device list confirmed via Apple docs. Runtime check via `model.availability`. |
| mlx-swift for iOS LLM | MEDIUM | Apple-maintained, active development, but iOS LLM is still early. Memory on 6GB devices needs profiling. |
| Gemma 3N E2B as fallback model | MEDIUM | Strong benchmarks, ~1.5GB Q4 is within budget, but French text reformulation quality needs evaluation |
| GRDB + FTS5 for history | HIGH | Mature library (v7.10.0, 8+ years), FTS5 is proven SQLite extension, French accent support confirmed |
| WhisperKit promptTokens | HIGH | Standard Whisper mechanism, exposed in WhisperKit API, documented by OpenAI |
| LLM on iPhone 12/13 (4GB) | HIGH (not feasible) | No viable LLM fits in 4GB RAM alongside app + OS. These devices cannot run Smart Mode. |

---

## Sources

### Primary (HIGH confidence)
- [Apple Foundation Models documentation](https://developer.apple.com/documentation/FoundationModels) -- official API reference
- [Apple Foundation Models newsroom](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/) -- device requirements, capabilities
- [Exploring the Foundation Models framework (createwithswift.com)](https://www.createwithswift.com/exploring-the-foundation-models-framework/) -- API details: LanguageModelSession, @Generable, GenerationOptions
- [StoreKit 2 Apple Developer](https://developer.apple.com/storekit/) -- official StoreKit 2 reference
- [StoreKit 2 sharing purchases with extensions (Aisultan Askarov)](https://medium.com/@aisultanios/implement-inn-app-subscriptions-using-swift-and-storekit2-serverless-and-share-active-purchases-7d50f9ecdc09) -- App Group sync pattern
- [GRDB.swift GitHub](https://github.com/groue/GRDB.swift) -- v7.10.0, FTS5 documentation
- [GRDB FTS5 documentation](https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md) -- unicode61 tokenizer, accent handling
- [WhisperKit Configurations.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Configurations.swift) -- promptTokens API verification
- [mlx-swift GitHub](https://github.com/ml-explore/mlx-swift) -- Apple's ML framework
- [mlx-swift-examples GitHub](https://github.com/ml-explore/mlx-swift-examples) -- LLMEval iOS app, MLXLLM library

### Secondary (MEDIUM confidence)
- [Explore LLMs on Apple Silicon with MLX (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/298/) -- Apple's official MLX presentation
- [Building Offline RAG on iOS with Gemma 3N (Greg Sommerville)](https://medium.com/google-cloud/building-offline-rag-on-ios-how-to-run-gemma-3n-locally-ffdfda6f7217) -- Gemma 3N E2B iOS deployment, MLX vs MediaPipe comparison
- [Gemma 3N E2B specifications (apxml.com)](https://apxml.com/models/gemma-3n-e2b-it) -- memory requirements, parameter counts
- [Running Phi models on iOS with MLX (strathweb.com)](https://www.strathweb.com/2025/03/running-phi-models-on-ios-with-apple-mlx-framework/) -- iOS MLX practical guide
- [What's new in StoreKit and IAP (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/241/) -- 2025 StoreKit updates
- [OpenAI Whisper prompt vs prefix discussion](https://github.com/openai/whisper/discussions/117) -- prompt conditioning best practices
- [Step-by-step LLM on iPhone with MLX Swift (awni gist)](https://gist.github.com/awni/fe4f96c21ead68e60191190cbc1c129b) -- practical iOS MLX guide

### Tertiary (LOW confidence)
- [Small Language Models Guide 2026 (localaimaster.com)](https://localaimaster.com/blog/small-language-models-guide-2026) -- model comparison, RAM requirements
- [LLMEval memory usage issue #17](https://github.com/ml-explore/mlx-swift-examples/issues/17) -- real-world memory reports (Qwen2 4B uses 10GB+ after inference)
- [RevenueCat vs Native IAP (nativelaunch.dev)](https://nativelaunch.dev/articles/compare/revenuecat-vs-native-iap) -- comparison analysis
