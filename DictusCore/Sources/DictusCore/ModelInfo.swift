// DictusCore/Sources/DictusCore/ModelInfo.swift
import Foundation

/// Visibility state of a model in the download catalog.
///
/// WHY soft deprecation instead of removal:
/// Users who already downloaded Tiny/Base models should still be able to use them.
/// We hide deprecated models from the "new download" catalog but keep them resolvable
/// so ModelManager can display and manage them if present on device.
public enum CatalogVisibility {
    case available
    case deprecated
}

/// Metadata for a supported WhisperKit model variant.
/// Used by the model manager UI and dictation pipeline.
///
/// Each model has a WhisperKit identifier (matching the argmaxinc/whisperkit-coreml
/// repository naming), a human-readable display name, numeric gauge scores for
/// accuracy and speed (0.0-1.0), and a short English description.
public struct ModelInfo: Identifiable {
    /// Identifiable conformance uses `identifier` as the unique ID.
    /// WHY Identifiable: SwiftUI's ForEach requires elements to be Identifiable
    /// so it can efficiently diff and animate list changes.
    public var id: String { identifier }

    public let identifier: String
    public let displayName: String
    public let sizeLabel: String
    public let sizeBytes: Int64

    /// Speech-to-text engine this model uses (WhisperKit or Parakeet).
    public let engine: SpeechEngine

    /// Accuracy score from 0.0 (worst) to 1.0 (best), used for gauge display.
    public let accuracyScore: Double

    /// Speed score from 0.0 (slowest) to 1.0 (fastest), used for gauge display.
    public let speedScore: Double

    /// Short English description for the model selection UI.
    public let description: String

    /// Whether this model is shown in the download catalog or only kept for backward compat.
    public let visibility: CatalogVisibility

    // MARK: - Deprecated label properties (backward compat)

    /// Use accuracyScore instead. Kept temporarily for existing UI references.
    @available(*, deprecated, message: "Use accuracyScore gauge instead")
    public var accuracyLabel: String {
        switch accuracyScore {
        case 0.8...: return "Best"
        case 0.5...: return "Better"
        default: return "Good"
        }
    }

    /// Use speedScore instead. Kept temporarily for existing UI references.
    @available(*, deprecated, message: "Use speedScore gauge instead")
    public var speedLabel: String {
        switch speedScore {
        case 0.8...: return "Fast"
        case 0.5...: return "Balanced"
        default: return "Slow"
        }
    }

    // MARK: - Catalog

    /// Models available for new downloads. Excludes deprecated Tiny/Base.
    /// On iOS 17+, includes Parakeet models. On iOS 16, Parakeet is filtered out.
    ///
    /// WHY runtime OS version check instead of #available:
    /// ModelInfo is in DictusCore (a framework), not the app target.
    /// Static properties can't use @available. ProcessInfo gives the same
    /// result at runtime, ensuring iOS 16 users never see Parakeet models
    /// they can't download or use.
    public static let all: [ModelInfo] = {
        let isIOS17OrLater = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
        return allIncludingDeprecated.filter { model in
            guard model.visibility == .available else { return false }
            // Hide Parakeet models on iOS 16
            if model.engine == .parakeet && !isIOS17OrLater { return false }
            return true
        }
    }()

    /// All known models including deprecated ones. Used for backward compatibility
    /// so already-downloaded Tiny/Base models still resolve and function.
    public static let allIncludingDeprecated: [ModelInfo] = [
        ModelInfo(
            identifier: "openai_whisper-tiny",
            displayName: "Tiny",
            sizeLabel: "~40 MB",
            sizeBytes: 40_000_000,
            engine: .whisperKit,
            accuracyScore: 0.3,
            speedScore: 1.0,
            description: "Fast but inaccurate",
            visibility: .deprecated
        ),
        ModelInfo(
            identifier: "openai_whisper-base",
            displayName: "Base",
            sizeLabel: "~75 MB",
            sizeBytes: 75_000_000,
            engine: .whisperKit,
            accuracyScore: 0.4,
            speedScore: 0.9,
            description: "Fast but inaccurate",
            visibility: .deprecated
        ),
        ModelInfo(
            identifier: "openai_whisper-small",
            displayName: "Small",
            sizeLabel: "~250 MB",
            sizeBytes: 250_000_000,
            engine: .whisperKit,
            accuracyScore: 0.6,
            speedScore: 0.7,
            description: "Accurate and balanced",
            visibility: .available
        ),
        ModelInfo(
            identifier: "openai_whisper-small_216MB",
            displayName: "Small (Quantized)",
            sizeLabel: "~216 MB",
            sizeBytes: 216_000_000,
            engine: .whisperKit,
            accuracyScore: 0.55,
            speedScore: 0.75,
            description: "Compact and fast",
            visibility: .available
        ),
        ModelInfo(
            identifier: "openai_whisper-medium",
            displayName: "Medium",
            sizeLabel: "~750 MB",
            sizeBytes: 750_000_000,
            engine: .whisperKit,
            accuracyScore: 0.8,
            speedScore: 0.4,
            description: "Best accuracy",
            visibility: .available
        ),
        ModelInfo(
            identifier: "parakeet-tdt-0.6b-v3",
            displayName: "Parakeet v3",
            sizeLabel: "~800 MB",
            sizeBytes: 800_000_000,
            engine: .parakeet,
            accuracyScore: 0.85,
            speedScore: 0.9,
            description: "Fast and accurate (NVIDIA)",
            visibility: .available
        ),
    ]

    /// Set of all supported model identifiers for quick lookup.
    /// Uses allIncludingDeprecated so downloaded Tiny/Base models still resolve.
    public static let supportedIdentifiers: Set<String> = Set(allIncludingDeprecated.map(\.identifier))

    /// Look up a model by its WhisperKit identifier.
    /// Searches allIncludingDeprecated so deprecated models are still resolvable.
    /// Returns nil if the identifier is not in the supported list.
    public static func forIdentifier(_ id: String) -> ModelInfo? {
        allIncludingDeprecated.first { $0.identifier == id }
    }

    // MARK: - RAM-based Recommendation

    /// Returns the recommended model identifier based on device RAM.
    ///
    /// WHY RAM-based instead of hardcoded:
    /// Different iPhones have different RAM tiers. Parakeet v3 (~800 MB) needs
    /// enough headroom to compile and run without OOM. Devices with >=6 GB RAM
    /// (iPhone 12 Pro, 13 Pro, 14+, 15+, 16+) can handle it comfortably.
    /// Devices with <=4 GB RAM (iPhone 12, 12 mini, 13, 13 mini) should stick
    /// with the smaller Whisper Small model.
    ///
    /// WHY in ModelInfo (not ModelManager):
    /// This is catalog-level logic — which model fits this device. It doesn't
    /// depend on download state or any @Published properties. Accessible from
    /// both ModelManager and onboarding without passing an ObservableObject.
    /// Cached result — computed once per process since device RAM doesn't change.
    private static let _recommendedIdentifier: String = {
        let ramGB = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        let model = ramGB >= 6 ? "parakeet-tdt-0.6b-v3" : "openai_whisper-small"
        #if DEBUG
        print("[ModelInfo] Device RAM: \(ramGB) GB, recommending: \(model)")
        #endif
        return model
    }()

    public static func recommendedIdentifier() -> String {
        return _recommendedIdentifier
    }

    /// Whether the given model identifier matches the device-recommended model.
    public static func isRecommended(_ identifier: String) -> Bool {
        identifier == recommendedIdentifier()
    }
}
