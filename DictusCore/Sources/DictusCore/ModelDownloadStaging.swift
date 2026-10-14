// DictusCore/Sources/DictusCore/ModelDownloadStaging.swift
// The disk half of a resumable model download: landed chunks, partials, and folding one into the other.
import Foundation

/// One model's staging directory, and every file-system step that turns landed chunks
/// into a published file.
///
/// WHY THIS LIVES IN DICTUSCORE (issue #732). These steps used to be `ManifestStore`'s,
/// in the DictusApp target, which has no test bundle. The freeze #732 fixes was in
/// exactly this layer: a chunk durably on disk that nothing would ever fold into its
/// partial, because folding only happened in the completion of a task that a killed
/// process never got to run. The arithmetic was already here and tested
/// (`ModelDownloadManifest`); the bytes it governs now are too.
///
/// Layout, unchanged from `ManifestStore`: `<fileIndex>.part` for a file being
/// assembled, `<fileIndex>-<chunkIndex>.chunk` for a chunk that landed and is not yet
/// appended.
public struct ModelDownloadStaging: Sendable {

    /// What one absorb pass did to a file.
    public struct Absorption: Equatable, Sendable {
        /// Chunks appended to the partial, in order.
        public var absorbed: [Int] = []
        /// Chunks found on disk with the wrong length and deleted, with the reason, so
        /// the next `chunksToEnqueue` asks for them again.
        public var discarded: [Discarded] = []

        public init(absorbed: [Int] = [], discarded: [Discarded] = []) {
            self.absorbed = absorbed
            self.discarded = discarded
        }

        /// Nothing absorbed and nothing discarded: the manifest is untouched.
        public var isEmpty: Bool { absorbed.isEmpty && discarded.isEmpty }
    }

    /// A stored chunk refused by the absorb pass.
    public struct Discarded: Equatable, Sendable {
        public let chunk: Int
        /// The `lengthMismatch` reason, e.g. `chunk-length-100-expected-554`.
        public let reason: String

        public init(chunk: Int, reason: String) {
            self.chunk = chunk
            self.reason = reason
        }
    }

    /// The model's staging directory. Not created here: `store` creates it on demand.
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: - Paths

    /// The partial being assembled for one file.
    public func partialURL(fileIndex: Int) -> URL {
        directory.appendingPathComponent("\(fileIndex).part")
    }

    public func chunkURL(fileIndex: Int, chunkIndex: Int) -> URL {
        directory.appendingPathComponent("\(fileIndex)-\(chunkIndex).chunk")
    }

    // MARK: - Chunks

