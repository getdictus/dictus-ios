// DictusCore/InKeyboardEarlyCapture.swift
import Foundation

/// Capturing from the mic tap rather than from the route decision (spike, #992 round 4).
///
/// WHY: the keyboard waits 500 ms for DictusApp to answer its Darwin start post before it
/// decides to dictate itself, and `getUserMedia` then takes 0.24–0.6 s more on an
/// iPhone 15 Pro Max (1.2–1.4 s twice). The first words were spoken into that gap and
/// lost. Now the capture starts at the tap, in parallel with the wait, and buffers from
/// its first sample; the route decision then keeps or drops what was buffered.
///
/// The one thing it must not do is open the keyboard's microphone while DictusApp is
/// recording the same words: the capture's audio session interrupts the app's engine
/// (device, 2026-11-23 12:55:37: `earlyCapture started=true lastPongAgeMs=60810`, the
/// app claimed the session, then `audioInterruptionBegan` in the app and nobody
/// recorded). So the keyboard asks again at the tap: it posts `inKeyboardPing` beside
/// the start post and waits `tapPingWindow`. A running app answers both (the pong and
/// the session claim) within that window; only a silent app gets the capture. A pong
/// from before the tap says nothing about this tap, in either direction (device,
/// 10:32:01: a pong from when the keyboard appeared, then the app was killed).
public enum InKeyboardEarlyCapture {

    /// How long the keyboard waits for the app's answer to the ping sent at the tap
    /// before it opens its own microphone. A running app answers a Darwin ping in a few
    /// milliseconds (`pongAtTapMs` in the log); the rest of the 500 ms wait is untouched.
    public static let tapPingWindow: TimeInterval = 0.12

    public enum Resolution: String, Equatable, Sendable {
        /// The keyboard dictates: the buffer is the start of the dictation.
        case keep
        /// DictusApp records, or the keyboard falls back to opening it: discard.
        case drop
    }

    /// Whether the app answered the ping sent at this tap. Only a pong received at or
    /// after `pingSentAt` counts: an older one is about an earlier moment of the app.
    public static func appAnsweredTapPing(pingSentAt: Date, lastPong: Date?) -> Bool {
        guard let lastPong else { return false }
        return lastPong >= pingSentAt
    }

    /// Open the keyboard's microphone at the end of `tapPingWindow` only when the keyboard
    /// could take the tap, the app did not answer this tap's ping, and the app has not
    /// claimed the session.
    public static func shouldStartCapture(mayTakeColdTap: Bool, appAnsweredTapPing: Bool,
                                          sessionOwner: DictationSessionClaim.Owner?) -> Bool {
        mayTakeColdTap && !appAnsweredTapPing && sessionOwner != .app
    }

    /// What the route decision does with an early capture. Kept only when the keyboard
    /// dictates and the app does not own the session.
    public static func resolve(route: InKeyboardDictationRoute,
                               claimOwner: DictationSessionClaim.Owner?) -> Resolution {
        guard route == .inKeyboard, claimOwner != .app else { return .drop }
        return .keep
    }
}
