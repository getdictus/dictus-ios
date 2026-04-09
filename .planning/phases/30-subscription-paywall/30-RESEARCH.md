# Phase 30: Subscription + Paywall - Research

**Researched:** 2026-04-09
**Domain:** StoreKit 2 subscriptions, feature gating, paywall UI, App Group sync
**Confidence:** HIGH

## Summary

StoreKit 2 is the correct and only choice for implementing subscriptions in a single-tier, iOS-only, 100% offline app. The API is mature (introduced WWDC 2021, refined through WWDC 2025), uses Swift concurrency natively, and handles transaction verification on-device -- no server needed. The core pattern is straightforward: a `SubscriptionManager` (ObservableObject) that fetches products, handles purchases, listens for transaction updates, and syncs Pro status to App Group UserDefaults for the keyboard extension.

Apple provides built-in `SubscriptionStoreView` (iOS 17+) for paywall rendering, but the user has locked a custom paywall design (full-screen page with feature cards, specific CTA, beta banner). The custom approach gives full control over the Liquid Glass styling, beta override logic, and the specific layout described in CONTEXT.md. StoreKit views remain useful as a reference but should NOT be used here.

**Primary recommendation:** Build a custom `SubscriptionManager` (ObservableObject) + `ProStatusManager` (App Group sync) + custom `PaywallView` (SwiftUI). Use the established `SharedKeys` + `@AppStorage` pattern for cross-process Pro status. Keep beta logic as a simple compile-time `isBeta` flag.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Full-screen dedicated page pushed via NavigationStack (not a modal sheet) for paywall
- Pro benefits displayed as feature cards with SF Symbol icons, title, and one-line description (3 cards: Smart Mode, History, Vocabulary)
- Price embedded directly in the CTA button: "Subscribe -- 4.99 EUR/month"
- "Cancel anytime" reassurance text below the button
- Restore purchases + Terms of Service + Privacy Policy links at the bottom
- Paywall accessible from two entry points: Settings "Dictus Pro" row AND compact Home screen banner
- Compact gradient card at bottom of HomeView for Pro banner (disappears after subscribing)
- During beta: subscribe button replaced by a prominent banner "All Pro features free during beta" -- no purchase flow at all
- Small "BETA" pill badge on the Dictus Pro row in Settings showing "BETA Active"
- Beta messaging only on paywall + Settings row (not scattered everywhere)
- Simple `isBeta` Bool flag in code -- flip to `false` and ship an update
- TestFlight builds always have `isBeta = true`; App Store builds have `isBeta = false`
- No server-side flag, no grace period
- Lock icon + colored "PRO" pill badge on locked features in Settings
- Dedicated "Pro Features" section in Settings (separate from Transcription and Keyboard sections)
- Free users see the exact same keyboard as today -- NO Pro-specific UI on the keyboard
- All feature gating happens in the app Settings, not in the keyboard extension
- Pro features (e.g., Smart Mode button) only appear on keyboard when Pro is active AND feature is enabled in Settings
- PAY-05 redefined: keyboard simply doesn't show Pro features to free users (no upgrade prompt)
- Pro status stored in App Group SharedKeys (same pattern as language, layout, haptics)
- New SharedKeys: `proActive` (Bool), plus per-feature toggles (e.g., `smartModeEnabled`)

