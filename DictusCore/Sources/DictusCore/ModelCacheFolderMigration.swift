// DictusCore/Sources/DictusCore/ModelCacheFolderMigration.swift
// Moves a model cache from a folder name an SDK stopped using into the one it uses now (#558).
import Foundation

/// Merges a model cache folder the SDK no longer reads into the folder it reads now.
///
/// WHY THIS EXISTS (#558, "layer 0"): FluidAudio 0.15 changed where Parakeet's cache lives.
/// `Repo.folderName` used to be the repository name, `parakeet-tdt-0.6b-v3-coreml`; it now
/// strips `-coreml`, so the cache is `parakeet-tdt-0.6b-v3`. Every install that downloaded
/// Parakeet on 0.12 holds 483 MB in a folder nothing reads any more. Left alone, the model
/// would read as not installed, layer 1 would download all of it again, and an offline user
/// would lose the default model outright.
///
/// THE RULE: every entry of the old folder that the new folder lacks is MOVED into it, then
/// the old folder is removed. A move on the same volume is a rename, instant and without a
/// second copy on disk. When both folders exist, neither is chosen as the winner: the new
/// folder keeps what it has, and the old one fills its gaps. An entry the new folder already
/// holds is not compared, and the old copy of it is deleted with the old folder; the
/// completeness rule that runs after this (`ParakeetModelRepository.missingEntries`) then
/// says whether what remains is loadable, and layers 2 and 1 complete whatever it is not.
///
/// Entry by entry at the top level only (a `.mlmodelc` bundle moves as one directory): the
/// completeness rule judges bundles whole, so a bundle is either taken or left, never merged
/// file by file with a partial one.
///
/// Idempotent: with no old folder there is nothing to do, which is every launch after the
/// first.
public enum ModelCacheFolderMigration {

    /// What one migration did, for the log.
    public struct Outcome: Equatable, Sendable {
        /// Top-level entries moved from the old folder, sorted.
        public let moved: [String]
        /// Top-level entries left behind because the new folder already had them, sorted.
        /// They are deleted with the old folder.
        public let alreadyPresent: [String]
        /// Whether an old folder existed at all. `false` means nothing happened.
        public let foundLegacyFolder: Bool
        /// Whether the old folder is gone afterwards.
        public let removedLegacyFolder: Bool

        public init(moved: [String], alreadyPresent: [String], foundLegacyFolder: Bool, removedLegacyFolder: Bool) {
            self.moved = moved
            self.alreadyPresent = alreadyPresent
            self.foundLegacyFolder = foundLegacyFolder
            self.removedLegacyFolder = removedLegacyFolder
        }

        static let nothingToDo = Outcome(moved: [], alreadyPresent: [], foundLegacyFolder: false, removedLegacyFolder: false)
    }

    /// Merges `legacyFolder` into `currentFolder`, then removes `legacyFolder`.
    ///
    /// Never throws: a migration that fails half way must not stop the app launching. What
    /// did not move stays in the old folder (removal is only attempted once every missing
    /// entry has moved), and the completeness rule downstream reports the model as incomplete,
    /// which layer 1 repairs.
    public static func migrate(
        from legacyFolder: URL,
        to currentFolder: URL,
        fileManager: FileManager = .default
    ) -> Outcome {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyFolder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .nothingToDo
        }

        let entries = ((try? fileManager.contentsOfDirectory(atPath: legacyFolder.path)) ?? []).sorted()

        do {
            try fileManager.createDirectory(at: currentFolder, withIntermediateDirectories: true)
        } catch {
            return Outcome(moved: [], alreadyPresent: [], foundLegacyFolder: true, removedLegacyFolder: false)
        }

        var moved: [String] = []
        var alreadyPresent: [String] = []
        var everyMissingEntryMoved = true
        for entry in entries {
            let destination = currentFolder.appendingPathComponent(entry)
            if fileManager.fileExists(atPath: destination.path) {
                alreadyPresent.append(entry)
                continue
            }
            do {
                try fileManager.moveItem(at: legacyFolder.appendingPathComponent(entry), to: destination)
                moved.append(entry)
            } catch {
                everyMissingEntryMoved = false
            }
        }

        var removed = false
        if everyMissingEntryMoved {
            removed = (try? fileManager.removeItem(at: legacyFolder)) != nil
        }
        return Outcome(
            moved: moved,
            alreadyPresent: alreadyPresent,
            foundLegacyFolder: true,
            removedLegacyFolder: removed
        )
    }
}
