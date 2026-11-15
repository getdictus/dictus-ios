// DictusApp/Models/ModelDownloadManifestStore.swift
// The durable staging area of an unfinished model download: manifest, partials, landed chunks.
import Foundation
import DictusCore

/// Where an unfinished model download keeps its manifest, its partials and the chunks
/// that have landed but are not yet folded in.
///
/// WHY A STAGING DIRECTORY OF ITS OWN, and not the engine's cache directory: everything
/// in there is a promise. `AsrModels.modelsExist`, `WhisperModelRepository`,
/// `ParakeetModelRepository` and the downloader's own tripwire all read that directory
/// as "a file that exists is a file that finished", and a half-written weight blob
/// sitting next to the finished ones would break that promise for every one of them.
/// Partial bytes live here until they are whole; a file crosses over by one atomic move.
///
/// WHY `Application Support` and not the App Group container: only DictusApp downloads
/// models. The keyboard extension has no business seeing a half-downloaded file, and
/// the extension's 50 MB budget has no business paying for the directory scan.
enum ManifestStore {

    private static let folderName = "DictusModelDownloads"

    /// Root of the staging area, created on demand.
    static var rootDirectory: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let root = support.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// The staging area itself (issue #493 moved its file-system steps to DictusCore,
    /// where they are tested), or nil when the container is unreachable.
    private static var area: ModelDownloadStagingArea? {
        rootDirectory.map(ModelDownloadStagingArea.init(root:))
    }

    /// One model's staging directory. See `ModelDownloadStagingArea.directory`.
    static func directory(_ model: String) -> URL? {
        area?.directory(model)
    }

    /// The disk half of one model's staging area: chunks, partials, absorb, publish
    /// (issue #732 moved it to DictusCore, where it is tested). A `/dev/null` directory
    /// when the container is unreachable, which every caller turns into a plain
    /// file-system failure.
    static func staging(_ model: String) -> ModelDownloadStaging {
        ModelDownloadStaging(directory: directory(model) ?? URL(fileURLWithPath: "/dev/null"))
    }

    // MARK: Manifest

    static func save(_ manifest: ModelDownloadManifest) {
        area?.save(manifest)
    }

    static func load(_ model: String) -> ModelDownloadManifest? {
        area?.load(model)
    }

    /// Every manifest on disk, keyed by the identifier each one names.
    static func loadAll() -> [String: ModelDownloadManifest] {
        area?.loadAll() ?? [:]
    }

    /// Identifiers with a manifest on disk that has not finished transferring.
    static func interruptedIdentifiers() -> [String] {
        area?.interruptedIdentifiers() ?? []
    }

    static func discard(_ model: String) {
        area?.discard(model)
    }

    /// Drops one file's partial and every chunk of it, leaving the rest of the download
    /// intact. Used when a range was refused or an assembled file failed its checksum.
    static func discardFile(_ model: String, fileIndex: Int) {
        staging(model).discardFile(fileIndex: fileIndex)
    }
}

// MARK: - What a fresh process can read about a download

// The service's answers that need nothing but the manifest on disk. Here, next to the store
// they read, so the service's file stays within SwiftLint's length budget (issue #493).
extension BackgroundModelDownloadService {

    /// Identifiers with a manifest on disk that has not finished transferring.
    /// Read straight from the file system so a fresh process can answer it.
    static func interruptedModelIdentifiers() -> [String] {
        ManifestStore.interruptedIdentifiers()
    }

    /// Whether a transfer for this model is already under way — a manifest on disk that
    /// has not finished. Read straight from the file system, so it answers in a process
    /// that has done nothing yet.
    static func hasUnfinishedTransfer(for identifier: String) -> Bool {
        guard let manifest = ManifestStore.load(identifier) else { return false }
        return !manifest.isTransferComplete
    }

    /// Durable progress of an interrupted download, for a screen that has to show
    /// something before the first delegate callback of this process arrives.
    static func persistedProgress(for identifier: String) -> ModelRepoDownloader.Progress? {
        guard let manifest = ManifestStore.load(identifier) else { return nil }
        return ModelRepoDownloader.Progress(
            bytesDownloaded: manifest.receivedBytes,
            totalBytes: manifest.totalBytes,
            completedFiles: manifest.completedFileCount,
            totalFiles: manifest.files.count
        )
    }
}
