// DictusCore/Sources/DictusCore/SpokenLanguage.swift
// The language a user speaks, and what it decides about the keyboard and the model (#649).
import Foundation

/// The language the user speaks, named by its Whisper / ISO 639-1 code ("fr", "zh", …).
///
/// WHY a separate notion from `SupportedLanguage` (#649): `SupportedLanguage` is a Dictus
/// KEYBOARD language — four of them, each with a layout and a dictionary. What a person
/// speaks is a much wider set: Whisper transcribes about a hundred languages and Parakeet
/// 25. A Chinese or Italian speaker has a spoken language but no Dictus keyboard, and the
/// onboarding has to handle both halves of that. Same split, and same reason, as
/// `TranscriptionLanguageMode` (#226).
///
/// WHY a caseless enum: it is a namespace for pure functions. Everything that reads the
/// device (`Locale.preferredLanguages`) or the App Group is injected, so each rule here is
/// unit-testable without either.
public enum SpokenLanguage {

    /// Every code a user can declare as their spoken language: the Whisper set, which is
    /// the widest any model in the catalogue covers.
    public static let selectableCodes: [String] = ModelLanguageSupport.whisperLanguageCodes

    private static let selectableSet = Set(selectableCodes)

    /// iOS language codes that Whisper spells differently.
    ///
    /// iOS names Norwegian Bokmål `nb`, Whisper's tokenizer has `no`; iOS says `fil` for
    /// Filipino where Whisper has Tagalog `tl`. `iw`/`in`/`jw` are the legacy codes for
    /// Hebrew, Indonesian and Javanese that older locale data can still produce.
    static let aliases: [String: String] = [
        "nb": "no",
        "fil": "tl",
        "iw": "he",
        "in": "id",
        "jw": "jv"
    ]

    /// The spoken-language code behind a language tag such as "zh-Hans-CN" or "pt_BR",
    /// or nil when no model in the catalogue transcribes that language.
    ///
    /// Only the language subtag counts: the script and the region say how the text is
    /// written and where the person lives, not which model can hear them.
    public static func code(fromLanguageTag tag: String) -> String? {
        let base = tag
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map { String($0).lowercased() } ?? ""
        let normalized = aliases[base] ?? base
        return selectableSet.contains(normalized) ? normalized : nil
    }

    /// The spoken language the onboarding prefills: the first of the iPhone's preferred
    /// languages that a model can transcribe, or English when none can.
    ///
    /// - Parameter preferredLanguages: `Locale.preferredLanguages`, injected.
    public static func prefilled(from preferredLanguages: [String]) -> String {
        preferredLanguages.lazy.compactMap(code(fromLanguageTag:)).first
            ?? SupportedLanguage.english.rawValue
    }

    /// The Dictus keyboard language that goes with `spokenLanguage`.
    ///
    /// The spoken language itself when Dictus has a keyboard for it. Otherwise the first
    /// of the iPhone's preferred languages that does, and English when none does: a
    /// Chinese speaker whose second iPhone language is French is more likely to type
    /// French than English, and the screen shows the choice anyway.
    public static func keyboardLanguage(
        forSpokenLanguage spokenLanguage: String,
        preferredLanguages: [String]
    ) -> SupportedLanguage {
        if let own = SupportedLanguage(rawValue: spokenLanguage) {
            return own
        }
        return preferredLanguages.lazy
            .compactMap(code(fromLanguageTag:))
            .compactMap(SupportedLanguage.init(rawValue:))
            .first ?? .english
    }

    // MARK: - Which language the recommendation is for

    /// The spoken language the model recommendation should be computed for, from the
    /// settings as they stand.
    ///
    /// WHY this exists outside onboarding: the Models screen marks one model as
    /// "Recommended", and it has to agree with what onboarding installed. A Chinese
    /// speaker sent to Whisper by onboarding must not open Models and find Parakeet
    /// recommended.
    ///
    /// - an explicit transcription language says what is spoken;
    /// - "Follow keyboard language" transcribes in the keyboard language, so that is it;
    /// - Auto-detect is the only mode where the settings do not say. The language the user
    ///   declared in onboarding answers; an install that onboarded before #649 never
    ///   declared one, and the iPhone's own language is the best remaining guess.
    public static func forRecommendation(
        mode: TranscriptionLanguageMode,
        keyboardLanguage: SupportedLanguage,
        declaredSpokenLanguage: String?,
        preferredLanguages: [String]
    ) -> String {
        switch mode {
        case .explicit(let language):
            return language.rawValue
        case .followKeyboard:
            return keyboardLanguage.rawValue
        case .autoDetect:
            if let declared = declaredSpokenLanguage, selectableSet.contains(declared) {
                return declared
            }
            return prefilled(from: preferredLanguages)
        }
    }

    /// `forRecommendation` read from the App Group and the device.
    public static func forRecommendation() -> String {
        forRecommendation(
            mode: .active,
            keyboardLanguage: .active,
            declaredSpokenLanguage: AppGroup.defaults.string(forKey: SharedKeys.spokenLanguage),
            preferredLanguages: Locale.preferredLanguages
        )
    }
}

/// What the onboarding language screen sets up: the spoken language, the keyboard
/// language and layout that go with it, and the transcription mode (#649).
///
/// WHY one value type for the whole screen: the screen's fields depend on each other —
/// changing the spoken language changes the keyboard language, which changes the default
/// layout — and those rules are the part worth testing. Keeping them here leaves the view
/// with nothing but bindings.
public struct LanguageSetup: Equatable, Sendable {

