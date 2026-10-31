// DictusCore/Sources/DictusCore/KeyboardOnboardingGate.swift
import Foundation

/// Whether a keyboard action may go ahead while onboarding may not be finished (#827).
///
/// WHY this exists. Before #827 the keyboard never read `hasCompletedOnboarding`, so a
/// mic tap from a host app before setup ran a whole dictation hand-off with no model
/// behind it: DictusApp recorded, failed with "No model downloaded", and still sent the
/// user back to the host app; the long-press menu's Dictus Pro row raised the paywall
/// on top of onboarding. The product rule is the simple one: until onboarding is done,
/// the keyboard opens Dictus and leaves the user there.
///
/// Two cases are let through even before onboarding is done, because onboarding itself
/// needs them: its test dictation step types into a field inside DictusApp with the
/// Dictus keyboard. The keyboard knows it is in Dictus either because the host resolved
/// to Dictus's own bundle identifier, or — when host resolution misses, which it can —
/// because DictusApp last reported itself active.
///
/// Pure on purpose: the keyboard extension has no test bundle, so the decision lives
/// here where every combination is tested, and the extension only reads the inputs.
public enum KeyboardOnboardingGate {

    /// What the gate decided, and why. The raw value goes on the keyboard's log line.
    public enum Decision: String, Equatable, Sendable {
        /// Onboarding is done: everything behaves exactly as before #827.
        case onboardingComplete
        /// The keyboard is typing into DictusApp itself (the onboarding test dictation).
        case hostIsDictus
        /// DictusApp is in the foreground, so the keyboard is serving it.
        case appActive
        /// Onboarding is not done and the keyboard serves another app: open Dictus only.
        case openOnboarding

        /// Whether the keyboard may run the action it was asked for.
        public var allowsAction: Bool { self != .openOnboarding }
    }

    /// DictusApp's bundle identifier, as host resolution reports it when the keyboard's
    /// host is a text field inside the app.
    public static let dictusHostId = "com.pivi.dictus"

    /// The decision for one keyboard action.
    ///
    /// - Parameters:
    ///   - onboardingCompleted: `SharedKeys.hasCompletedOnboarding`, read through
    ///     `isOnboardingCompleted(in:)` so a missing key reads false.
    ///   - hostId: the host resolved at the tap, nil when resolution failed.
    ///   - appPhase: DictusApp's last published phase, `.unknown` when none is stored.
    public static func decide(
        onboardingCompleted: Bool,
        hostId: String?,
        appPhase: AppScenePhaseMarker
    ) -> Decision {
        if onboardingCompleted { return .onboardingComplete }
        if hostId == dictusHostId { return .hostIsDictus }
        if appPhase == .active { return .appActive }
        return .openOnboarding
    }

    /// Whether onboarding is done, as the App Group says.
    ///
    /// A missing key reads **false**, the same default DictusApp's own `@AppStorage`
    /// uses to decide whether to show onboarding. That is safe for existing users: the
    /// key has been written to this App Group suite, under this name, by every version
    /// since the onboarding flow first shipped, so an install that finished onboarding
    /// always holds `true`. A missing key is a new install, or one whose onboarding was
    /// never finished, and the app shows onboarding to both — the keyboard agreeing
    /// with it is the point. A stored value of another type also reads false, for the
    /// same reason the app would.
    public static func isOnboardingCompleted(in defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.object(forKey: SharedKeys.hasCompletedOnboarding) as? Bool ?? false
    }

    /// The screen a keyboard `dictus://open` request may ask for.
    ///
    /// Before onboarding is done, `.pro` becomes `.settings`, which has no route of its
    /// own: the app comes forward and onboarding stays on screen. Every other intent is
    /// unchanged, and nothing changes once onboarding is done.
    public static func openIntent(
        _ intent: KeyboardOpenIntent,
        onboardingCompleted: Bool
    ) -> KeyboardOpenIntent {
        guard !onboardingCompleted, intent == .pro else { return intent }
        return .settings
    }

    /// Whether DictusApp may start a dictation the keyboard asked for over the Darwin
    /// notification. App-side safety net for a keyboard built before #827, or one that
    /// read a stale phase: refused only when onboarding is not done and the app is not
    /// in the foreground, which is the onboarding test dictation's one requirement.
    public static func appMayStartKeyboardDictation(onboardingCompleted: Bool, appIsActive: Bool) -> Bool {
        onboardingCompleted || appIsActive
    }

    /// What DictusApp does with a `dictus://dictate` URL.
    public enum DictateURLRoute: Equatable, Sendable {
        /// The keyboard asks for a model warm-up only (#262): no recording.
        case prepare
        /// Onboarding is not done and the keyboard serves another app: stay on onboarding.
        case stayOnOnboarding
        /// Record.
        case dictate
    }

    /// The route for one `dictus://dictate` URL.
    ///
    /// WHY `prepare` COMES FIRST (#868): it records nothing and has no model to fail on, so
    /// the #827 rule (no dictation, no error before onboarding) has nothing to refuse there.
    /// With the guard in front, a process that read the onboarding flag wrong also refused
    /// the warm-up the keyboard asked for, and every later tap asked again.
    ///
    /// WHY A HOST OF DICTUS GOES THROUGH: it is the onboarding test dictation, which the
    /// keyboard sends by URL when the app's audio engine is not running. Same rule as
    /// `decide(onboardingCompleted:hostId:appPhase:)`.
    ///
    /// - Parameters:
    ///   - intent: `KeyboardDictationURL.intent(from:)`, nil for a URL that is not the
    ///     keyboard's (the widget's).
    ///   - hostId: `KeyboardDictationURL.hostId(from:)`.
    ///   - onboardingCompleted: the flag as the app last read it.
    public static func dictateURLRoute(
        intent: KeyboardDictationIntent?,
        hostId: String?,
        onboardingCompleted: Bool
    ) -> DictateURLRoute {
        if intent == .prepare { return .prepare }
        if onboardingCompleted || hostId == dictusHostId { return .dictate }
        return .stayOnOnboarding
    }
}