### Claude's Discretion
- Exact Liquid Glass styling for paywall cards and banner
- SF Symbol choices for each Pro feature card
- StoreKit 2 product ID naming convention
- Transaction.updates listener architecture
- FeatureGate/ProFeature enum design
- Restore purchases flow details
- Error handling for failed purchases

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SUB-01 | User can subscribe to Dictus Pro via StoreKit 2 in-app purchase (single tier) | SubscriptionManager with Product.products() fetch + product.purchase() flow |
| SUB-02 | User's Pro status is cached in App Group and readable by keyboard extension | ProStatusManager writes to SharedKeys.proActive via App Group UserDefaults |
| SUB-03 | User can restore previous purchases from the paywall screen | AppStore.sync() call from paywall + Transaction.currentEntitlements refresh |
| SUB-04 | Pro status updates in real-time when subscription state changes | Transaction.updates async sequence listener started at app launch |
| SUB-05 | During beta period, all Pro features are unlocked for free with clear messaging | isBeta compile-time flag, beta banner on paywall, BETA pill in Settings |
| SUB-06 | FeatureGate system checks Pro status for any gated feature (ProFeature enum) | ProFeature enum + FeatureGate struct with static check method |
| PAY-01 | User sees a paywall screen when tapping a locked Pro feature or from Settings | Custom PaywallView pushed via NavigationStack |
| PAY-02 | Paywall displays Pro benefits, pricing, and subscribe button | Feature cards with SF Symbols, price in CTA button |
| PAY-03 | Paywall includes restore purchases functionality | "Restore purchases" link calling AppStore.sync() |
| PAY-04 | During beta, paywall shows "All Pro features free during beta" banner | Conditional view based on isBeta flag |
| PAY-05 | Keyboard extension hides Pro features for free users (redefined from CONTEXT.md) | Keyboard reads SharedKeys.proActive + per-feature toggles from App Group |
| PAY-06 | Paywall includes links to Terms of Service and Privacy Policy | Button links at bottom of PaywallView (Apple requirement) |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| StoreKit 2 | iOS 17+ (framework) | Subscriptions, purchases, transaction verification | Apple's native IAP framework, no third-party dependency needed for single-tier |
| SwiftUI | iOS 17+ (framework) | Paywall UI, Settings sections, feature cards | Already used throughout Dictus |
| App Group UserDefaults | iOS 17+ (framework) | Cross-process Pro status sync | Already established pattern in Dictus (SharedKeys + AppGroup) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| StoreKit Configuration File | Xcode 15+ | Local testing of subscriptions without sandbox | During development and testing |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom paywall | SubscriptionStoreView (Apple built-in) | Less design control, cannot implement beta banner or Liquid Glass cards |
| Custom SubscriptionManager | RevenueCat SDK | Overkill for single-tier iOS-only (1% rev share), adds dependency -- explicitly excluded in REQUIREMENTS.md |

**Installation:** No additional packages needed. StoreKit 2 is a system framework.

## Architecture Patterns

### Recommended Project Structure
```
DictusCore/Sources/DictusCore/
├── SharedKeys.swift              # ADD: proActive, smartModeEnabled keys
├── Subscription/
│   ├── ProFeature.swift          # ProFeature enum + FeatureGate
│   └── ProStatusManager.swift    # App Group Pro status read/write

DictusApp/
├── Subscription/
│   ├── SubscriptionManager.swift # StoreKit 2 product fetch, purchase, listener
│   └── StoreKitConfig.storekit   # Local testing configuration
├── Views/
│   ├── PaywallView.swift         # Full-screen paywall with feature cards
│   ├── ProBannerView.swift       # Compact gradient banner for HomeView
│   └── SettingsView.swift        # MODIFY: add Pro section + Dictus Pro row
│   └── HomeView.swift            # MODIFY: add ProBannerView at bottom
```

### Pattern 1: SubscriptionManager (ObservableObject)
**What:** Central class managing all StoreKit 2 interactions
**When to use:** App launch (listener), paywall (purchase/restore), settings (status display)
**Example:**
```swift
// Source: Apple StoreKit 2 documentation + verified patterns
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    
    private let productIDs = ["solutions.pivi.dictus.pro.monthly"]
    private var transactionListener: Task<Void, Never>?
    private let proStatus: ProStatusManager
    
    init(proStatus: ProStatusManager) {
        self.proStatus = proStatus
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            // Handle error
        }
    }
    
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateProStatus()
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .pending
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error)
        }
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateProStatus()
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await self?.updateProStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    private func updateProStatus() async {
        var isActive = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? result.payloadValue,
               transaction.revocationDate == nil {
                isActive = true
            }
        }
        proStatus.setProActive(isActive)
    }
}

enum PurchaseState {
    case idle, purchasing, pending, success, failed(Error)
}
```

