// DictusApp/Extensions/ModelInfo+Localized.swift
// Localized display strings for ModelInfo, resolved via String Catalog.
import DictusCore
import SwiftUI

extension ModelInfo {
    /// Localized description for display in model cards.
    /// Source strings are in English; French provided via String Catalog.
    var localizedDescription: String {
        switch identifier {
        case "openai_whisper-tiny", "openai_whisper-base":
            return String(localized: "Fast but inaccurate")
        case "openai_whisper-small":
            return String(localized: "Accurate and balanced")
        case "openai_whisper-small_216MB":
            return String(localized: "Compact and fast")
        case "openai_whisper-medium":
            return String(localized: "Best accuracy")
        case "parakeet-tdt-0.6b-v3":
            return String(localized: "Fast and accurate (NVIDIA)")
        case "openai_whisper-large-v3_turbo_954MB":
            return String(localized: "Most accurate but slowest")
        default:
            return description
        }
    }
}
