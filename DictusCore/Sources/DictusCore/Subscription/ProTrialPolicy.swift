// DictusCore/Sources/DictusCore/Subscription/ProTrialPolicy.swift
// Who is entitled, who gets a trial, and what each surface may say about it (#593).
import Foundation

/// The entitlement rule, as a pure function.
///
/// `ProStatusManager.isProActiveStatic` is still the one place entitlement is
/// decided (#460); it reads its inputs from the App Group and hands them here. The
/// rule is split out so it can be tested against an injected clock and against a
/// `trialsEnabled` the shipping `PremiumFlags.paywallVisible` constant would pin.
public enum ProEntitlement {

    /// Paid, **or** a reverse trial running.
    ///
    /// - Parameter trialsEnabled: `PremiumFlags.paywallVisible`. With the paywall
    ///   hidden no trial may start (#593, #279), and a record left behind by a
    ///   development build that had the flag up must not grant anything in one that
    ///   does not: with the flag down the product has no subscription at all (#236).
    public static func isActive(isPaid: Bool, trial: ProTrialState, trialsEnabled: Bool) -> Bool {
        isPaid || (trialsEnabled && trial.isRunning)
    }
}

/// When the reverse trial starts, and what the app shows around it.
///
/// Every question is a pure function of the facts that decide it, for the reason
/// `SmartModeSurface` gives: the answers have to hold on surfaces nobody can
/// screenshot in a review, and DictusCore is the target with a test bundle. No
/// parameter has a default, for the reason `SmartModeAvailability.armability` gives
/// about its own: the safe-looking default is the one that produces the bug.
public enum ProTrialPolicy {

    /// Whether a reverse trial may start now.
    ///
    /// - **Decision 2.** `deviceIsCapable` is `SmartModeAvailability.deviceIsCapable`,
    ///   which is `SmartModeUnavailableReason.isRecoverable` read as a capability
    ///   question: `deviceNotEligible` and `osTooOld` (and `sdkMissing`) are the
    ///   definitive reasons, and a device in one of them never gets a trial, new user
    ///   or existing. On such a device Pro is History and Vocabulary only, and Pierre
    ///   does not want to push a subscription that light. A capable iPhone with Apple
    ///   Intelligence switched off **is** capable and gets the trial.
    /// - **No second trial.** Anything but `.neverStarted` refuses, whatever the rest
    ///   says. The Keychain behind `ProTrialStore` is what makes `.neverStarted` true
    ///   only once per device.
    /// - **Paid users get nothing to start.** They already have Pro; a trial clock
    ///   ticking under a subscription would only ever produce a wrong badge.
    public static func mayStart(paywallVisible: Bool,
                                deviceIsCapable: Bool,
                                isPaid: Bool,
                                trial: ProTrialState) -> Bool {
        paywallVisible && deviceIsCapable && !isPaid && trial == .neverStarted
    }

    /// Whether the announcement that starts the trial is due.
    ///
    /// One rule for both populations #593 names. A new user completes onboarding and
    /// meets it straight away; an existing user updated to the Pro version has
    /// completed onboarding long ago and meets it on the first launch that finds no
    /// trial recorded. Either way the disclosure is on screen **before** the trial
    /// starts: the announcement starts it when the user dismisses it.
    public static func announcementDue(onboardingCompleted: Bool,
                                       paywallVisible: Bool,
                                       deviceIsCapable: Bool,
                                       isPaid: Bool,
                                       trial: ProTrialState) -> Bool {
        onboardingCompleted && mayStart(
            paywallVisible: paywallVisible, deviceIsCapable: deviceIsCapable, isPaid: isPaid, trial: trial
        )
    }

    /// Whether the end-of-trial paywall should open now.
    ///
    /// Once, on the next launch after the trial ended, and only for someone who did
    /// not subscribe. A device covered by decision 2 never reaches it, because it
    /// never had a trial to end.
    public static func endOfTrialPaywallDue(paywallVisible: Bool,
                                            isPaid: Bool,
                                            trial: ProTrialState,
                                            alreadyShown: Bool) -> Bool {
        paywallVisible && !isPaid && trial.isExpired && !alreadyShown
    }

    /// The number the discreet `Pro · N days left` badge shows, or nil for no badge.
    ///
    /// Nil for a subscriber: the badge tells a user what they have and for how long,
    /// and a subscriber's Pro does not run out in N days.
    public static func badgeDaysLeft(paywallVisible: Bool,
                                     isPaid: Bool,
                                     trial: ProTrialState,
                                     now: Date) -> Int? {
        guard paywallVisible, !isPaid else { return nil }
        return trial.daysLeft(now: now)
    }
}

/// What a promotional Pro entry point shows: the home banner and the keyboard
/// panel's pill.
public enum ProPromotionEntry: Equatable, Sendable {

    /// Nothing at all.
    case hidden

    /// The ordinary "Dictus Pro" entry, leading to the paywall.
    case upgrade

    /// The trial ends soon (decision 3): the entry names how many days are left and
    /// leads to the paywall, where subscribing keeps Pro with no gap.
    case trialEnding(daysLeft: Int)
}

/// The promotion policy (#593 decision 2, #279).
public enum ProPromotion {

    // swiftlint:disable function_parameter_count
    // Six parameters because six independent facts decide the answer, each consulted
    // by one rung of the order below. A struct bundling them would only rename the
    // same six fields and hide which rung reads which.

    /// What a promotional entry point shows.
    ///
    /// The order is the message:
    ///
    /// 1. **Paywall hidden:** nothing, the product has no subscription (#236).
    /// 2. **Device that can never run Smart Modes:** nothing. Pro stays purchasable
    ///    from the Settings row, which is not a promotion and is not governed here;
    ///    what disappears is every place that *pushes* it (decision 2).
    /// 3. **Subscriber:** nothing to sell.
    /// 4. **Trial in its last two days:** the reminder (decision 3).
    /// 5. **Entitled otherwise** (a trial with days to spare, or the DEBUG override):
    ///    nothing. During the trial the only indicator is the discreet badge.
    /// 6. **Everyone else:** the ordinary entry.
    public static func entry(paywallVisible: Bool,
                             deviceIsCapable: Bool,
                             isPaid: Bool,
                             isEntitled: Bool,
                             trial: ProTrialState,
                             now: Date) -> ProPromotionEntry {
        guard paywallVisible, deviceIsCapable, !isPaid else { return .hidden }
        if trial.isInReminderWindow(now: now), let daysLeft = trial.daysLeft(now: now) {
            return .trialEnding(daysLeft: daysLeft)
        }
        return isEntitled ? .hidden : .upgrade
    }
    // swiftlint:enable function_parameter_count
}
