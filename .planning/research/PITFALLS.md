# Domain Pitfalls

**Domain:** iOS keyboard app premium tier -- StoreKit 2 subscriptions, on-device LLM, transcription history, custom vocabulary (Open Core model)
**Researched:** 2026-04-08
**Confidence:** HIGH (StoreKit 2, SwiftData, App Store Review), MEDIUM (Apple Foundation Models -- iOS 26 not yet GA, extension support unconfirmed), MEDIUM (WhisperKit initialPrompt -- 224-token limit documented but workarounds untested in Dictus context)

**Context:** Dictus v1.5 adds a premium tier to an existing MIT-licensed iOS keyboard app. All Pro features run 100% on-device. The keyboard extension has a ~50MB RAM limit and runs in a separate process. Data sharing is via App Group (`group.solutions.pivi.dictus`). The app is currently in public TestFlight beta, and the beta period grants all Pro features for free.

---

## Critical Pitfalls

Mistakes that cause App Store rejection, data loss, rewrites, or fundamental architecture failures.

### Pitfall 1: Attempting StoreKit Purchase Inside Keyboard Extension Crashes or Silently Fails

**What goes wrong:**
StoreKit 2's `Product.purchase()` requires a valid window scene context to present the Apple payment sheet. Keyboard extensions run as a separate process with no `UIApplication.shared` and no `UIWindowScene`. Calling `purchase()` from the keyboard extension either throws an error (no scene available), silently fails, or crashes. Developers who prototype in the Simulator may not see this because the Simulator sometimes has a looser sandbox.

Even the iOS 18.2+ workaround `confirmIn(viewController:)` is designed for share extensions with `UIHostingController`, not keyboard extensions which have a fundamentally different view hierarchy (`UIInputViewController`).

**Why it happens:**
The natural impulse is to show a paywall when the user taps a Pro feature in the keyboard. But keyboard extensions are the most restricted extension type in iOS -- no access to `UIApplication`, no scene, limited API surface.

**How to avoid:**
1. **Never call StoreKit purchase APIs from the keyboard extension.** All purchases happen in the main DictusApp only
2. **Keyboard detects "not subscribed" and shows a teaser/CTA** that opens DictusApp via URL scheme (`dictus://upgrade`), where the actual paywall lives
3. **Subscription status is read-only in the keyboard extension.** Use `Transaction.currentEntitlements` or a cached boolean in App Group `UserDefaults` to check entitlement. StoreKit 2's `Transaction.currentEntitlements` should work in extensions (read-only, no purchase flow), but verify on device
4. **Test the full flow on a physical device** with StoreKit Configuration disabled (real sandbox) -- Simulator + StoreKit Config files bypass many extension restrictions

**Warning signs:**
`Product.purchase()` call anywhere in the DictusKeyboard target. Import of `StoreKit` in keyboard extension files beyond `Transaction` for entitlement checking. Payment sheet never appears during keyboard testing.

**Phase to address:**
SubscriptionManager infrastructure phase. Decide the architecture (main app only for purchase, extension for read-only check) before writing any StoreKit code.

---

### Pitfall 2: Apple Foundation Models Unavailable in Keyboard Extension or Under 50MB Memory Limit

**What goes wrong:**
Apple Foundation Models (AFM) uses a 3B-parameter on-device model with 4-bit quantization. Even quantized, inference requires significant memory -- Apple's Unified Memory Architecture helps, but the model is loaded into the shared memory pool. In a keyboard extension with a ~50MB budget, loading the AFM may push memory past the limit and cause iOS to kill the extension silently.

Additionally, AFM availability in app extensions is **unconfirmed** as of April 2026. The framework requires iOS 26+, Apple Intelligence enabled, and iPhone 15 Pro+ (A17 Pro or later). Apple's documentation does not explicitly state whether `FoundationModels` framework works in keyboard extensions. The MessageFilter extension community has been requesting AFM support, suggesting it may not be universally available in all extension types.

Even if AFM works in extensions, the 4096-token context window is small. A reformulation task ("rewrite this dictation as a professional email") needs: system prompt + user instruction + transcribed text + output -- easily exceeding 4096 tokens for longer dictations.

**Why it happens:**
AFM is designed for app-level intelligence features (Writing Tools, Siri). Keyboard extensions are the most memory-constrained environment in iOS. Apple may not have optimized or even tested AFM in this context.

