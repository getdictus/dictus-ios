// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteSpeechAssetPlan.swift
// Which Apple speech model the app reserves for shared voice notes, and when (#1056).
import Foundation

/// Whether the app reserves and installs Apple's on-device speech model for voice notes,
/// and for which language.
///
/// WHY the app reserves it ahead of time: the share extension will transcribe a voice
/// note with Apple's `SpeechTranscriber` when the app is closed (#1056), and it must find
/// the model already on the device. A download is a long, network-bound job that belongs
/// to the app, never to a share sheet. The download comes from Apple; transcription never
/// leaves the device.
///
/// The rule, as a pure function so every branch is tested:
/// - only for users who can use voice notes (`VoiceNoteAvailability.isEntitled`): voice
///   notes are Pro, and a model nobody can use is a download for nothing;
/// - iOS 26 or later, with `SpeechTranscriber` available on this iPhone;
/// - the voice-note language when the user fixed one, the keyboard language under
///   automatic detection (Pierre, 2026-11-25: Apple's recognizer takes one language);
/// - that language listed in `SpeechTranscriber.supportedLocales`.
public enum VoiceNoteSpeechAssetPlan: Equatable, Sendable {
    /// Reserve and install the model for this language.
    case reserve(languageCode: String, source: LanguageSource)
    /// Nothing to reserve.
    case skip(SkipReason)

    /// Where the language comes from, for the log.
    public enum LanguageSource: String, Equatable, Sendable {
        /// The user fixed a voice-note language.
        case voiceNoteLanguage
        /// Voice notes detect the language: the keyboard (dictation) language stands in.
        case dictationLanguage
    }

    public enum SkipReason: Equatable, Sendable {
        /// No Pro, or voice notes switched off in the Dictus Pro hub.
        case notEntitled
        /// Older than iOS 26.
        case systemTooOld
        /// iOS 26 or later, but `SpeechTranscriber.isAvailable` is false (older iPhones,
        /// every iOS Simulator).
        case speechTranscriberUnavailable
        /// Apple does not list the language.
        case languageNotCovered(String)
    }

    /// The language a voice note would be handed to Apple's recognizer in. Needs no
    /// system call, so the app can tell a language change apart cheaply.
    public static func requestedLanguage(voiceNoteLanguage: VoiceNoteLanguage,
                                         keyboardLanguage: SupportedLanguage) -> (code: String, source: LanguageSource) {
        switch voiceNoteLanguage {
        case .fixed(let language): return (language.rawValue, .voiceNoteLanguage)
        case .autoDetect: return (keyboardLanguage.rawValue, .dictationLanguage)
        }
    }

    /// What the device says about Apple's recognizer.
    public struct System: Equatable, Sendable {
        /// The running iOS major version.
        public var majorVersion: Int
        /// `SpeechTranscriber.isAvailable`, false before iOS 26.
        public var speechTranscriberAvailable: Bool
        /// `SpeechTranscriber.supportedLocales`, BCP 47 identifiers.
        public var supportedLocales: [String]

        public init(majorVersion: Int, speechTranscriberAvailable: Bool, supportedLocales: [String]) {
            self.majorVersion = majorVersion
            self.speechTranscriberAvailable = speechTranscriberAvailable
            self.supportedLocales = supportedLocales
        }
    }

    /// - Parameter isEntitled: `VoiceNoteAvailability.isEntitled`.
    public static func evaluate(voiceNoteLanguage: VoiceNoteLanguage,
                                keyboardLanguage: SupportedLanguage,
                                isEntitled: Bool,
                                system: System) -> VoiceNoteSpeechAssetPlan {
        guard isEntitled else { return .skip(.notEntitled) }
        guard system.majorVersion >= AppleEngineAvailability.minimumSystemMajorVersion else {
            return .skip(.systemTooOld)
        }
        guard system.speechTranscriberAvailable else { return .skip(.speechTranscriberUnavailable) }
        let requested = requestedLanguage(voiceNoteLanguage: voiceNoteLanguage, keyboardLanguage: keyboardLanguage)
        guard AppleSpeechLanguage.isLanguageCovered(requested.code, bySupportedLocales: system.supportedLocales) else {
            return .skip(.languageNotCovered(requested.code))
        }
        return .reserve(languageCode: requested.code, source: requested.source)
    }
}

/// When the app runs `VoiceNoteSpeechAssetPlan`: once at launch, then only when what it
/// depends on moved.
///
/// The app asks at several points (launch, each activation, the voice-note and keyboard
/// language pickers), because the keyboard language can change in another process (the
/// keyboard's own language switch). An unchanged language costs nothing: no
/// `AssetInventory` call, no log line.
public struct VoiceNoteSpeechAssetTrigger: Equatable, Sendable {
    public enum Reason: String, Equatable, Sendable {
        /// First check of this process.
        case launch
        /// The voice-note language, or the keyboard language standing in for it, changed.
        case languageChanged
        /// The user became able to use voice notes (Pro started, or the switch turned on).
        case entitlementChanged
    }

    /// What the plan depends on that the app can read without a system call.
    public struct Inputs: Equatable, Sendable {
        public var languageCode: String
        public var isEntitled: Bool

        public init(languageCode: String, isEntitled: Bool) {
            self.languageCode = languageCode
            self.isEntitled = isEntitled
        }
    }

    public private(set) var lastInputs: Inputs?

    public init() {}

    /// Why the plan should run now, or nil when nothing it depends on changed. Losing the
    /// entitlement is not a reason: a model already reserved is left alone.
    public mutating func reason(for inputs: Inputs) -> Reason? {
        defer { lastInputs = inputs }
        guard let last = lastInputs else { return .launch }
        if last.languageCode != inputs.languageCode { return .languageChanged }
        if !last.isEntitled && inputs.isEntitled { return .entitlementChanged }
        return nil
    }
}
