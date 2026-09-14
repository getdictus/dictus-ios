// DictusCore/Tests/DictusCoreTests/ModelCacheFolderMigrationTests.swift
// The layer-0 rule of #558: Parakeet's cache folder moved in FluidAudio 0.15.
import XCTest
@testable import DictusCore

final class ModelCacheFolderMigrationTests: XCTestCase {

    private var root: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ModelCacheFolderMigrationTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let root {
            try? FileManager.default.removeItem(at: root)
        }
        root = nil
        try super.tearDownWithError()
    }

    private func folders() throws -> (legacy: URL, current: URL) {
        let root = try XCTUnwrap(root)
        return (root.appendingPathComponent("parakeet-tdt-0.6b-v3-coreml", isDirectory: true),
                root.appendingPathComponent("parakeet-tdt-0.6b-v3", isDirectory: true))
    }

    /// A bundle with a marker whose content says where it came from.
    private func makeBundle(_ name: String, in folder: URL, tag: String) throws {
        let bundle = folder.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try Data(tag.utf8).write(to: bundle.appendingPathComponent("coremldata.bin"))
    }

    private func tag(of name: String, in folder: URL) throws -> String {
        String(decoding: try Data(contentsOf: folder.appendingPathComponent("\(name)/coremldata.bin")), as: UTF8.self)
    }

    /// The app's rule, restated for the tests: a bundle is complete when its marker is there.
    /// (`ParakeetModelRepository.isCompiledModelBundle` asks for more; the merge only needs a yes
    /// or a no, and this keeps the fixtures small.)
    private func isComplete(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("coremldata.bin").path)
            || (url.pathExtension == "json" && FileManager.default.fileExists(atPath: url.path))
    }

    private func migrate(_ legacy: URL, _ current: URL, obsolete: Set<String> = []) -> ModelCacheFolderMigration.Outcome {
        ModelCacheFolderMigration.migrate(from: legacy, to: current, obsoleteEntries: obsolete, isComplete: isComplete)
    }

    /// A bundle directory with no marker: an interrupted download.
    private func makePartialBundle(_ name: String, in folder: URL) throws {
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("\(name)/weights", isDirectory: true), withIntermediateDirectories: true)
    }

    private func entries(_ folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    /// The update from 0.12: everything sits in the old folder, the new one does not exist.
    func testOldFolderOnlyMovesEverythingAndRemovesIt() throws {
        let (legacy, current) = try folders()
        for bundle in ["Decoder.mlmodelc", "Encoder.mlmodelc", "JointDecision.mlmodelc", "Preprocessor.mlmodelc"] {
            try makeBundle(bundle, in: legacy, tag: "old")
        }
        try Data("{}".utf8).write(to: legacy.appendingPathComponent("parakeet_vocab.json"))

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome.moved, ["Decoder.mlmodelc", "Encoder.mlmodelc", "JointDecision.mlmodelc",
                                       "Preprocessor.mlmodelc", "parakeet_vocab.json"])
        XCTAssertEqual(outcome.alreadyPresent, [])
        XCTAssertTrue(outcome.foundLegacyFolder)
        XCTAssertTrue(outcome.removedLegacyFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(entries(current), outcome.moved)
        XCTAssertEqual(try tag(of: "Encoder.mlmodelc", in: current), "old")
    }

    /// Every launch after the first: nothing to do, nothing touched.
    func testNewFolderOnlyIsLeftAlone() throws {
        let (legacy, current) = try folders()
        try makeBundle("Encoder.mlmodelc", in: current, tag: "new")

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome, ModelCacheFolderMigration.Outcome(
            moved: [], alreadyPresent: [], foundLegacyFolder: false, removedLegacyFolder: false))
        XCTAssertFalse(outcome.didAnything)
        XCTAssertEqual(entries(current), ["Encoder.mlmodelc"])
        XCTAssertEqual(try tag(of: "Encoder.mlmodelc", in: current), "new")
    }

    /// Both partial, e.g. a 0.15 download interrupted over an old cache: the old folder fills
    /// the new one's gaps, the new one keeps what it has, and no winner is chosen.
    func testBothPartialFillsTheGapsAndKeepsTheNewFoldersEntries() throws {
        let (legacy, current) = try folders()
        try makeBundle("Encoder.mlmodelc", in: legacy, tag: "old")
        try makeBundle("Decoder.mlmodelc", in: legacy, tag: "old")
        try makeBundle("Decoder.mlmodelc", in: current, tag: "new")
        try makeBundle("JointDecisionv3.mlmodelc", in: current, tag: "new")

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome.moved, ["Encoder.mlmodelc"])
        XCTAssertEqual(outcome.alreadyPresent, ["Decoder.mlmodelc"])
        XCTAssertTrue(outcome.removedLegacyFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(entries(current), ["Decoder.mlmodelc", "Encoder.mlmodelc", "JointDecisionv3.mlmodelc"])
        XCTAssertEqual(try tag(of: "Decoder.mlmodelc", in: current), "new")
        XCTAssertEqual(try tag(of: "Encoder.mlmodelc", in: current), "old")
    }

    /// A device that never downloaded Parakeet: no folder is created.
    func testNeitherFolderDoesNothingAndCreatesNothing() throws {
        let (legacy, current) = try folders()

        let outcome = migrate(legacy, current)

        XCTAssertFalse(outcome.foundLegacyFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
    }

    /// Running it again after a migration is the new-folder-only case.
    func testASecondRunIsANoOp() throws {
        let (legacy, current) = try folders()
        try makeBundle("Encoder.mlmodelc", in: legacy, tag: "old")
        _ = migrate(legacy, current)

        let second = migrate(legacy, current)

        XCTAssertFalse(second.foundLegacyFolder)
        XCTAssertEqual(entries(current), ["Encoder.mlmodelc"])
    }

    // MARK: - Review and device findings (#558)

    /// CodeRabbit, PR #561: an interrupted 0.15 download left a partial bundle in the new folder
    /// while the old one holds it complete. The complete copy must win, or an offline user loses
    /// a bundle nothing can bring back.
    func testACompleteLegacyBundleReplacesAPartialDestination() throws {
        let (legacy, current) = try folders()
        try makeBundle("Encoder.mlmodelc", in: legacy, tag: "old-complete")
        try makePartialBundle("Encoder.mlmodelc", in: current)

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome.replaced, ["Encoder.mlmodelc"])
        XCTAssertEqual(outcome.alreadyPresent, [])
        XCTAssertTrue(outcome.removedLegacyFolder)
        XCTAssertEqual(try tag(of: "Encoder.mlmodelc", in: current), "old-complete")
    }

    /// Both partial: nothing is gained by swapping, the new folder's copy stays for layers 2 and 1.
    func testTwoPartialCopiesKeepTheDestination() throws {
        let (legacy, current) = try folders()
        try makePartialBundle("Encoder.mlmodelc", in: legacy)
        try makePartialBundle("Encoder.mlmodelc", in: current)
        try Data("new-marker".utf8).write(
            to: current.appendingPathComponent("Encoder.mlmodelc/weights/partial.bin"))

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome.replaced, [])
        XCTAssertEqual(outcome.alreadyPresent, ["Encoder.mlmodelc"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: current.appendingPathComponent("Encoder.mlmodelc/weights/partial.bin").path))
    }

    /// A complete destination is never replaced, even by a complete old copy.
    func testACompleteDestinationIsNeverReplaced() throws {
        let (legacy, current) = try folders()
        try makeBundle("Decoder.mlmodelc", in: legacy, tag: "old")
        try makeBundle("Decoder.mlmodelc", in: current, tag: "new")

        let outcome = migrate(legacy, current)

        XCTAssertEqual(outcome.alreadyPresent, ["Decoder.mlmodelc"])
        XCTAssertEqual(try tag(of: "Decoder.mlmodelc", in: current), "new")
    }

    /// Device finding, 2026-09-14: the 0.12 joint, which 0.15 never loads, was carried into the
    /// new folder. It is not moved, and it goes with the old folder.
    func testAnObsoleteEntryIsNotMovedAndGoesWithTheOldFolder() throws {
        let (legacy, current) = try folders()
        for bundle in ["Decoder.mlmodelc", "Encoder.mlmodelc", "JointDecision.mlmodelc", "Preprocessor.mlmodelc"] {
            try makeBundle(bundle, in: legacy, tag: "old")
        }

        let outcome = migrate(legacy, current, obsolete: ["JointDecision.mlmodelc"])

        XCTAssertEqual(outcome.moved, ["Decoder.mlmodelc", "Encoder.mlmodelc", "Preprocessor.mlmodelc"])
        XCTAssertEqual(outcome.removedObsolete, ["JointDecision.mlmodelc"])
        XCTAssertTrue(outcome.removedLegacyFolder)
        XCTAssertFalse(entries(current).contains("JointDecision.mlmodelc"))
    }

    /// A device a previous build already migrated holds the obsolete joint in the new folder and
    /// has no old folder any more. It is removed there, and nothing else is touched.
    func testAnObsoleteEntryAlreadyMigratedIsRemovedFromTheNewFolder() throws {
        let (legacy, current) = try folders()
        for bundle in ["Decoder.mlmodelc", "JointDecision.mlmodelc", "JointDecisionv3.mlmodelc"] {
            try makeBundle(bundle, in: current, tag: "new")
        }

        let outcome = migrate(legacy, current, obsolete: ["JointDecision.mlmodelc"])

        XCTAssertFalse(outcome.foundLegacyFolder)
        XCTAssertEqual(outcome.removedObsolete, ["JointDecision.mlmodelc"])
        XCTAssertTrue(outcome.didAnything)
        XCTAssertEqual(entries(current), ["Decoder.mlmodelc", "JointDecisionv3.mlmodelc"])
        XCTAssertFalse(migrate(legacy, current, obsolete: ["JointDecision.mlmodelc"]).didAnything,
                       "a second launch has nothing left to do")
    }
}
