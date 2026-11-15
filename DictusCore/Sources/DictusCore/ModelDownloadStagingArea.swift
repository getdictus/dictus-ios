// DictusCore/Sources/DictusCore/ModelDownloadStagingArea.swift
// The directory that holds every unfinished model download: one folder per model, a manifest in each.
import Foundation

/// The root that holds one staging directory per model, each with its manifest.
///
/// WHY THIS LIVES IN DICTUSCORE (issue #493). What a launch adopts is whatever this
/// directory lists (`interruptedIdentifiers`), so "a cancelled download is not resumed on
/// the next launch" is a statement about this directory, and DictusApp has no test
/// bundle to prove it in. `ManifestStore` in DictusApp is the app's one instance of it,
/// rooted in `Application Support`; tests root one in a temporary directory.
public struct ModelDownloadStagingArea: Sendable {

    private static let manifestFileName = "manifest.json"

    /// The directory that holds one folder per model. Not created here.
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// One model's staging directory.
    ///
    /// The folder name is a sanitized identifier and is never parsed back: `loadAll`
    /// reads the identifier out of the manifest itself, so a model whose identifier
    /// needed escaping still reports its real name.
    public func directory(_ model: String) -> URL {
        let safe = model.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
                ? character
                : "_"
        }
        return root.appendingPathComponent(String(safe), isDirectory: true)
    }

    public func manifestURL(_ model: String) -> URL {
        directory(model).appendingPathComponent(Self.manifestFileName)
    }

    public func save(_ manifest: ModelDownloadManifest) {
        let directory = directory(manifest.modelIdentifier)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        // Atomic so a manifest is never read half written by the next launch.
        try? data.write(to: manifestURL(manifest.modelIdentifier), options: .atomic)
    }

    public func load(_ model: String) -> ModelDownloadManifest? {
        guard let data = try? Data(contentsOf: manifestURL(model)) else { return nil }
        return try? JSONDecoder().decode(ModelDownloadManifest.self, from: data)
    }

    /// Every manifest on disk, keyed by the identifier each one names.
    public func loadAll() -> [String: ModelDownloadManifest] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return [:]
        }
        var result: [String: ModelDownloadManifest] = [:]
        for entry in entries {
            let url = entry.appendingPathComponent(Self.manifestFileName)
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(ModelDownloadManifest.self, from: data)
            else { continue }
            result[manifest.modelIdentifier] = manifest
        }
        return result
    }

    /// Identifiers with a manifest on disk that has not finished transferring: exactly
    /// what `ModelManager.adoptInterruptedDownloads` resumes at launch (issue #449).
    public func interruptedIdentifiers() -> [String] {
        loadAll()
            .filter { !$0.value.isTransferComplete }
            .keys
            .sorted()
    }

    /// Removes one model's staging directory: its manifest, partials and chunks. The
    /// other models' directories are not touched.
    public func discard(_ model: String) {
        try? FileManager.default.removeItem(at: directory(model))
    }
}
