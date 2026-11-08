// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteSettings.swift
// The defaults a shared voice note is transcribed with, since nobody is asked (#620).
import Foundation

/// The language a shared voice note is transcribed in.
public enum VoiceNoteLanguage: Equatable, Hashable, Sendable {
    /// Whatever the engine hears. The default: a voice note is someone else
    /// speaking, and the decision accepts that a French user who receives an English
    /// note gets an English transcript.
    case autoDetect
    /// One language, always.
    case fixed(SupportedLanguage)

    static let autoStoredValue = "auto"

    /// Unknown and absent values read as `.autoDetect`, which is also the default.
    init(storedValue: String?) {
        if let raw = storedValue, let language = SupportedLanguage(rawValue: raw) {
            self = .fixed(language)
        } else {
            self = .autoDetect
        }
    }

    var storedValue: String {
        switch self {
        case .autoDetect: return Self.autoStoredValue
        case .fixed(let language): return language.rawValue
        }
    }

    /// As the dictation pipeline's mode. Never `.followKeyboard`: the keyboard
    /// language is what the user *types*, and it says nothing about what language
    /// somebody else spoke in a message to them.
    public var transcriptionMode: TranscriptionLanguageMode {
        switch self {
        case .autoDetect: return .autoDetect
        case .fixed(let language): return .explicit(language)
        }
    }
}

/// What runs on a voice note's transcript when its result is opened.
public enum VoiceNoteMode: Equatable, Hashable, Sendable {
    /// The transcript alone.
    case transcriptOnly
    /// A Smart Mode from the catalogue, by identifier. `Résumé` by default.
    case smartMode(String)

    static let noneStoredValue = "none"

    /// The default: `Résumé` (#571), the mode a long voice message is the obvious
    /// input for, and the "Summary" half of the result screen (#620 decision 5).
    public static let defaultMode = VoiceNoteMode.smartMode(SmartModeCatalogue.summaryIdentifier)

    init(storedValue: String?) {
        switch storedValue {
        case .none: self = Self.defaultMode
        case .some(Self.noneStoredValue): self = .transcriptOnly
        case .some(let identifier): self = .smartMode(identifier)
        }
    }

    var storedValue: String {
        switch self {
        case .transcriptOnly: return Self.noneStoredValue
        case .smartMode(let identifier): return identifier
        }
    }

    /// The mode record, or nil for `.transcriptOnly` and for an identifier this
    /// build no longer ships — which then behaves as transcript only rather than
    /// guessing at a replacement.
    public var smartMode: SmartMode? {
        guard case .smartMode(let identifier) = self else { return nil }
        return SmartModeCatalogue.builtIns.first { $0.id == identifier }
    }
}

/// The voice note defaults, read from and written to the App Group.
///
/// ### Why defaults and not a choice screen
///
/// #620 decision 4: the share sheet starts the transcription and the user goes back
/// to their conversation. MacWhisper asks four questions before it starts and
/// VivaDicta opens a sheet; both were judged worse for the case that matters, which
/// is a voice note received in a messenger. So the choice is made once, here, in a
/// section of the Pro hub (#216), and every note uses it.
///
/// ### Why DictusCore
///
/// The share extension does not read these today, but the app and the hub do, and
/// the rules (what "unknown" means, what the default is) are worth one tested home.
public struct VoiceNoteSettings: Equatable, Sendable {
    public var language: VoiceNoteLanguage
    public var mode: VoiceNoteMode

    public init(language: VoiceNoteLanguage = .autoDetect, mode: VoiceNoteMode = .defaultMode) {
        self.language = language
        self.mode = mode
    }

    /// Read from `defaults`. Missing keys give the defaults above.
    public static func load(from defaults: UserDefaults = AppGroup.defaults) -> VoiceNoteSettings {
        VoiceNoteSettings(
            language: VoiceNoteLanguage(storedValue: defaults.string(forKey: SharedKeys.voiceNoteLanguage)),
            mode: VoiceNoteMode(storedValue: defaults.string(forKey: SharedKeys.voiceNoteMode))
        )
    }

    public func save(to defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(language.storedValue, forKey: SharedKeys.voiceNoteLanguage)
        defaults.set(mode.storedValue, forKey: SharedKeys.voiceNoteMode)
    }

    /// The language policy one voice note is transcribed under: these settings for
    /// the language, the user's active model for everything else. Captured once per
    /// note, for #226's reason — the settings can change while a queue runs.
    public func languagePolicy(activeModel: String, keyboardLanguage: SupportedLanguage) -> TranscriptionLanguagePolicy {
        TranscriptionLanguagePolicy(
            mode: language.transcriptionMode,
            keyboardLanguage: keyboardLanguage,
            engine: ModelInfo.forIdentifier(activeModel)?.engine ?? .whisperKit,
            modelIdentifier: activeModel
        )
    }

    /// The modes the hub section offers: every built-in mode. Translation included —
    /// "give me this note in English" is a reasonable default for someone who
    /// receives messages in a language they read slowly.
    public static var availableModes: [SmartMode] { SmartModeCatalogue.builtIns }
}
