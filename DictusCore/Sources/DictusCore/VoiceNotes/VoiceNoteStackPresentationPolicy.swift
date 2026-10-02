// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteStackPresentationPolicy.swift
// When DictusApp raises the voice note screen on its own (#620, smoke test of 7fdf2e1c).
import Foundation

/// Whether to present the voice note stack without being asked.
///
/// ### The rule (decided 2026-10-01)
///
/// The maintainer shared three notes, opened Dictus from its home-screen icon, and
/// saw no card: the screen only came up from the island. So whenever the app becomes
/// active, by any door, and a voice note is **ready and unread**, the stack comes up,
/// on the oldest unread one. Notes still in progress do not raise it on their own:
/// there is nothing to read yet.
///
/// It never interrupts: not during onboarding, not under a dictation, not over
/// another sheet or cover (paywall, preparation screen, History…). It waits, and is
/// asked again once the app is idle. It never stacks a second presentation: when the
/// stack is already showing, new notes are appended there.
public enum VoiceNoteStackPresentationPolicy {

    public enum Decision: Equatable, Sendable {
        /// Raise the stack now.
        case present
        /// There is something to read, and something in the way: ask again later.
        case wait
        /// Nothing to do.
        case none
    }

    public static func decide(readyUnreadCount: Int,
                              onboardingCompleted: Bool,
                              dictationActive: Bool,
                              somethingPresented: Bool,
                              stackShowing: Bool) -> Decision {
        guard readyUnreadCount > 0, !stackShowing else { return .none }
        guard onboardingCompleted, !dictationActive, !somethingPresented else { return .wait }
        return .present
    }
}
