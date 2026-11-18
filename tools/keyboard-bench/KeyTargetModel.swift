// tools/keyboard-bench/KeyTargetModel.swift
// The #949 spike: pick the letter of a tap from where it landed and from the letter the
// word being typed is likely to need next, as in Gunawardana, Paek and Meek, "Usability
// Guided Key-Target Resizing for Soft Keyboards" (IUI 2010). Bench code, not product
// code: the replay runs it in place of the plain hit test when asked to (run.sh --hit).
import Foundation
import UIKit

// MARK: - Next-letter mass from the shipped trie

/// Reads the `<lang>_spellcheck.dict` the keyboard ships (format: `dictus_trie_format.h`,
/// layout: `dictus_trie.cpp`) and answers how much word frequency lies under a prefix.
/// The trie stores `65535 * ln(1 + count) / ln(1 + maxCount)` per word
/// (`tools/dict_builder.py`); `mass` turns that back into a count before summing.
/// Accents are folded, because the typist types `tres` for `très`.
final class PrefixMass {
    private let bytes: [UInt8]
    private let rootCount: Int
    private let logMax: Double
    /// Mass under each one-letter prefix, summed once at load: without it, the first
    /// letter of every word walks a whole first-letter subtree (up to 18k nodes).
    private var firstLetter: [UInt16: Double] = [:]
    /// Nodes visited by the last `mass` call: the device-independent cost of a lookup.
    private(set) var visited = 0

    init?(path: String) {
        guard let data = FileManager.default.contents(atPath: path), data.count > 32,
              data.prefix(4) == Data("DTRI".utf8) else { return nil }
        bytes = [UInt8](data)
        let maxFreq = UInt32(bytes[16]) | UInt32(bytes[17]) << 8 | UInt32(bytes[18]) << 16 | UInt32(bytes[19]) << 24
        rootCount = Int(bytes[20])
        logMax = log(1 + Double(maxFreq))
        var offset = 32
        for _ in 0..<rootCount {
            let n = node(at: offset)
            firstLetter[fold(u16(n.charsOffset)), default: 0] += subtree(n)
            offset += n.size
        }
    }

    private struct Node {
        var charsOffset: Int
        var charCount: Int
        var terminal: Bool
        var frequency: UInt16
        var childCount: Int
        var childrenOffset: Int
        var size: Int
    }

    private func u16(_ at: Int) -> UInt16 { UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8 }

    private func node(at offset: Int) -> Node {
        let flags = bytes[offset]
        var p = offset + 1
        var count = 1
        if flags & 0x20 != 0 { count = Int(bytes[p]); p += 1 }
        let charsOffset = p
        p += 2 * count
        let terminal = flags & 0x10 != 0
        var frequency: UInt16 = 0
        if terminal { frequency = u16(p); p += 2 }
        let pointerSize = [0, 2, 3, 4][Int(flags & 0xC0) >> 6]
        var childCount = 0
        var childrenOffset = 0
        if pointerSize > 0 {
            childCount = Int(bytes[p])
            p += 1
            for i in 0..<pointerSize { childrenOffset |= Int(bytes[p + i]) << (8 * i) }
            p += pointerSize
        }
        return Node(charsOffset: charsOffset, charCount: count, terminal: terminal, frequency: frequency,
                    childCount: childCount, childrenOffset: childrenOffset, size: p - offset)
    }

    private func count(_ stored: UInt16) -> Double {
        stored == 0 ? 0 : exp(Double(stored) / 65535 * logMax) - 1
    }

    /// Summed frequency of every dictionary word whose folded form starts with `prefix`
    /// (folded, lowercase UTF-16).
    func mass(_ prefix: [UInt16]) -> Double {
        visited = 0
        if prefix.count == 1 { return firstLetter[prefix[0]] ?? 0 }
        return siblings(at: 32, count: rootCount, prefix[...])
    }

