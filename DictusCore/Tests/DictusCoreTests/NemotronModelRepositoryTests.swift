// DictusCore/Tests/DictusCoreTests/NemotronModelRepositoryTests.swift
// The completeness rule for the Nemotron 3.5 model directory (#558).
import XCTest
@testable import DictusCore

final class NemotronModelRepositoryTests: XCTestCase {

    private var modelDirectory: URL?

    /// What the app supplies: FluidAudio 0.15.7's `ModelNames.NemotronMultilingualStreaming`
    /// encoder, decoder and joint, plus the fused `decoder_joint` the multilingual ship carries.
    private let requiredBundles: Set<String> = [
        "encoder.mlmodelc", "decoder.mlmodelc", "joint.mlmodelc", "decoder_joint.mlmodelc"
    ]
    private let rootFiles = ["metadata.json", "tokenizer.json"]

    override func setUpWithError() throws {
        try super.setUpWithError()
        modelDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("NemotronModelRepositoryTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let modelDirectory {
            try? FileManager.default.removeItem(at: modelDirectory)
        }
        modelDirectory = nil
        try super.tearDownWithError()
    }

    private func directory() throws -> URL {
        try XCTUnwrap(modelDirectory)
    }

    private func makeBundle(_ name: String, includeWeights: Bool = true) throws {
        let bundle = try directory().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("weights", isDirectory: true), withIntermediateDirectories: true
        )
        try Data([0]).write(to: bundle.appendingPathComponent("coremldata.bin"))
        try Data([0]).write(to: bundle.appendingPathComponent("model.mil"))
        if includeWeights {
            try Data([0]).write(to: bundle.appendingPathComponent("weights/weight.bin"))
        }
    }

    private func makeCompleteModel() throws {
        try FileManager.default.createDirectory(at: try directory(), withIntermediateDirectories: true)
        for bundle in requiredBundles {
            try makeBundle(bundle)
        }
        for file in rootFiles {
            try Data("{}".utf8).write(to: try directory().appendingPathComponent(file))
        }
    }

    func testACompleteModelResolves() throws {
        try makeCompleteModel()
        let dir = try directory()
        XCTAssertEqual(NemotronModelRepository.installedModelDirectory(
            dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ), dir)
        XCTAssertEqual(NemotronModelRepository.missingEntries(
            in: dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ), [])
    }

    func testANeverDownloadedModelIsAbsentAndEverythingIsMissing() throws {
        let dir = try directory()
        XCTAssertNil(NemotronModelRepository.installedModelDirectory(
            dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ))
        XCTAssertEqual(NemotronModelRepository.missingEntries(
            in: dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ), ["decoder.mlmodelc", "decoder_joint.mlmodelc", "encoder.mlmodelc", "joint.mlmodelc",
            "metadata.json", "tokenizer.json"])
    }

    /// The encoder's weights are 565 MB of the 665 MB, so an interrupted transfer almost
    /// always stops inside them, with every small file already on disk.
    func testATransferStoppedInsideTheEncoderWeightsIsIncomplete() throws {
        try makeCompleteModel()
        let dir = try directory()
        try FileManager.default.removeItem(at: dir.appendingPathComponent("encoder.mlmodelc/weights/weight.bin"))
        XCTAssertNil(NemotronModelRepository.installedModelDirectory(
            dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ))
        XCTAssertEqual(NemotronModelRepository.missingEntries(
            in: dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ), ["encoder.mlmodelc"])
    }

    /// `metadata.json` holds the prompt dictionary; without it FluidAudio refuses to load.
    func testAMissingMetadataFileIsIncomplete() throws {
        try makeCompleteModel()
        let dir = try directory()
        try FileManager.default.removeItem(at: dir.appendingPathComponent("metadata.json"))
        XCTAssertEqual(NemotronModelRepository.missingEntries(
            in: dir, requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        ), ["metadata.json"])
    }

    func testAnEmptyRequirementNeverPasses() throws {
        try makeCompleteModel()
        XCTAssertNil(NemotronModelRepository.installedModelDirectory(
            try directory(), requiredModelBundles: [], rootFileNames: rootFiles
        ))
    }

    /// The downloader's tripwire names leaf files under the variant folder, never a bundle
    /// directory, the rule #433 and #438 each learned once.
    func testRequiredDownloadPathsAreLeafFilesUnderTheVariantDirectory() {
        let paths = NemotronModelRepository.requiredDownloadPaths(
            requiredModelBundles: requiredBundles, rootFileNames: rootFiles
        )
        XCTAssertEqual(paths.count, requiredBundles.count * 3 + rootFiles.count)
        XCTAssertTrue(paths.allSatisfy { $0.hasPrefix("multilingual/2240ms/") })
        XCTAssertFalse(paths.contains { $0.hasSuffix(".mlmodelc") })
        XCTAssertTrue(paths.contains("multilingual/2240ms/encoder.mlmodelc/weights/weight.bin"))
        XCTAssertEqual(Array(paths.suffix(2)), ["multilingual/2240ms/metadata.json", "multilingual/2240ms/tokenizer.json"])
    }
}
