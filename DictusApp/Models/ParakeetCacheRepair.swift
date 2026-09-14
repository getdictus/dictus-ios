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
/// Three layers answer it, decided on #558, and they run in this order:
/// - **Layer 0, here, permanent.** FluidAudio 0.15 also renamed the cache folder,
///   `parakeet-tdt-0.6b-v3-coreml` to `parakeet-tdt-0.6b-v3`. `migrateLegacyCacheFolder`
///   moves a 0.12 cache into the folder 0.15 reads, before anything judges it.
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

    /// The folders FluidAudio 0.12 cached Parakeet in, by version: `Repo.folderName` was then
    /// the repository name with its `-coreml` suffix, which 0.15 strips. Written out rather
    /// than derived, because the SDK that derived them no longer exists in this build.
    /// v2 is listed for deletion only; Dictus never shipped it, but the old delete path
    /// cleared both, and the new one must not leave what the old one would have removed.
    static let legacyCacheFolderNames: [AsrModelVersion: String] = [
        .v3: "parakeet-tdt-0.6b-v3-coreml",
        .v2: "parakeet-tdt-0.6b-v2-coreml"
    ]

    /// Where a FluidAudio 0.12 install kept the Parakeet v3 cache.
    static var legacyCacheDirectory: URL {
        MLModelConfigurationUtils.defaultModelsDirectory()
            .appendingPathComponent(legacyCacheFolderNames[.v3] ?? "parakeet-tdt-0.6b-v3-coreml", isDirectory: true)
    }

    /// Bundles the 0.12 loader used that 0.15.7 never opens: `JointDecision.mlmodelc`, which
    /// `JointDecisionv3.mlmodelc` replaced.
    ///
    /// Derived rather than written out: the 0.12 set is still `ModelNames.ASR.requiredModels`,
    /// and whatever it names that the v3 set does not is dead weight. Derived this way it can
    /// never name a bundle the loader needs. Measured on device 2026-09-14: layer 0 as first
    /// written carried it across, 12.7 MB on every migrated phone.
    static let obsoleteModelBundles: Set<String> = ModelNames.ASR.requiredModels.subtracting(ParakeetEngine.requiredModelBundles)

    /// Layer 0 (#558): moves a cache left in the 0.12 folder into the folder 0.15 reads, and
    /// removes what 0.15 never loads.
    ///
    /// The rule and its cases are `ModelCacheFolderMigration`'s, in DictusCore where they are
    /// tested. Completeness is `ParakeetModelRepository`'s, the load guard's own rule. Logs only
    /// when it did something, so a normal launch writes nothing.
    static func migrateLegacyCacheFolder(context: String, fileManager: FileManager = .default) {
        let outcome = ModelCacheFolderMigration.migrate(
            from: legacyCacheDirectory,
            to: cacheDirectory,
            obsoleteEntries: obsoleteModelBundles,
            isComplete: { url in
                url.pathExtension == "mlmodelc"
                    ? ParakeetModelRepository.isCompiledModelBundle(url, fileManager: fileManager)
                    : ParakeetModelRepository.isRegularFile(url, fileManager: fileManager)
            },
            fileManager: fileManager
        )
        guard outcome.didAnything else { return }
        // Built field by field: one concatenated interpolation of this length is more than the
        // type checker will solve in reasonable time.
        let fields: [String] = [
            "context=\(context)",
            "from=\(legacyCacheDirectory.lastPathComponent)",
            "to=\(cacheDirectory.lastPathComponent)",
            "legacyFound=\(outcome.foundLegacyFolder)",
            "moved=\(list(outcome.moved))",
            "replaced=\(list(outcome.replaced))",
            "alreadyPresent=\(list(outcome.alreadyPresent))",
            "obsoleteRemoved=\(list(outcome.removedObsolete))",
            "legacyRemoved=\(outcome.removedLegacyFolder)"
        ]
        PersistentLog.log(.diagnosticProbe(
            component: "ParakeetCacheRepair",
            instanceID: "parakeet-tdt-0.6b-v3",
            action: "legacyFolderMigrated",
            details: fields.joined(separator: " ")
        ))
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
    /// A list for a log field, `none` when empty.
    private static func list(_ names: [String]) -> String {
        names.isEmpty ? "none" : names.joined(separator: ",")
    }

    @discardableResult
    static func restoreFromBundleIfNeeded(context: String, fileManager: FileManager = .default) -> [String] {
        // Layer 0 first, every time: the bundle restore below acts only on a cache that exists
        // in the folder 0.15 reads, and a 0.12 cache is not there until it has moved. With no
        // old folder this is one `fileExists`.
        migrateLegacyCacheFolder(context: context, fileManager: fileManager)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: cacheDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return missingEntries(fileManager: fileManager)
        }

        sweepStaleStaging(fileManager: fileManager)

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

    /// Prefix of the staging directories `copyBundle` creates, hidden and named for the sweep.
    static let stagingPrefix = ".restoring-"

    /// Removes staging directories a previous restore left: the process died between the copy
    /// and the move (CodeRabbit, PR #561). Each is a hidden, uniquely named partial copy that
    /// nothing reads and nothing else would ever delete, short of deleting the model.
    private static func sweepStaleStaging(fileManager: FileManager) {
        let names = (try? fileManager.contentsOfDirectory(atPath: cacheDirectory.path)) ?? []
        for name in names where name.hasPrefix(stagingPrefix) {
            try? fileManager.removeItem(at: cacheDirectory.appendingPathComponent(name, isDirectory: true))
        }
    }

    /// Copies one compiled bundle into the cache, replacing any shell of it.
    ///
    /// Staged under a temporary name and moved into place, so a copy interrupted by the
    /// process dying leaves a directory the completeness rule refuses (no bundle of that
    /// name) rather than a half-written bundle under the real name, which it might not. A
    /// failure at any step after the staging directory exists removes it, and a death the
    /// process cannot clean up after is swept by the next restore.
    private static func copyBundle(from source: URL, named name: String, fileManager: FileManager) throws {
        let destination = cacheDirectory.appendingPathComponent(name, isDirectory: true)
        let staging = cacheDirectory.appendingPathComponent("\(stagingPrefix)\(name)-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.copyItem(at: source, to: staging)
            if fileManager.fileExists(atPath: destination.path) {
                // A shell an interrupted download left: `missingEntries` already said it is
                // not a compiled bundle, so nothing usable is lost by removing it.
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }
}