### Pattern 2: ProStatusManager (App Group sync)
**What:** Lightweight class that reads/writes Pro status to App Group UserDefaults
**When to use:** Both DictusApp and DictusKeyboard (lives in DictusCore)
**Example:**
```swift
// Lives in DictusCore (shared framework)
public final class ProStatusManager: ObservableObject {
    @Published public private(set) var isProActive: Bool
    
    public init() {
        // During beta, always return true
        if ProConfig.isBeta {
            self.isProActive = true
            return
        }
        self.isProActive = AppGroup.defaults.bool(forKey: SharedKeys.proActive)
    }
    
    /// Called by SubscriptionManager after transaction updates (DictusApp only)
    public func setProActive(_ active: Bool) {
        AppGroup.defaults.set(active, forKey: SharedKeys.proActive)
        isProActive = active || ProConfig.isBeta
    }
    
    /// Lightweight read for keyboard extension (no StoreKit needed)
    public static var isProActiveStatic: Bool {
        ProConfig.isBeta || AppGroup.defaults.bool(forKey: SharedKeys.proActive)
    }
}
```

### Pattern 3: FeatureGate / ProFeature enum
**What:** Centralized feature gating with enum of Pro features
**When to use:** Anywhere a feature needs Pro check (Settings toggles, keyboard feature visibility)
**Example:**
```swift
// Lives in DictusCore
public enum ProFeature: String, CaseIterable {
    case smartMode
    case history
    case vocabulary
    
    public var displayName: String {
        switch self {
        case .smartMode: return "Smart Mode"
        case .history: return "History"
        case .vocabulary: return "Vocabulary"
        }
    }
    
    public var icon: String {
        switch self {
        case .smartMode: return "sparkles"
        case .history: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .vocabulary: return "character.book.closed"
        }
    }
    
    public var settingsKey: String {
        switch self {
        case .smartMode: return SharedKeys.smartModeEnabled
        case .history: return SharedKeys.historyEnabled
        case .vocabulary: return SharedKeys.vocabularyEnabled
        }
    }
}

public struct FeatureGate {
    /// Check if a Pro feature is available (Pro active + feature individually enabled)
    public static func isAvailable(_ feature: ProFeature) -> Bool {
        guard ProStatusManager.isProActiveStatic else { return false }
        return AppGroup.defaults.bool(forKey: feature.settingsKey)
    }
    
    /// Check if Pro is active (for UI gating without per-feature check)
    public static var isProActive: Bool {
        ProStatusManager.isProActiveStatic
    }
}
```

### Pattern 4: Beta Configuration
**What:** Compile-time flag for beta vs production behavior
**When to use:** Paywall view, Pro status checks, Settings badge
**Example:**
```swift
// Lives in DictusCore
public enum ProConfig {
    /// When true, all Pro features are free. Flip to false for App Store release.
    /// TestFlight builds override this to true via compiler flag.
    #if TESTFLIGHT
    public static let isBeta = true
    #else
    public static let isBeta = true  // Change to false for App Store release
    #endif
}
```

### Anti-Patterns to Avoid
- **Checking StoreKit in keyboard extension:** The keyboard extension has ~50MB memory limit and cannot make StoreKit calls. Always read Pro status from App Group UserDefaults only.
- **Using SubscriptionStoreView for custom paywall:** The user wants feature cards with Liquid Glass styling and a beta banner. SubscriptionStoreView does not support this level of customization.
- **Storing transaction data in App Group:** Only store the boolean `proActive` flag. Transaction details stay in StoreKit's own secure storage.
- **Calling AppStore.sync() on every app launch:** This triggers a sign-in prompt. Only call it from an explicit "Restore Purchases" user action.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Transaction verification | Custom JWS parsing | StoreKit 2 automatic verification (.payloadValue) | Apple handles cryptographic verification on-device |
| Receipt validation | Server-side receipt checking | Transaction.currentEntitlements | 100% offline architecture, StoreKit 2 validates locally |
| Subscription state tracking | Manual expiry date tracking | Transaction.updates async sequence | StoreKit 2 handles renewals, cancellations, refunds automatically |
| Restore purchases | Custom transaction scanning | AppStore.sync() | Apple's recommended approach, re-downloads missing transactions |
| Product metadata | Hardcoded pricing strings | Product.displayPrice | Handles localization, currency formatting automatically |