    /// The language the user speaks (a `SpokenLanguage` code).
    public private(set) var spokenLanguage: String

    /// The Dictus keyboard language. Equal to the spoken language whenever Dictus has a
    /// keyboard for it.
    public private(set) var keyboardLanguage: SupportedLanguage

    /// The layout the keyboard language will type on. Free to change on the screen.
    public var layout: LayoutType

    /// Whether Dictus has a keyboard in the spoken language. When it does not, the screen
    /// asks for the keyboard language separately (#649 decision 3).
    public var spokenLanguageHasDictusKeyboard: Bool {
        SupportedLanguage(rawValue: spokenLanguage) != nil
    }

    /// The transcription language mode this setup writes.
    ///
    /// "Follow keyboard language" when the keyboard is in the spoken language, which is
    /// the default and transcribes exactly that language.
    ///
    /// Auto-detect otherwise. Following the keyboard would force the KEYBOARD language on
    /// the speech model, so a Chinese speaker on an English keyboard would be transcribed
    /// as English. And an explicit mode cannot name Chinese: #226 decided that explicit
    /// entries stop at the four tested languages and that the rest of Whisper's languages
    /// are reached through Auto-detect only, which is the path #226 validated on device
    /// with Mandarin. Parakeet ignores the setting either way, but polish does not: in
    /// Auto-detect it polishes in the language spoken instead of translating into the
    /// keyboard's (#239).
    public var transcriptionMode: TranscriptionLanguageMode {
        spokenLanguageHasDictusKeyboard ? .followKeyboard : .autoDetect
    }

    /// A setup for `spokenLanguage`, with the keyboard language that goes with it and
    /// that language's layout.
    ///
    /// - Parameters:
    ///   - preferredLanguages: `Locale.preferredLanguages`, injected.
    ///   - layoutFor: the layout a keyboard language types on. The app passes
    ///     `KeyboardLayoutPreference.layout(for:)`, so a re-run onboarding shows a layout
    ///     the user already chose; the default is the language's `defaultLayout`.
    public init(
        spokenLanguage: String,
        preferredLanguages: [String],
        layoutFor: (SupportedLanguage) -> LayoutType = { $0.defaultLayout }
    ) {
        let keyboard = SpokenLanguage.keyboardLanguage(
            forSpokenLanguage: spokenLanguage,
            preferredLanguages: preferredLanguages
        )
        self.spokenLanguage = spokenLanguage
        self.keyboardLanguage = keyboard
        self.layout = layoutFor(keyboard)
    }

    /// The setup the screen opens on: the iPhone's language, so most users confirm it in
    /// one tap.
    public static func prefilled(
        preferredLanguages: [String],
        layoutFor: (SupportedLanguage) -> LayoutType = { $0.defaultLayout }
    ) -> LanguageSetup {
        LanguageSetup(
            spokenLanguage: SpokenLanguage.prefilled(from: preferredLanguages),
            preferredLanguages: preferredLanguages,
            layoutFor: layoutFor
        )
    }

    /// Changes the spoken language. The keyboard language and the layout follow it.
    public mutating func setSpokenLanguage(
        _ code: String,
        preferredLanguages: [String],
        layoutFor: (SupportedLanguage) -> LayoutType = { $0.defaultLayout }
    ) {
        self = LanguageSetup(spokenLanguage: code, preferredLanguages: preferredLanguages, layoutFor: layoutFor)
    }

    /// Changes the keyboard language, for a spoken language Dictus has no keyboard for.
    /// The layout follows it.
    ///
    /// Ignored when the spoken language has its own keyboard: the screen does not offer
    /// the choice then, and a setup where an English speaker silently types on a German
    /// keyboard is not one it can produce.
    public mutating func setKeyboardLanguage(
        _ language: SupportedLanguage,
        layoutFor: (SupportedLanguage) -> LayoutType = { $0.defaultLayout }
    ) {
        guard !spokenLanguageHasDictusKeyboard else { return }
        keyboardLanguage = language
        layout = layoutFor(language)
    }

    /// The model this setup recommends on `capabilities`.
    public func recommendedModel(on capabilities: DeviceCapabilities) -> String {
        ModelInfo.recommendedIdentifier(forSpokenLanguage: spokenLanguage, on: capabilities)
    }

    /// Writes the setup to the App Group.
    ///
    /// Order matters: `SupportedLanguage.activate` runs the #272 layout migration before
    /// the language moves, so it goes first, and the layout is then recorded against the
    /// new language. A layout equal to what the language already resolves to is NOT
    /// recorded, so a user who confirmed the default keeps tracking the default
    /// (`KeyboardLayoutPreference` explains why that distinction is kept).
    public func apply() {
        SupportedLanguage.activate(keyboardLanguage)
        if KeyboardLayoutPreference.layout(for: keyboardLanguage) != layout {
            KeyboardLayoutPreference.setLayout(layout, for: keyboardLanguage)
        }
        AppGroup.defaults.set(transcriptionMode.storedValue, forKey: SharedKeys.transcriptionLanguage)
        AppGroup.defaults.set(spokenLanguage, forKey: SharedKeys.spokenLanguage)
    }
}
