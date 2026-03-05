// DictusCore/Sources/DictusCore/ModelInfo.swift
import Foundation

/// Metadata for a supported WhisperKit model variant.
/// Used by the model manager UI and smart routing logic.
public struct ModelInfo {
    public let identifier: String
    public let displayName: String
    public let sizeLabel: String
    public let accuracyLabel: String
    public let speedLabel: String
    public let sizeBytes: Int64

    /// Stub — empty list. Will be populated in GREEN phase.
    public static let all: [ModelInfo] = []

    /// Set of all supported model identifiers.
    public static let supportedIdentifiers: Set<String> = Set(all.map(\.identifier))

    /// Look up a model by its WhisperKit identifier.
    public static func forIdentifier(_ id: String) -> ModelInfo? {
        all.first { $0.identifier == id }
    }
}