**Key insight:** StoreKit 2 eliminates most subscription complexity. The on-device verification means no server, no receipt parsing, no webhook handling. For a single-tier subscription, the entire StoreKit layer is ~100 lines of code.

## Common Pitfalls

### Pitfall 1: Transaction.updates Not Started Early Enough
**What goes wrong:** User purchases on another device or subscription renews while app is in background. App never processes the transaction.
**Why it happens:** Transaction.updates listener not started at app init, or task gets cancelled.
**How to avoid:** Start the listener in `SubscriptionManager.init()` and store the Task reference. Start it in `@main App.init()` before any view renders.
**Warning signs:** Pro status out of sync after app restart.

### Pitfall 2: Calling AppStore.sync() on Launch
**What goes wrong:** iOS shows a StoreKit sign-in prompt every time the app opens.
**Why it happens:** AppStore.sync() contacts Apple's servers and may require authentication.
**How to avoid:** Only call AppStore.sync() from an explicit "Restore Purchases" button tap. Use Transaction.currentEntitlements for passive status checks.
**Warning signs:** Users complain about unexpected sign-in prompts.

### Pitfall 3: Not Finishing Transactions
**What goes wrong:** StoreKit keeps re-delivering the same transaction, or purchase appears stuck.
**Why it happens:** `transaction.finish()` not called after processing.
**How to avoid:** Always call `await transaction.finish()` after updating Pro status, both in purchase flow AND in Transaction.updates listener.
**Warning signs:** Duplicate transactions, "pending" state that never resolves.

### Pitfall 4: Keyboard Extension Stale Pro Status
**What goes wrong:** User subscribes but keyboard still shows free-tier features until app restart.
**Why it happens:** Keyboard extension caches UserDefaults at launch and doesn't re-read mid-session.
**How to avoid:** Keyboard reads Pro status from App Group at `viewDidLoad` / `viewWillAppear`. Since keyboard extensions are frequently recreated by iOS, this is usually sufficient. For immediate sync, consider Darwin notification from app to keyboard.
**Warning signs:** User subscribes, switches to keyboard, features still locked.

### Pitfall 5: TestFlight Beta Detection Complexity
**What goes wrong:** Trying to detect TestFlight at runtime with `appStoreReceiptURL` path checking is fragile and changes between iOS versions.
**Why it happens:** No official Apple API to detect TestFlight vs App Store.
**How to avoid:** User decided on a simple `isBeta` Bool flag in code. Use `#if TESTFLIGHT` compiler flag set in the Xcode build configuration (Active Compilation Conditions). TestFlight scheme adds `TESTFLIGHT` flag, App Store scheme does not.
**Warning signs:** Beta detection fails on some iOS versions.

### Pitfall 6: Displaying Hardcoded Prices
**What goes wrong:** Price shown in UI doesn't match App Store Connect price, or shows wrong currency.
**Why it happens:** Hardcoding "4.99 EUR" instead of using StoreKit's localized price.
**How to avoid:** Use `product.displayPrice` for the CTA button text. The user wants "Subscribe -- 4.99 EUR/month" format, but the price part should come from `product.displayPrice` to handle localization.
**Warning signs:** Wrong price for non-EUR users, App Store review rejection.

## Code Examples