    private func siblings(at offset: Int, count: Int, _ rest: ArraySlice<UInt16>) -> Double {
        var total = 0.0
        var offset = offset
        for _ in 0..<count {
            let n = node(at: offset)
            visited += 1
            total += matching(n, rest)
            offset += n.size
        }
        return total
    }

    private func matching(_ n: Node, _ rest: ArraySlice<UInt16>) -> Double {
        var rest = rest
        for i in 0..<n.charCount {
            guard let first = rest.first else { break }
            if fold(u16(n.charsOffset + 2 * i)) != first { return 0 }
            rest = rest.dropFirst()
        }
        if rest.isEmpty { return subtree(n) }
        return n.childCount > 0 ? siblings(at: n.childrenOffset, count: n.childCount, rest) : 0
    }

    private func subtree(_ n: Node) -> Double {
        var total = n.terminal ? count(n.frequency) : 0
        var offset = n.childrenOffset
        for _ in 0..<n.childCount {
            let child = node(at: offset)
            visited += 1
            total += subtree(child)
            offset += child.size
        }
        return total
    }
}

/// Lowercase, accents removed, one UTF-16 unit in, one out, for Latin-1 and Latin
/// Extended-A; any other unit is its own fold.
private let foldTable: [UInt16] = (0..<0x180).map { (c: Int) -> UInt16 in
    guard let scalar = Unicode.Scalar(c) else { return UInt16(c) }
    let base = String(scalar).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).utf16
    return base.count == 1 ? base[base.startIndex] : UInt16(c)
}

func fold(_ c: UInt16) -> UInt16 { Int(c) < foldTable.count ? foldTable[Int(c)] : c }

func folded(_ s: String) -> [UInt16] { s.utf16.map(fold) }

// MARK: - The combined model

struct ModelParameters {
    /// Spread of the touch likelihood around a key centre, in key widths and row heights.
    var sigmaX: CGFloat = 0.25
    var sigmaY: CGFloat = 0.25
    /// A tap this close to the centre of the key under it types that key, always (#949 guardrail).
    var coreX: CGFloat = 0.25
    var coreY: CGFloat = 0.25
    /// Weight of the language term against the touch term.
    var weight: Double = 1
    /// Floor of a next letter no dictionary word continues with, as a share of the
    /// candidates' total mass. Keeps an unknown word typable, and bounds the language
    /// term at `weight * ln((1 + floor) / floor)`, so a boundary between two keys moves at
    /// most `sigmaX² * weight * ln((1 + floor) / floor)` key widths: 0.15 with these
    /// values. The default was chosen on the committed #954 runs, under the constraint
    /// of not breaking more rare-word letters than it fixes (docs/research/949-key-targets/).
    var floor: Double = 0.1
    /// Context: add the words the n-grams predict after the previous word.
    var ngram = false
    var ngramWeight: Double = 1

    /// `sx=0.25,sy=0.25,core=0.25,w=1,floor=0.1,ngram=1,nw=1`
    init(_ spec: String) {
        for pair in spec.split(separator: ",") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2, let v = Double(kv[1]) else { fatalError("bad model parameter \(pair)") }
            switch kv[0] {
            case "sx": sigmaX = CGFloat(v)
            case "sy": sigmaY = CGFloat(v)
            case "core": coreX = CGFloat(v); coreY = CGFloat(v)
            case "w": weight = v
            case "floor": floor = v
            case "ngram": ngram = v != 0
            case "nw": ngramWeight = v
            default: fatalError("unknown model parameter \(kv[0])")
            }
        }
        // A zero spread divides by zero in `pick`: every score is NaN or -infinity, nothing wins.
        guard sigmaX.isFinite, sigmaY.isFinite, sigmaX > 0, sigmaY > 0 else {
            fatalError("sx and sy must be positive")
        }
    }
}

