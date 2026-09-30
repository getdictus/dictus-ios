// DictusApp/Subscription/SubscriptionManager.swift
// StoreKit 2 subscription management: product fetch, purchase, restore, transaction listener.
import Foundation
import StoreKit
import DictusCore

// `PremiumFlags` moved to DictusCore so DictusKeyboard can read the same flag
// (#241): the keyboard panel has a Pro entry point too, and an app-target
// constant is invisible to the extension.

/// Manages all StoreKit 2 interactions for the Dictus Pro subscription.
///
/// WHY @MainActor:
/// StoreKit 2 purchase() returns on the calling actor. Since SwiftUI views
/// observe @Published properties, keeping everything on MainActor avoids
/// cross-actor data races and explicit DispatchQueue.main.async calls.
///
/// WHY a single class for all StoreKit logic:
/// Dictus sells three plans — a subscription group with monthly and yearly,
/// plus a lifetime non-consumable outside it (#350). A single manager handles
/// product fetch, purchase, restore, and transaction listening for all three.
/// No need for abstraction layers: the lifetime needs no special entitlement
/// path, see `updateProStatus()`.
@MainActor
final class SubscriptionManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    /// What the user owns, for the Pro hub's subscriber block (#216): the lifetime,
    /// and the auto-renewable plan with its renewal date. `nil` until the first
    /// entitlement scan of this launch lands, so the hub can wait rather than guess.
    ///
    /// Refreshed by every scan, alongside `isPaid`, so a renewal, a cancellation made
    /// in Apple's sheet or a refund moves it without the hub asking.
    @Published private(set) var ownership: ProOwnership?

    /// Identifiers live in `DictusCore.ProProductID`, which the DictusCore test
    /// suite checks against the local StoreKit configuration — this target has
    /// no tests of its own and an identifier typo is unrecoverable (#215).
    /// PaywallView looks products up by ID (never by array index, since
    /// StoreKit's fetch order is unspecified) to preselect the yearly plan.
    private let productIDs = ProProductID.all

    var monthlyProduct: Product? { products.first { $0.id == ProProductID.monthly } }
    var yearlyProduct: Product? { products.first { $0.id == ProProductID.yearly } }
    var lifetimeProduct: Product? { products.first { $0.id == ProProductID.lifetime } }

    private var transactionListener: Task<Void, Never>?
    private let proStatus: ProStatusManager

    init(proStatus: ProStatusManager) {
        self.proStatus = proStatus
        // Start listening IMMEDIATELY at init — before any view renders.
        // WHY: If user purchased on another device or subscription renewed
        // while the app was killed, Transaction.updates delivers those
        // transactions on next launch. Missing them = stale Pro status.
        transactionListener = listenForTransactions()
        // Products first, then the entitlement scan (passive, no sign-in prompt).
        // WHY in that order: the scan's grace-period check reads the subscription
        // status through a loaded product, and run in parallel it could find none
        // and leave a subscriber in grace period unpaid until the next event.
        // `loadProducts()` never throws, so the scan runs even when the fetch fails.
        Task {
            await loadProducts()
            await updateProStatus()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    /// Fetch subscription products from App Store / StoreKit Config.
    ///
    /// Safe to call repeatedly: PaywallView retries on appear when the launch
    /// fetch came back empty (e.g. store not ready during cold start).
    func loadProducts() async {
        do {
            // Sort by ascending price so array order is deterministic —
            // Product.products(for:) returns results in unspecified order.
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
            // An unknown product ID returns an empty array WITHOUT throwing —
            // the signature of a missing StoreKit configuration. Log it so the
            // dead "..." CTA is diagnosable from exported logs.
            if products.isEmpty {
                PersistentLog.log(.subscriptionError(
                    action: "loadProducts",
                    error: "empty result (StoreKit configuration missing or product ID unknown)"
                ))
            } else if products.count != productIDs.count {
                // A partial result is just as silent and harder to notice: the
                // missing plan's row simply does not render, and the paywall
                // looks intentional. One product can fail alone — mistyped,
                // still Waiting for Review, or not cleared for the storefront —
                // while the others resolve. Name the absent ones: that is the
                // whole diagnosis, and it is invisible from the screen (#350).
                let missing = productIDs.subtracting(products.map(\.id)).sorted()
                PersistentLog.log(.subscriptionError(
                    action: "loadProducts",
                    error: "missing product IDs: \(missing.joined(separator: ", "))"
                ))
            }
        } catch {
            PersistentLog.log(.subscriptionError(action: "loadProducts", error: error.localizedDescription))
        }
    }

    /// Purchase the Pro subscription.
    ///
    /// WHY separate purchaseState enum:
    /// The paywall CTA button shows different states (loading spinner, error).
    /// Using an enum makes the view layer's switch statement exhaustive.
    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                Self.logStoreKit(action: "purchaseSucceeded", details: Self.describe(transaction))
                await updateProStatus()
                await transaction.finish()
                purchaseState = .success
            case .userCancelled:
                Self.logStoreKit(action: "purchaseCancelled", details: "product=\(product.id)")
                purchaseState = .idle
            case .pending:
                Self.logStoreKit(action: "purchasePending", details: "product=\(product.id)")
                purchaseState = .pending
            @unknown default:
                Self.logStoreKit(action: "purchaseUnknownResult", details: "product=\(product.id)")
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
            PersistentLog.log(.subscriptionError(action: "purchase", error: error.localizedDescription))
        }
    }

    /// Restore purchases — contacts Apple servers. Only call from explicit user tap.
    ///
    /// WHY not called on launch:
    /// AppStore.sync() may trigger a sign-in prompt. Only invoke from
    /// the "Restore purchases" button tap to avoid unexpected prompts.
    func restorePurchases() async {
        purchaseState = .purchasing
        do {
            try await AppStore.sync()
            await updateProStatus()
            // `isPaid` and not `isProActive` (#593): during the reverse trial Pro is
            // already active, and a restore that found nothing would otherwise
            // celebrate a purchase that does not exist.
            purchaseState = proStatus.isPaid ? .success : .idle
        } catch {
            purchaseState = .failed(error.localizedDescription)
            PersistentLog.log(.subscriptionError(action: "restore", error: error.localizedDescription))
        }
    }

    /// Re-scan entitlements without contacting Apple's servers (no sign-in prompt).
    ///
    /// Called by the Pro hub when Apple's Manage subscription sheet closes (#216):
    /// switching auto-renew off there produces no transaction, so the listener above
    /// never hears of it, and "Renews on" would stay on screen after a cancellation.
    func refreshEntitlements() async {
        await updateProStatus()
    }

    /// Reset purchaseState to idle — called by PaywallView after dismissing error alerts.
    func resetState() {
        purchaseState = .idle
    }

    // MARK: - Private

    /// Listen for transaction updates (renewals, refunds, family sharing changes).
    ///
    /// WHY Task.detached:
    /// Transaction.updates is an AsyncSequence that runs indefinitely.
    /// Using Task.detached ensures it doesn't inherit the caller's actor
    /// context, preventing potential deadlocks. We hop back to MainActor
    /// for status updates via the @MainActor class annotation.
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    Self.logStoreKit(action: "transactionUpdate", details: Self.describe(transaction))
                case .unverified(let transaction, let error):
                    Self.logStoreKit(action: "transactionUpdate", details: "UNVERIFIED \(transaction.productID) error=\(error)")
                }
                if let transaction = try? result.payloadValue {
                    await self?.updateProStatus()
                    await transaction.finish()
                }
            }
        }
    }

    /// Scan current entitlements to determine Pro status.
    ///
    /// WHY Transaction.currentEntitlements instead of storing expiry dates:
    /// StoreKit 2 manages all subscription state internally. currentEntitlements
    /// returns only active, non-revoked transactions. No manual expiry tracking needed.
    ///
    /// WHY no filter on product type: currentEntitlements also yields the
    /// lifetime non-consumable, so owning it grants Pro through this same loop
    /// with no code of its own (#350). Restore lands here too, which is the
    /// whole promise of a non-consumable.
    private func updateProStatus() async {
        var isActive = false
        var seen: [String] = []
        var owned: [Transaction] = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                seen.append(Self.describe(transaction))
                if transaction.revocationDate == nil {
                    isActive = true
                    owned.append(transaction)
                }
            case .unverified(let transaction, let error):
                seen.append("UNVERIFIED \(transaction.productID) error=\(error)")
            }
        }
        var source = isActive ? "currentEntitlements" : "none"
        if !isActive, let other = await entitlementFromOtherSources() {
            isActive = true
            source = other
        }
        // Logged every scan: this is the only place that decides `isPaid`, and a
        // purchase that did not unlock Pro is invisible without it (#593 device
        // test, 2026-09-29: a sandbox purchase left the app unpaid).
        Self.logStoreKit(
            action: "entitlementScan",
            details: "active=\(isActive) source=\(source) entitlements=\(seen.isEmpty ? "none" : seen.joined(separator: "; "))"
        )
        // Before `setProActive`, so the hub never renders a paid state with the
        // previous scan's plan under it.
        ownership = isActive ? await readOwnership(entitlements: owned) : ProOwnership.none
        proStatus.setProActive(isActive)
    }

    /// What the user owns, read for the hub (#216).
    ///
    /// WHY the latest transactions on top of `entitlements`: the same iOS 27.0 sandbox
    /// gap `entitlementFromOtherSources` documents. `currentEntitlements` can come back
    /// empty for a subscription that is paid, and the hub must still name the plan
    /// rather than fall back to "unknown".
    ///
    /// WHY the renewal date comes from the group status and not from the transaction:
    /// `expirationDate` is the end of the period, and whether that is a renewal or the
    /// last day of Pro is in the renewal info alone. A subscriber who cancelled in
    /// Apple's sheet has to read "Ends on", not "Renews on".
    private func readOwnership(entitlements: [Transaction]) async -> ProOwnership {
        var transactions = entitlements
        for id in productIDs.sorted() where !transactions.contains(where: { $0.productID == id }) {
            guard case .verified(let transaction)? = await Transaction.latest(for: id),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate, expires <= Date() { continue }
            transactions.append(transaction)
        }

        let ownsLifetime = transactions.contains { $0.productID == ProProductID.lifetime }

        // The subscription group's status: which plan is live, and its renewal info.
        var subscription: ProActiveSubscription?
        if let group = (yearlyProduct ?? monthlyProduct)?.subscription,
           let statuses = try? await group.status {
            for status in statuses where status.state == .subscribed || status.state == .inGracePeriod {
                guard case .verified(let transaction) = status.transaction else { continue }
                let renewal = try? status.renewalInfo.payloadValue
                subscription = ProActiveSubscription(
                    productID: transaction.productID,
                    periodEnd: renewal?.renewalDate ?? transaction.expirationDate,
                    willAutoRenew: renewal?.willAutoRenew
                )
                break
            }
        }
        // No status (products not loaded, or StoreKit refused): the transaction still
        // names the plan and its period end. Renewal left unknown, not assumed.
        if subscription == nil,
           let transaction = transactions.first(where: { $0.productType == .autoRenewable }) {
            subscription = ProActiveSubscription(
                productID: transaction.productID,
                periodEnd: transaction.expirationDate,
                willAutoRenew: nil
            )
        }

        Self.logStoreKit(
            action: "ownershipScan",
            details: "lifetime=\(ownsLifetime) subscription=\(subscription?.productID ?? "none") willAutoRenew=\(subscription?.willAutoRenew.map(String.init) ?? "unknown")"
        )
        return ProOwnership(ownsLifetime: ownsLifetime, subscription: subscription)
    }

    /// Whether the latest transaction of any Pro product, or the subscription
    /// group's status, still grants Pro. Returns the source that did, or nil.
    ///
    /// WHY a second source at all: on iOS 27.0 in the sandbox,
    /// `Transaction.currentEntitlements` came back empty for a verified, unexpired
    /// monthly subscription, right after its purchase and at every scan after it,
    /// while `Transaction.latest(for:)` returned that very transaction and the group
    /// status read `subscribed` (#593 device test, 2026-09-29). A buyer who has paid
    /// must never be refused Pro because one StoreKit view of the same fact is empty.
    ///
    /// WHY the status on top of the latest transaction: during a grace period the
    /// latest transaction has expired while the subscription is still owed.
    private func entitlementFromOtherSources() async -> String? {
        for id in productIDs.sorted() {
            guard case .verified(let transaction)? = await Transaction.latest(for: id),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate {
                if expires > Date() { return "latestTransaction:\(id)" }
            } else if transaction.productType == .nonConsumable {
                return "latestTransaction:\(id)"
            }
        }
        if let subscription = (yearlyProduct ?? monthlyProduct)?.subscription,
           let statuses = try? await subscription.status,
           statuses.contains(where: { $0.state == .subscribed || $0.state == .inGracePeriod }) {
            return "subscriptionStatus"
        }
        return nil
    }

    nonisolated private static func describe(_ transaction: Transaction) -> String {
        let expires = transaction.expirationDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "none"
        let revoked = transaction.revocationDate.map { "\(Int($0.timeIntervalSince1970))" } ?? "none"
        return "product=\(transaction.productID) id=\(transaction.id) env=\(transaction.environment.rawValue) expires=\(expires) revoked=\(revoked)"
    }

    nonisolated private static func logStoreKit(action: String, details: String) {
        PersistentLog.log(.diagnosticProbe(component: "storeKit", instanceID: "0", action: action, details: details))
    }

    /// Verify transaction signature (StoreKit 2 does this automatically).
    ///
    /// WHY checkVerified wrapper:
    /// payloadValue already verifies the JWS signature. This wrapper makes
    /// the verification step explicit in the purchase flow and provides
    /// a single point to handle verification failures.
    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}

/// Purchase flow state for PaywallView CTA button rendering.
enum PurchaseState: Equatable {
    case idle
    case purchasing
    case pending
    case success
    case failed(String)

    static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.purchasing, .purchasing),
             (.pending, .pending), (.success, .success):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}
