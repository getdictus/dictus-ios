// DictusCore/Sources/DictusCore/LiveActivityInterruptionPolicy.swift
// What the Live Activity does when an audio interruption begins and ends (#353).
// Testable in isolation -- no ActivityKit dependency.

import Foundation

/// The Live Activity's answer to an audio interruption.
public enum LiveActivityInterruptionAction: String, Equatable, Sendable {
    /// Update the standby activity to its paused content. No request, no end.
    case pause
    /// Update the paused activity back to standby.
    case resume
    /// End the activity.
    case end
    /// Leave it alone: there is nothing to pause, resume or end.
    case none
}

/// WHY the activity is paused rather than ended (#353, device batch 7eaf771b): the
/// interruption arrives with the app in the background, and iOS refuses
/// `Activity.request` from there ("Target is not foreground"). An activity ended at
/// `.began` could therefore never be recreated after the call, and the next dictation's
/// bootstrap failed the same way. `Activity.update` is allowed from the background, so
/// the activity that exists is kept and its content changes instead.
public enum LiveActivityInterruptionPolicy {

    /// At `.began`. The standby pill is paused. A dictation's activity is left to the
    /// dictation (#851): it decides at the same instant whether the captured audio is
    /// transcribed (the pill goes on to transcribing, then ready) or the dictation
    /// fails (`DictationCoordinator` ends the pill itself). Anything else ends.
    public static func atBegan(hasActivity: Bool, phase: LiveActivityStateMachine.Phase) -> LiveActivityInterruptionAction {
        guard hasActivity else { return .none }
        switch phase {
        case .standby: return .pause
        case .recording, .transcribing, .processing: return .none
        case .idle, .ready, .failed: return .end
        }
    }

    /// At `.ended`, once the engine's resume has been tried.
    ///
    /// - Parameter engineWarm: the engine is running after the attempt — resumed, or
    ///   already warmed by the app during the call. A paused pill over a cold engine
    ///   would promise a warm start that is not there, so it ends.
    ///
    /// Nothing is ever requested here: with no paused activity to update, a request
    /// from the background would only fail, and the next background transition starts
    /// the standby pill when the app is in front.
    public static func atEnded(isPaused: Bool, hasActivity: Bool, engineWarm: Bool) -> LiveActivityInterruptionAction {
        guard isPaused, hasActivity else { return .none }
        return engineWarm ? .resume : .end
    }
}
