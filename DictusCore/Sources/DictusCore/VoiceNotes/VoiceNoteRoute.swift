// DictusCore/VoiceNotes/VoiceNoteRoute.swift
// Who transcribes a shared voice note: the app, the share extension, or nobody yet (#1056).
import Foundation

/// Who transcribes a shared voice note (#1056, voice notes with the app closed).
///
/// The share extension drops the note in the App Group inbox and waits 1.5 s for DictusApp
/// to take it. A running app takes it and transcribes it with the model the user chose,
/// as before, even when that model is still compiling (Pierre, 2026-11-25: the app waits,
/// as today). When nothing takes it, the extension used to open Dictus on the note. It now
/// transcribes the file itself with Apple's on-device model (`SpeechTranscriber`) when the
/// device can, and opens Dictus as before when it cannot.
///
/// The rule, in order (each step is a reason the log names):
/// 1. the app took the note → the app;
/// 2. iOS older than 26, no `SpeechTranscriber`, or a language Apple does not list →
///    today's route;
/// 3. Apple's model for that language not installed on the device → today's route;
/// 4. a note longer than `extensionCap` → today's route, with its own sentence;
/// 5. otherwise → the extension.
///
/// The language is the one the app reserves Apple's model for (`VoiceNoteSpeechAssetPlan`,
/// #1069): the voice-note language when the user fixed one, the dictation (keyboard)
/// language under automatic detection, the default. Apple's recognizer takes one language
/// and does not detect; the sheet says which language it used.
///
/// Pure, so every branch is tested. The model check (step 3) is the only one that needs an
/// `AssetInventory` call: the caller decides once with `modelInstalled: nil`, and asks the
/// recognizer only when the answer is `.openApp(.modelNotInstalled)`.
public enum VoiceNoteRoute: Equatable, Sendable {
    /// DictusApp took the note: today's path, unchanged.
    case appTookIt
    /// Nobody took it and the device can transcribe it on its own: the extension does.
    case shareExtension(languageCode: String, source: VoiceNoteSpeechAssetPlan.LanguageSource)
    /// Nobody took it and the extension does not transcribe it: open Dictus, as before.
    case openApp(OpenAppReason)

    public enum OpenAppReason: Equatable, Sendable {
        case systemTooOld
        case speechTranscriberUnavailable
        case languageNotCovered(String)
        /// Apple lists the language, but its model is not on this device (or was not
        /// asked yet: `modelInstalled == nil`).
        case modelNotInstalled(String)
        /// Longer than `extensionCap`. The only reason the sheet words differently.
        case overExtensionCap(seconds: Int)

        /// Short name for the log.
        public var logName: String {
            switch self {
            case .systemTooOld: return "systemTooOld"
            case .speechTranscriberUnavailable: return "speechTranscriberUnavailable"
            case .languageNotCovered(let code): return "languageNotCovered(\(code))"
            case .modelNotInstalled(let code): return "modelNotInstalled(\(code))"
            case .overExtensionCap(let seconds): return "overExtensionCap(\(seconds)s)"
            }
        }
    }

    /// The longest note the extension transcribes: 5 minutes (Pierre, 2026-11-25), until
    /// the extension's memory is measured on an iPhone. Measured on the simulator in #992:
    /// 5 min 18 s peaked at 80.7 MB in the extension; decoded audio costs about 10 MB a
    /// minute, and a share extension's limit on an iPhone is assumed near 120 MB, not
    /// measured. Longer notes take today's route: the app transcribes them, up to
    /// `SharedAudioDecoder.maximumDuration`.
    public static let extensionCap: TimeInterval = 5 * 60

    /// Whether a note of `seconds` is over `extensionCap`. Same tolerance as the app's
    /// 10-minute cap (`SharedAudioDecoder.exceedsCap`): a 5:00.4 note is a 5-minute note.
    public static func exceedsExtensionCap(_ seconds: TimeInterval) -> Bool {
        SharedAudioDecoder.exceedsCap(seconds, maximum: extensionCap)
    }

    /// What the route reads.
    public struct Inputs: Equatable, Sendable {
        /// DictusApp moved every drop out of the inbox within the wait.
        public var appTookIt: Bool
        /// What the device says about `SpeechTranscriber`.
        public var system: VoiceNoteSpeechAssetPlan.System
        public var voiceNoteLanguage: VoiceNoteLanguage
        public var keyboardLanguage: SupportedLanguage
        /// Whether Apple's model for the language is on the device; nil when not asked yet.
        public var modelInstalled: Bool?
        /// The longest duration the containers stated, nil when none did. A note with no
        /// stated length is checked again after decoding, which the decoder caps at
        /// `extensionCap`.
        public var longestKnownSeconds: TimeInterval?