### PaywallView Structure
```swift
// Source: CONTEXT.md decisions + StoreKit 2 patterns
struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var proStatus: ProStatusManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Feature cards (Smart Mode, History, Vocabulary)
                featureCardsSection
                
                if ProConfig.isBeta {
                    // Beta banner replaces purchase flow
                    betaBanner
                } else {
                    // Subscribe CTA with price
                    subscribeCTA
                    
                    // "Cancel anytime" text
                    Text("Cancel anytime")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
                
                // Bottom links
                bottomLinks
            }
            .padding()
        }
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Dictus Pro")
    }
    
    private var subscribeCTA: some View {
        Button {
            Task {
                if let product = subscriptionManager.products.first {
                    await subscriptionManager.purchase(product)
                }
            }
        } label: {
            Text("Subscribe — \(subscriptionManager.products.first?.displayPrice ?? "4,99 €")/month")
                .font(.dictusSubheading)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.dictusAccent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(GlassPressStyle())
    }
    
    private var bottomLinks: some View {
        VStack(spacing: 12) {
            Button("Restore purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(.dictusCaption)
            
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://dictus.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://dictus.app/privacy")!)
            }
            .font(.dictusCaption)
            .foregroundColor(.secondary)
        }
    }
}
```

### StoreKit Configuration File Setup
```
// DictusApp/Subscription/StoreKitConfig.storekit
// Create via: File > New > File > StoreKit Configuration File
// Configure:
//   - Type: Auto-Renewable Subscription
//   - Group: Dictus Pro
//   - Product ID: solutions.pivi.dictus.pro.monthly
//   - Reference Name: Dictus Pro Monthly
//   - Price: 4.99 EUR
//   - Duration: 1 month
// Then: Edit Scheme > Run > Options > StoreKit Configuration > Select this file
```

