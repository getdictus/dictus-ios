// DictusApp/Models/FluidAudioDownloadRoute.swift
// What differs between the two FluidAudio engines on the download and delete paths (#558).
import Foundation
import DictusCore
import FluidAudio

/// The engine-specific half of `ModelManager`'s FluidAudio download path.
///
/// WHY A TYPE: Parakeet and Nemotron go through one download sequence, and that sequence is
/// long for good reasons (#207, #210, #252, #405, #422, #427, #428, #449). Copying it for
/// Nemotron would have given the next fix two places to land in and one to forget. What
/// genuinely differs between the engines is small and is all here: which repository files,
/// which directory, which engine compiles them, and what completeness means on disk.
struct FluidAudioDownloadRoute {
    let engine: SpeechEngine

    /// Where the downloader writes, as the repository root.
    var cacheDirectory: URL {
        switch engine {
        case .parakeet:
            return AsrModels.defaultCacheDirectory(for: .v3)
        case .nemotron:
            return NemotronEngine.repositoryCacheDirectory
        case .whisperKit:
            // Not a FluidAudio engine; `ModelManager` never builds a route for it. Answered
            // rather than trapped, and answered with WhisperKit's own location, so a mistake
            // could only ever point at the right engine's files.
            return WhisperModelRepository.repositoryURL() ?? AsrModels.defaultCacheDirectory(for: .v3)
        }
    }

    /// Which repository and which files.
    var downloaderConfiguration: ModelRepoDownloader.Configuration {
        switch engine {
        case .parakeet, .whisperKit:
            return .parakeet()
        case .nemotron:
            return .nemotron()
        }
    }

    /// A fresh, unloaded engine for the compile step.
    func makeEngine() -> SpeechModelProtocol {
        switch engine {
        case .parakeet, .whisperKit:
            return ParakeetEngine()
        case .nemotron:
            return NemotronEngine()
        }
    }

    /// What a load would find missing right now. Empty when the files are complete.
    func missingEntries() -> [String] {
        switch engine {
        case .parakeet, .whisperKit:
            return ParakeetCacheRepair.missingEntries()
        case .nemotron:
            return NemotronEngine.missingEntries()
        }
    }

    /// The `component` of the repair's diagnostic lines, so a log reader greps one engine.
    var repairLogComponent: String {
        switch engine {
        case .parakeet, .whisperKit:
            return "ParakeetCacheRepair"
        case .nemotron:
            return "NemotronCacheRepair"
        }
    }

    /// Removes every cached file of this engine's model, best effort or throwing.
    ///
    /// Parakeet clears every `AsrModelVersion` directory it has ever used, as it always did.
    /// Nemotron clears its whole repository directory, every ship and tier in it: Dictus only
    /// ever writes one variant there, and a stale one left by an older build is the user's
    /// disk too.
    func removeCachedFiles(fileManager: FileManager = .default) throws {
        switch engine {
        case .parakeet:
            for version: AsrModelVersion in [.v2, .v3] {
                let versionDir = AsrModels.defaultCacheDirectory(for: version)
                if fileManager.fileExists(atPath: versionDir.path) {
                    try fileManager.removeItem(at: versionDir)
                }
            }
        case .nemotron:
            let directory = NemotronEngine.repositoryCacheDirectory
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        case .whisperKit:
            break
        }
    }
}
