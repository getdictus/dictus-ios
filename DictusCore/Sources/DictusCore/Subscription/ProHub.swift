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