### SharedKeys Additions
```swift
// Add to SharedKeys.swift
// MARK: - Pro / Subscription
public static let proActive = "dictus.proActive"
public static let smartModeEnabled = "dictus.smartModeEnabled"
public static let historyEnabled = "dictus.historyEnabled"
public static let vocabularyEnabled = "dictus.vocabularyEnabled"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| StoreKit 1 (SKPaymentQueue, delegates) | StoreKit 2 (async/await, Product, Transaction) | WWDC 2021 | Much simpler API, on-device verification |
| Server-side receipt validation | On-device Transaction verification | WWDC 2021 | No server needed for offline apps |
| RevenueCat/third-party SDKs | Native StoreKit 2 | 2023+ for simple tiers | No dependency, no revenue share |
| Manual paywall UI | SubscriptionStoreView (Apple built-in) | WWDC 2023 (iOS 17) | Quick setup but limited customization |
| Receipt URL path for TestFlight detection | Compiler flags (#if TESTFLIGHT) | Best practice 2024+ | Reliable, no runtime fragility |

**Deprecated/outdated:**
- StoreKit 1 (`SKPaymentQueue`, `SKProduct`): Still works but StoreKit 2 is recommended for all new projects
- `appStoreReceiptURL` path checking for TestFlight: Fragile across iOS versions, use compiler flags instead
- Transaction.listener: Renamed to Transaction.updates in later StoreKit 2 updates

## Open Questions

1. **Terms of Service / Privacy Policy URLs**
   - What we know: Apple requires these links on any paywall (PAY-06)
   - What's unclear: Whether dictus.app domain is set up with /terms and /privacy pages
   - Recommendation: Use placeholder URLs during development, finalize before App Store submission. Can use GitHub-hosted pages if no website exists yet.

2. **Product ID in App Store Connect**
   - What we know: Product ID must match between StoreKit Configuration and App Store Connect
   - What's unclear: Whether App Store Connect product is already created
   - Recommendation: Use `solutions.pivi.dictus.pro.monthly` as the product ID. Create in App Store Connect before TestFlight testing of real purchases.

3. **Immediate Pro Unlock After Purchase**
   - What we know: StoreKit 2 purchase returns synchronously after user confirms
   - What's unclear: Exact UI transition from paywall to unlocked state
   - Recommendation: After successful purchase, dismiss paywall and update ProStatusManager. @Published property triggers UI refresh automatically.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) + StoreKit Testing |
| Config file | DictusApp/Subscription/StoreKitConfig.storekit (Wave 0) |
| Quick run command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing DictusTests/SubscriptionTests` |
| Full suite command | `xcodebuild test -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUB-01 | StoreKit 2 purchase completes | unit (StoreKit Testing) | StoreKit Config + manual Simulator test | Wave 0 |
| SUB-02 | Pro status written to App Group | unit | Read SharedKeys.proActive after mock purchase | Wave 0 |
| SUB-03 | Restore purchases works | unit (StoreKit Testing) | AppStore.sync() + verify entitlements | Wave 0 |
| SUB-04 | Transaction.updates fires on changes | unit (StoreKit Testing) | Simulate renewal in StoreKit Config | Wave 0 |
| SUB-05 | Beta mode unlocks all features | unit | Assert ProStatusManager.isProActive when isBeta=true | Wave 0 |
| SUB-06 | FeatureGate checks Pro status | unit | FeatureGate.isAvailable(.smartMode) with mock status | Wave 0 |
| PAY-01 | Paywall screen shows on tap | manual | Navigate to paywall from Settings and Home | N/A |
| PAY-02 | Paywall displays benefits + pricing | manual | Visual inspection of paywall UI | N/A |
| PAY-03 | Restore purchases on paywall | manual | Tap restore, verify Pro unlocks | N/A |
| PAY-04 | Beta banner shows during beta | manual | Build with isBeta=true, inspect paywall | N/A |
| PAY-05 | Keyboard hides Pro features when free | manual | Disable Pro, check keyboard has no Pro UI | N/A |
| PAY-06 | ToS + Privacy links present | manual | Verify links on paywall | N/A |

### Sampling Rate
- **Per task commit:** Build + run on Simulator to verify no compile errors
- **Per wave merge:** Manual walkthrough of paywall flow + StoreKit Testing purchase
- **Phase gate:** Full purchase flow tested in Simulator with StoreKit Configuration

### Wave 0 Gaps
- [ ] `DictusApp/Subscription/StoreKitConfig.storekit` -- StoreKit Configuration file for local testing
- [ ] SharedKeys additions (`proActive`, `smartModeEnabled`, `historyEnabled`, `vocabularyEnabled`)
- [ ] ProConfig.isBeta flag setup

## Sources

### Primary (HIGH confidence)
- [Apple StoreKit 2 Developer Documentation](https://developer.apple.com/storekit/) -- framework overview, API reference
- [Apple: Setting up StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) -- testing configuration
- [Apple: Testing at all stages of development](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox) -- sandbox vs Xcode testing

### Secondary (MEDIUM confidence)
- [StoreKit 2 subscription tutorial with extension sharing (Aisultan Askarov)](https://medium.com/@aisultanios/implement-inn-app-subscriptions-using-swift-and-storekit2-serverless-and-share-active-purchases-7d50f9ecdc09) -- verified App Group sharing pattern, code examples cross-checked
- [StoreKit paywall views fieldguide (Superwall)](https://superwall.com/blog/storekit-paywall-views-in-swiftui-the-complete-fieldguide) -- SubscriptionStoreView capabilities and limitations
- [WWDC 2025 StoreKit updates (DEV Community)](https://dev.to/arshtechpro/wwdc-2025-whats-new-in-storekit-and-in-app-purchase-31if) -- Transaction.currentEntitlements(for:) update, SubscriptionOfferView

### Tertiary (LOW confidence)
- SF Symbol names for feature cards -- chosen by convention, verify in SF Symbols app

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- StoreKit 2 is Apple's official framework, no alternatives needed
- Architecture: HIGH -- patterns verified across multiple sources, consistent with existing Dictus codebase patterns
- Pitfalls: HIGH -- well-documented across Apple docs and community sources
- Paywall UI: MEDIUM -- custom design from CONTEXT.md, standard SwiftUI patterns apply
- Beta flag approach: MEDIUM -- compiler flag approach is common but TESTFLIGHT flag setup needs scheme configuration

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable domain, StoreKit 2 API is mature)
