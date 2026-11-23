// DictusCore/DictationStartTable.swift
// Who records a keyboard mic tap, in every start case (#992, device round 2, 2026-11-23).
import Foundation

/// What DictusApp answers a keyboard's start: record it, or say it cannot.
///
/// WHY it exists (device, 2026-11-23 13:38:56, log 200): the app was alive in the
/// background while its model compiled, its engine stopped. It claimed the keyboard's
/// session (`sessionClaim side=app mayStart=true`), then found it could not record
/// (`dictationDeferred reason=no engine running, appState=2`). The keyboard read the
/// claim, routed `appIsRecording`, skipped its URL fallback (`skipped=urlFallback`), and
/// nobody recorded: « Démarrage » for five seconds, then the watchdog. The claim said
/// "I record" before the app knew whether it could.
///
/// So the app decides first, with the same questions `startDictation` asks in the same
/// order, and only a `.record` answer claims the session or answers the keyboard's ping
/// as "I will record". A declined start leaves the session free for the keyboard.
public enum AppKeyboardStartAnswer: Equatable, Sendable {
    case record
    case decline(Reason)

    public enum Reason: String, Sendable {
        /// A dictation is already recording, transcribing or polishing.
        case busy
        /// Onboarding is not done and the app is not in front (#827).
        case beforeOnboarding
        /// The app is in the background and its engine is stopped: iOS forbids starting
        /// a recording engine from the background, only a URL can bring it forward.
        case engineNotRunning
        /// No model on the device.
        case noModel
        /// The model is loading, or its Core ML cache is cold (`RecordTapRouting`, #542):
        /// a recording now would wait minutes for its transcription.
        case modelNotReady
    }

    public var willRecord: Bool { self == .record }

    public var logValue: String {
        switch self {
        case .record: return "record"
        case .decline(let reason): return "decline-\(reason.rawValue)"
        }
    }

    /// What the app knows when the keyboard's start (or ping) arrives.
    public struct Situation: Equatable {
        public var appIsActive: Bool
        public var engineRunning: Bool
        public var dictationStatus: DictationStatus
        public var onboardingCompleted: Bool
        public var isModelDownloaded: Bool
        public var loadState: ModelLoadState
        public var isModelWarm: Bool

        public init(appIsActive: Bool, engineRunning: Bool, dictationStatus: DictationStatus, onboardingCompleted: Bool,
                    isModelDownloaded: Bool, loadState: ModelLoadState, isModelWarm: Bool) {
            self.appIsActive = appIsActive
            self.engineRunning = engineRunning
            self.dictationStatus = dictationStatus
            self.onboardingCompleted = onboardingCompleted
            self.isModelDownloaded = isModelDownloaded
            self.loadState = loadState
            self.isModelWarm = isModelWarm
        }
    }

    public static func decide(_ situation: Situation) -> AppKeyboardStartAnswer {
        guard ColdStartResolutionPolicy.canStartNewDictation(from: situation.dictationStatus) else { return .decline(.busy) }
        guard KeyboardOnboardingGate.appMayStartKeyboardDictation(onboardingCompleted: situation.onboardingCompleted,
                                                                  appIsActive: situation.appIsActive)
        else { return .decline(.beforeOnboarding) }
        guard situation.appIsActive || situation.engineRunning else { return .decline(.engineNotRunning) }
        guard situation.isModelDownloaded else { return .decline(.noModel) }
        let preparation = RecordTapRouting.decide(dictationStatus: situation.dictationStatus, isModelDownloaded: true,
                                                  loadState: situation.loadState, isModelWarm: situation.isModelWarm)
        guard preparation == .startDictation else { return .decline(.modelNotReady) }
        return .record
    }
}

/// The keyboard's side: one row per start case, the outcome, and why (#992 round 2).
///
/// Every mic tap ends in exactly one of five outcomes, decided once the app has had its
/// 500 ms. The rule is the whole table; `KeyboardState` only carries it out, and logs
/// `startRow outcome=… why=…` so the device log says, for every tap, which row it took.
///
/// | Case                                         | Who records | What the user sees |
/// |----------------------------------------------|-------------|--------------------|
/// | App not running                              | keyboard    | « En écoute » at the first sample |
/// | App running, engine warm, model ready        | app         | « En écoute » when the app records |
/// | App running, engine stopped (background)     | keyboard    | as "not running"; app opened by URL when the keyboard cannot |
/// | App running, model loading or cold cache     | keyboard    | as "not running"; preparation screen when the keyboard cannot |
/// | App suspended                                | keyboard    | as "not running" (a suspended app gets no Darwin post in time) |
/// | App killed after the keyboard appeared       | keyboard    | as "not running"; a stale pong does not count |
/// | Setting off                                  | app         | today's path: background start, else URL, else preparation |
/// | Language not covered (auto-detect, no model) | app         | as "setting off" |
/// | Microphone refused                           | nobody      | one line: turn the microphone on |
/// | Full Access off                              | app         | today's path (the toolbar shows the Full Access bar) |
///
/// Whatever the row, `DictationStartSafetyNet` opens the app by URL when no audio has
/// been captured `deadline` after the tap: « Démarrage » never ends in nothing.
public enum DictationStartTable {

