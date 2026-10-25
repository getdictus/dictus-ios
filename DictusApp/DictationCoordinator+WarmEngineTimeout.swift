// DictusApp/DictationCoordinator+WarmEngineTimeout.swift
// The coordinator's half of the inactivity timeout setting (#380).
//
// WHY a file of its own: DictationCoordinator.swift sits at the length budget of #146,
// the same reason `DictationCoordinator+SessionActivation.swift` exists. The timer itself
// lives in `UnifiedAudioEngine`; what lives here is the part only the coordinator can
// judge, whether a dictation or a voice note still needs the engine.
import Foundation
import DictusCore

extension DictationCoordinator {

    /// The user changed the inactivity timeout in Settings: the warm engine takes the
    /// new window now rather than at its next dictation.
    func warmEngineTimeoutDidChange() {
        applyIdleTimeoutChangeToEngine()
        releaseWarmStateIfImmediate(after: "settingChanged")
    }

    /// Release the warm engine as soon as nothing needs it, when the timeout is
    /// Immediately (#380 decision 2).
    ///
    /// Called wherever a piece of work that needed the engine ends: a dictation
    /// reaching a terminal status, the keyboard hand-off concluding, the voice note
    /// queue draining, the setting itself changing. WHY not when the samples are
    /// collected: the transcription, the Smart Mode and the hand-off all run after
    /// that, and from the keyboard the warm engine is what keeps Dictus running in
    /// the background while they do (`WarmEngineTimeoutOption.idleTimerInterval`).
    ///
    /// It waits for all three to be over, so the end of one never cuts another: a
    /// dictation finishing while a voice note transcribes leaves the release to the
    /// note's queue (#620). Recording always wins, again, inside `releaseWarmState`.
    func releaseWarmStateIfImmediate(after event: String) {
        guard WarmEngineTimeout.option() == .immediately,
              !DictationSessionLivenessPolicy.isActive(status),
              polishHandoffSession == nil,
              !VoiceNoteProcessor.shared.isRunning else { return }
        releaseWarmEngine(reason: "immediately-\(event)")
    }
}