**How to avoid:**
1. **Run ALL LLM inference in the main DictusApp, never in the keyboard extension.** The keyboard sends text to DictusApp via App Group or URL scheme, DictusApp runs AFM inference, writes result back to App Group, keyboard reads result
2. **Architecture: keyboard is a thin client for Smart Mode.** Keyboard shows "Processing..." state, DictusApp does the heavy lifting in background
3. **Test AFM in keyboard extension early** -- if it works, great (simplifies architecture). If it crashes or is unavailable, the two-process architecture handles it. This must be validated in the first phase, not discovered mid-implementation
4. **For the open-source fallback models (Gemma 3 1B, Phi-4 Mini):** these are 1-3GB on disk and need 1-4GB RAM at inference. They absolutely cannot run in the keyboard extension. Main app only
5. **Handle the 4096-token context window:** truncate input text to ~2000 tokens, leaving room for system prompt and output. Show a warning for very long dictations

**Warning signs:**
`import FoundationModels` in any DictusKeyboard file. LLM model loading code in the keyboard extension target. Memory spikes >30MB during Smart Mode in keyboard process.

**Phase to address:**
Smart Mode LLM phase. Must validate AFM extension availability as the very first task. Architecture decision (main app inference vs. extension inference) blocks all other Smart Mode work.

---

### Pitfall 3: SwiftData Database Corruption from Simultaneous Access by App and Extension

**What goes wrong:**
SwiftData (backed by Core Data/SQLite) stores the transcription history database in the App Group container, shared between DictusApp and DictusKeyboard. SQLite supports concurrent readers but only one writer at a time. If both the app and keyboard extension write simultaneously (e.g., keyboard saves a new transcription while user deletes one in the app), SQLite returns `SQLITE_BUSY` or `SQLITE_LOCKED`. SwiftData may throw, silently drop the write, or corrupt the WAL (Write-Ahead Log).

Worse: the `0xdead10cc` crash. If the keyboard extension holds a SQLite lock when iOS suspends it (user switches apps), iOS terminates the extension with termination code `0xdead10cc` ("dead lock"). This is a common crash in extensions using Core Data/SwiftData that developers discover only after App Store release from crash reports.

**Why it happens:**
SwiftData's high-level API abstracts away SQLite's locking behavior. The `.modelContainer` modifier and `ModelContext` make it feel like a simple object graph. Developers don't realize two separate processes (app + extension) hitting the same SQLite file need coordination that SwiftData does not provide automatically.

**How to avoid:**
1. **Make the keyboard extension write-only for new transcriptions, and DictusApp read/write for everything else.** Minimize concurrent write paths
2. **Use `NSFileCoordination` for all database writes from the extension.** This is already used in Dictus for log file coordination -- apply the same pattern to SwiftData writes
3. **Configure SwiftData with WAL mode explicitly** (this is the default, but verify): `ModelConfiguration(groupContainer: .identifier("group.solutions.pivi.dictus"))`. WAL mode allows concurrent reads with a single writer
4. **Handle `0xdead10cc`:** Release the `ModelContext` and close the database connection in `viewWillDisappear` of the keyboard extension, before iOS suspends it. Alternatively, use a lightweight write mechanism (append to a JSON file in App Group) instead of direct SwiftData access from the extension, and have DictusApp import pending entries on launch
5. **Test the concurrent scenario:** Open DictusApp to history view, switch to Messages, dictate (keyboard writes transcription), switch back to DictusApp. Repeat 20 times. Check for crashes in Console.app with `0xdead10cc`

**Warning signs:**
Transcriptions disappear after being saved. App crashes on launch after keyboard was used. Console shows `0xdead10cc` termination. `SQLITE_BUSY` errors in logs.

**Phase to address:**
Transcription history phase. Database architecture (who writes, who reads, how to coordinate) must be decided before any SwiftData code is written. Consider the "extension writes JSON, app imports to SwiftData" pattern as the safest approach.

---

### Pitfall 4: Open Core Feature Gating Bypassed by Anyone Reading the MIT Source Code

**What goes wrong:**
Dictus is MIT-licensed with all code (including Pro features) in the public repository. Feature gating is a boolean check: `if SubscriptionManager.shared.isProUser { showSmartMode() }`. Anyone can:
1. Fork the repo, change `isProUser` to always return `true`, build and sideload via Xcode
2. On a jailbroken device, modify the App Group `UserDefaults` to set the cached entitlement flag to `true`
3. Use a tool like FLEX or iGameGuardian to flip the boolean at runtime

