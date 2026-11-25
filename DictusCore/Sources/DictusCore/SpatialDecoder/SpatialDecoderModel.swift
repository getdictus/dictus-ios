// DictusCore/Sources/DictusCore/SpatialDecoder/SpatialDecoderModel.swift
//
// Ported from Hex (github.com/anomalyco/hex, branch dev, ios/HEXShared/FullKeyboard/
// TypingDecoder.swift, `TypingDecoderModel`), MIT, Copyright (c) 2026 Christopher Langton.
// The file format is Hex's "HXTM" v3, unchanged, so Hex's models load as they are (#1011).
import Darwin
import Foundation

/// The spatial decoder's word list and word-pair language model, memory-mapped read-only
/// from a `.hextm` file `tools/typing-model/build-typing-model.py` writes.
///
/// WHY memory-mapped: mapped pages are clean and file-backed, so iOS can drop them under
/// pressure instead of counting them against the keyboard's ~50 MB. Only the pages a
/// search touches are ever read in.
public final class SpatialDecoderModel: @unchecked Sendable {
    public let wordCount: Int
    public let bigramCount: Int
    public let byteCount: Int
    /// The language it was built for ("en", "fr").
    public let language: String
    /// Letter codes (1…) by character, each code's character, and its unaccented letter's code.
    let codes: [Character: UInt8]
    let characters: [Character]
    let baseCodes: [UInt8]
    let apostropheCode: UInt8?
    private let base: UnsafeRawPointer
    private let offsetsAt: Int
    private let unigramAt: Int
    private let pairRowsAt: Int
    private let pairWordsAt: Int
    private let pairCostsAt: Int
    private let blobAt: Int

