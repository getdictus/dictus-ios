// DictusCore/Tests/DictusCoreTests/ModelDownloadCancellationTests.swift
// A cancelled download is not adopted by the next launch, and only its own files go (issue #493).
import XCTest
@testable import DictusCore

final class ModelDownloadCancellationTests: XCTestCase {

    private let parakeet = "parakeet-tdt-0.6b-v3"
    private let small = "openai_whisper-small_216MB"

    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staging-area-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// A manifest whose first file is done and second is not: an interrupted transfer.
    private func interruptedManifest(_ model: String) -> ModelDownloadManifest {
        ModelDownloadManifest(
            modelIdentifier: model,
            repositoryID: "example/\(model)",
            revision: "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe",
            chunkSize: 4,
            files: [
                .init(path: "config.json", size: 4, completed: true),
                .init(path: "weights/weight.bin", size: 12)
            ]
        )
    }

    /// Stages an interrupted download the way the service leaves one: a manifest, a
    /// partial and a landed chunk in the model's directory.
    private func stageInterruptedDownload(_ model: String, in area: ModelDownloadStagingArea) throws {
        area.save(interruptedManifest(model))
        let staging = ModelDownloadStaging(directory: area.directory(model))
        try Data("abcd".utf8).write(to: staging.partialURL(fileIndex: 1))
        try Data("efgh".utf8).write(to: staging.chunkURL(fileIndex: 1, chunkIndex: 1))
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - What the next launch adopts

    func testInterruptedDownloadsAreWhatTheNextLaunchAdopts() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(parakeet, in: area)
        try stageInterruptedDownload(small, in: area)

        XCTAssertEqual(area.interruptedIdentifiers(), [small, parakeet].sorted())
    }

    func testCancelledDownloadIsNotAdoptedByTheNextLaunch() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(parakeet, in: area)

        area.discard(parakeet)

        // A fresh instance over the same directory, as a relaunched process builds one.
        let nextLaunch = ModelDownloadStagingArea(root: root)
        XCTAssertEqual(nextLaunch.interruptedIdentifiers(), [])
        XCTAssertNil(nextLaunch.load(parakeet))
    }

    func testCancelDeletesThisModelsPartialBytesOnly() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(parakeet, in: area)
        try stageInterruptedDownload(small, in: area)
        let other = ModelDownloadStaging(directory: area.directory(small))

        area.discard(parakeet)

        XCTAssertFalse(exists(area.directory(parakeet)), "the cancelled model's partial and chunks must be gone")
        XCTAssertTrue(exists(other.partialURL(fileIndex: 1)), "another model's partial must survive")
        XCTAssertEqual(other.storedChunkIndices(fileIndex: 1), [1], "another model's chunks must survive")
        XCTAssertEqual(ModelDownloadStagingArea(root: root).interruptedIdentifiers(), [small],
                       "another model's interrupted download must still be resumed")
    }

    func testCancellingWithNothingStagedIsHarmless() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(small, in: area)

        area.discard(parakeet)

        XCTAssertEqual(area.interruptedIdentifiers(), [small])
    }

    func testACancelledModelCanBeDownloadedAgain() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(parakeet, in: area)
        area.discard(parakeet)

        area.save(interruptedManifest(parakeet))

        XCTAssertEqual(area.interruptedIdentifiers(), [parakeet])
    }

    func testFinishedTransferIsNotAdopted() {
        let area = ModelDownloadStagingArea(root: root)
        var manifest = interruptedManifest(parakeet)
        manifest.markCompleted(fileAt: 1)
        area.save(manifest)

        XCTAssertEqual(area.interruptedIdentifiers(), [])
    }

    /// The folder name escapes the dots; the identifier comes back from the manifest.
    func testIdentifierSurvivesTheSanitizedFolderName() throws {
        let area = ModelDownloadStagingArea(root: root)
        try stageInterruptedDownload(parakeet, in: area)

        XCTAssertEqual(area.directory(parakeet).lastPathComponent, "parakeet-tdt-0_6b-v3")
        XCTAssertEqual(Array(area.loadAll().keys), [parakeet])
    }

    // MARK: - An attempt already under way

    func testAttemptStartedBeforeTheCancelIsCancelled() {
        var cancellations = ModelDownloadCancellations()
        let attempt = cancellations.token(for: parakeet)

        cancellations.cancel(parakeet)

        XCTAssertTrue(cancellations.isCancelled(parakeet, since: attempt))
    }

    func testAttemptStartedAfterTheCancelIsNotCancelled() {
        var cancellations = ModelDownloadCancellations()
        let cancelledAttempt = cancellations.token(for: parakeet)
        cancellations.cancel(parakeet)

        // The user taps Download again, before or after the old attempt has noticed.
        let newAttempt = cancellations.token(for: parakeet)

        XCTAssertFalse(cancellations.isCancelled(parakeet, since: newAttempt))
        XCTAssertTrue(cancellations.isCancelled(parakeet, since: cancelledAttempt),
                      "the old attempt must still see its cancel after the new one started")
    }

    func testCancelOfOneModelLeavesAnotherModelsAttemptAlone() {
        var cancellations = ModelDownloadCancellations()
        let otherAttempt = cancellations.token(for: small)

        cancellations.cancel(parakeet)

        XCTAssertFalse(cancellations.isCancelled(small, since: otherAttempt))
    }

    func testSecondCancelStopsTheRetriedAttempt() {
        var cancellations = ModelDownloadCancellations()
        cancellations.cancel(parakeet)
        let retry = cancellations.token(for: parakeet)

        cancellations.cancel(parakeet)

        XCTAssertTrue(cancellations.isCancelled(parakeet, since: retry))
    }
}
