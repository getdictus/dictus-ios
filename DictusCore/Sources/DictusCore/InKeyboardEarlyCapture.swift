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
/// recording the same words. So it starts only when the app did not answer the
/// keyboard's last ping (sent when the keyboard appeared), and the decision drops the
/// buffer whenever the app ends up owning the session.
public enum InKeyboardEarlyCapture {

    /// How long a pong from DictusApp vouches for it being alive.
    public static let pongFreshness: TimeInterval = 30

    public enum Resolution: String, Equatable, Sendable {
        /// The keyboard dictates: the buffer is the start of the dictation.
        case keep
        /// DictusApp records, or the keyboard falls back to opening it: discard.
        case drop
    }

    /// Whether the app answered a ping recently enough to be trusted to answer the start.
    public static func appAnsweredRecently(lastPong: Date?, now: Date) -> Bool {
        guard let lastPong else { return false }
        let age = now.timeIntervalSince(lastPong)
        return age >= 0 && age <= pongFreshness
    }

    /// Start capturing at the tap only when the keyboard could take the tap and the app
    /// is not known to be running.
    public static func shouldStartAtTap(mayTakeColdTap: Bool, appAnsweredRecently: Bool) -> Bool {
        mayTakeColdTap && !appAnsweredRecently
    }

    /// What the route decision does with an early capture. Kept only when the keyboard
    /// dictates and the app does not own the session.
    public static func resolve(route: InKeyboardDictationRoute,
                               claimOwner: DictationSessionClaim.Owner?) -> Resolution {
        guard route == .inKeyboard, claimOwner != .app else { return .drop }
        return .keep
    }
}
