// DictusCore/Sources/DictusCore/Subscription/ProHub.swift
// What the Dictus Pro hub shows under its feature cards, per subscription state (#216).
import Foundation

/// The auto-renewable subscription a user holds, as the hub needs to describe it.
///
/// WHY a mirror of StoreKit's facts rather than StoreKit's types: DictusCore is linked
/// by the keyboard extension, which has no business with StoreKit (see
/// `ProSubscriptionUnit`). `SubscriptionManager` reads StoreKit and fills this in.
public struct ProActiveSubscription: Equatable, Sendable {
    /// One of `ProProductID.monthly` / `.yearly`, or an identifier this build does
    /// not know, which the hub names generically rather than guessing.
    public let productID: String

    /// When the current period ends: the renewal date, or the last day of Pro for a
    /// subscription that will not renew. Nil when StoreKit gave none.
    public let periodEnd: Date?

    /// Whether the subscription renews at `periodEnd`. Nil when the renewal info could
    /// not be read, in which case the hub states the date without claiming either way.
    public let willAutoRenew: Bool?

    public init(productID: String, periodEnd: Date?, willAutoRenew: Bool?) {
        self.productID = productID
        self.periodEnd = periodEnd
        self.willAutoRenew = willAutoRenew
    }

    /// The plan's period, from its identifier.
    public var period: ProPlanPeriod {
        switch productID {
        case ProProductID.monthly: return .monthly
        case ProProductID.yearly: return .yearly
        default: return .unlabelled
        }
    }
}

/// What a paying user owns, as read from StoreKit at the last entitlement scan.
public struct ProOwnership: Equatable, Sendable {
    /// The lifetime non-consumable.
    public let ownsLifetime: Bool

    /// An auto-renewable subscription still granting Pro, if any.
    public let subscription: ProActiveSubscription?

    public init(ownsLifetime: Bool, subscription: ProActiveSubscription?) {
        self.ownsLifetime = ownsLifetime
        self.subscription = subscription
    }

    /// Nothing found.
    public static let none = ProOwnership(ownsLifetime: false, subscription: nil)
}

/// The block under the hub's feature cards (#216 decision 2).
public enum ProHubBottomBlock: Equatable, Sendable {

    /// The paywall as validated in #78: plan selector, CTA, reassurance. For a free
    /// user `trialEndsAt` is nil and the block is exactly today's paywall; during the
    /// reverse trial it carries the end date and the days left above the offers.
    case offers(trialEndsAt: Date?, daysLeft: Int?)

    /// A monthly or yearly subscriber: the plan, its date, Manage subscription.
    case subscription(ProActiveSubscription)

    /// A lifetime owner: no date and, normally, no manage button.
    ///
    /// `alsoSubscribed` carries an auto-renewable subscription held **as well**. Apple
    /// does not cancel a subscription when the same user buys the lifetime, so someone
    /// who subscribed first and bought the lifetime later keeps paying every month.
    /// Decision 2 drops the manage button because "nothing renews, nothing to cancel";
    /// for this user both halves are false, and hiding the one way to stop paying for
    /// something they no longer need is the support ticket #216 exists to prevent.
    case lifetime(alsoSubscribed: ProActiveSubscription?)

    /// Paid, and StoreKit's scan of this launch has not landed yet. A short wait: the
    /// hub shows a placeholder rather than guessing, so a lifetime owner is never
    /// flashed a Manage subscription button they have no use for.
    case paidPlanPending

    /// Paid, the scan landed, and it named no product this build recognises. The hub
    /// still offers Manage subscription: a subscriber must always find how to cancel,
    /// and Apple's sheet shows whatever there is.
    case paidPlanUnknown

    /// Entitled without a purchase and outside a trial. Only the DEBUG forced
    /// entitlement (#460) produces it; nothing may be sold here, since that switch
    /// exists precisely while the paywall is hidden (#577).
    case entitledWithoutPurchase

    /// Whether the feature cards above this block are the active ones: toggles and
    /// navigation (decision 4). Only a free user gets the informational cards.
    public var cardsAreActive: Bool {
        if case .offers(let endsAt, _) = self { return endsAt != nil }
        return true
    }

    /// Whether the plan selector and CTA render, and with them Restore purchases.
    public var sellsPlans: Bool {
        if case .offers = self { return true }
        return false
    }
}

/// The hub's state rule (#216), as a pure function.
///
/// WHY here and not in the view: the same reason `ProPromotion` gives. A state rule
/// answered inline in the view that draws it is one nobody can test, and this one
/// decides whether a subscriber can find the cancel button.
public enum ProHub {

