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
/// THE RULE, entry by entry at the top level (a `.mlmodelc` bundle moves as one directory):
/// - An **obsolete** entry, one the new SDK never loads, is not moved. It is deleted with the
///   old folder, and deleted from the new folder too if a previous migration already moved it
///   there (#558 device test: the 0.12 `JointDecision.mlmodelc`, 12.7 MB 0.15 never opens,
///   had been carried across).
/// - An entry the new folder **lacks** is moved into it: a rename on the same volume, instant,
///   without a second copy on disk.
/// - An entry both folders hold: the new folder's copy is kept when it is **complete**. When
///   it is incomplete (an interrupted 0.15 download) and the old copy is complete, the old
///   copy replaces it: an offline user must not lose a complete bundle to a partial one.
///   When neither is complete, the new folder's copy stays, and layers 2 and 1 repair it.
/// - Then the old folder is removed, but only if every entry that had to move did. What did
///   not move stays where it was, and the next launch tries again.
///
/// "Complete" is the caller's rule (`isComplete`), so this type states the merge and the app
/// states what a usable Parakeet bundle is, through `ParakeetModelRepository`, the same rule
/// the load guard applies.
///
/// Idempotent: with no old folder and nothing obsolete left, nothing happens, which is every
/// launch after the first.
public enum ModelCacheFolderMigration {

    /// What one migration did, for the log.
    public struct Outcome: Equatable, Sendable {
        /// Top-level entries moved from the old folder into a gap in the new one, sorted.
        public let moved: [String]
        /// Entries whose incomplete copy in the new folder was replaced by a complete old copy.
        public let replaced: [String]
        /// Entries left behind because the new folder already had a copy it keeps, sorted.
        /// They are deleted with the old folder.
        public let alreadyPresent: [String]
        /// Obsolete entries removed, from either folder, sorted.
        public let removedObsolete: [String]
        /// Whether an old folder existed at all.
        public let foundLegacyFolder: Bool
        /// Whether the old folder is gone afterwards.
        public let removedLegacyFolder: Bool

        public init(moved: [String], replaced: [String] = [], alreadyPresent: [String],
                    removedObsolete: [String] = [], foundLegacyFolder: Bool, removedLegacyFolder: Bool) {
            self.moved = moved
            self.replaced = replaced
            self.alreadyPresent = alreadyPresent
            self.removedObsolete = removedObsolete
            self.foundLegacyFolder = foundLegacyFolder
            self.removedLegacyFolder = removedLegacyFolder
        }

        /// Whether anything happened that a log reader needs to know about.
        public var didAnything: Bool {
            foundLegacyFolder || !removedObsolete.isEmpty
        }
    }

    /// Merges `legacyFolder` into `currentFolder`, then removes `legacyFolder`.
    ///
    /// Never throws: a migration that fails half way must not stop the app launching. See the
    /// type's rule for what survives a failure.
    ///
    /// - Parameters:
    ///   - obsoleteEntries: top-level names the current SDK never loads. Never moved, and
    ///     removed from `currentFolder` when present there.
    ///   - isComplete: whether the entry at a URL is usable as it stands.
    public static func migrate(
        from legacyFolder: URL,
        to currentFolder: URL,
        obsoleteEntries: Set<String> = [],
        isComplete: (URL) -> Bool,
        fileManager: FileManager = .default
    ) -> Outcome {
        // Obsolete entries a previous migration carried into the new folder, first: they are
        // there whether or not an old folder still is.
        var removedObsolete = obsoleteEntries.sorted().filter { name in
            let url = currentFolder.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path) else { return false }
            return (try? fileManager.removeItem(at: url)) != nil
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyFolder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return Outcome(moved: [], alreadyPresent: [], removedObsolete: removedObsolete,
                           foundLegacyFolder: false, removedLegacyFolder: false)
        }

        let entries = ((try? fileManager.contentsOfDirectory(atPath: legacyFolder.path)) ?? []).sorted()

        do {
            try fileManager.createDirectory(at: currentFolder, withIntermediateDirectories: true)
        } catch {
            return Outcome(moved: [], alreadyPresent: [], removedObsolete: removedObsolete,
                           foundLegacyFolder: true, removedLegacyFolder: false)
        }

        var moved: [String] = []
        var replaced: [String] = []
        var alreadyPresent: [String] = []
        var obsoleteInLegacyFolder: [String] = []
        var everyEntryThatHadToMoveMoved = true
        for entry in entries {
            let source = legacyFolder.appendingPathComponent(entry)
            let destination = currentFolder.appendingPathComponent(entry)

            if obsoleteEntries.contains(entry) {
                // Goes with the old folder, and is reported once it has.
                obsoleteInLegacyFolder.append(entry)
                continue
            }

            if fileManager.fileExists(atPath: destination.path) {
                guard !isComplete(destination), isComplete(source) else {
                    alreadyPresent.append(entry)
                    continue
                }
                // A partial copy against a complete one. Removing the partial first loses
                // nothing usable, and if the move then fails the complete copy is still in the
                // old folder, which is kept because the flag below goes false.
                do {
                    try fileManager.removeItem(at: destination)
                    try fileManager.moveItem(at: source, to: destination)
                    replaced.append(entry)
                } catch {
                    everyEntryThatHadToMoveMoved = false
                }
                continue
            }

            do {
                try fileManager.moveItem(at: source, to: destination)
                moved.append(entry)
            } catch {
                everyEntryThatHadToMoveMoved = false
            }
        }

        var removed = false
        if everyEntryThatHadToMoveMoved {
            removed = (try? fileManager.removeItem(at: legacyFolder)) != nil
        }
        if removed {
            removedObsolete = Array(Set(removedObsolete).union(obsoleteInLegacyFolder))
        }
        return Outcome(
            moved: moved,
            replaced: replaced,
            alreadyPresent: alreadyPresent,
            removedObsolete: removedObsolete.sorted(),
            foundLegacyFolder: true,
            removedLegacyFolder: removed
        )
    }
}