    /// Nil when the file is missing, truncated or not a v3 model.
    public init?(path: String) {
        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_size >= 28 else { return nil }
        let size = Int(info.st_size)
        guard let mapped = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0), mapped != MAP_FAILED else { return nil }
        let base = UnsafeRawPointer(mapped)
        func u32(_ at: Int) -> Int { Int(base.loadUnaligned(fromByteOffset: at, as: UInt32.self)) }
        // "HXTM", version 3.
        guard base.loadUnaligned(as: UInt32.self) == 0x4D54_5848, u32(4) == 3 else { munmap(mapped, size); return nil }
        let words = u32(8), bigrams = u32(12), blob = u32(16), letters = u32(20)
        guard letters < 255, 28 + 8 * letters <= size else { munmap(mapped, size); return nil }
        let languageBytes = (0..<4).map { base.load(fromByteOffset: 24 + $0, as: UInt8.self) }.filter { $0 != 0 }
        var codes: [Character: UInt8] = [:]
        var characters = [Character](repeating: " ", count: letters + 1)
        var baseCodes = [UInt8](repeating: 0, count: letters + 1)
        for i in 0..<letters {
            let at = 28 + 8 * i
            guard let scalar = Unicode.Scalar(u32(at)) else { munmap(mapped, size); return nil }
            let code = Int(base.load(fromByteOffset: at + 4, as: UInt8.self))
            let baseCode = base.load(fromByteOffset: at + 5, as: UInt8.self)
            guard code >= 1, code <= letters, baseCode >= 1, Int(baseCode) <= letters else { munmap(mapped, size); return nil }
            codes[Character(scalar)] = UInt8(code)
            characters[code] = Character(scalar)
            baseCodes[code] = baseCode
        }
        let offsetsAt = 28 + 8 * letters
        let unigramAt = offsetsAt + 4 * (words + 1)
        var rowsAt = unigramAt + words
        rowsAt += (4 - rowsAt % 4) % 4
        let pairWordsAt = rowsAt + 4 * (words + 1)
        let pairCostsAt = pairWordsAt + 4 * bigrams
        let blobAt = pairCostsAt + bigrams
        guard blobAt + blob == size else { munmap(mapped, size); return nil }
        self.base = base
        self.byteCount = size
        self.language = String(bytes: languageBytes, encoding: .utf8) ?? ""
        self.codes = codes
        self.characters = characters
        self.baseCodes = baseCodes
        self.apostropheCode = codes["'"]
        self.wordCount = words
        self.bigramCount = bigrams
        self.offsetsAt = offsetsAt
        self.unigramAt = unigramAt
        self.pairRowsAt = rowsAt
        self.pairWordsAt = pairWordsAt
        self.pairCostsAt = pairCostsAt
        self.blobAt = blobAt
    }

    deinit {
        munmap(UnsafeMutableRawPointer(mutating: base), byteCount)
    }

    @inline(__always) private func start(_ i: Int) -> Int {
        Int(base.loadUnaligned(fromByteOffset: offsetsAt + 4 * i, as: UInt32.self))
    }

    @inline(__always) func length(_ i: Int) -> Int { start(i + 1) - start(i) }

    /// The word's letter code at `depth`, or -1 past its end.
    @inline(__always) func byte(_ i: Int, _ depth: Int) -> Int {
        let s = start(i)
        guard depth < start(i + 1) - s else { return -1 }
        return Int(base.load(fromByteOffset: blobAt + s + depth, as: UInt8.self))
    }

    /// The word's letter codes in place, in the mapped file: no copy, nothing kept. Ported
    /// from Hex's `TypingDecoderModel.withCodes` for the swipe decoder (#948).
    @inline(__always) func withCodes<R>(_ i: Int, _ body: (UnsafeRawBufferPointer) -> R) -> R {
        let s = start(i)
        return body(UnsafeRawBufferPointer(start: base.advanced(by: blobAt + s), count: start(i + 1) - s))
    }

    func word(_ i: Int) -> String {
        let s = start(i)
        return String((s..<start(i + 1)).map { characters[Int(base.load(fromByteOffset: blobAt + $0, as: UInt8.self))] })
    }

    /// The word's letter codes, or nil when it has a letter the model doesn't.
    func encode(_ word: String) -> [UInt8]? {
        var out: [UInt8] = []
        for c in word {
            guard let code = codes[c] else { return nil }
            out.append(code)
        }
        return out
    }

    /// -ln P(word), in nats.
    @inline(__always) func unigramCost(_ i: Int) -> Double {
        Double(base.load(fromByteOffset: unigramAt + i, as: UInt8.self)) / 8
    }

    /// -ln P(b | a), in nats, when the pair is in the model.
    func bigramCost(_ a: Int, _ b: Int) -> Double? {
        guard a >= 0, a < wordCount else { return nil }
        var lo = Int(base.loadUnaligned(fromByteOffset: pairRowsAt + 4 * a, as: UInt32.self))
        let end = Int(base.loadUnaligned(fromByteOffset: pairRowsAt + 4 * (a + 1), as: UInt32.self))
        guard lo <= end, end <= bigramCount else { return nil }
        var hi = end
        let target = UInt32(b)
        while lo < hi {
            let mid = (lo + hi) / 2
            if base.loadUnaligned(fromByteOffset: pairWordsAt + 4 * mid, as: UInt32.self) < target { lo = mid + 1 } else { hi = mid }
        }
        guard lo < end, base.loadUnaligned(fromByteOffset: pairWordsAt + 4 * lo, as: UInt32.self) == target else { return nil }
        return Double(base.load(fromByteOffset: pairCostsAt + lo, as: UInt8.self)) / 8
    }

    /// The index of `word` (lowercase), or nil when the model lacks it.
    public func index(of word: String) -> Int? {
        guard let bytes = encode(word) else { return nil }
        return index(ofCodes: bytes)
    }

    /// Whether the model knows `word` (lowercase).
    public func contains(_ word: String) -> Bool { index(of: word) != nil }

    func index(ofCodes bytes: [UInt8]) -> Int? {
        var lo = 0, hi = wordCount
        for (depth, b) in bytes.enumerated() {
            (lo, hi) = narrow(lo, hi, depth: depth, byte: Int(b))
            if lo >= hi { return nil }
        }
        return length(lo) == bytes.count ? lo : nil
    }
}

/// A word list sorted by letter codes, searchable letter by letter: the model's, or one word.
protocol SpatialWordList {
    var wordCount: Int { get }
    func length(_ i: Int) -> Int
    /// The word's letter code at `depth`, or -1 past its end.
    func byte(_ i: Int, _ depth: Int) -> Int
}

extension SpatialWordList {
    /// The words in `lo..<hi` (which share their first `depth` codes) whose next code is
    /// `target`. Words are sorted by their code bytes, so this is two binary searches.
    func narrow(_ lo: Int, _ hi: Int, depth: Int, byte target: Int) -> (Int, Int) {
        var a = lo, b = hi
        while a < b {
            let mid = (a + b) / 2
            if byte(mid, depth) < target { a = mid + 1 } else { b = mid }
        }
        var c = a, d = hi
        while c < d {
            let mid = (c + d) / 2
            if byte(mid, depth) <= target { c = mid + 1 } else { d = mid }
        }
        return (a, c)
    }
}

extension SpatialDecoderModel: SpatialWordList {}
