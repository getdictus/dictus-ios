// DictusCore/Sources/DictusCore/HostForegroundDebt.swift
// Whether a keyboard dictation took the foreground away from the host app, and
// therefore owes it back (#23, #567).
// Testable in isolation -- no UIKit, no UserDefaults, no audio engine.

import Foundation

/// The foreground DictusApp took from the app the user was typing in.
///
/// WHY this exists (issue #567): the app decided the swipe-back overlay and the
/// auto-return from two *different* expressions of the same idea. The overlay fired on
/// `isColdStart || isEngineDeadRestart` and the return on `isColdStart` alone, and those
/// two flags are mutually exclusive by construction — so every engine-dead restart got
/// the overlay and was structurally excluded from the return. The user was dropped into
/// Dictus with no way back but a manual swipe, on the path *every* dictation takes after
/// ten idle minutes: `releaseWarmState` (#106) stops the engine, which is exactly what
/// makes the next keyboard tap an engine-dead restart. The first dictation of a session
/// is the one that lost the return.
///
/// The fix is this type rather than a second `||`: **one named condition, consumed by
/// both gates**, so a later change to one cannot silently desynchronise them again.
///
/// WHY it is named for the debt and not for the mechanism: what the two live cases share
/// is not how the app woke up, it is that the user lost their host app and is owed it
/// back. `isColdStart` and `isEngineDead` describe causes; `owesReturnToHost` describes
/// the obligation, and the obligation is what both gates are actually asking about.
///
/// WHY it lives in DictusCore: the decision is three booleans in, one case out, while its
/// caller is a SwiftUI `App` that reads a live `AVAudioEngine` through
/// `DictationCoordinator.shared` and can only run on a device. Same argument, and the
/// same shape, as `ColdStartResolutionPolicy` and `IdleReleasePolicy`.
public enum HostForegroundDebt: Equatable, Sendable, CaseIterable {

    /// The app was not in memory: the keyboard's URL launched it from nothing. The user
    /// was looking at their host app one moment and at Dictus the next.
    case coldStart

    /// The app was already in memory, but its audio engine was not running — after the
    /// ten-minute idle release (#106), or after the Dynamic Island's Power button. iOS
    /// will not start an audio engine from the background, so the dictation had to come
    /// through the URL fallback and take the foreground, exactly as a cold start does.
    case engineDead

    /// Nothing is owed. Either the URL is not a keyboard hand-off at all — the widget's
    /// `dictus://dictate` carries no `source=keyboard` and its dictation belongs in the
    /// app — or the app was genuinely warm, engine running, and never took the foreground
    /// away. Returning here would yank a user who is deliberately looking at Dictus.
    case nothingOwed

    /// **The condition both gates consume.** True when the app is on screen only because
    /// the keyboard had to bring it there, which is the same fact that raises
    /// `SwipeBackOverlayView` and the same fact that owes an auto-return.
    public var owesReturnToHost: Bool { self != .nothingOwed }

    /// The `context=` field of the `coldStartFlagSet` log line.
    ///
    /// The two live strings are the ones device captures are grepped for — `first launch`
    /// and `engine dead` — and they predate this type. Renaming them would silently
    /// invalidate every capture protocol written against them, so they are kept verbatim.
    public var logContext: String {
        switch self {
        case .coldStart: return "first launch"
        case .engineDead: return "engine dead"
        case .nothingOwed: return "warm"
        }
    }

    /// Reads the three facts available when the `dictus://dictate` URL arrives.
    ///
    /// - Parameters:
    ///   - isFromKeyboard: the URL carries `source=keyboard`, i.e. a keyboard extension
    ///     asked for this dictation. A widget-launched one never owes anything.
    ///   - hasBeenActive: this process has already been foreground at least once. False
    ///     means the URL is what launched it.
    ///   - isEngineRunning: the audio engine is live right now.
    ///
    /// WHY `hasBeenActive` is read before `isEngineRunning`: a cold start has no engine
    /// to ask about, and the two cases must stay mutually exclusive — which is now the
    /// enum's job rather than a coincidence between two `&&` chains.
    public static func resolve(
        isFromKeyboard: Bool,
        hasBeenActive: Bool,
        isEngineRunning: Bool
    ) -> HostForegroundDebt {
        guard isFromKeyboard else { return .nothingOwed }
        guard hasBeenActive else { return .coldStart }
        return isEngineRunning ? .nothingOwed : .engineDead
    }
}