    /// What DictusApp said to this tap's ping.
    public enum AppAnswer: String, Sendable {
        /// `inKeyboardPong`: running, and `AppKeyboardStartAnswer` is `.record`.
        case willRecord
        /// `inKeyboardPongDeclined`: running, but it cannot record this tap.
        case declined
        /// Nothing after the tap: not running, suspended, or answering too late.
        case silent
    }

    /// The app's answer to a ping, stamped with the moment it answered, written to the
    /// App Group before the Darwin pong.
    ///
    /// WHY a stamp and not the pong's arrival time (simulator, 2026-11-23 14:07:09 and
    /// 14:08:11): a keyboard process that iOS had suspended gets a Darwin notification
    /// when it resumes, possibly after the tap, so a pong the app sent to the keyboard's
    /// appearance ping read as the answer to the tap, from an app suspended since. Both
    /// processes read the same clock; only an answer given at or after the tap counts.
    public struct PingAnswerStamp: Equatable, Sendable {
        public let answer: AppAnswer
        public let answeredAt: Date

        public init(answer: AppAnswer, answeredAt: Date) {
            self.answer = answer
            self.answeredAt = answeredAt
        }

        public var storedValue: String { "\(answer.rawValue)|\(answeredAt.timeIntervalSince1970)" }

        public init?(storedValue: String?) {
            let parts = storedValue?.split(separator: "|")
            guard let parts, parts.count == 2, let answer = AppAnswer(rawValue: String(parts[0])),
                  let seconds = TimeInterval(String(parts[1])) else { return nil }
            self.init(answer: answer, answeredAt: Date(timeIntervalSince1970: seconds))
        }

        /// What the app said to the ping sent at `tap`: `.silent` for no answer or an
        /// answer from before it.
        public static func answer(to tap: Date?, stored: String?) -> AppAnswer {
            guard let tap, let stamp = PingAnswerStamp(storedValue: stored), stamp.answeredAt >= tap else { return .silent }
            return stamp.answer
        }
    }

    public enum Outcome: String, Sendable {
        /// DictusApp records in the background.
        case appRecords
        /// The keyboard records through its web view.
        case keyboardRecords
        /// Open DictusApp by URL to record (today's cold start).
        case openAppToRecord
        /// Open DictusApp on its preparation screen (#262, #542).
        case openAppToPrepare
        /// Say the microphone is off; nothing can record.
        case microphoneRefused
    }

    public struct Decision: Equatable, Sendable {
        public let outcome: Outcome
        /// The row, in words the log keeps.
        public let why: String

        public init(outcome: Outcome, why: String) {
            self.outcome = outcome
            self.why = why
        }

        /// The legacy route the keyboard's code already branches on.
        public var route: InKeyboardDictationRoute {
            switch outcome {
            case .appRecords: return .appIsRecording
            case .keyboardRecords: return .inKeyboard
            case .openAppToRecord, .openAppToPrepare: return .openAppURL
            case .microphoneRefused: return .microphoneDenied
            }
        }
    }

    public struct Inputs: Equatable, Sendable {
        public var settingEnabled: Bool
        public var systemMajorVersion: Int
        /// The chosen dictation language; nil under automatic detection.
        public var languageCode: String?
        /// Apple's model for that language, per `AssetInventory`; nil when unanswered.
        public var localeInstalled: Bool?
        public var hasFullAccess: Bool
        public var microphone: InKeyboardDictationRoute.MicrophonePermission
        public var appAnswer: AppAnswer
        public var sessionOwner: DictationSessionClaim.Owner?
        /// The app moved the shared status past `requested` within the wait.
        public var appMovedPastRequested: Bool
        /// `KeyboardState.preparationDeferral()` is non-nil: the Dictus model is loading
        /// or cold, so opening the app to record would wait on it.
        public var dictusModelNeedsPreparation: Bool

        public init(settingEnabled: Bool, systemMajorVersion: Int, languageCode: String?, localeInstalled: Bool?,
                    hasFullAccess: Bool, microphone: InKeyboardDictationRoute.MicrophonePermission,
                    appAnswer: AppAnswer, sessionOwner: DictationSessionClaim.Owner?,
                    appMovedPastRequested: Bool, dictusModelNeedsPreparation: Bool) {
            self.settingEnabled = settingEnabled
            self.systemMajorVersion = systemMajorVersion
            self.languageCode = languageCode
            self.localeInstalled = localeInstalled
            self.hasFullAccess = hasFullAccess
            self.microphone = microphone
            self.appAnswer = appAnswer
            self.sessionOwner = sessionOwner
            self.appMovedPastRequested = appMovedPastRequested
            self.dictusModelNeedsPreparation = dictusModelNeedsPreparation
        }
    }