    // swiftlint:disable function_parameter_count
    // Six parameters because six independent facts decide the block, each read by one
    // rung below. Same reasoning as `ProPromotion.entry`.

    /// The block under the cards.
    ///
    /// The order is the message:
    ///
    /// 1. **Paid:** what they own. Checked first so a subscription taken during the
    ///    trial shows the plan, not the trial it replaced.
    /// 2. **Trial running** (with the paywall visible, the only build where one can
    ///    exist): the days left, then the offers.
    /// 3. **Entitled otherwise:** the DEBUG force. Nothing is sold.
    /// 4. **Everyone else:** the paywall, unchanged.
    ///
    /// - Parameter ownership: `nil` until StoreKit's first scan of this launch lands.
    public static func bottomBlock(paywallVisible: Bool,
                                   isPaid: Bool,
                                   isEntitled: Bool,
                                   trial: ProTrialState,
                                   now: Date,
                                   ownership: ProOwnership?) -> ProHubBottomBlock {
        if isPaid {
            guard let ownership else { return .paidPlanPending }
            if ownership.ownsLifetime {
                // Only a subscription that will (or may) renew is worth a button: one
                // already cancelled costs the lifetime owner nothing more.
                let renewing = ownership.subscription.flatMap { $0.willAutoRenew == false ? nil : $0 }
                return .lifetime(alsoSubscribed: renewing)
            }
            if let subscription = ownership.subscription {
                return .subscription(subscription)
            }
            return .paidPlanUnknown
        }
        if paywallVisible, case .running(let endsAt) = trial {
            return .offers(trialEndsAt: endsAt, daysLeft: trial.daysLeft(now: now))
        }
        if isEntitled {
            return .entitledWithoutPurchase
        }
        return .offers(trialEndsAt: nil, daysLeft: nil)
    }
    // swiftlint:enable function_parameter_count
}

/// The "Upgrade to lifetime" row a monthly or yearly subscriber gets in the hub
/// (#216 decision 15).
public struct ProLifetimeUpgrade: Equatable, Sendable {

    /// Whether the row carries, before purchase, the line saying the subscription is
    /// not cancelled automatically. Apple does not cancel it when the same person
    /// buys the lifetime, so someone who upgrades without reading it keeps paying.
    public let showsSubscriptionKeepsBillingNote: Bool

    public init(showsSubscriptionKeepsBillingNote: Bool) {
        self.showsSubscriptionKeepsBillingNote = showsSubscriptionKeepsBillingNote
    }

    /// The row for this block, or nil for no row.
    ///
    /// - **Only a monthly or yearly subscriber.** A lifetime owner has nothing to
    ///   upgrade to; free, trial and end-of-trial users already see the lifetime in
    ///   their plan selector; a paid state whose plan is unknown or pending is not
    ///   known to be a subscription.
    /// - **Only with the paywall visible.** The row sells; under the DEBUG forced
    ///   entitlement with the flag down, a phone that owns a sandbox subscription
    ///   reaches this block, and nothing may be sold there (#236, #577).
    /// - **The note** shows unless the subscription is known to be cancelled already.
    ///   An unreadable renewal status (`willAutoRenew == nil`) keeps it: claiming the
    ///   subscription stops by itself is the one wrong answer.
    public static func offer(for block: ProHubBottomBlock, paywallVisible: Bool) -> ProLifetimeUpgrade? {
        guard paywallVisible, case .subscription(let subscription) = block else { return nil }
        return ProLifetimeUpgrade(showsSubscriptionKeepsBillingNote: subscription.willAutoRenew != false)
    }
}

/// How the hub re-reads ownership after Apple's Manage subscription sheet closes
/// (#216, device test of 2026-10-02).
///
/// ### Why a re-read at all
///
/// Cancelling in the sheet changes the renewal info and creates no transaction, so
/// `Transaction.updates` stays silent. A single scan on dismissal read the renewal
/// info before StoreKit had it: the hub kept "Renews on" until the sheet was opened
/// and closed a second time. `Product.SubscriptionInfo.Status.updates` is the event
/// source for that change and `SubscriptionManager` listens to it; this schedule is
/// the bounded backstop for the case where it is late or silent (sandbox), not a
/// polling loop: a few reads over about ten seconds, ending at the first change.
public enum ProOwnershipRecheck {

    /// Seconds to wait before each re-read, in order. About ten seconds in total,
    /// front-loaded: a cancellation usually lands within the first seconds.
    public static let delays: [Double] = [0.5, 1, 1.5, 3, 4]

    /// Whether to stop re-reading: the ownership moved since the sheet closed, so the
    /// hub is already showing the change the user made.
    public static func isSettled(before: ProOwnership?, after: ProOwnership?) -> Bool {
        before != after
    }
}
