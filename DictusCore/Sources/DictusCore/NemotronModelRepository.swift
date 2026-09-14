// DictusCore/Sources/DictusCore/NemotronModelRepository.swift
// Where the Nemotron 3.5 model comes from, and when its files on disk are complete (#558).
import Foundation

/// The Nemotron 3.5 ASR multilingual ship Dictus downloads, and the completeness rule for it.
///
/// WHY IN DictusCore when FluidAudio is DictusApp-only: the same reason as
/// `ParakeetModelRepository`. The rule has to be testable with `swift test`, which cannot
/// reach DictusApp, and the file names come from the caller, which reads FluidAudio's own
/// `ModelNames.NemotronMultilingualStreaming`, so a renamed bundle is a compile-time change
/// in the app rather than a silent divergence here.
///
/// WHY THIS SHIP AND THIS TIER, from #558:
/// - `multilingual/`, not `latin/`. The latin ship covers six languages; Dictus offers every
///   language Nemotron can transcribe through auto-detect. FluidAudio documents both ships
///   as scoring identically, so #552's figures, taken on the latin ship, carry over.
/// - `2240ms`, the tier FluidAudio recommends for the full-vocabulary models: the 13 087-token
///   joint only fits the Neural Engine's working set efficiently there.
///
/// WHY NOT FluidAudio's `downloadVariant`: it bypasses Dictus's progress and cancellation,
/// and it picks the `latin/` ship for any `fr`/`en`/`es`/`de` code. `ModelRepoDownloader`
/// downloads `variantDirectory` from `repositoryID` instead, into the directory FluidAudio's
/// own cache layout would use.
public enum NemotronModelRepository {

    /// The catalogue identifier of the one Nemotron entry, in `ModelInfo`.
    ///
    /// Names the variant it downloads, so a second tier or the latin ship, should one ever be
    /// added, gets an identifier of its own instead of silently reusing this one's warmth
    /// record and cache.
    public static let catalogueIdentifier = "nemotron-3.5-asr-multilingual-2240ms"

    /// The HuggingFace repository the model is downloaded from.
    public static let repositoryID = "FluidInference/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML"

    /// The repository-relative directory of the one variant Dictus uses. It is the model
    /// directory `StreamingNemotronMultilingualAsrManager.loadModels(from:)` is given.
    public static let variantDirectory = "multilingual/2240ms"

    /// Repository-relative paths a completed download must have left: the leaf files inside
    /// every required bundle, then the root files, all under `variantDirectory`.
    ///
    /// Same leaf-not-directory rule as Parakeet (#433, #438), through the same
    /// `ParakeetModelRepository.requiredBundleEntries`: every Nemotron bundle in the repository
    /// carries `coremldata.bin`, `model.mil` and `weights/weight.bin` (tree read 2026-09-14).
    ///
    /// - Parameters:
    ///   - requiredModelBundles: the compiled bundles the engine loads. Sorted here.
    ///   - rootFileNames: the plain files the engine reads beside them (`metadata.json`,
    ///     `tokenizer.json`), in the order given.
    public static func requiredDownloadPaths(
        requiredModelBundles: Set<String>,
        rootFileNames: [String]
    ) -> [String] {
        let bundlePaths = requiredModelBundles.sorted().flatMap { bundle in
            ParakeetModelRepository.requiredBundleEntries.map { "\(variantDirectory)/\(bundle)/\($0)" }
        }
        return bundlePaths + rootFileNames.map { "\(variantDirectory)/\($0)" }
    }

    /// The required entries not usable on disk under `modelDirectory`: each bundle that is not
    /// a compiled Core ML directory, then each root file that is not a regular file. Empty
    /// when the model can be loaded without the network.
    ///
    /// - Parameter modelDirectory: the local copy of `variantDirectory`.
    public static func missingEntries(
        in modelDirectory: URL,
        requiredModelBundles: Set<String>,
        rootFileNames: [String],
        fileManager: FileManager = .default
    ) -> [String] {
        let missingBundles = requiredModelBundles.sorted().filter { bundle in
            !ParakeetModelRepository.isCompiledModelBundle(
                modelDirectory.appendingPathComponent(bundle, isDirectory: true),
                fileManager: fileManager
            )
        }
        let missingFiles = rootFileNames.filter { name in
            !ParakeetModelRepository.isRegularFile(
                modelDirectory.appendingPathComponent(name),
                fileManager: fileManager
            )
        }
        return missingBundles + missingFiles
    }

    /// `modelDirectory` when it holds a complete model, otherwise `nil`.
    ///
    /// The dictation path treats `nil` as "download it in the model manager" and never
    /// downloads anything itself (#252). An empty requirement never passes, for the same
    /// reason as Parakeet's: it would call any directory, including a missing one, complete.
    public static func installedModelDirectory(
        _ modelDirectory: URL,
        requiredModelBundles: Set<String>,
        rootFileNames: [String],
        fileManager: FileManager = .default
    ) -> URL? {
        guard !requiredModelBundles.isEmpty else { return nil }
        let missing = missingEntries(
            in: modelDirectory,
            requiredModelBundles: requiredModelBundles,
            rootFileNames: rootFileNames,
            fileManager: fileManager
        )
        return missing.isEmpty ? modelDirectory : nil
    }
}
