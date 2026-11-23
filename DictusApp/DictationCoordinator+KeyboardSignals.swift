// DictusApp/DictationCoordinator+KeyboardSignals.swift
// The keyboard's stop/cancel signals and the onboarding gate on its start, moved out of
// DictationCoordinator.swift unchanged: that file sits at the `file_length` budget, and
// neither extension reaches a private member.
import DictusCore
import UIKit

// MARK: - Keyboard stop and cancel (#868)

extension DictationCoordinator {

    /// Decide a keyboard stop or cancel, clear its flag when it is acted on, and log it when
    /// it is not acted on, or acted on with the flag reading false.
    ///
    /// WHY BOTH LOG LINES: before #868 an ignored stop left nothing in the log, and twelve
    /// taps in a row read as the app never receiving them. `stopIgnored` / `cancelIgnored`
    /// say a signal arrived and why nothing happened; `…HonoredWithoutFlag` says the App
    /// Group read was stale, which is the evidence a launch before first unlock leaves.
    func mayActOnKeyboardSignal(_ signal: KeyboardSignal, flagKey: String) -> Bool {
        let requested = defaults.bool(forKey: flagKey)
        let decision = KeyboardSignalPolicy.decide(signal, flagRequested: requested, status: status)
        switch decision {
        case .honor:
            // Always, even when it read false: in a stale view the keyboard's `true` is on
            // disk, and only this write can clear it for the next session.
            defaults.set(false, forKey: flagKey)
            defaults.synchronize()
            if !requested {
                PersistentLog.log(.diagnosticProbe(
                    component: "KeyboardSignal",
                    instanceID: signal.rawValue,
                    action: "\(signal.rawValue)HonoredWithoutFlag",
                    details: "status=\(status.rawValue)"
                ))
            }
            return true
        case .ignore(let reason):
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardSignal",
                instanceID: signal.rawValue,
                action: "\(signal.rawValue)Ignored",
                details: "reason=\(reason)"
            ))
            return false
        }
    }
}

// MARK: - Onboarding gate (#827)

extension DictationCoordinator {

    /// Start the dictation the keyboard asked for over the Darwin notification, unless
    /// onboarding is not done and the app is not in the foreground.
    ///
    /// Safety net for a keyboard built before #827, or one that read a stale app phase:
    /// before onboarding there is no model, so a dictation started here would fail and
    /// leave its error behind. The onboarding test dictation is unaffected — it runs with
    /// the app active, which `KeyboardOnboardingGate.appMayStartKeyboardDictation` lets
    /// through.
    func startKeyboardDictationUnlessBeforeOnboarding(appState: UIApplication.State) {
        guard KeyboardOnboardingGate.appMayStartKeyboardDictation(
            onboardingCompleted: KeyboardOnboardingGate.isOnboardingCompleted(in: defaults),
            appIsActive: appState == .active
        ) else {
            PersistentLog.log(.dictationDeferred(reason: "keyboard start before onboarding with app not active"))
            return
        }
        startDictation(origin: .keyboard)
    }
}
