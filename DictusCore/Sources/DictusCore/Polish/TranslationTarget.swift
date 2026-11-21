// DictusCore/Sources/DictusCore/Polish/TranslationTarget.swift
// A language the Translate mode can write into (issue #622).
import Foundation

/// A language the Translate Smart Mode can write into. **Not a dictation language.**
///
/// ### Why this is not `SupportedLanguage`
///
/// `SupportedLanguage` means "a language Dictus has a keyboard, a layout, autocorrect
/// and polish prompts for". Until #622 the translation targets were that list, which is
/// why Translate offered exactly French, English, Spanish and German: the targets were
/// whatever keyboards Dictus had, not whatever Apple can translate into. Every `switch`
/// on `SupportedLanguage` (`displayName`, `defaultLayout`, `spaceName`, `returnName`)
/// would need 22 meaningless cases if it also held translation targets, so the two
/// lists are separate types and only meet in `builtIn`.
///
/// ### Why the list is written down rather than read at runtime
///
/// The brief of 2026-11-21 (#622, option B) fixes it: the 26 languages
/// `LanguageAvailability().supportedLanguages` returned on macOS 27.0 with Apple
/// Intelligence on (47 locales, one entry per language, one per script for Chinese).
/// A runtime list would change what the mode list shows from one OS to the next with
/// no guardrail measurement behind the new entries, and each entry here carries a
/// fact a runtime query cannot give: the code `NLLanguageRecognizer` answers for it,
/// which the output-language check is keyed on (see `recognizerCode`). A target the
/// framework stops supporting on some device still behaves: its status reads
/// `unsupported` and the mode falls back, or says it cannot translate.
///
/// ### Three codes per target, because three APIs disagree
///
/// - `code` — the identifier suffix, `translate.<code>`, and the contract's stored
///   value. A wire value: it crosses the App Group in the armed snapshot and the
///   pinned list, so `fr`/`en`/`es`/`de` are the four codes they always were.
/// - `frameworkIdentifier` — what `Locale.Language(identifier:)` is built from for the
///   Translation framework. Equal to `code` for all 26; kept apart because the two
///   answer to different owners (`pt` resolves to `pt-BR` in the framework, measured
///   2026-11-21 — `maximalIdentifier` reads `pt-Latn-BR`).
/// - `recognizerCode` — the `NLLanguage` raw value the recogniser answers for this
///   language: `nb` and not `no`, `zh-Hans` and `zh-Hant` and never `zh`. A wrong one
///   here rejects every translation into the language, so it is tested per target.
public struct TranslationTarget: Hashable, Sendable {

    /// The identifier suffix and the stored value. See the type's doc comment.
    public let code: String

    /// What the Translation framework is handed, as a `Locale.Language` identifier.
    public let frameworkIdentifier: String

    /// The `NLLanguage` raw value `NLLanguageRecognizer` answers for this language.
    public let recognizerCode: String

    /// Whether Apple Foundation Models can write this language, so whether the
    /// Translate mode has a fallback when the framework declines (#648).
    ///
    /// True for the 16 languages of Apple's Apple Intelligence list for the 27.0
    /// releases (support.apple.com/en-us/121115): en, da, nl, fr, de, it, nb, pt, es,
    /// sv, tr, vi, zh-Hans, zh-Hant, ja, ko. **False for ar, fi, he, hi, id, ms, pl, ru,
    /// th, uk**: a model that cannot write the language would hand back the wrong
    /// language or the input, and the guardrail would refuse it at best. Those ten say
    /// plainly that the translation is unavailable instead (`TranslateRoutingPolishEngine`).
    public let hasModelFallback: Bool

    /// The dictation language this target is, for the four that are one. Those four
    /// keep the hand-written prompt examples and the per-language typography post-pass,
    /// which exist for `SupportedLanguage` only.
    public let builtIn: SupportedLanguage?

    init(code: String, recognizerCode: String? = nil, hasModelFallback: Bool,
         builtIn: SupportedLanguage? = nil) {
        self.code = code
        self.frameworkIdentifier = code
        self.recognizerCode = recognizerCode ?? code
        self.hasModelFallback = hasModelFallback
        self.builtIn = builtIn
    }

    // MARK: - The four built-in targets

    public static let french = TranslationTarget(code: "fr", hasModelFallback: true, builtIn: .french)
    public static let english = TranslationTarget(code: "en", hasModelFallback: true, builtIn: .english)
    public static let spanish = TranslationTarget(code: "es", hasModelFallback: true, builtIn: .spanish)
    public static let german = TranslationTarget(code: "de", hasModelFallback: true, builtIn: .german)

    /// The target for a dictation language. Every `SupportedLanguage` is one.
    public init(_ language: SupportedLanguage) {
        switch language {
        case .french: self = .french
        case .english: self = .english
        case .spanish: self = .spanish
        case .german: self = .german
        }
    }

    /// The four targets Translate shipped with, in `SupportedLanguage` order. These are
    /// the catalogue's built-in rows, unchanged by #622: same identifiers, same prompt.
    public static let builtIns: [TranslationTarget] = SupportedLanguage.allCases.map(TranslationTarget.init)