    /// Chunk indices whose bytes are durably on disk for this file.
    public func storedChunkIndices(fileIndex: Int) -> Set<Int> {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }
        let prefix = "\(fileIndex)-"
        let suffix = ".chunk"
        var result: Set<Int> = []
        for entry in entries where entry.hasPrefix(prefix) && entry.hasSuffix(suffix) {
            let middle = entry.dropFirst(prefix.count).dropLast(suffix.count)
            if let index = Int(middle) { result.insert(index) }
        }
        return result
    }

    /// Moves a completed chunk out of the system's temporary location, which is emptied
    /// the instant `didFinishDownloadingTo` returns. This move is the whole reason the
    /// download is chunked: it is where in-flight bytes become durable ones.
    public func store(chunkAt location: URL, fileIndex: Int, chunkIndex: Int) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = chunkURL(fileIndex: fileIndex, chunkIndex: chunkIndex)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: location, to: destination)
    }

    /// Deletes one stored chunk, so the next enqueue asks for it again.
    public func discardChunk(fileIndex: Int, chunkIndex: Int) {
        try? FileManager.default.removeItem(at: chunkURL(fileIndex: fileIndex, chunkIndex: chunkIndex))
    }

    /// Drops one file's partial and every chunk of it, leaving the rest of the download
    /// intact. Used when a range was refused or an assembled file failed its checksum.
    public func discardFile(fileIndex: Int) {
        try? FileManager.default.removeItem(at: partialURL(fileIndex: fileIndex))
        for index in storedChunkIndices(fileIndex: fileIndex) {
            discardChunk(fileIndex: fileIndex, chunkIndex: index)
        }
    }

    /// The chunk at `location` is not the length the span asked for, or `nil` when it is.
    ///
    /// This is what validates a span the client resumed itself, where the response header
    /// only describes the final leg. A short chunk appended into the partial would leave
    /// a file of the wrong length made of misaligned bytes, and nothing downstream but
    /// the SHA-256 would notice. Since #732 it also vets a chunk found on disk with no
    /// completion to vouch for it.
    public static func lengthMismatch(at location: URL, span: ModelDownloadChunkSpan) -> String? {
        guard let end = span.end else { return nil }
        let expected = end - span.start + 1
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: location.path),
              let actual = (attributes[.size] as? NSNumber)?.int64Value else {
            return "chunk-length-unreadable"
        }
        return actual == expected ? nil : "chunk-length-\(actual)-expected-\(expected)"
    }

    // MARK: - Assembly

    /// Appends chunks, in the order given, to the file's partial and deletes them.
    ///
    /// Streamed in 1 MB reads: a chunk is 32 MB and this runs in an app iOS already
    /// watches for memory (issues #104, #362).
    public func append(chunks: [Int], ofFile fileIndex: Int, startingAt: Int64) throws {
        guard !chunks.isEmpty else { return }
        let partial = partialURL(fileIndex: fileIndex)
        if !FileManager.default.fileExists(atPath: partial.path) {
            FileManager.default.createFile(atPath: partial.path, contents: nil)
        }
        let writer = try FileHandle(forWritingTo: partial)
        defer { try? writer.close() }
        // Everything past the manifest's offset is unaccounted for — bytes a process
        // that died mid-append wrote and never recorded. Dropping them is what makes an
        // append idempotent, and an append that is not idempotent silently doubles a
        // chunk inside a 445 MB file.
        try writer.truncate(atOffset: UInt64(max(0, startingAt)))
        try writer.seekToEnd()

        for chunkIndex in chunks {
            let source = chunkURL(fileIndex: fileIndex, chunkIndex: chunkIndex)
            let reader = try FileHandle(forReadingFrom: source)
            defer { try? reader.close() }
            while let data = try reader.read(upToCount: 1 << 20), !data.isEmpty {
                try writer.write(contentsOf: data)
            }
            try? reader.close()
            try? FileManager.default.removeItem(at: source)
        }
        try writer.synchronize()
    }

    /// Folds every stored chunk that is contiguous with the partial into it, and
    /// advances the manifest to match. The caller saves the manifest.
    ///
    /// WHY THIS IS NOT ONLY THE COMPLETION'S JOB ANY MORE (issue #732). Measured on
    /// device on 2026-10-13: the single chunk of `Decoder.mlmodelc/coremldata.bin` was
    /// moved into place by `didFinishDownloadingTo`, the app was SIGKILLed 108 ms later,
    /// and the completion that would have appended it never ran. Every relaunch then saw
    /// a file with nothing appended, every chunk of it "already stored", and nothing in
    /// flight — so nothing was ever asked for again and the download froze for good. The
    /// disk is the truth about what landed; this lets it win over a missing completion.
    ///
    /// WHY THE LENGTH IS CHECKED HERE. A chunk landing through a completion is checked
    /// before it is stored. One found on disk has no completion to vouch for it, so each
    /// candidate is held to the same `lengthMismatch` rule before it is appended. A chunk
    /// that fails is deleted and the pass stops there: the next enqueue asks for it again
    /// rather than freezing on it or folding it into the file. The SHA-256 at publish is
    /// still the last word on the bytes.
    ///
    /// WHY IT CANNOT APPEND A CHUNK TWICE. The append starts by truncating the partial to
    /// the `appendedBytes` read before this pass advances it, and deletes each chunk it
    /// copied. A second pass over the same state either finds the chunk gone, or — when a
    /// process died after writing and before the manifest was saved — rewrites the same
    /// bytes at the same offset.
    ///
    /// - Parameters:
    ///   - manifest: advanced in place; left unchanged when the append throws, because
    ///     the bytes it would claim are not durably there.
    ///   - index: file being assembled.
    ///   - excluding: chunks to leave alone even if stored — those whose own completion
    ///     is still to come and will absorb them.
    public func absorbStoredChunks(
        into manifest: inout ModelDownloadManifest,
        fileAt index: Int,
        excluding: Set<Int> = []
    ) throws -> Absorption {
        guard manifest.files.indices.contains(index), !manifest.files[index].completed else {
            return Absorption()
        }
        let stored = storedChunkIndices(fileIndex: index).subtracting(excluding)
        guard !stored.isEmpty else { return Absorption() }

        // Vet the contiguous run before the manifest is touched, so a bad chunk in the
        // middle stops the pass exactly where the first request has to resume.
        var result = Absorption()
        var accepted: Set<Int> = []
        var next = manifest.nextChunkIndex(ofFileAt: index)
        while stored.contains(next), let span = manifest.span(ofChunk: next, inFileAt: index) {
            let url = chunkURL(fileIndex: index, chunkIndex: next)
            if let reason = Self.lengthMismatch(at: url, span: span) {
                discardChunk(fileIndex: index, chunkIndex: next)
                result.discarded.append(Discarded(chunk: next, reason: reason))
                break
            }
            accepted.insert(next)
            next += 1
        }
        guard !accepted.isEmpty else { return result }

        // The offset the partial is authoritative up to, read BEFORE the manifest
        // advances: `append` truncates to it, which is what makes the operation
        // replayable.
        let appendAt = manifest.files[index].appendedBytes
        var advanced = manifest
        let absorbed = advanced.absorbContiguousChunks(ofFileAt: index, available: accepted)
        try append(chunks: absorbed, ofFile: index, startingAt: appendAt)
        manifest = advanced
        result.absorbed = absorbed
        return result
    }

    /// Verifies a fully received file and moves it to `destination`, atomically
    /// publishing a complete file or nothing.
    ///
    /// - Returns: `nil` once published, otherwise why the partial was refused. A refused
    ///   partial is left where it is; the caller decides what to throw away.
    /// - Throws: a file-system error from creating the folder or the move.
    public func publish(
        fileAt index: Int,
        of manifest: ModelDownloadManifest,
        to destination: URL
    ) throws -> ModelFileIntegrity.Failure? {
        guard manifest.files.indices.contains(index) else { return .unreadable }
        let file = manifest.files[index]
        let partial = partialURL(fileIndex: index)
        if let failure = ModelFileIntegrity.verify(
            fileAt: partial,
            expectedSize: file.size,
            expectedSHA256: file.sha256
        ) {
            return failure
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Remove any stale destination, then move. The property everything downstream
        // leans on: a file that exists is a file that finished (see
        // `WhisperModelRepository`).
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: partial, to: destination)
        return nil
    }
}
