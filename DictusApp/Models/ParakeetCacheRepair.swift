// DictusApp/Models/ParakeetCacheRepair.swift
// Completes a Parakeet cache the loader cannot use, from the app bundle when it can (#558).
import Foundation
import DictusCore
import FluidAudio

/// Makes an incomplete Parakeet cache whole again without the network, when the app
/// bundle carries what is missing.
///
/// WHY THIS EXISTS: FluidAudio 0.15 loads Parakeet v3 with `JointDecisionv3.mlmodelc`
/// where 0.12 loaded `JointDecision.mlmodelc`. Every install that downloaded Parakeet
/// before the bump holds four complete bundles and not that one, so the first launch
/// after the update would find the default model unusable. The SDK is barred from
/// fetching it itself (`ModelHub.offlineMode`, set in `DictusApp.init`), and it should
/// be: that fetch is the silent download #252 removed from the load path.
///
/// Two layers answer it, decided on #558:
/// - **Layer 2, here, temporary.** The bundle carries the new joint, byte-identical to
///   the repository file, and a missing copy is restored from it before any load. The
///   first launch after the update works offline, with no download at all.
/// - **Layer 1, permanent.** Whatever the bundle cannot supply is fetched through
///   `ModelRepoDownloader` by `ModelManager.repairIncompleteModelsIfNeeded`, with
///   progress on the model card. It covers a user who skips the release carrying the
///   bundled joint, an interrupted transfer, and the next SDK bump that renames a file.
///
/// DictusApp only. FluidAudio is not linked into the keyboard extension, and the
/// extension never loads a model.
enum ParakeetCacheRepair {

    /// The compiled bundles the app ships for the migration, by name.
    ///
    /// REMOVE BEFORE THE 2.0.0 CUT, with the resource itself. The resource is the folder
    /// reference `DictusApp/ParakeetMigration/JointDecisionv3.mlmodelc` (12 658 756 bytes,
    /// fetched from `FluidInference/parakeet-tdt-0.6b-v3-coreml` at revision `7dd20fe`
    /// and checked byte for byte against the repository's hashes). It exists for 1.8.3,
    /// the release that moves users from FluidAudio 0.12 to 0.15, which is cut before
    /// 2.0.0. Removing it means: delete the folder and its `project.pbxproj` entries,
    /// empty this list, and leave everything else alone. A user who updates straight
    /// from a pre-1.8.3 build to 2.0.0 then goes through layer 1, which downloads the
    /// 12.7 MB joint with progress on the card. See `DictusApp/ParakeetMigration/README.md`.
    static let bundledModelBundles: Set<String> = ["JointDecisionv3.mlmodelc"]

    /// The Parakeet v3 cache directory FluidAudio loads from.
    static var cacheDirectory: URL {
        AsrModels.defaultCacheDirectory(for: .v3)
    }

    /// What the loader would find missing right now. Empty when the cache is complete.
    static func missingEntries(fileManager: FileManager = .default) -> [String] {
        ParakeetModelRepository.missingEntries(
            in: cacheDirectory,
            requiredModelBundles: ParakeetEngine.requiredModelBundles,
            vocabularyFileName: ModelNames.ASR.vocabularyFile,
            fileManager: fileManager
        )
    }

    /// Restores from the app bundle every missing entry the bundle carries.
    ///
    /// Cheap when there is nothing to do, and that is the common case: one directory
    /// check, then four bundle checks. So it runs at launch AND in front of every
    /// Parakeet load and download, rather than once, because a file can go missing
    /// between them and "before any Parakeet load" is the rule the brief states.
    ///
    /// Acts only on a cache that exists. A user who never downloaded Parakeet has no
    /// directory, and copying 12.7 MB into one would put a partial model on a device
    /// that asked for none. `downloadParakeetModel` creates the directory before it
    /// calls this, which is how a fresh download also takes the joint from here.
    ///
    /// - Parameter context: who asked, for the log.
    /// - Returns: what is still missing afterwards, which is what layer 1 has to fetch.
    @discardableResult
    static func restoreFromBundleIfNeeded(context: String, fileManager: FileManager = .default) -> [String] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: cacheDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return missingEntries(fileManager: fileManager)
        }

        let missing = missingEntries(fileManager: fileManager)
        let restorable = missing.filter { bundledModelBundles.contains($0) }
        guard !restorable.isEmpty else { return missing }

        var restored: [String] = []
        for name in restorable {
            guard let source = Bundle.main.url(
                forResource: (name as NSString).deletingPathExtension,
                withExtension: (name as NSString).pathExtension
            ) else {
                PersistentLog.log(.diagnosticProbe(
                    component: "ParakeetCacheRepair",
                    instanceID: name,
                    action: "bundleCopyUnavailable",
                    details: "context=\(context) reason=notInAppBundle"
                ))
                continue
            }
            do {
                try copyBundle(from: source, named: name, fileManager: fileManager)
                restored.append(name)
            } catch {
                PersistentLog.log(.diagnosticProbe(
                    component: "ParakeetCacheRepair",
                    instanceID: name,
                    action: "bundleCopyFailed",
                    details: "context=\(context) error=\(error.localizedDescription)"
                ))
            }
        }

        let stillMissing = missingEntries(fileManager: fileManager)
        if !restored.isEmpty {
            PersistentLog.log(.diagnosticProbe(
                component: "ParakeetCacheRepair",
                instanceID: "parakeet-tdt-0.6b-v3",
                action: "restoredFromBundle",
                details: "context=\(context) missing=\(missing.joined(separator: ",")) "
                    + "restored=\(restored.joined(separator: ",")) source=bundle "
                    + "stillMissing=\(stillMissing.isEmpty ? "none" : stillMissing.joined(separator: ","))"
            ))
        }
        return stillMissing
    }

    /// Copies one compiled bundle into the cache, replacing any shell of it.
    ///
    /// Staged under a temporary name and moved into place, so a copy interrupted by the
    /// process dying leaves a directory the completeness rule refuses (no bundle of that
    /// name) rather than a half-written bundle under the real name, which it might not.
    private static func copyBundle(from source: URL, named name: String, fileManager: FileManager) throws {
        let destination = cacheDirectory.appendingPathComponent(name, isDirectory: true)
        let staging = cacheDirectory.appendingPathComponent(".\(name).restoring-\(UUID().uuidString)", isDirectory: true)
        try fileManager.copyItem(at: source, to: staging)
        if fileManager.fileExists(atPath: destination.path) {
            // A shell an interrupted download left: `missingEntries` already said it is
            // not a compiled bundle, so nothing usable is lost by removing it.
            try fileManager.removeItem(at: destination)
        }
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }
}
