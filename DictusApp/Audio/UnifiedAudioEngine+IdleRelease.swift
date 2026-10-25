// DictusApp/Audio/UnifiedAudioEngine+IdleRelease.swift
// The inactivity timeout's arming side (#106 Phase B, #380): when the warm-idle engine's
// release is scheduled, re-armed or cancelled.
//
// WHY a file of its own: UnifiedAudioEngine.swift went past the file_length budget of
// #146 once #380 and #353 both landed in it. The backstop (`enforceIdleReleaseIfDue`)
// and the teardown (`releaseWarmState`) stay in the main file, next to the engine and
// session state they read; only the scheduling moved, so the stored state it drives
// (`idleReleaseWorkItem`, `lastIdleStartTime`, `armedIdleReleaseInterval`) is internal
// rather than private.
import Foundation
import DictusCore

extension UnifiedAudioEngine {
    /// Arm the idle-release work item. Idempotent by construction: it cancels any
    /// prior timer first, so the extra call sites added for #256 can never stack
    /// timers — the last caller to arm always owns the only pending work item.
    /// The work runs on the main queue after the window elapses with no recording
    /// activity. Must be called from MainActor context.
    ///
    /// The window is the user's inactivity timeout (#380), read at each arming, so
    /// one setting governs every door into warm-idle — after a dictation and after
    /// a warm-up alike (decision 4). Unlimited arms no timer, but still sets the
    /// idle anchor: the engine IS warm-idle, a later setting change re-arms from
    /// it, and a release by another path still reports how long it idled.
    ///
    /// - Parameter context: names the door, for the `idleReleaseArmed` line that
    ///   proves in a device log which timeout a release was measured against.
    /// - Parameter idleSince: when the window started. Now, except for an interruption
    ///   resume, which re-arms the window the interruption cut short (#353): the release
    ///   then fires at that window's deadline, and the anchor the wall-clock backstop and
    ///   `warmStateReleased idleSeconds` read stays the original one.
    func scheduleIdleRelease(context: String, idleSince: Date = Date()) {
        cancelIdleRelease()
        lastIdleStartTime = idleSince
        let option = WarmEngineTimeout.option()
        armedIdleReleaseInterval = option.idleTimerInterval
        PersistentLog.log(.idleReleaseArmed(
            option: option.rawValue,
            timerSeconds: option.idleTimerInterval.map { Int($0) },
            context: context
        ))
        guard let interval = option.idleTimerInterval else { return }

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.releaseWarmState(reason: "idleTimeout")
            }
        }
        idleReleaseWorkItem = work
        let remaining = max(0, interval - Date().timeIntervalSince(idleSince))
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    /// Re-arm the idle release from now, if one is armed (#620).
    ///
    /// A shared voice note transcribed in the background runs in this process only
    /// because the warm engine keeps it alive (`UIBackgroundModes: audio`). Releasing
    /// the engine mid-note would let iOS suspend the app with the note half done. A
    /// voice note is the user using Dictus, so it earns the same window a dictation
    /// does: the release is pushed back by one full idle interval, never pulled
    /// forward, and nothing happens when the engine is not warm-idle — there is no
    /// warm state to extend, and starting one from the background is what iOS forbids.
    ///
    /// Under Unlimited no timer is armed, so there is nothing to push back and the
    /// engine stays warm anyway.
    func extendWarmWindow() {
        guard idleReleaseWorkItem != nil else { return }
        scheduleIdleRelease(context: "voiceNote")
    }

    /// Apply a changed inactivity timeout to the warm-idle engine (#380): re-arm the
    /// pending release with the new window, or arm none for Unlimited.
    ///
    /// WHY from now and not from the original idle start: a shorter window measured
    /// from the past could release the instant the user picks it, from inside
    /// Settings, which reads as the picker breaking something. From now, the new
    /// value means what the picker says. Immediately is not handled here: its
    /// release depends on whether a dictation or a voice note still needs the
    /// engine, which only `DictationCoordinator` knows.
    ///
    /// Does nothing when the engine is not warm-idle (nothing armed, or a recording
    /// running): the next door into warm-idle reads the new value anyway.
    func applyIdleTimeoutChange() {
        guard lastIdleStartTime != nil, !isRecording else { return }
        scheduleIdleRelease(context: "settingChanged")
    }

    /// Cancel a pending idle release. Safe to call when none is armed.
    ///
    /// WHY it also clears `lastIdleStartTime`: the anchor is only meaningful while
    /// a release is armed. Every caller here (`startRecording`, `stopEngine`,
    /// `deactivateSession`, `forceRestart`, interruption and media-services-reset
    /// handling) is leaving the warm-idle state, so keeping the old timestamp let
    /// the wall-clock backstop measure an idle age that had already ended — most
    /// dangerously during an active recording, where the next `didBecomeActive`
    /// could have released the engine mid-sentence (issue #256).
    func cancelIdleRelease() {
        idleReleaseWorkItem?.cancel()
        idleReleaseWorkItem = nil
        lastIdleStartTime = nil
    }
}