This is **expected and acceptable** for an Open Core model -- the code is intentionally public. But the pitfall is spending engineering time trying to prevent bypass (DRM, obfuscation, server verification) when the MIT license philosophically accepts it.

**Why it happens:**
Developer instinct is to "protect" paid features. But in an Open Core model with no server, any client-side protection is trivially bypassable. The real protection is the App Store distribution (most users install from the App Store, not sideloading) and the inconvenience of building from source.

**How to avoid:**
1. **Accept bypass as a feature, not a bug.** The MIT license guarantees this right. Users who build from source are developers, not your target market
2. **Use StoreKit 2's JWS-signed transactions as the source of truth, not UserDefaults.** `Transaction.currentEntitlements` returns cryptographically signed receipts that cannot be forged without Apple's private key. Check this on app launch and cache the result
3. **Cache entitlement in App Group `UserDefaults` for the keyboard extension** (which may not have reliable network/StoreKit access), but re-verify from `Transaction.currentEntitlements` every time DictusApp opens
4. **Do NOT add server-side receipt validation.** This contradicts the "100% offline, no server" identity. The App Store handles fraud prevention for you
5. **Do NOT obfuscate the feature gate code.** It's MIT-licensed and public. Obfuscation adds complexity, breaks debugging, and provides zero real security against a determined bypass
6. **Document the Open Core model clearly** in the repo README: "Pro features are gated by StoreKit subscription. If you build from source, you can unlock them -- that's by design"

**Warning signs:**
Time spent on "anti-piracy" measures. Server-side validation code being written. Obfuscation tools being considered. Feature gate checks scattered across 20+ files instead of centralized.

**Phase to address:**
SubscriptionManager phase. Establish the philosophy (accept bypass) and the architecture (StoreKit JWS as truth, UserDefaults as cache) in the first PR. Do not revisit.

---

### Pitfall 5: App Store Rejection for Subscription That Doesn't Provide "Ongoing Value"

**What goes wrong:**
App Store Review Guideline 3.1.2 requires auto-renewable subscriptions to provide "dynamic, ongoing value" over time. Dictus Pro's features (Smart Mode LLM, history search, custom vocabulary) are all local processing features that don't inherently improve over time -- they work the same on day 1 as day 365. Apple may reject the subscription arguing these should be a one-time purchase, not a subscription.

Additionally, common paywall rejection reasons:
- Price and subscription duration not prominently displayed
- Missing "Restore Purchases" button
- Missing links to Terms of Service and Privacy Policy
- Free trial terms not clearly stated
- Beta labeling ("beta" in app name or description)

**Why it happens:**
Apple's reviewers apply Guideline 3.1.2 inconsistently, but keyboard apps with subscriptions are scrutinized because the "ongoing value" argument is harder to make for offline tools. Apps that successfully use subscriptions (Grammarly, SwiftKey) either have cloud services or clearly communicate ongoing improvements.

**How to avoid:**
1. **Frame the subscription as "Dictus Pro with ongoing model updates":** The value proposition includes future LLM model improvements, new reformulation templates, expanded vocabulary packs, and new language support. This is genuine ongoing value you plan to deliver
2. **Include a "What's New in Pro" section** in the app that highlights recent additions -- even during beta, list planned features with dates
3. **Paywall compliance checklist** (Apple will reject if any are missing):
   - [ ] `product.displayPrice` used (never hardcode prices)
   - [ ] Subscription duration clearly shown ("4.99 EUR/month")
   - [ ] Auto-renewal terms displayed
   - [ ] "Restore Purchases" button visible and functional
   - [ ] Link to Privacy Policy (URL, not just text)
   - [ ] Link to Terms of Service (URL, not just text)
   - [ ] Free trial terms if applicable ("7-day free trial, then 4.99 EUR/month")
   - [ ] Cancel instructions or link to Apple subscription management
4. **Do NOT use the word "beta" in the app name or primary description** during App Store review -- it triggers rejection. "Early access" is acceptable, or simply don't mention it
5. **Consider offering a one-time purchase alternative** alongside the subscription if Apple pushes back. Some developers report success with a "lifetime" option at 10x monthly price

