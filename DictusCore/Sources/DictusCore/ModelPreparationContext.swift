import Foundation

/// The user-facing flow that caused model preparation to be shown.
///
/// The same preparation overlay is reused by onboarding, model selection, the
/// keyboard cold-start handoff, and an in-app record tap that landed during a load.
/// Keeping the context explicit lets each flow explain what is happening without
/// duplicating the loading UI.
public enum ModelPreparationContext: String, Codable, CaseIterable, Sendable {
    case onboarding
    case modelSelection
    case keyboardColdStart

    /// A record button *inside Dictus* was tapped while a model load was in flight (#484).
    ///
    /// Before this case the tap was refused in silence by `startDictation`'s load guard —
    /// twelve taps in eleven seconds, no overlay, no message, no disabled state — because
    /// the guard's only route out was the keyboard's, and the keyboard is not where this
    /// user is. It is `.keyboardColdStart`'s in-app twin and shares its one hard rule
    /// (`isPrepareOnly`), but not its assumption that the user came from somewhere else.
    case appRecordTap

    /// Whether this preparation must never turn into a recording by itself.
    ///
    /// Both prepare-only contexts are reached from a *tap the user has already made*, and a
    /// Turbo compile can take three and a half minutes (#432). Starting the microphone at
    /// the end of a wait that long acts on an intent that has almost certainly expired, and
    /// on a phone that may well be back in a pocket. The user taps again; nothing is queued.
    ///
    /// WHY a switch and not `self == …`: a fifth context must be forced to answer this
    /// question rather than inherit `false` from the shape of an equality test.
    public var isPrepareOnly: Bool {
        switch self {
        case .onboarding, .modelSelection:
            return false
        case .keyboardColdStart, .appRecordTap:
            return true
        }
    }

    /// Whether the user reached this screen from *outside* Dictus.
    ///
    /// WHY THIS IS A SECOND BOOLEAN AND NOT `isPrepareOnly` (#484): the flag above used to
    /// carry both "do not start recording by itself" and "you came here from another app",
    /// which held only as long as the keyboard was the sole prepare-only entry point. The
    /// two questions have different answers for `.appRecordTap`, and it is *this* one that
    /// decides the completion sentence — "return to your app" is false for someone who never
    /// left it — and which of the two waiting notices is shown. Staying in the foreground is
    /// what keeps a compile off the system's background throttle (#472), so the in-app case
    /// asks the user to stay on the page rather than merely to wait.
    public var startedFromAnotherApp: Bool {
        switch self {
        case .keyboardColdStart:
            return true
        case .onboarding, .modelSelection, .appRecordTap:
            return false
        }
    }

}

/// How a preparation ends, for the screen that is watching it (issue #428).
///
/// This type used to time an escape hatch as well. The escape was cut from #428 after
/// four review passes put every serious finding in it or in something it forced; what
/// remains is the part that has nothing to do with the user leaving the screen, and
/// everything to do with the screen telling the truth about how a load finished.
public enum ModelPreparationOutcome {

    /// The launch preload's deadline expired. Written by `runLaunchPreload`.
    public static let deadlineExpiredReason = "init-preload-deadline"

    public static let gaveUpReasons: Set<String> = [deadlineExpiredReason]

    /// Whether a load-state reason means the app gave up rather than finished.
    public static func reasonMeansGaveUp(_ reason: String) -> Bool {
        gaveUpReasons.contains(reason)
    }

    /// Whether a preparation may run its completion state without ever having seen work
    /// happen — the checkmark, then the dismissal — because the model is already loaded.
    ///
    /// WHY THIS IS NOT JUST "the load state says ready" (issue #579): `modelLoadState`
    /// lives in the App Group, so it outlives the process that wrote it. A launch from
    /// dead reads its predecessor's verdict, and on a keyboard cold start that verdict is
    /// `ready` about RAM this process does not have. Measured on device 2026-09-17: the
    /// screen celebrated and dismissed two seconds into a twenty-second load, and the user
    /// went back to a keyboard that still refused them.
    ///
    /// `loadStateIsFromThisLaunch` is the whole fix. It is false until a live process in
    /// this launch publishes a load state, which is what makes the value evidence rather
    /// than a leftover. The launch preload publishes `.loading` within the first turns of
    /// every launch that has a model, so the window this closes is exactly the one where
    /// nothing in this process has spoken yet.
    ///
    /// WHY NOT THE CONTEXT TEST THE ISSUE PROPOSED, which was to exclude
    /// `.keyboardColdStart` outright: the keyboard never *asks* for preparation about a
    /// model it believes is loaded, but the app answers later than the keyboard asked —
    /// a URL open and an app activation later. A load that lands in that window writes
    /// `.ready` from a live process, and that value is a fact. Excluding the context
    /// would leave the screen up with nothing left to dismiss it, and this screen
    /// replaces the tab bar rather than covering it (issue #428). Freshness refuses the
    /// stale value and keeps the honest one, which is what the issue's second acceptance
    /// criterion asks for in those words.
    ///
    /// WHY IT STAYS `isPrepareOnly`: onboarding and model selection present this screen
    /// *before* their own work starts, so a `.ready` read at that moment is about the
    /// model they are replacing. They have `hasSeenWorkPhase` for that, and they keep it.
    ///
    /// - Parameters:
    ///   - context: the flow that raised the preparation screen.
    ///   - isModelOnDisk: whether the model's files are installed — `ModelState.ready`,
    ///     which is a statement about the filesystem and never about RAM.
    ///   - loadState: `SharedKeys.modelLoadState`, as this process currently reads it.
    ///   - loadStateIsFromThisLaunch: whether a live process in this launch wrote that
    ///     value, rather than it being the App Group's memory of a process that is gone.
    public static func preparationWasAlreadyReady(
        context: ModelPreparationContext,
        isModelOnDisk: Bool,
        loadState: ModelLoadState,
        loadStateIsFromThisLaunch: Bool
    ) -> Bool {
        context.isPrepareOnly
            && loadStateIsFromThisLaunch
            && isModelOnDisk
            && loadState == .ready
    }
}
