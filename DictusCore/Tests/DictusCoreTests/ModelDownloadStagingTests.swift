// DictusCore/Tests/DictusCoreTests/ModelDownloadStagingTests.swift
// Chunks that landed on disk but were never appended: absorbed, refused, never doubled (issue #732).
import XCTest
import CryptoKit
@testable import DictusCore

final class ModelDownloadStagingTests: XCTestCase {

    /// Small on purpose: the arithmetic is the shipped one, only the scale changes.
    private let chunkSize: Int64 = 4
    /// Two in flight, the value `BackgroundModelDownloadService.chunksInFlight` ships.
    private let window = 2

    private var directory: URL!
    private var cache: URL!
    private var staging: ModelDownloadStaging!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        directory = root.appendingPathComponent("parakeet-tdt-0_6b-v3", isDirectory: true)
        cache = root.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        staging = ModelDownloadStaging(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func manifest(
        _ files: [ModelDownloadManifest.FileEntry],
        chunkSize: Int64? = nil
    ) -> ModelDownloadManifest {
        ModelDownloadManifest(
            modelIdentifier: "parakeet-tdt-0.6b-v3",
            repositoryID: "FluidInference/parakeet-tdt-0.6b-v3-coreml",
            revision: "7dd20fe6b1797d35f5e3307e8b1732d9a178edfe",
            chunkSize: chunkSize ?? self.chunkSize,
            files: files
        )
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Writes a chunk the way `store` leaves one: `<file>-<chunk>.chunk` in the directory.
    private func storeChunk(_ data: Data, file: Int, chunk: Int) throws {
        try data.write(to: staging.chunkURL(fileIndex: file, chunkIndex: chunk))
    }

    /// The bytes of one chunk of `content`, as the server would send them for its span.
    private func bytes(of content: Data, chunk: Int) -> Data {
        let start = chunk * Int(chunkSize)
        let end = min(start + Int(chunkSize), content.count)
        return content.subdata(in: start..<end)
    }

    private func partial(_ file: Int) throws -> Data {
        try Data(contentsOf: staging.partialURL(fileIndex: file))
    }

    // MARK: - The device state of 2026-10-13

    func testARelaunchAbsorbsTheOrphanedChunkPublishesTheFileAndMovesOn() throws {
        // `Decoder.mlmodelc/coremldata.bin`: one chunk, landed and moved into place, the
        // process killed before its completion appended it. `appendedBytes` is 0, the
        // chunk is on disk with the right digest, nothing is in flight.
        let content = Data("coremldata".utf8)
        let next = Data("weights!".utf8)
        // Chunks bigger than the file, so it really is a single chunk, as on device.
        var subject = manifest([
            .init(path: "Decoder.mlmodelc/coremldata.bin", size: Int64(content.count), sha256: sha256(content)),
            .init(path: "Decoder.mlmodelc/weights/weight.bin", size: Int64(next.count))
        ], chunkSize: 16)
        try storeChunk(content, file: 0, chunk: 0)

        // The freeze, reproduced: before #732 `pump` asked `chunksToEnqueue` straight away,
        // got nothing back, and had no task in flight to ever change that.
        XCTAssertFalse(subject.isFileFullyReceived(at: 0))
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 0,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 0),
                window: window
            ),
            []
        )