**Warning signs:**
Rejection with Guideline 3.1.2 citation. Paywall missing any of the checklist items. Hardcoded prices in UI. No Restore Purchases flow.

**Phase to address:**
Paywall UI phase. The paywall must be compliance-complete before the first TestFlight build that includes subscription products.

---

### Pitfall 6: Beta Period "All Features Free" Creates Entitlement State Chaos at Launch

**What goes wrong:**
During TestFlight beta, all Pro features are free (no subscription required). At launch, you flip the switch and features become gated. The pitfall is in the transition:
1. **Users who used Pro features during beta lose access** with no warning, causing 1-star reviews and support requests
2. **Beta testers' local data (transcription history, custom vocabulary) was created with Pro features.** If you gate history search behind Pro after launch, their existing searches/exports stop working
3. **The `isProUser` logic during beta is a hardcoded override** (`isBeta ? true : isSubscribed`). If this override leaks into production (forgot to flip the flag, wrong build configuration), all users get Pro for free permanently
4. **StoreKit sandbox testing during beta is unreliable.** TestFlight uses the sandbox environment, but sandbox subscriptions auto-renew at accelerated rates (monthly = 5 minutes) and expire. Beta testers who also test purchasing will have confusing subscription states

**Why it happens:**
The beta override is a temporary hack that touches the same code path as the real entitlement check. Without clean separation, the beta behavior bleeds into production.

**How to avoid:**
1. **Use a compile-time flag, not a runtime flag, for beta override:** `#if BETA_OVERRIDE` in the SubscriptionManager. The App Store build configuration strips this flag automatically. No risk of it leaking
2. **Alternatively, use StoreKit Configuration file for TestFlight:** Grant a free subscription via StoreKit sandbox configuration rather than bypassing the entitlement check. This tests the real code path
3. **Grandfather beta testers:** Give all users who installed before the launch date a 30-day free Pro trial via a promotional offer. This prevents the "features disappeared" shock
4. **Separate "feature available" from "feature gated":** History base features (view recent transcriptions) are always free. Only Pro features (search, export, unlimited history) are gated. Users never lose functionality they had
5. **Test the transition explicitly:** Build a release config locally, verify Pro features are locked, verify the upgrade flow works, verify beta data is still accessible in free tier

**Warning signs:**
`isProUser` returning `true` in a release build without a subscription. Beta testers reporting features disappeared. Runtime boolean for beta override instead of compile-time.

**Phase to address:**
SubscriptionManager phase. The beta override mechanism must be designed alongside the entitlement system, not bolted on afterward.

---

## Moderate Pitfalls

Issues that cause days of debugging, subtle UX problems, or performance regressions.

### Pitfall 7: WhisperKit initialPrompt 224-Token Limit Makes Custom Vocabulary Useless for Large Dictionaries

**What goes wrong:**
Whisper's `initialPrompt` (which WhisperKit exposes) is limited to 224 tokens. Each word is roughly 1-3 tokens. A user's custom vocabulary of 50+ terms (proper nouns, technical jargon, brand names) easily exceeds 224 tokens. When the prompt exceeds the limit, only the **last** 224 tokens are kept -- all earlier words are silently discarded. The user adds words thinking they'll be recognized, but they aren't.

Worse, the attention mechanism assigns higher weight to tokens at the end of the prompt. Words at the beginning of a long prompt get less "attention" even if within the 224-token window. This creates inconsistent recognition -- some custom words work, others don't, seemingly at random.

**Why it happens:**
Whisper's prompt mechanism was designed for short contextual hints ("The following is a meeting about quantum physics"), not as a vocabulary injection system. Using it as a custom dictionary is a hack, not a supported feature.

**How to avoid:**
1. **Limit custom vocabulary to 30-40 terms maximum** and communicate this limit clearly in the UI. "Add your most important words" not "Add your entire dictionary"
2. **Format as contextual sentences, not word lists:** Instead of "Jean-Pierre, Sorbonne, CNRS, hematologie", write: "Jean-Pierre travaille a la Sorbonne et au CNRS en hematologie." Contextual sentences give Whisper better signal with fewer tokens
3. **Prioritize and rotate vocabulary based on context:** If the user has 100 terms, select the 30 most relevant based on recent usage or category. Implement a "vocabulary profile" system (work, medical, personal) that loads different prompt sets
4. **Place highest-priority terms at the END of the prompt** (where attention is strongest)
5. **Set expectations in the UI:** "Custom vocabulary improves recognition of unusual names and terms. It works best with 10-30 specific words." Do not promise perfect recognition
6. **Test with real French proper nouns:** Names like "Thierry", "Guillaume", "Montpellier" that Whisper's base model may already know. Only add words Whisper genuinely struggles with

