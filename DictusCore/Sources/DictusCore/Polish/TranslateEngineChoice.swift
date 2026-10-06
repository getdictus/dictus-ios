// DictusCore/Sources/DictusCore/Polish/TranslateEngineChoice.swift
import Foundation

/// Which engine the Translate Smart Mode runs on — a debug switch for the #648 device
/// test, not a product setting.
///
/// #648's harness bench could not answer two questions on a Mac: whether Apple's
/// Translation framework (`.highFidelity`, never run on an iPhone) avoids the gross
/// errors the device's Apple FM makes, and whether it runs at all inside the keyboard
/// extension, where polish has run since #361. This switch lets the maintainer
/// compare on his own dictations. It lives in the App Group because the keyboard
/// reads it, and it defaults to Apple FM, the shipped engine: with the switch never
/// touched, nothing changes.
public enum TranslateEngineChoice: String, CaseIterable, Sendable {
    case appleFM
    case translationHighFidelity
    case translationLowLatency

    /// The stored choice. Absent or unrecognised reads as `.appleFM`.
    public static var current: TranslateEngineChoice {
        AppGroup.defaults.string(forKey: SharedKeys.debugTranslateEngine)
            .flatMap(TranslateEngineChoice.init(rawValue:)) ?? .appleFM
    }

    public static func store(_ choice: TranslateEngineChoice) {
        AppGroup.defaults.set(choice.rawValue, forKey: SharedKeys.debugTranslateEngine)
    }

    /// The strategy name as it appears in the log, `-` for Apple FM.
    public var strategyName: String {
        switch self {
        case .appleFM: return "-"
        case .translationHighFidelity: return "highFidelity"
        case .translationLowLatency: return "lowLatency"
        }
    }

    public var displayName: String {
        switch self {
        case .appleFM: return "Apple FM (shipped)"
        case .translationHighFidelity: return "Translation · highFidelity"
        case .translationLowLatency: return "Translation · lowLatency"
        }
    }
}
