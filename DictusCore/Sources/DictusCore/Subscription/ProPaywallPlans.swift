// DictusCore/Sources/DictusCore/Subscription/ProPaywallPlans.swift
// Which plans the paywall shows, and when closing it offers the monthly plan (#724).
import Foundation

/// The paywall's plan list and its one dismiss-time offer (#724).
///
/// Decided in the 2026-10-12 monetization grilling: two plans in view, the yearly
/// (preselected) and the lifetime, with the monthly behind a "See all plans" link. And
/// on the end-of-trial paywall only, closing without buying offers the monthly plan
/// once, at its existing price.
///
/// WHY in DictusCore: DictusApp has no test target, and both rules decide what a user
/// can be charged for, which is worth a test. The view maps StoreKit's products onto
/// identifiers and asks here.
///
/// WHY an enum with no cases: a pure namespace, like `ProProductID`.
public enum ProPaywallPlans {

    /// Whether a plan's row is drawn.
    ///
    /// WHY the selection keeps a row visible: the paywall's invariant is that the
    /// checked row, the CTA and the charge never disagree. When the yearly fails to
    /// load, the selection falls onto the cheapest plan that did, the monthly; hiding
    /// it then would put a button that charges 4,99 € a month under no checked row.
    /// Making the selected plan visible keeps the invariant without a second rule.
    ///
    /// - Parameters:
    ///   - productID: the plan being drawn.
    ///   - showsAllPlans: whether the user tapped "See all plans".
    ///   - selectedID: the plan the CTA would buy.
    public static func isVisible(_ productID: String, showsAllPlans: Bool, selectedID: String) -> Bool {
        productID != ProProductID.monthly || showsAllPlans || selectedID == ProProductID.monthly
    }

    /// Whether the "See all plans" link is drawn: only while it would reveal something.
    ///
    /// - Parameter loaded: the identifiers StoreKit returned. A monthly that failed to
    ///   load has nothing to reveal, and a link that opens onto nothing is a dead tap.
    public static func showsSeeAllPlansLink(loaded: Set<String>, showsAllPlans: Bool, selectedID: String) -> Bool {
        loaded.contains(ProProductID.monthly)
            && !isVisible(ProProductID.monthly, showsAllPlans: showsAllPlans, selectedID: selectedID)
    }

    /// Whether closing the paywall shows the monthly offer instead of closing.
    ///
    /// Only on the end-of-trial paywall: closing a paywall the user opened from
    /// Settings, the home card or a locked feature never nags. That paywall is itself
    /// shown once (`ProTrialPolicy.endOfTrialPaywallDue`), and `alreadyOffered` makes
    /// the offer once within it, so a user meets it at most once, ever.
    ///
    /// - Parameters:
    ///   - isEndOfTrialPaywall: the paywall the app opened when the trial ended.
    ///   - isPaid: a user who bought, or restored, has nothing left to be offered.
    ///   - monthlyLoaded: the offer names a StoreKit price, never a written one, so
    ///     with no monthly product there is nothing to offer.
    ///   - alreadyOffered: the offer was shown during this presentation.
    public static func offersMonthlyOnClose(isEndOfTrialPaywall: Bool,
                                            isPaid: Bool,
                                            monthlyLoaded: Bool,
                                            alreadyOffered: Bool) -> Bool {
        isEndOfTrialPaywall && !isPaid && monthlyLoaded && !alreadyOffered
    }
}