**Warning signs:**
Users report custom vocabulary "doesn't work." Token count exceeds 224 silently. Vocabulary list shows 100+ entries. UI promises "perfect recognition of all your words."

**Phase to address:**
Custom vocabulary phase. Token budget management and contextual formatting are core design decisions, not implementation details.

---

### Pitfall 8: LLM Reformulation Quality is Terrible for French Without Careful Prompting

**What goes wrong:**
Apple Foundation Models (3B parameters) and small open-source models (Gemma 3 1B, Phi-4 Mini 3.8B) produce mediocre French text. Common failures:
- **Gender/agreement errors:** "Le lettre est envoye" instead of "La lettre est envoyee"
- **Awkward phrasing:** Literal English-pattern translations ("je suis excite de" instead of "j'ai hate de")
- **Hallucinated content:** Adding information not in the original dictation
- **Losing the user's voice:** Over-formalizing casual dictation or casualizing formal text
- **Truncated output:** 4096-token context window means long dictations produce incomplete reformulations

AFM's 3B model is optimized for English-first tasks. French is a secondary language that received less training attention. The small open-source models have even worse French quality.

**Why it happens:**
Small models struggle with low-resource language nuances. French grammar (gendered nouns, complex conjugation, subjunctive mood) requires more parameters than English to handle well. Developers test with simple English examples and assume French works equally well.

**How to avoid:**
1. **Test every reformulation template with 20+ real French dictation samples** before shipping. Include: formal letters, casual messages, medical notes, technical descriptions, slang-heavy SMS
2. **System prompts must be in French** for French reformulation. "Tu es un assistant qui reformule des textes dictes en francais" not "You are a reformulation assistant"
3. **Constrained output with Guided Generation:** Use AFM's `@Generable` macro to constrain output structure (e.g., force output to be a single paragraph, or an email with subject/body). This reduces hallucination
4. **Show the original alongside the reformulation** so users can compare and choose. Never auto-replace the original text
5. **Add a quality threshold:** If the model's output is shorter than 50% or longer than 200% of the input, flag it as potentially bad and show a warning
6. **Template-specific prompts:** "Rewrite as professional email" needs a different system prompt than "Summarize this." One generic prompt will produce bad results for all templates
7. **Measure latency on target devices:** A 3B model on iPhone 15 Pro may take 3-10 seconds for a paragraph. If >5 seconds, show a progress indicator with the option to cancel

**Warning signs:**
French output with English word order. Gender errors in first test. Reformulation adds content not in original. Users reporting "Smart Mode makes my text worse."

**Phase to address:**
Smart Mode LLM phase. French quality testing is a gating requirement before any reformulation template ships. Budget 2-3 days specifically for prompt engineering and quality evaluation.

---

### Pitfall 9: Transcription History Database Grows Unbounded and Kills Extension Memory

**What goes wrong:**
Every dictation saves a transcription to the SwiftData database in the App Group container. A regular user might dictate 10-50 times per day. After a month: 300-1500 entries. After a year: 3600-18000 entries. Each entry contains: text (variable, 50-5000 chars), timestamp, duration, model used, word count.

When the keyboard extension opens the database to save a new entry, SwiftData may load the model container metadata, which grows with the number of entries. On a database with 10000+ entries, the initial `ModelContainer` creation may allocate several MB just for the schema and index structures.

Free-tier users have limited history (e.g., last 10 entries). But if the database still contains all entries (just hidden in UI), the storage and memory impact is the same.

**Why it happens:**
Developers test with 10-50 entries. The database works perfectly. Six months later, users have thousands of entries and the extension starts crashing.

**How to avoid:**
1. **Implement a retention policy from day one:** Free tier keeps last 10 entries and auto-deletes older ones from the database (not just hides them). Pro tier keeps everything but with a configurable limit (default: 1 year)
2. **Keyboard extension writes to a lightweight staging area** (JSON file or single-row SQLite table in App Group), not the full history database. DictusApp imports staged entries on launch. This keeps the keyboard extension's database interaction minimal
3. **Lazy-load history in DictusApp:** Use SwiftData's `@Query` with a `fetchLimit` and pagination. Never load all entries into memory
4. **Add a "Storage used" indicator** in settings showing database size. Users with 500MB of transcription history need to know
5. **Test with a synthetic database of 10,000 entries** before shipping. Measure keyboard extension launch time and memory usage