    /// The 22 targets #622 adds, in code order. Reached through "Other language…".
    public static let additional: [TranslationTarget] = [
        TranslationTarget(code: "ar", hasModelFallback: false),
        TranslationTarget(code: "da", hasModelFallback: true),
        TranslationTarget(code: "fi", hasModelFallback: false),
        TranslationTarget(code: "he", hasModelFallback: false),
        TranslationTarget(code: "hi", hasModelFallback: false),
        TranslationTarget(code: "id", hasModelFallback: false),
        TranslationTarget(code: "it", hasModelFallback: true),
        TranslationTarget(code: "ja", hasModelFallback: true),
        TranslationTarget(code: "ko", hasModelFallback: true),
        TranslationTarget(code: "ms", hasModelFallback: false),
        TranslationTarget(code: "nb", hasModelFallback: true),
        TranslationTarget(code: "nl", hasModelFallback: true),
        TranslationTarget(code: "pl", hasModelFallback: false),
        TranslationTarget(code: "pt", hasModelFallback: true),
        TranslationTarget(code: "ru", hasModelFallback: false),
        TranslationTarget(code: "sv", hasModelFallback: true),
        TranslationTarget(code: "th", hasModelFallback: false),
        TranslationTarget(code: "tr", hasModelFallback: true),
        TranslationTarget(code: "uk", hasModelFallback: false),
        TranslationTarget(code: "vi", hasModelFallback: true),
        TranslationTarget(code: "zh-Hans", hasModelFallback: true),
        TranslationTarget(code: "zh-Hant", hasModelFallback: true)
    ]

    /// Every target: the four built-ins, then the 22 others.
    public static let all: [TranslationTarget] = builtIns + additional

    /// The target with this `code`, or nil for a code this build does not know — a
    /// downgrade from a build with more targets, or a corrupted value.
    public init?(code: String) {
        guard let target = Self.all.first(where: { $0.code == code }) else { return nil }
        self = target
    }

    // MARK: - Length

    /// The shortest output, as a share of the input's characters, a translation into
    /// this target may be before the length guardrail refuses it.
    ///
    /// **0.4 — the band Translate always had — except for Chinese, Japanese and Korean,
    /// which get 0.15.** Their scripts write a sentence in a fraction of the characters
    /// a Latin one takes, so a correct translation lands under 0.4 by construction.
    /// Measured 2026-11-21 through `PolishPipeline` with the real framework (the live
    /// audit in `TranslationTargetLiveAuditTests`), from two French sentences of 48 and
    /// 71 characters: zh-Hans 0.27 and 0.35, zh-Hant 0.25 and 0.35, ja 0.375 and 0.45,
    /// ko 0.396 and 0.51. At 0.4 six of those eight correct translations were refused on
    /// `check=length` and the user got nothing. 0.15 clears the worst of them (0.25)
    /// with margin and still refuses an output cut to a word or two, which is what the
    /// floor exists for.
    public var minimumLengthRatio: Double {
        Self.compactScripts.contains(code) ? 0.15 : 0.4
    }

    /// The targets whose script writes a sentence in far fewer characters than a Latin
    /// one. See `minimumLengthRatio`.
    private static let compactScripts: Set<String> = ["ja", "ko", "zh-Hans", "zh-Hant"]

    // MARK: - Names

    /// The two or so characters the fan row ("→ PT") and the mic pill's 18 pt badge
    /// show. Language-neutral on purpose, like the arrow: one string in every UI locale.
    ///
    /// Chinese is the one exception, because `ZH` cannot tell the two scripts apart —
    /// the reason the badge is text at all (`SmartModeBadge`) — and `ZH-T` does not fit
    /// the disc. `简` and `繁` are the marks Apple's own Chinese keyboards use for the
    /// two scripts: one glyph each, and different from each other.
    public var shortCode: String {
        switch code {
        case "zh-Hans": return "\u{7B80}"
        case "zh-Hant": return "\u{7E41}"
        default: return code.uppercased()
        }
    }

    /// The language's name in `locale`, from the system: "portugais", "chinois
    /// simplifié", "Portuguese". Never hard-coded (#622 brief), so no string catalog
    /// carries a language name and a new UI locale gets them for free.
    public func localizedName(in locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: code) ?? code
    }

    /// The English name the Apple FM fallback prompt names the target with.
    ///
    /// The system's own English name, with its list form turned into a phrase: the
    /// system says "Chinese, Simplified", which is an index entry, not something a
    /// sentence can "translate into", so the qualifier goes in brackets — "Chinese
    /// (Simplified)". Every other target has no comma and comes through as is, which is
    /// what keeps "French", "English", "Spanish" and "German" the exact words the four
    /// built-in prompts shipped with.
    public var englishName: String {
        let name = Locale(identifier: "en").localizedString(forIdentifier: code) ?? code
        let parts = name.components(separatedBy: ", ")
        guard parts.count == 2 else { return name }
        return "\(parts[0]) (\(parts[1]))"
    }
}
