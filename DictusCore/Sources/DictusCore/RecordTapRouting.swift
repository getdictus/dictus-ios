// DictusCore/Sources/DictusCore/RecordTapRouting.swift
import Foundation

/// What a record button should do with a tap — in DictusApp (#484) and in the keyboard (#542).
///
/// WHY THIS EXISTS: `startDictation` refuses a non-URL start while
/// `modelLoadState == .loading` and returns `Void`, so the caller cannot learn that it was
/// refused. On device that read as a dead button — twelve taps in eleven seconds, every one
/// logged as `dictationDeferred` and none of them producing a single pixel, because the
/// published `DictationStatus` never left `.idle` and no view had anything to react to. The
/// guard is right to refuse; what was missing is that the two in-app buttons never asked the
/// question *before* calling, so they had nothing to show instead.
///
/// THE GUARD STAYS. This does not replace `startDictation`'s check — that one is the backstop
/// for every other caller, the keyboard's Darwin path included. This asks the same question
/// one frame earlier, in the one place that can answer it with a screen.
///
/// WHY THE ORDER BELOW MIRRORS THE GUARD'S, EXACTLY: `startDictation` tests liveness first,
/// then `modelReady`, then the load state. Ask them in any other order and a tap that the
/// coordinator would have answered with "No model downloaded" gets a preparation screen for a
/// model that is not on the device.
///
/// THE KEYBOARD ASKS THE SAME QUESTION NOW (#542). It used to keep its own copy —
/// `isModelLoading()`, one line, reading the same `modelLoadState` — and both copies were
/// blind to the same thing: a model whose file is on disk and whose Core ML cache is cold. A
/// cold model is minutes away from transcribing and the load state says `ready`, because the
/// compile has not started yet. It starts when the app launches, which is the same instant
/// the keyboard is handing off. The keyboard asked the right question and got an answer that
/// was true and useless, and a user lost a dictation to it in silence.
public enum RecordTapRouting {

    /// What the button does with this tap.
    public enum Decision: Equatable, Sendable {
        /// Call `startDictation`. Includes every case the coordinator answers for itself —
        /// a duplicate tap, a missing model — because those already have an answer.
        case startDictation
        /// Raise the model preparation screen instead of calling in.
        case presentPreparation
    }

    /// - Parameters:
    ///   - dictationStatus: the coordinator's published status at the instant of the tap.
    ///   - isModelDownloaded: `SharedKeys.modelReady`, i.e. is there a model on disk at all.
    ///   - loadState: `SharedKeys.modelLoadState`, the flag the guard reads.
    ///   - isModelWarm: `ModelWarmth.isActiveModelWarm`, i.e. has this model ever produced an
    ///     inference in this installation. The one input the other three cannot stand in for.
    public static func decide(
        dictationStatus: DictationStatus,
        isModelDownloaded: Bool,
        loadState: ModelLoadState,
        isModelWarm: Bool
    ) -> Decision {
        // WHY `canStartNewDictation` AND NOT `ModelPreparationGate.dictationOwnsTheDisplay`,
        // which is #458's rule and is `status != .idle`:
        //
        // The gate answers "is a dictation on screen", and that is the right question for the
        // three presenters it was written for, which raise the screen off a load-state change
        // behind the user's back. This is the other kind of presentation — the user's own tap,
        // whose entire meaning is "put that away and record again". The start-again mic on the
        // result screen (`RecordingView`) is drawn at `.ready` or `.failed`, so the gate's
        // predicate would refuse it and leave this exact bug in place on the second of the two
        // entry points. And the tap it would be protecting already replaces that screen the
        // moment the model *is* ready.
        //
        // So a user tap may raise preparation exactly when it could have started a dictation.
        // Same list, one line later, in `startDictation` itself — which is why this delegates
        // rather than restating it. `.recording`, `.transcribing` and `.processing` are the
        // three it refuses, and they are the ones #458 and #484 both name: a dictation that is
        // still running is never covered by a preparation screen.
        guard ColdStartResolutionPolicy.canStartNewDictation(from: dictationStatus) else {
            return .startDictation
        }
        // No model on the device is not a wait, it is an error, and the coordinator already
        // words it ("No model downloaded. Open Dictus to download a model."). A preparation
        // screen here would name a model that will never become ready and never dismiss.
        guard isModelDownloaded else {
            return .startDictation
        }
        switch loadState {
        case .loading:
            return .presentPreparation
        case .idle, .ready:
            // NO THRESHOLD AND NO PER-MODEL TABLE (#542). No record for this install means
            // refuse, whatever the model. Every measured model is over the 30s stage
            // watchdog on a cold backgrounded cache — Parakeet 48s and unfinished, Medium
            // 32s, Turbo 632MB 236s — so a duration threshold would separate nothing. And a
            // keyboard dictation is a backgrounded app by construction, so the slow number
            // is the only one this gate ever faces.
            //
            // THE ACCEPTED COST: tiny, base and small are unmeasured. If one of them
            // compiles in five seconds, its user pays one preparation screen and one extra
            // tap, once per install. That is cheaper than a table with two guessed entries.
            //
            // WHAT THIS MUST NOT TOUCH is the ordinary cold start — a dead app process with
            // a warm cache, which is most of the time iOS has killed us. That case is
            // `isModelWarm == true` and goes through here untouched: the app opens, the
            // recording runs, the user is sent back to their app.
            return isModelWarm ? .startDictation : .presentPreparation
        }
    }
}