**Warning signs:**
Keyboard extension launch slows over weeks of use. App Group container grows beyond 100MB. `ModelContainer` init takes >500ms.

**Phase to address:**
Transcription history phase. Retention policy and the staging pattern must be in the initial design, not added after users report problems.

---

### Pitfall 10: StoreKit Transaction Listener Not Started at App Launch Causes Missing Purchases

**What goes wrong:**
StoreKit 2 requires calling `Transaction.updates` at app launch to process pending transactions. If this listener isn't started immediately (e.g., it's started only when the paywall screen appears), several scenarios break:
- User purchases a subscription, kills the app before the transaction completes, relaunches -- purchase is lost
- User subscribes on another device (Family Sharing), opens Dictus -- subscription not recognized until they visit the paywall
- Apple processes a refund -- the app doesn't revoke Pro access because it never heard about the transaction update
- User's subscription auto-renews -- if the app wasn't listening, the renewal transaction is queued but not processed

**Why it happens:**
Developers focus on the purchase flow (user taps buy, payment sheet appears, handle result) and forget that StoreKit transactions can arrive at any time -- app launch, background refresh, after app update.

**How to avoid:**
1. **Start `Transaction.updates` listener in the App Delegate or SwiftUI `App.init`**, before any UI renders. Process every transaction immediately
2. **Also iterate `Transaction.currentEntitlements` at every app launch** to sync the entitlement state. This catches transactions that arrived while the app was killed
3. **Persist entitlement state to App Group `UserDefaults`** after every transaction update, so the keyboard extension has current status without needing to call StoreKit itself
4. **Handle `Transaction.updates` for revocations and expirations**, not just purchases. When a subscription expires, flip `isProUser` to `false` immediately and update the App Group cache
5. **Test with sandbox subscription lifecycle:** Purchase -> verify -> wait for expiration (5 min in sandbox) -> verify revocation -> re-purchase -> verify restoration

**Warning signs:**
Users report purchasing but features not unlocking. Pro features still work after subscription expires. `Transaction.updates` started anywhere other than app initialization.

**Phase to address:**
SubscriptionManager phase. Transaction listener must be the first piece of StoreKit code written.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode product IDs | Fast implementation | Breaks when adding tiers | Never -- use a ProductID enum from day 1 |
| UserDefaults as sole entitlement source | Works without StoreKit | Trivially bypassable, no renewal handling | Never -- always verify with `Transaction.currentEntitlements` |
| Skip SwiftData migration versioning | Faster initial development | Database crashes when schema changes in v1.6 | Never -- add `VersionedSchema` from day 1 |
| One generic LLM prompt for all templates | Ship faster | Poor quality across all reformulation types | MVP only -- replace with template-specific prompts within 2 weeks |
| Store entire transcription text in UserDefaults | No SwiftData needed | UserDefaults has ~1MB practical limit, corrupts at scale | Never -- use proper database or file storage |
| Run LLM inference synchronously on main thread | Simpler code | UI freezes for 3-10 seconds during reformulation | Never -- always async with cancellation support |

## Integration Gotchas

Common mistakes when connecting these features together.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| StoreKit 2 + Keyboard Extension | Calling `purchase()` from extension | Purchase in main app only, cache entitlement in App Group UserDefaults |
| SwiftData + App Group | Both app and extension write simultaneously | Extension writes to staging file, app imports to SwiftData |
| AFM + Keyboard Extension | Loading model in extension process | Run inference in main app, pass results via App Group |
| WhisperKit + Custom Vocabulary | Dumping all words into initialPrompt | Contextual sentences, 30-40 term limit, priority rotation |
| Beta Override + Production | Runtime boolean for beta check | Compile-time `#if BETA_OVERRIDE` stripped from release builds |
| StoreKit + App Group | Extension checks StoreKit directly | App writes entitlement to App Group, extension reads cached value |
| SwiftData + Schema Evolution | No versioning in initial schema | `VersionedSchema` with `SchemaMigrationPlan` from first model definition |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unbounded history database | Extension launch slows, crashes | Retention policy + fetch limits | >1000 entries (~1-3 months of regular use) |
| Loading all history for search | Memory spike, UI freeze | SwiftData `@Query` with `FetchDescriptor` predicate, not in-memory filter | >500 entries |
| LLM inference blocking main thread | UI frozen during Smart Mode | Async with `Task`, show progress, support cancellation | Always (3-10s inference time) |
| Large custom vocabulary in initialPrompt | Silent truncation, inconsistent recognition | 30-40 term limit, contextual sentence format | >50 terms (~150+ tokens) |
| Checking `Transaction.currentEntitlements` on every keystroke | Perceptible typing lag | Check on app launch, cache in memory, update on `Transaction.updates` | Always (StoreKit queries have latency) |