        public init(appTookIt: Bool, system: VoiceNoteSpeechAssetPlan.System,
                    voiceNoteLanguage: VoiceNoteLanguage, keyboardLanguage: SupportedLanguage,
                    modelInstalled: Bool?, longestKnownSeconds: TimeInterval?) {
            self.appTookIt = appTookIt
            self.system = system
            self.voiceNoteLanguage = voiceNoteLanguage
            self.keyboardLanguage = keyboardLanguage
            self.modelInstalled = modelInstalled
            self.longestKnownSeconds = longestKnownSeconds
        }
    }

    public static func decide(_ inputs: Inputs) -> VoiceNoteRoute {
        let appTookIt = inputs.appTookIt, modelInstalled = inputs.modelInstalled
        if appTookIt { return .appTookIt }
        // The app's own reservation rule, minus the entitlement: the share sheet only gets
        // here once `VoiceNoteAvailability.shareDecision` accepted the note.
        let plan = VoiceNoteSpeechAssetPlan.evaluate(
            voiceNoteLanguage: inputs.voiceNoteLanguage,
            keyboardLanguage: inputs.keyboardLanguage,
            isEntitled: true,
            system: inputs.system
        )
        switch plan {
        case .skip(.notEntitled):
            // Unreachable with `isEntitled: true`; kept total rather than trapping.
            return .openApp(.speechTranscriberUnavailable)
        case .skip(.systemTooOld):
            return .openApp(.systemTooOld)
        case .skip(.speechTranscriberUnavailable):
            return .openApp(.speechTranscriberUnavailable)
        case .skip(.languageNotCovered(let code)):
            return .openApp(.languageNotCovered(code))
        case .reserve(let code, let source):
            guard modelInstalled == true else { return .openApp(.modelNotInstalled(code)) }
            if let seconds = inputs.longestKnownSeconds, exceedsExtensionCap(seconds) {
                return .openApp(.overExtensionCap(seconds: Int(seconds.rounded())))
            }
            return .shareExtension(languageCode: code, source: source)
        }
    }

    /// Short name for the log.
    public var logName: String {
        switch self {
        case .appTookIt: return "appTookIt"
        case .shareExtension: return "shareExtension"
        case .openApp: return "openApp"
        }
    }
}

/// What the share extension produced for a note it transcribed itself, left in the App
/// Group for DictusApp. The app adopts it, completing the note in its queue and running
/// what only it runs (the card, the Smart Mode), instead of transcribing again.
///
/// The extension writes it before it reports success: a note whose result could not be
/// written is released to the app, which transcribes it as before (#992 review).
public struct VoiceNoteExtensionResult: Codable, Equatable, Sendable {
    public let id: UUID
    public let transcript: String
    /// `TranscriptionRecord.language`.
    public let language: String
    public let durationSeconds: Int
    public let savedToHistory: Bool
    public let engine: String
    public let transcribedAt: Date
    /// `TranscriptionRecord.languageWasAssumed` (#1084). Nil in every result written
    /// before it, and when the user fixed the voice-note language.
    public let languageWasAssumed: Bool?

    public init(id: UUID, transcript: String, language: String, durationSeconds: Int,
                savedToHistory: Bool, engine: String, transcribedAt: Date = Date(),
                languageWasAssumed: Bool = false) {
        self.id = id
        self.transcript = transcript
        self.language = language
        self.durationSeconds = durationSeconds
        self.savedToHistory = savedToHistory
        self.engine = engine
        self.transcribedAt = transcribedAt
        self.languageWasAssumed = languageWasAssumed ? true : nil
    }

    static func directory(in storage: VoiceNoteStorage) -> URL {
        storage.root.appendingPathComponent("ExtensionResults", isDirectory: true)
    }

    static func file(for id: UUID, in storage: VoiceNoteStorage) -> URL {
        directory(in: storage).appendingPathComponent("\(id.uuidString).json")
    }

    public func write(to storage: VoiceNoteStorage) throws {
        try FileManager.default.createDirectory(at: Self.directory(in: storage), withIntermediateDirectories: true)
        try JSONEncoder.voiceNotes.encode(self).write(to: Self.file(for: id, in: storage), options: .atomic)
    }

    public static func read(_ id: UUID, from storage: VoiceNoteStorage) -> VoiceNoteExtensionResult? {
        guard let data = try? Data(contentsOf: file(for: id, in: storage)) else { return nil }
        return try? JSONDecoder.voiceNotes.decode(VoiceNoteExtensionResult.self, from: data)
    }

    public static func remove(_ id: UUID, from storage: VoiceNoteStorage) {
        try? FileManager.default.removeItem(at: file(for: id, in: storage))
    }
}
