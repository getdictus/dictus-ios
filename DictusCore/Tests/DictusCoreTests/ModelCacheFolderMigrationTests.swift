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

        let outcome = ModelCacheFolderMigration.migrate(from: legacy, to: current)

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

        let outcome = ModelCacheFolderMigration.migrate(from: legacy, to: current)

        XCTAssertEqual(outcome, ModelCacheFolderMigration.Outcome(
            moved: [], alreadyPresent: [], foundLegacyFolder: false, removedLegacyFolder: false))
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

        let outcome = ModelCacheFolderMigration.migrate(from: legacy, to: current)

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

        let outcome = ModelCacheFolderMigration.migrate(from: legacy, to: current)

        XCTAssertFalse(outcome.foundLegacyFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
    }

    /// Running it again after a migration is the new-folder-only case.
    func testASecondRunIsANoOp() throws {
        let (legacy, current) = try folders()
        try makeBundle("Encoder.mlmodelc", in: legacy, tag: "old")
        _ = ModelCacheFolderMigration.migrate(from: legacy, to: current)

        let second = ModelCacheFolderMigration.migrate(from: legacy, to: current)

        XCTAssertFalse(second.foundLegacyFolder)
        XCTAssertEqual(entries(current), ["Encoder.mlmodelc"])
    }
}
