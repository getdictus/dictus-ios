// DictusCore/Sources/DictusCore/SmartModelRouter.swift
import Foundation

/// Routes audio to the appropriate Whisper model based on duration and
/// which models are currently downloaded on-device.
public struct SmartModelRouter {

    /// Stub — returns first downloaded model. Will be implemented in GREEN phase.
    public static func selectModel(
        audioDuration: TimeInterval,
        downloadedModels: [String]
    ) -> String {
        return downloadedModels.first ?? ""
    }
}
