// DictusApp/Views/ProTrialDebugSection.swift
// DEBUG-only controls that move the reverse trial through its states on a device (#593).
#if DEBUG
import SwiftUI
import DictusCore

/// The Developer section's reverse-trial controls.
///
/// A trial lasts fourteen days and its record survives a reinstall by design, so
/// without these the maintainer could see each state once per device, ever. They
/// write through `ProStatusManager`'s DEBUG entry points, which rewrite the Keychain
/// and the mirror together, so the keyboard sees exactly what the app sees.
///
/// Strings are verbatim, not catalogue entries: the whole type is compiled out of
/// Release, and nobody but the maintainer reads it.
///
/// Nothing here opens the paywall's gate. With `PremiumFlags.paywallVisible` down the
/// record is written but grants nothing and shows nothing (#279); the footer says so.
struct ProTrialDebugSection: View {
    @EnvironmentObject var proStatus: ProStatusManager
    @EnvironmentObject var trialCoordinator: ProTrialCoordinator

    var body: some View {
        Section {
            LabeledContent {
                Text(verbatim: stateDescription)
            } label: {
                Text(verbatim: "Trial state")
            }
            LabeledContent {
                Text(verbatim: "\(proStatus.trialUsage.smartModeUses) / \(proStatus.trialUsage.vocabularyFixes)")
            } label: {
                Text(verbatim: "Smart Mode uses / vocabulary fixes")
            }
            Button {
                proStatus.debugSetTrial(endingInDays: Double(ProTrial.durationDays))
            } label: {
                Text(verbatim: "Start a fresh 14-day trial")
            }
            Button {
                proStatus.debugSetTrial(endingInDays: 1.5)
            } label: {
                Text(verbatim: "Move to the last 2 days")
            }
            Button {
                proStatus.debugSetTrial(endingInDays: -0.01)
                trialCoordinator.evaluate(canPresent: true)
            } label: {
                Text(verbatim: "End the trial now")
            }
            Button(role: .destructive) {
                proStatus.debugResetTrial()
            } label: {
                Text(verbatim: "Forget the trial (Keychain, mirror, counters, paywall)")
            }
        } header: {
            Text(verbatim: "Reverse trial (#593)")
        } footer: {
            Text(verbatim: PremiumFlags.paywallVisible
                 ? "Rewrites the Keychain record and the App Group mirror. After \"Forget\", relaunch the app to see the existing-user announcement."
                 : "PremiumFlags.paywallVisible is false in this build: the record is written but grants nothing and shows nothing.")
        }
    }

    private var stateDescription: String {
        switch proStatus.trialState {
        case .neverStarted:
            return "never started"
        case .running(let endsAt):
            return "running, ends \(endsAt.formatted(date: .abbreviated, time: .shortened))"
        case .expired(let endedAt):
            return "expired \(endedAt.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}
#endif