        // `pump`'s order since #732: absorb what is stored and not in flight first.
        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])
        XCTAssertEqual(absorption, .init(absorbed: [0], discarded: []))
        XCTAssertEqual(subject.files[0].appendedBytes, Int64(content.count))
        XCTAssertEqual(try partial(0), content)
        XCTAssertTrue(staging.storedChunkIndices(fileIndex: 0).isEmpty, "an appended chunk is deleted")

        // Then the existing flow: fully received → publish.
        XCTAssertTrue(subject.isFileFullyReceived(at: 0))
        let destination = cache.appendingPathComponent(subject.files[0].path)
        XCTAssertNil(try staging.publish(fileAt: 0, of: subject, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), content)
        subject.markCompleted(fileAt: 0)

        // And the download moves on to the next file, from its first chunk.
        XCTAssertEqual(subject.currentFileIndex, 1)
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 1,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 1),
                window: window
            ),
            [0]
        )
    }

    func testOnlyTheMissingChunkIsEnqueuedOnceTheStoredOnesAreAbsorbed() throws {
        // Three chunks (4 + 4 + 2 bytes); 0 and 1 landed and were never appended, 2 never
        // landed.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "Encoder.mlmodelc/weights/weight.bin", size: Int64(content.count))])
        try storeChunk(bytes(of: content, chunk: 0), file: 0, chunk: 0)
        try storeChunk(bytes(of: content, chunk: 1), file: 0, chunk: 1)

        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertEqual(absorption.absorbed, [0, 1])
        XCTAssertEqual(subject.files[0].appendedBytes, 8)
        XCTAssertEqual(try partial(0), content.prefix(8))
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 0,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 0),
                window: window
            ),
            [2]
        )
    }

    func testAChunkLeftBehindAGapWaitsForItsPredecessor() throws {
        // Chunk 1 is on disk, chunk 0 is not: nothing is contiguous yet, and chunk 0 is
        // what gets asked for. Chunk 1 is not asked for a second time.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count))])
        try storeChunk(bytes(of: content, chunk: 1), file: 0, chunk: 1)

        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertTrue(absorption.isEmpty)
        XCTAssertEqual(subject.files[0].appendedBytes, 0)
        XCTAssertEqual(staging.storedChunkIndices(fileIndex: 0), [1])
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 0,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 0),
                window: window
            ),
            [0, 2]
        )
    }

    // MARK: - A stored chunk that cannot be trusted

    func testAStoredChunkOfTheWrongLengthIsDiscardedAndAskedForAgain() throws {
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count))])
        try storeChunk(Data("012".utf8), file: 0, chunk: 0)

        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertEqual(absorption.absorbed, [])
        XCTAssertEqual(absorption.discarded, [.init(chunk: 0, reason: "chunk-length-3-expected-4")])
        XCTAssertEqual(subject.files[0].appendedBytes, 0, "nothing absorbed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.partialURL(fileIndex: 0).path))
        XCTAssertTrue(staging.storedChunkIndices(fileIndex: 0).isEmpty, "the bad chunk is deleted")
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 0,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 0),
                window: window
            ),
            [0, 1]
        )
    }

    func testABadChunkStopsThePassWhereTheNextRequestResumes() throws {
        // 0 is good, 1 is too long, 2 is good: 0 is absorbed, 1 is thrown away, and 2
        // waits on disk for the new 1 rather than being appended out of place.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count))])
        try storeChunk(bytes(of: content, chunk: 0), file: 0, chunk: 0)
        try storeChunk(Data("45678".utf8), file: 0, chunk: 1)
        try storeChunk(bytes(of: content, chunk: 2), file: 0, chunk: 2)

        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertEqual(absorption.absorbed, [0])
        XCTAssertEqual(absorption.discarded, [.init(chunk: 1, reason: "chunk-length-5-expected-4")])
        XCTAssertEqual(subject.files[0].appendedBytes, 4)
        XCTAssertEqual(try partial(0), content.prefix(4))
        XCTAssertEqual(staging.storedChunkIndices(fileIndex: 0), [2])
        XCTAssertEqual(
            subject.chunksToEnqueue(
                ofFileAt: 0,
                inFlight: [],
                alreadyStored: staging.storedChunkIndices(fileIndex: 0),
                window: window
            ),
            [1]
        )
    }

    func testAChunkOfTheRightLengthWithTheWrongBytesIsRefusedAtPublish() throws {
        // The length check cannot see this one; the SHA-256 at publish does, and nothing
        // is moved into the cache directory.
        let content = Data("coremldata".utf8)
        var subject = manifest(
            [.init(path: "Decoder.mlmodelc/coremldata.bin", size: Int64(content.count), sha256: sha256(content))],
            chunkSize: 16
        )
        try storeChunk(Data("COREMLDATA".utf8), file: 0, chunk: 0)

        XCTAssertEqual(try staging.absorbStoredChunks(into: &subject, fileAt: 0).absorbed, [0])
        let destination = cache.appendingPathComponent(subject.files[0].path)
        guard case .checksumMismatch = try staging.publish(fileAt: 0, of: subject, to: destination) else {
            return XCTFail("a partial with the wrong digest must be refused")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - Never appended twice

    func testACompletionAndARelaunchAbsorbingTheSameChunkAppendItOnce() throws {
        // Both orders `BackgroundModelDownloadService` can run them in, on its one serial
        // queue: the completion's pass first, then `pump`'s — or the reverse.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count))])
        try storeChunk(bytes(of: content, chunk: 0), file: 0, chunk: 0)

        let first = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])
        let second = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertEqual(first.absorbed, [0])
        XCTAssertTrue(second.isEmpty, "the first pass deleted the chunk it appended")
        XCTAssertEqual(subject.files[0].appendedBytes, 4)
        XCTAssertEqual(try partial(0), content.prefix(4))
    }

    func testAnAppendTheProcessDiedInIsReplayedNotDoubled() throws {
        // The process wrote chunk 1's bytes into the partial and died before deleting the
        // chunk and before saving the manifest: the partial holds 8 bytes, the manifest
        // vouches for 4, the chunk is still on disk. The relaunch absorbs it again; the
        // append truncates to 4 first, so the partial ends with 8 bytes, not 12.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count), appendedBytes: 4)])
        try content.prefix(8).write(to: staging.partialURL(fileIndex: 0))
        try storeChunk(bytes(of: content, chunk: 1), file: 0, chunk: 1)

        let absorption = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])

        XCTAssertEqual(absorption.absorbed, [1])
        XCTAssertEqual(subject.files[0].appendedBytes, 8)
        XCTAssertEqual(try partial(0), content.prefix(8))
    }

    func testAChunkStillInFlightIsLeftToItsOwnCompletion() throws {
        // `pump` excludes `inFlight`: a chunk stored between `didFinishDownloadingTo` and
        // `didCompleteWithError` belongs to that completion, which then absorbs it once.
        let content = Data("0123456789".utf8)
        var subject = manifest([.init(path: "a", size: Int64(content.count))])
        try storeChunk(bytes(of: content, chunk: 0), file: 0, chunk: 0)

        let pumped = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [0])
        XCTAssertTrue(pumped.isEmpty)
        XCTAssertEqual(subject.files[0].appendedBytes, 0)

        let completed = try staging.absorbStoredChunks(into: &subject, fileAt: 0, excluding: [])
        XCTAssertEqual(completed.absorbed, [0])
        XCTAssertEqual(try partial(0), content.prefix(4))
    }

    func testACompletedFileIsNeverReabsorbed() throws {
        var subject = manifest([.init(path: "a", size: 4, appendedBytes: 4, completed: true)])
        try storeChunk(Data("0123".utf8), file: 0, chunk: 0)

        XCTAssertTrue(try staging.absorbStoredChunks(into: &subject, fileAt: 0).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.partialURL(fileIndex: 0).path))
    }
}