    public static func decide(_ inputs: Inputs) -> Decision {
        if inputs.sessionOwner == .app { return Decision(outcome: .appRecords, why: "app-owns-session") }
        if inputs.appMovedPastRequested { return Decision(outcome: .appRecords, why: "app-status-past-requested") }
        let route = InKeyboardDictationRoute.decide(
            settingEnabled: inputs.settingEnabled,
            appAnswered: false,
            systemMajorVersion: inputs.systemMajorVersion,
            localeInstalled: inputs.languageCode == nil ? nil : inputs.localeInstalled,
            hasFullAccess: inputs.hasFullAccess,
            microphone: inputs.microphone,
            sessionOwner: inputs.sessionOwner
        )
        switch route {
        case .inKeyboard:
            return Decision(outcome: .keyboardRecords, why: inputs.appAnswer == .declined ? "app-declined" : "app-\(inputs.appAnswer.rawValue)")
        case .microphoneDenied:
            return Decision(outcome: .microphoneRefused, why: "microphone-denied")
        case .appIsRecording, .openAppURL:
            let why = keyboardCannotReason(inputs)
            return inputs.dictusModelNeedsPreparation
                ? Decision(outcome: .openAppToPrepare, why: why)
                : Decision(outcome: .openAppToRecord, why: why)
        }
    }

    /// The first reason the keyboard cannot take the tap, in `InKeyboardDictationRoute`'s order.
    static func keyboardCannotReason(_ inputs: Inputs) -> String {
        if !inputs.settingEnabled { return "setting-off" }
        if inputs.systemMajorVersion < InKeyboardDictationRoute.minimumSystemMajorVersion { return "ios-too-old" }
        if inputs.languageCode == nil { return "auto-detect" }
        if inputs.localeInstalled != true { return "locale-not-installed" }
        if !inputs.hasFullAccess { return "full-access-off" }
        if inputs.microphone == .undetermined { return "microphone-undetermined" }
        return "unknown"
    }
}

/// The start safety net (Titus and Pierre, 2026-11-23): if no audio is captured — by
/// the app or by the keyboard — `deadline` after the mic tap, the keyboard gives up
/// cleanly and opens DictusApp by URL, the path every tap took before #992.
///
/// WHY 1.5 s: over the 30 in-keyboard starts in device logs 190–200 (iPhone 15 Pro Max,
/// iOS 27.0.1), tap to first sample was 374–1240 ms, median ≈ 500 ms. The 1240 ms one
/// was a capture started at the route decision (500 ms) whose `getUserMedia` took
/// 659 ms; the worst `getUserMedia` seen was 875 ms. A warm app records within ~100 ms of
/// the tap (pong 7–89 ms, status `recording` in the same second). 1.5 s clears the worst
/// measured start by 260 ms, and is short enough that a user who sees « Démarrage » for
/// that long has not yet given up on the tap.
///
/// The net does not wait out the deadline when the keyboard's capture has already died
/// without a single sample (device, 13:39:21, `captureInterrupted reason=context-interrupted`
/// at 660 ms, `seconds=0.0 action=discard`, back to idle): that tap fires at once.
public enum DictationStartSafetyNet {

    public static let deadline: TimeInterval = 1.5

    public enum Verdict: Equatable, Sendable {
        /// Nothing captured yet, deadline not reached.
        case keepWaiting
        /// The tap is served or left the keyboard: the net is not needed.
        case standDown(String)
        /// Open the app by URL now.
        case fire(String)

        public var logFields: String {
            switch self {
            case .keepWaiting: return "fired=false reason=waiting"
            case .standDown(let reason): return "fired=false reason=\(reason)"
            case .fire(let reason): return "fired=true reason=\(reason)"
            }
        }
    }

    public struct Reading: Equatable, Sendable {
        /// Seconds since the tap.
        public var elapsed: TimeInterval
        /// The keyboard's capture delivered at least one sample.
        public var keyboardHasAudio: Bool
        /// The app reported `recording` (or later) for this tap, the keyboard not dictating.
        public var appIsRecording: Bool
        /// The tap already left the keyboard: the app opened by URL or on its preparation
        /// screen, a message shown, or the user cancelled (status back to idle).
        public var tapEnded: Bool
        /// The keyboard's capture ended (interrupted, failed) before the dictation began:
        /// no sample, or less than `InKeyboardInterruptionPolicy.minimumSeconds` of them.
        public var captureEndedWithoutAudio: Bool

        public init(elapsed: TimeInterval, keyboardHasAudio: Bool, appIsRecording: Bool, tapEnded: Bool,
                    captureEndedWithoutAudio: Bool) {
            self.elapsed = elapsed
            self.keyboardHasAudio = keyboardHasAudio
            self.appIsRecording = appIsRecording
            self.tapEnded = tapEnded
            self.captureEndedWithoutAudio = captureEndedWithoutAudio
        }
    }

    public static func evaluate(_ reading: Reading) -> Verdict {
        // First: a capture that ended before the dictation began fired even if it
        // delivered a few samples, or the overlay would stay on a dead capture.
        if reading.captureEndedWithoutAudio { return .fire("capture-ended-without-audio") }
        if reading.keyboardHasAudio { return .standDown("keyboard-audio") }
        if reading.appIsRecording { return .standDown("app-recording") }
        if reading.tapEnded { return .standDown("tap-ended") }
        return reading.elapsed >= deadline ? .fire("no-audio-by-deadline") : .keepWaiting
    }
}