## Security Considerations

Domain-specific security issues for an Open Core offline app.

| Consideration | Risk | Approach |
|---------|------|------------|
| UserDefaults entitlement cache tampered | Jailbreak users get free Pro | Accept: MIT license, offline app, no server. StoreKit JWS is the real check in DictusApp |
| Transcription history contains sensitive data | Privacy breach if device compromised | Use SwiftData with file protection (NSFileProtectionComplete), no cloud sync, no export without user action |
| LLM output may contain hallucinated PII | User sends reformulated text with wrong names/numbers | Always show original alongside reformulation, never auto-send |
| Custom vocabulary stored in App Group | Other extensions in same group could read user's vocabulary | App Group is app-private (same team ID only), acceptable risk |
| Source code reveals Pro feature implementation | Competitors copy features | Accept: MIT license, features are the competitive moat, not the code |

## UX Pitfalls

Common user experience mistakes when adding premium features to a free app.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing paywall on first keyboard use | Users feel baited, uninstall | Let users discover Pro features naturally, show upgrade prompt only when they try a Pro feature |
| Locking previously free features behind Pro | Betrayal, 1-star reviews | Never. All v1.4 features remain free forever. Only new features are Pro |
| Smart Mode replaces original text silently | Users lose their dictation | Show original + reformulation side by side, user explicitly chooses |
| No way to dismiss paywall from keyboard | User trapped, force-quit needed | Always have a clear "Not now" / "X" dismiss, return to keyboard immediately |
| Pro badge everywhere in free tier | Feels like adware | Subtle Pro indicators only on Pro features, no persistent upgrade banners |
| Custom vocabulary has no feedback | User adds words, doesn't know if they work | Show a "test pronunciation" or highlight custom words in transcriptions |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **StoreKit Subscription:** Often missing `Transaction.updates` listener at app launch -- verify transactions process even when paywall is not visible
- [ ] **StoreKit Subscription:** Often missing restore purchases flow -- verify a user on a new device can restore without re-purchasing
- [ ] **Paywall UI:** Often missing Terms of Service and Privacy Policy links -- Apple rejects without them
- [ ] **Paywall UI:** Often missing subscription auto-renewal disclosure -- "Auto-renews at [price]/[period] until cancelled"
- [ ] **SwiftData History:** Often missing schema versioning -- verify `VersionedSchema` is set up before first release, because v1.6 schema changes will crash
- [ ] **SwiftData History:** Often missing `0xdead10cc` handling -- verify database connection is released when extension is suspended
- [ ] **LLM Smart Mode:** Often missing cancellation support -- verify user can abort a slow reformulation
- [ ] **LLM Smart Mode:** Often missing device capability check -- verify graceful fallback when device doesn't support AFM (pre-iPhone 15 Pro, Apple Intelligence disabled)
- [ ] **Custom Vocabulary:** Often missing token count validation -- verify the UI prevents adding more words than the 224-token budget allows
- [ ] **Beta Override:** Often missing production verification -- verify a release build without `BETA_OVERRIDE` actually gates Pro features

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| StoreKit purchase in extension crashes | LOW | Move purchase code to main app, add URL scheme handler. 1-2 day refactor |
| SwiftData corruption from concurrent access | HIGH | Export surviving data, redesign to staging pattern, re-import. 3-5 day recovery |
| AFM unavailable in keyboard extension | MEDIUM | Already have two-process architecture for dictation. Add Smart Mode to same flow. 2-3 days |
| App Store rejection for 3.1.2 | LOW | Update paywall copy, resubmit. Add "ongoing model updates" framing. 1-2 days |
| LLM quality too poor for French | HIGH | Extensive prompt engineering, possibly switch models, may need to delay Smart Mode launch. 1-2 weeks |
| Beta override leaks to production | MEDIUM | Emergency build with compile-time flag fixed, expedited review. 1-2 days |
| History database too large | MEDIUM | Add retention policy retroactively, write migration to prune old entries. 2-3 days |
| Custom vocabulary exceeds token limit | LOW | Add UI validation, truncate with warning. 1 day |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| #1 StoreKit in extension | SubscriptionManager | `purchase()` never called from DictusKeyboard target. Grep verification |
| #2 AFM in extension / memory | Smart Mode (first task) | Test `import FoundationModels` in keyboard extension on device. Pass/fail in first 2 hours |
| #3 SwiftData concurrent access | Transcription History (architecture) | Stress test: 20 rapid app/extension switches with writes on both sides |
| #4 Open Core bypass | SubscriptionManager (philosophy) | No obfuscation code, no server validation, documented in README |
| #5 App Store 3.1.2 rejection | Paywall UI | Paywall compliance checklist 100% before first submission |
| #6 Beta override chaos | SubscriptionManager | `#if BETA_OVERRIDE` in code, release build tested without flag |
| #7 initialPrompt token limit | Custom Vocabulary (design) | UI shows token count, prevents exceeding 200 tokens |
| #8 LLM French quality | Smart Mode (prompt engineering) | 20+ French samples tested per template, quality metrics defined |
| #9 Unbounded history | Transcription History (design) | Retention policy active, test with 10K synthetic entries |
| #10 Transaction listener missing | SubscriptionManager (first task) | `Transaction.updates` started in App.init, verified with sandbox lifecycle test |

