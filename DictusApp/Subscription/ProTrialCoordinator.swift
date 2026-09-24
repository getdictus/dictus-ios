// DictusApp/Subscription/ProTrialCoordinator.swift
// When the app itself raises something about the reverse trial: the announcement, the end (#593).
import Foundation
import DictusCore

/// Which of the two populations #593 names an announcement is for.
enum ProTrialAnnouncementKind: Equatable {
    /// Onboarding just completed in this process.
    case newUser
    /// An install that completed onboarding before the Pro version existed.
    case existingUser
}

/// The two screens the app opens on its own about the reverse trial.
///
/// Everything else about the trial is passive: badges, marks, a banner in its last
/// two days. These two are the exceptions, and each is shown when a policy in
/// DictusCore says it is due:
///
/// - **The announcement**, which starts the trial. A new user meets it when onboarding
///   completes; an existing user updated to the Pro version meets it on the first
///   launch that finds no trial recorded. One sheet, two wordings. The trial starts
///   when the sheet is dismissed, so its disclosure (duration, end date, what stops,
///   what it costs to keep) is always read **before** anything starts.
/// - **The end-of-trial paywall**, once, on the first launch after the trial ended.
///
/// WHY a coordinator rather than state on `MainTabView`: the announcement is decided
/// by two different events in two different views (onboarding completing in
/// `DictusApp`, the app becoming active in `MainTabView`), and both must land on the
/// same single presentation. An object both can reach is the one place that can
/// refuse to present it twice.
@MainActor
final class ProTrialCoordinator: ObservableObject {

    /// One presentation of the announcement.
    struct Announcement: Identifiable, Equatable {
        let kind: ProTrialAnnouncementKind
        /// When the sheet went up. The trial counts from here, so the end date the
        /// sheet printed is the end date stored.
        let shownAt: Date

        var id: Date { shownAt }

        /// The end date the sheet announces.
        var endsAt: Date { ProTrialRecord.starting(at: shownAt).endsAt }
    }

    /// The announcement on screen, if any.
    @Published var announcement: Announcement?

    /// Whether the end-of-trial paywall is on screen.
    @Published var showsEndOfTrialPaywall = false

    private let proStatus: ProStatusManager

    /// Set when onboarding completes in this process, so the announcement reads as
    /// a welcome rather than as news about an update the user never saw.
    private var onboardedThisLaunch = false

    /// The announcement whose dismissal will start the trial.
    ///
    /// Kept apart from `announcement`, which SwiftUI sets back to nil before
    /// `onDismiss` runs.
    private var pendingStart: Announcement?

    init(proStatus: ProStatusManager) {
        self.proStatus = proStatus
    }

    /// Onboarding just completed. Called from `DictusApp`.
    ///
    /// The announcement waits for the onboarding cover to finish leaving: a sheet
    /// requested while a full-screen cover is still dismissing is dropped by UIKit
    /// ("already presenting"), and the trial would then start on the next launch
    /// instead of now.
    func onboardingCompleted() {
        onboardedThisLaunch = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            evaluate(canPresent: true)
        }
    }

    /// Decide whether either screen is due, and raise it.
    ///
    /// - Parameter canPresent: whether the app is showing its ordinary navigation.
    ///   False during a cold-start dictation, a model preparation screen or a
    ///   recording: those screens own the display, and a sheet over them would
    ///   interrupt the dictation #593 promises never to interrupt.
    func evaluate(canPresent: Bool) {
        // Expiry is a clock passing an instant, which publishes nothing on its own.
        proStatus.refreshFromAppGroup()
        guard canPresent, announcement == nil, !showsEndOfTrialPaywall else { return }

        let onboarded = AppGroup.defaults.bool(forKey: SharedKeys.hasCompletedOnboarding)
        if onboarded && proStatus.mayStartTrial {
            let next = Announcement(kind: onboardedThisLaunch ? .newUser : .existingUser, shownAt: Date())
            pendingStart = next
            announcement = next
            PersistentLog.log(.diagnosticProbe(
                component: "proTrial", instanceID: "0", action: "announcementShown",
                details: "kind=\(next.kind == .newUser ? "newUser" : "existingUser")"
            ))
            return
        }

        if proStatus.endOfTrialPaywallDue {
            // Marked on presentation, not on dismissal: "shown once" has to hold even
            // if the process dies with the paywall on screen.
            proStatus.markEndOfTrialPaywallShown()
            showsEndOfTrialPaywall = true
            PersistentLog.log(.diagnosticProbe(
                component: "proTrial", instanceID: "0", action: "endOfTrialPaywallShown",
                details: "usage=\(proStatus.trialUsage.smartModeUses)/\(proStatus.trialUsage.vocabularyFixes)"
            ))
        }
    }

    /// The announcement left the screen, whichever way: its button or a swipe. The
    /// trial is a gift, not an opt-in, so both start it.
    ///
    /// If the process dies with the sheet up, nothing started and the next launch
    /// shows it again, which is the right failure: the disclosure is never skipped.
    func announcementDismissed() {
        guard let pending = pendingStart else { return }
        pendingStart = nil
        proStatus.startTrialIfEligible(from: pending.shownAt)
    }
}
