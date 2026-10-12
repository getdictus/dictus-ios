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
    private static let manifestFileName = "manifest.json"

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

    /// One model's staging directory.
    ///
    /// The folder name is a sanitized identifier and is never parsed back: `loadAll`
    /// reads the identifier out of the manifest itself, so a model whose identifier
    /// needed escaping still reports its real name.
    static func directory(_ model: String) -> URL? {
        let safe = model.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? character
                : "_"
        }
        guard let root = rootDirectory else { return nil }
        return root.appendingPathComponent(String(safe), isDirectory: true)
    }

    static func manifestURL(_ model: String) -> URL? {
        directory(model)?.appendingPathComponent(manifestFileName)
    }

    /// The partial being assembled for one file. Empty path when the container is
    /// unreachable, which every caller turns into a plain file-system failure.
    static func partialURL(_ model: String, fileIndex: Int) -> URL {
        directory(model)?.appendingPathComponent("\(fileIndex).part")
            ?? URL(fileURLWithPath: "/dev/null/\(fileIndex).part")
    }

    static func chunkURL(_ model: String, fileIndex: Int, chunkIndex: Int) -> URL {
        directory(model)?.appendingPathComponent("\(fileIndex)-\(chunkIndex).chunk")
            ?? URL(fileURLWithPath: "/dev/null/\(fileIndex)-\(chunkIndex).chunk")
    }

    // MARK: Manifest

    static func save(_ manifest: ModelDownloadManifest) {
        guard let directory = directory(manifest.modelIdentifier),
              let url = manifestURL(manifest.modelIdentifier) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        // Atomic so a manifest is never read half written by the next launch.
        try? data.write(to: url, options: .atomic)
    }

    static func load(_ model: String) -> ModelDownloadManifest? {
        guard let url = manifestURL(model),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ModelDownloadManifest.self, from: data)
    }

    /// Every manifest on disk, keyed by the identifier each one names.
    static func loadAll() -> [String: ModelDownloadManifest] {
        guard let root = rootDirectory,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: root,
                  includingPropertiesForKeys: nil
              ) else {
            return [:]
        }
        var result: [String: ModelDownloadManifest] = [:]
        for entry in entries {
            let url = entry.appendingPathComponent(manifestFileName)
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(ModelDownloadManifest.self, from: data)
            else { continue }
            result[manifest.modelIdentifier] = manifest
        }
        return result
    }

    static func discard(_ model: String) {
        guard let directory = directory(model) else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Drops one file's partial and every chunk of it, leaving the rest of the download
    /// intact. Used when a range was refused or an assembled file failed its checksum.
    static func discardFile(_ model: String, fileIndex: Int) {
        try? FileManager.default.removeItem(at: partialURL(model, fileIndex: fileIndex))
        for index in storedChunkIndices(model, fileIndex: fileIndex) {
            try? FileManager.default.removeItem(
                at: chunkURL(model, fileIndex: fileIndex, chunkIndex: index)
            )
        }
    }

    // MARK: Chunks

    /// Chunk indices whose bytes are durably on disk for this file.
    static func storedChunkIndices(_ model: String, fileIndex: Int) -> Set<Int> {
        guard let directory = directory(model),
              let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }
        let prefix = "\(fileIndex)-"
        let suffix = ".chunk"
        var result: Set<Int> = []
        for entry in entries where entry.hasPrefix(prefix) && entry.hasSuffix(suffix) {
            let middle = entry.dropFirst(prefix.count).dropLast(suffix.count)
            if let index = Int(middle) { result.insert(index) }
        }
        return result
    }

    /// Moves a completed chunk out of the system's temporary location, which is emptied
    /// the instant `didFinishDownloadingTo` returns. This move is the whole reason the
    /// download is chunked: it is where in-flight bytes become durable ones.
    static func store(chunkAt location: URL, model: String, fileIndex: Int, chunkIndex: Int) throws {
        guard let directory = directory(model) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = chunkURL(model, fileIndex: fileIndex, chunkIndex: chunkIndex)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: location, to: destination)
    }

    /// Appends chunks, in the order given, to the file's partial and deletes them.
    ///
    /// Streamed in 1 MB reads: a chunk is 32 MB and this runs in an app iOS already
    /// watches for memory (issues #104, #362).
    static func append(chunks: [Int], ofFile fileIndex: Int, model: String, startingAt: Int64) throws {
        guard !chunks.isEmpty else { return }
        let partial = partialURL(model, fileIndex: fileIndex)
        if !FileManager.default.fileExists(atPath: partial.path) {
            FileManager.default.createFile(atPath: partial.path, contents: nil)
        }
        let writer = try FileHandle(forWritingTo: partial)
        defer { try? writer.close() }
        // Everything past the manifest's offset is unaccounted for — bytes a process
        // that died mid-append wrote and never recorded. Dropping them is what makes an
        // append idempotent, and an append that is not idempotent silently doubles a
        // chunk inside a 445 MB file.
        try writer.truncate(atOffset: UInt64(max(0, startingAt)))
        try writer.seekToEnd()

        for chunkIndex in chunks {
            let source = chunkURL(model, fileIndex: fileIndex, chunkIndex: chunkIndex)
            let reader = try FileHandle(forReadingFrom: source)
            defer { try? reader.close() }
            while let data = try reader.read(upToCount: 1 << 20), !data.isEmpty {
                try writer.write(contentsOf: data)
            }
            try? reader.close()
            try? FileManager.default.removeItem(at: source)
        }
        try writer.synchronize()
    }
}
