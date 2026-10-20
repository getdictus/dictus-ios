// DictusCore/Sources/DictusCore/Polish/TranslationLanguagePair.swift
// The language pair a Translate mode needs installed, and whether it is (issue #648).
import Foundation
#if canImport(Translation)
import Translation
#endif

/// A source language and a Translate target: what Apple's Translation framework has to
/// have installed for a Translate mode to run on it (#648).
///
/// The source is a language code rather than a `SupportedLanguage` because a dictation
/// can be in any language Parakeet or Whisper transcribes, not only the four Dictus has
/// keyboards for. The target is one of the four, since those are the Translate modes.
public struct TranslationLanguagePair: Hashable, Sendable {
    public let source: String
    public let target: SupportedLanguage

    /// Nil when there is nothing to translate: source and target are the same language.
    /// That input runs Translate's Apple FM path, which is the shipped rule-8 behaviour
    /// for text already in the target, and never a raw passthrough.
    public init?(source: String, target: SupportedLanguage) {
        let base = Locale.Language(identifier: source).languageCode?.identifier ?? source
        guard base != target.rawValue else { return nil }
        self.source = source
        self.target = target
    }

    /// The target of a Translate mode, or nil for any other mode.
    public static func translateTarget(of mode: SmartMode) -> SupportedLanguage? {
        SupportedLanguage.allCases.first { SmartModeCatalogue.translateIdentifier(target: $0) == mode.id }
    }
}

/// Whether a pair is installed for the strategy Translate ships with (`.highFidelity`).
///
/// **On a device with Apple Intelligence, `.highFidelity` never needs a download.**
/// Apple's documentation for the strategy: "The models are already downloaded when
/// Apple Intelligence is enabled, so no additional language downloads are required.
/// […] On devices without Apple Intelligence, it falls back to the traditional models
/// used by lowLatency." Measured the same way twice: on the Mac every one of 64 pairs
/// (16 sources × 4 targets) read `installed` under `.highFidelity`, against 60
/// `supported` and 4 `unsupported` under `.lowLatency`; on the iPhone every
/// `.highFidelity` call read `installed`, including after the languages were deleted
/// in iOS Settings (#648, 2026-10-08). Translate needs Apple Intelligence anyway, so
/// `.notInstalled` is not expected under shipping conditions. It is still read before
/// every call, because it costs one query and covers a transient state nobody has
/// observed: anything but `.installed` sends Translate to Apple FM. The app has no
/// language download (removed 2026-10-09, once this was established).
public enum TranslationPairStatus: String, Equatable, Sendable {
    /// The framework can translate this pair right now.
    case installed
    /// Supported, but its languages are not installed. Translate runs on Apple FM.
    case notInstalled
    /// The framework cannot translate this pair at all. Translate runs on Apple FM.
    case unsupported
    /// No answer: an OS below 26.4, or a build without the framework.
    case unknown

    /// The framework's own verdict for `pair`, under `.highFidelity`.
    public static func current(for pair: TranslationLanguagePair) async -> TranslationPairStatus {
        #if canImport(Translation)
        guard #available(iOS 26.4, macOS 26.4, *) else { return .unknown }
        let status = await LanguageAvailability(preferredStrategy: .highFidelity).status(
            from: Locale.Language(identifier: pair.source),
            to: Locale.Language(identifier: pair.target.rawValue)
        )
        switch status {
        case .installed: return .installed
        case .supported: return .notInstalled
        case .unsupported: return .unsupported
        @unknown default: return .unknown
        }
        #else
        return .unknown
        #endif
    }
}