final class KeyTargetModel {
    let parameters: ModelParameters
    private let trie: PrefixMass
    private let ngrams: AOSPTrieBridge?
    /// Words the n-grams predict after the previous word, with their bigram score;
    /// fetched once per word, at its first letter.
    private var context: (previous: String, words: [([UInt16], Double)])?
    /// Nodes the last `pick` visited in the trie.
    private(set) var visited = 0

    init(parameters: ModelParameters, trie: PrefixMass, ngrams: AOSPTrieBridge?) {
        self.parameters = parameters
        self.trie = trie
        self.ngrams = ngrams
    }

    /// The key a tap types. `plain` is today's answer, the cell under the point.
    /// `word` is the word being typed before this tap, `previous` the word before it.
    func pick(_ point: CGPoint, plain: Cell?, cells: [Cell], word: String, previous: String?) -> Cell? {
        visited = 0
        // Only taps on a letter, or in the gap between two keys, are redistributed.
        // Space, shift, delete and the accent key keep today's behaviour.
        if let plain = plain {
            guard isLetter(plain) else { return plain }
            let dx = abs(point.x - plain.frame.midX) / plain.unitWidth
            let dy = abs(point.y - plain.frame.midY) / plain.frame.height
            if dx <= parameters.coreX && dy <= parameters.coreY { return plain }
        }
        let candidates = cells.filter { cell in
            isLetter(cell)
                && abs(point.x - cell.frame.midX) / cell.unitWidth <= 1.5
                && abs(point.y - cell.frame.midY) / cell.frame.height <= 1.0
        }
        guard candidates.count > 1 else { return candidates.first ?? plain }

        let prefix = folded(word.lowercased())
        var masses = candidates.map { cell -> Double in
            let m = trie.mass(prefix + folded(letter(cell)))
            visited += trie.visited
            return m
        }
        // The n-grams move a share of the trie's mass to the letters that continue the
        // words they expect after the previous word.
        let unigram = masses.reduce(0, +)
        if parameters.ngram, let previous = previous {
            let predicted = predictions(after: previous)
            for (i, cell) in candidates.enumerated() {
                let next = prefix + folded(letter(cell))
                let share = predicted.reduce(0.0) { $1.0.starts(with: next) ? $0 + $1.1 : $0 }
                masses[i] += parameters.ngramWeight * share * unigram
            }
        }
        let total = masses.reduce(0, +)

        var best: Cell?
        var bestScore = -Double.infinity
        for (cell, mass) in zip(candidates, masses) {
            let dx = (point.x - cell.frame.midX) / cell.unitWidth / parameters.sigmaX
            let dy = (point.y - cell.frame.midY) / cell.frame.height / parameters.sigmaY
            var score = -0.5 * Double(dx * dx + dy * dy)
            if total > 0 {
                let share = (mass + parameters.floor * total) / (total * (1 + parameters.floor * Double(candidates.count)))
                score += parameters.weight * log(share)
            }
            if score > bestScore { best = cell; bestScore = score }
        }
        return best
    }

    /// The n-gram predictions after `previous`, as shares of their summed bigram score.
    private func predictions(after previous: String) -> [([UInt16], Double)] {
        if let context = context, context.previous == previous { return context.words }
        var words: [([UInt16], Double)] = []
        if let ngrams = ngrams {
            let prev = previous.lowercased()
            let predicted = ngrams.predict(afterWord: prev, maxResults: 50) as? [String] ?? []
            let scores = predicted.map { Double(ngrams.bigramScore(forWord: $0, afterWord: prev)) }
            let sum = scores.reduce(0, +)
            if sum > 0 { words = zip(predicted, scores).map { (folded($0.0), $0.1 / sum) } }
        }
        context = (previous, words)
        return words
    }

    private func isLetter(_ cell: Cell) -> Bool {
        if case .input(let k, let alternate) = cell.key.type, alternate != "accent", k.count == 1,
           k.first?.isLetter == true { return true }
        return false
    }

    private func letter(_ cell: Cell) -> String {
        if case .input(let k, _) = cell.key.type { return k }
        return ""
    }
}