## Sources

- [StoreKit 2 and app extensions -- sharing purchases with extensions](https://medium.com/@aisultanios/implement-inn-app-subscriptions-using-swift-and-storekit2-serverless-and-share-active-purchases-7d50f9ecdc09) (MEDIUM confidence)
- [App Store Review Guidelines -- Guideline 3.1.2 Subscriptions](https://developer.apple.com/app-store/review/guidelines/) (HIGH confidence)
- [Common iOS paywall rejections and fixes](https://revenueflo.com/blog/common-ios-paywall-rejections-and-the-fixes-that-work) (MEDIUM confidence)
- [Apple Foundation Models framework documentation](https://developer.apple.com/documentation/FoundationModels) (HIGH confidence, but extension support unconfirmed)
- [Apple Foundation Models 2025 updates -- 3B model, 4-bit quantization](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) (HIGH confidence)
- [Apple Foundation Models context window improvements (iOS 26.4)](https://www.infoq.com/news/2026/03/apple-foundation-models-context/) (MEDIUM confidence)
- [SwiftData concurrent programming pitfalls](https://fatbobman.com/en/posts/concurret-programming-in-swiftdata/) (HIGH confidence)
- [0xdead10cc crash from SwiftData in extensions](https://scottdriggers.com/blog/0xdead10cc-crash-caused-by-swiftdata-modelcontainer/) (HIGH confidence)
- [SwiftData App Group configuration](https://developer.apple.com/forums/thread/732986) (HIGH confidence)
- [Whisper initial_prompt 224-token limit](https://github.com/openai/whisper/discussions/1824) (HIGH confidence)
- [Whisper prompting guide -- OpenAI Cookbook](https://developers.openai.com/cookbook/examples/whisper_prompting_guide) (HIGH confidence)
- [Contextual biasing for Whisper custom vocabulary (academic paper)](https://arxiv.org/html/2410.18363v1) (HIGH confidence)
- [WhisperKit feature request for custom prompt](https://github.com/argmaxinc/WhisperKit/issues/53) (HIGH confidence)
- [RevenueCat -- ultimate guide to subscription testing on iOS](https://www.revenuecat.com/blog/engineering/the-ultimate-guide-to-subscription-testing-on-ios/) (HIGH confidence)
- [Wrong ways to persist in-app purchase status](https://medium.com/@Faisalbin/all-the-wrong-ways-to-persist-in-app-purchase-status-in-your-macos-app-ce6eb9bcb0c3) (MEDIUM confidence)
- [Key considerations before using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) (HIGH confidence)

---
*Pitfalls research for: Dictus Pro premium tier (StoreKit 2 + on-device LLM + transcription history + custom vocabulary)*
*Researched: 2026-04-08*
