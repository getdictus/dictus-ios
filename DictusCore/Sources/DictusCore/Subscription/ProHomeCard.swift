// DictusCore/Sources/DictusCore/Subscription/ProHomeCard.swift
// What the Home Pro card shows, in every subscription state (#216 decision 16).
import Foundation

/// The Home Pro card's content.
public enum ProHomeCardContent: Equatable, Sendable {

    /// Nothing: the paywall is hidden, or the device can never run Smart Modes and
    /// nothing is owned (#593 decision 2).
    case hidden

    /// The sales card, as before #216.
    case upgrade

    /// The trial's last-days reminder, as before #216.
    case trialEnding(daysLeft: Int)

    /// The way into the hub for anyone who has Pro (paid, or a trial before its last
    /// days): "Dictus Pro" and how many of the features are switched on. No price,
    /// no sales copy.
    case member(activeFeatures: Int)
}

/// The rule behind the Home Pro card (#216 decision 16).
///
/// WHY a rule of its own and not a new case in `ProPromotion.entry`: that entry also
/// drives the keyboard panel's Pro pill, which must stay absent for a subscriber.
/// The card adds one state to it, for Home only, and leaves every other answer the
/// promotion gives exactly as it was.
public enum ProHomeCard {

    // swiftlint:disable function_parameter_count
    // Six independent facts, each read by one rung below; same reasoning as
    // `ProPromotion.entry` and `ProHub.bottomBlock`.

    /// - Parameters:
    ///   - promotion: `ProPromotion.entry`, today's answer for free and trial users.
    ///   - isPaid: a StoreKit entitlement exists.
    ///   - isEntitled: Pro is active (paid, trial running, or the DEBUG force).
    ///   - trial: the reverse trial's state.
    ///   - activeFeatures: how many Pro features are switched on.
    public static func content(paywallVisible: Bool,
                               promotion: ProPromotionEntry,
                               isPaid: Bool,
                               isEntitled: Bool,
                               trial: ProTrialState,
                               activeFeatures: Int) -> ProHomeCardContent {
        // The flag gates the whole card, the DEBUG force included (#236).
        guard paywallVisible else { return .hidden }
        // The trial's last-days reminder stays exactly as #593 made it. The promotion
        // only returns it for an unpaid user, so a subscriber never sees it.
        if case .trialEnding(let daysLeft) = promotion {
            return .trialEnding(daysLeft: daysLeft)
        }
        // Pro in hand, by purchase, by a trial with days to spare (decision 16, as
        // answered on 2026-10-05) or by the DEBUG force: the calm card. Shown on any
        // device; it sells nothing, so #593 decision 2 does not apply.
        if isPaid || isEntitled {
            return .member(activeFeatures: activeFeatures)
        }
        switch promotion {
        case .hidden: return .hidden
        case .upgrade: return .upgrade
        case .trialEnding(let daysLeft): return .trialEnding(daysLeft: daysLeft)
        }
    }
    // swiftlint:enable function_parameter_count
}
