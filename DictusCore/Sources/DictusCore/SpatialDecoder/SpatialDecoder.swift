// DictusCore/Sources/DictusCore/SpatialDecoder/SpatialDecoder.swift
//
// Ported from Hex (github.com/anomalyco/hex, branch dev, ios/HEXShared/FullKeyboard/
// TypingDecoder.swift, `TypingDecoder`), MIT, Copyright (c) 2026 Christopher Langton (#1011).
//
// Kept as Hex has it: the tap costs, the beam search, the edits, the split readings, the
// margins and Hex's tuned parameters. Left out for now: your own words (Hex searches
// Contacts and learned words too; Dictus keeps learned words immune and never a target,
// ADR 0004), the never-suggest list and the space-as-letter merge. Hex's adaptive touch
// reads the taps with personal centres (DictusCore/AdaptiveTouch, #1014), gated by
// `replaces(with:)` with the stock ones.
import CoreGraphics
import Foundation

/// A noisy-channel word decoder. Each tap is scored against every letter with a 2D
/// Gaussian around the key's centre, words are searched in the model's sorted word list
/// with a beam, and the word-pair model weighs them by the word before. A missed space is
/// tried by splitting the taps in two. What you typed is replaced only when the best
/// reading beats it by a margin.
///
/// WHY a decoder on the taps rather than on the letters: the trie only sees `trouce`; the
/// taps also say the `c` landed on the edge of `v`. A one-edit guess cannot tell `trouve`
/// from `trouée`, the touch point can.
public struct SpatialDecoder {
    public struct Parameters: Equatable, Sendable {
        // Hex's values, tuned on its benchmark's dev sentences.
        /// Touch spread as a share of the key pitch (key width plus gap; row height plus gap).
        public var sigmaX = 0.29
        public var sigmaY = 0.26
        public var lmWeight = 1.25
        public var deletionCost = 7.0
        public var insertionCost = 7.0
        public var transpositionCost = 5.0
        public var spaceOmissionCost = 6.0
        /// A tap on the bottom row read as a space the finger missed ("ofbthe"): this, plus
        /// `spaceTapWeight` times how much nearer its letter row than the space bar it landed.
        public var spaceTapCost = 5.0
        public var spaceTapWeight = 0.25
        public var maxEdits = 1
        public var beam = 48
        /// Nats the best reading must beat what you typed by to replace it on space.
        public var autoMargin = 2.0
        /// The same when what you typed is itself a word.
        public var validMargin = 7.0
        /// Language-model cost of a word the model lacks that the dictionary accepts, and
        /// of one nothing accepts.
        public var unknownValidCost = 15.0
        public var unknownCost = 22.0
        public var maxTapCost = 9.0
        public var splits = true
        /// Extra cost of an accented letter typed as its base letter's key (é from e).
        public var accentCost = 1.0
        /// A one-letter word stands alone in a split only when commoner than this (-ln p).
        public var oneLetterWordCost = 7.0
        /// The margin when the best reading only adds or moves accents on what you typed.
        public var accentMargin = 2.0

        public init() {}

        /// Hex's settings per language: English leans more on the word before, and Spanish's
        /// many short words make a letter read as a space too cheap a split.
        public static func tuned(for language: String) -> Parameters {
            var p = Parameters()
            if language == "en" { p.lmWeight = 1.5 }
            if language == "es" { p.spaceTapCost = .infinity }
            return p
        }
    }

    /// The letter keys of the page the taps were made on, in the taps' coordinates.
    public struct Keys: Equatable, Sendable {
        public var centres: [Character: CGPoint]
        /// One key's width and one row's height (Dictus's cells abut, so the cell is the pitch).
        public var pitch: CGSize
        /// The bottom letter row's centre, below which a tap may have been meant for space.
        public var bottomRowY: CGFloat
        /// The space bar, or nil when unknown.
        public var space: CGRect?

        public init(centres: [Character: CGPoint], pitch: CGSize, bottomRowY: CGFloat, space: CGRect?) {
            self.centres = centres
            self.pitch = pitch
            self.bottomRowY = bottomRowY
            self.space = space
        }
    }

    public struct Reading: Equatable, Sendable {
        public var text: String
        public var cost: Double
    }

    public struct Decision: Equatable, Sendable {
        /// What space should put in place of what you typed, or nil to keep it. Lowercase,
        /// one word or two separated by a space.
        public var replacement: String?
        /// Readings better than what you typed, best first.
        public var readings: [Reading]
        public var literalCost: Double
    }

    public let model: SpatialDecoderModel
    public var parameters: Parameters

    public init(model: SpatialDecoderModel, parameters: Parameters? = nil) {
        self.model = model
        self.parameters = parameters ?? Parameters.tuned(for: model.language)
    }

    /// `typed` is the lowercase letters the keys resolved, one per tap, without apostrophes
    /// (the search puts those back for free). `literal` is the word as the document has it,
    /// apostrophes included ("j'aa"), when it differs from `typed`. `previous` is the word
    /// before, lowercase (a clitic the model keeps apart, "l'", counts as one). Nil when the
    /// model can't read it: a letter it lacks, or taps that don't match the letters.
    public func decide(
        taps: [CGPoint], typed: String, literal: String? = nil, previous: String?, literalIsValid: Bool, keys: Keys
    ) -> Decision? {
        let literal = literal ?? typed
        guard taps.count == typed.count, !typed.isEmpty, let letters = model.encode(typed),
              !letters.contains(where: { $0 == model.apostropheCode }) else { return nil }
        let centres = codeCentres(keys)
        let costs = taps.map { tapCosts($0, centres: centres, keys: keys) }
        let prev = previous.flatMap { model.index(of: $0) }

        var literalCost = 0.0
        for (i, code) in letters.enumerated() {
            let c = costs[i][Int(code)]
            guard c.isFinite else { return nil }
            literalCost += c
        }
        let literalIndex = model.index(of: literal)
        let literalLM = literalIndex.map { lmCost($0, after: prev) }
            ?? (literalIsValid ? parameters.unknownValidCost : parameters.unknownCost)
        literalCost += parameters.lmWeight * literalLM

        var readings: [Reading] = []
        for (word, spatial) in search(model, costs, range: 0..<costs.count, limit: 5, maxEdits: parameters.maxEdits)
        where word != literalIndex {
            readings.append(Reading(text: model.word(word), cost: spatial + parameters.lmWeight * lmCost(word, after: prev)))
        }
        if parameters.splits, letters.count >= 3 {
            readings += splitReadings(costs, taps: taps, letters: letters, keys: keys, prev: prev)
        }
        readings.sort { $0.cost < $1.cost }
        var seen = Set<String>()
        readings = readings.filter {
            $0.text != literal && $0.cost < literalCost && seen.insert($0.text).inserted
        }

        var replacement: String?
        if let best = readings.first {
            var margin = (literalIndex != nil || literalIsValid) ? parameters.validMargin : parameters.autoMargin
            if Self.withoutAccents(best.text) == Self.withoutAccents(literal) {
                margin = min(margin, parameters.accentMargin)
            }
            if literalCost - best.cost >= margin { replacement = best.text }
        }
        return Decision(replacement: replacement, readings: Array(readings.prefix(3)), literalCost: literalCost)
    }

    /// The text with acute, grave, circumflex and diaeresis marks removed (é -> e), keeping ñ.
    public static func withoutAccents(_ text: String) -> String {
        let marks: ClosedRange<UInt32> = 0x300...0x308
        let scalars = text.decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { !(marks.contains($0.value) && $0.value != 0x303) }
        return String(String.UnicodeScalarView(scalars)).precomposedStringWithCanonicalMapping
    }

    /// -ln P(word | previous) with stupid backoff (0.4) to the unigram.
    private func lmCost(_ word: Int, after prev: Int?) -> Double {
        let backoff = 0.92 + model.unigramCost(word)
        guard let prev, let bigram = model.bigramCost(prev, word) else { return backoff }
        return min(bigram, backoff)
    }

    /// Key centres by the model's letter codes; nil for letters without a key.
    private func codeCentres(_ keys: Keys) -> [CGPoint?] {
        var out = [CGPoint?](repeating: nil, count: model.characters.count)
        for (c, p) in keys.centres {
            if let code = model.codes[c] { out[Int(code)] = p }
        }
        return out
    }

    /// Each letter code's cost for one tap, in nats above the likeliest letter's. An
    /// accented letter costs at most its base letter's plus `accentCost`; one with neither
    /// key is impossible (infinity).
    private func tapCosts(_ p: CGPoint, centres: [CGPoint?], keys: Keys) -> [Double] {
        let sx = Double(keys.pitch.width) * parameters.sigmaX
        let sy = Double(keys.pitch.height) * parameters.sigmaY
        var out = centres.map { centre -> Double in
            guard let c = centre else { return .infinity }
            let dx = (Double(p.x) - Double(c.x)) / sx
            let dy = (Double(p.y) - Double(c.y)) / sy
            return 0.5 * (dx * dx + dy * dy)
        }
        let raw = out
        for code in out.indices where code > 0 {
            let base = Int(model.baseCodes[code])
            if base != code, raw[base].isFinite { out[code] = min(raw[code], raw[base] + parameters.accentCost) }
        }
        let best = out.filter(\.isFinite).min() ?? 0
        for i in out.indices { out[i] -= best }
        return out
    }

    private struct State {
        var lo: Int32
        var hi: Int32
        var tap: Int16
        var edits: Int8
        var cost: Float
    }

    /// The best words of `words` for `costs[range]`, as (word index, spatial cost
    /// including edits).
    private func search<Words: SpatialWordList>(
        _ words: Words, _ costs: [[Double]], range: Range<Int>, limit: Int, maxEdits: Int
    ) -> [(Int, Double)] {
        let n = range.count
        let maxDepth = n + maxEdits + 2
        var layers = [[State]](repeating: [], count: maxDepth + 2)
        layers[0] = [State(lo: 0, hi: Int32(words.wordCount), tap: 0, edits: 0, cost: 0)]
        var found: [Int: Double] = [:]
        let letterChoices: [[(Int, Double)]] = range.map { i in
            costs[i].enumerated().filter { $0.offset > 0 && $0.element <= parameters.maxTapCost }
                .sorted { $0.element < $1.element }.map { ($0.offset, $0.element) }
        }
        // Dropping a clearly aimed, distinct tap needs more evidence than dropping an
        // accidental repeat or a tap between keys. Accents share their physical key.
        let extraTapCosts: [Double] = maxEdits == 0 ? [] : letterChoices.indices.map { tap in
            guard let code = letterChoices[tap].first?.0 else { return parameters.insertionCost }
            let key = model.baseCodes[code]
            for neighbor in [tap - 1, tap + 1] where letterChoices.indices.contains(neighbor) {
                if let other = letterChoices[neighbor].first?.0, model.baseCodes[other] == key {
                    return parameters.insertionCost
                }
            }
            let gap = letterChoices[tap].first { model.baseCodes[$0.0] != key }?.1 ?? parameters.maxTapCost
            return parameters.insertionCost + min(4, gap)
        }
        let apostrophe = model.apostropheCode.map(Int.init)
        let allCodes = (1..<model.characters.count).filter { $0 != apostrophe }
        for depth in 0...maxDepth {
            var layer = layers[depth]
            if layer.count > parameters.beam {
                layer.sort { $0.cost < $1.cost }
                layer.removeLast(layer.count - parameters.beam)
            }
            var k = 0
            while k < layer.count {
                let s = layer[k]
                k += 1
                let lo = Int(s.lo), hi = Int(s.hi), tap = Int(s.tap)
                if tap == n, words.length(lo) == depth {
                    let c = Double(s.cost)
                    if c < found[lo] ?? .infinity { found[lo] = c }
                }
                guard depth < maxDepth else { continue }
                func push(_ code: Int, tap nextTap: Int, edits: Int8, cost: Double) {
                    let (a, b) = words.narrow(lo, hi, depth: depth, byte: code)
                    guard a < b else { return }
                    layers[depth + 1].append(State(lo: Int32(a), hi: Int32(b), tap: Int16(nextTap), edits: edits, cost: Float(cost)))
                }
                let base = Double(s.cost)
                if tap < n {
                    for (code, c) in letterChoices[tap] {
                        push(code, tap: tap + 1, edits: s.edits, cost: base + c)
                    }
                }
                // Apostrophes are never typed: "dont" reads as "don't" for free.
                if depth > 0, let apostrophe { push(apostrophe, tap: tap, edits: s.edits, cost: base) }
                guard Int(s.edits) < maxEdits else { continue }
                let e = s.edits + 1
                // A letter you didn't type.
                for code in allCodes {
                    push(code, tap: tap, edits: e, cost: base + parameters.deletionCost)
                }
                // A tap that isn't in the word.
                if tap < n {
                    layer.append(State(lo: s.lo, hi: s.hi, tap: s.tap + 1, edits: e, cost: Float(base + extraTapCosts[tap])))
                }
                // Two letters typed in the wrong order.
                if tap + 1 < n, depth + 2 <= maxDepth {
                    for (a, ca) in letterChoices[tap + 1].prefix(3) {
                        let (lo2, hi2) = words.narrow(lo, hi, depth: depth, byte: a)
                        guard lo2 < hi2 else { continue }
                        for (b, cb) in letterChoices[tap].prefix(3) where b != a {
                            let (lo3, hi3) = words.narrow(lo2, hi2, depth: depth + 1, byte: b)
                            guard lo3 < hi3 else { continue }
                            layers[depth + 2].append(State(
                                lo: Int32(lo3), hi: Int32(hi3), tap: Int16(tap + 2), edits: e,
                                cost: Float(base + ca + cb + parameters.transpositionCost)
                            ))
                        }
                    }
                }
            }
        }
        // Ties broken by word index, so a replay is the same in every process.
        return found.sorted { $0.value != $1.value ? $0.value < $1.value : $0.key < $1.key }
            .prefix(limit).map { ($0.key, $0.value) }
    }

    /// Two words where the taps had no space, or one meant for space ("seehow", "seenhow").
    /// Each half is read with substitutions only, which keeps this cheap; around a tap on
    /// the bottom row's upper half read as a space ("ofbthe"), only as the letters typed.
    private func splitReadings(_ costs: [[Double]], taps: [CGPoint], letters: [UInt8], keys: Keys, prev: Int?) -> [Reading] {
        let n = costs.count
        var out: [Reading] = []
        func pair(left: Range<Int>, right: Range<Int>, extra: Double, exact: Bool = false) {
            guard !left.isEmpty, !right.isEmpty else { return }
            func halves(_ range: Range<Int>) -> [(Int, Double)] {
                guard exact else { return search(model, costs, range: range, limit: 3, maxEdits: 0) }
                guard let word = model.index(ofCodes: Array(letters[range])) else { return [] }
                return [(word, range.reduce(0) { $0 + costs[$1][Int(letters[$1])] })]
            }
            let lefts = halves(left).filter { canStandAlone($0.0) }
            guard !lefts.isEmpty else { return }
            // A clitic ("l'") ends a split only before a word, never at its end.
            let rights = halves(right).filter { canStandAlone($0.0) && !model.word($0.0).hasSuffix("'") }
            for (l, ls) in lefts {
                let lcost = ls + parameters.lmWeight * lmCost(l, after: prev)
                for (r, rs) in rights {
                    let cost = lcost + rs + parameters.lmWeight * lmCost(r, after: l) + extra
                    out.append(Reading(text: Self.join(model.word(l), model.word(r)), cost: cost))
                }
            }
        }
        for k in 1..<n {
            pair(left: 0..<k, right: k..<n, extra: parameters.spaceOmissionCost)
            guard k < n - 1 else { continue }
            if taps[k].y > keys.bottomRowY {
                pair(left: 0..<k, right: (k + 1)..<n, extra: parameters.spaceOmissionCost)
            } else if let extra = spaceCost(of: taps[k], keys: keys) {
                pair(left: 0..<k, right: (k + 1)..<n, extra: extra, exact: true)
            }
        }
        return out
    }

    /// Two words of a split. An elided clitic takes no space after it ("j'" + "ai").
    static func join(_ left: String, _ right: String) -> String {
        left.hasSuffix("'") ? left + right : left + " " + right
    }

    /// The cost of reading a tap on the bottom row's upper half as a space the finger
    /// missed, or nil when it can't be one.
    private func spaceCost(of tap: CGPoint, keys: Keys) -> Double? {
        guard parameters.spaceTapCost.isFinite, let bar = keys.space, bar.width > 0 else { return nil }
        let slack = keys.pitch.width / 2
        guard tap.x >= bar.minX - slack, tap.x <= bar.maxX + slack,
              tap.y > keys.bottomRowY - keys.pitch.height / 2 else { return nil }
        let sy = Double(keys.pitch.height) * parameters.sigmaY
        let toBar = (Double(tap.y) - Double(bar.midY)) / sy
        let toRow = (Double(tap.y) - Double(keys.bottomRowY)) / sy
        let likelierRow = max(0, 0.5 * (toBar * toBar - toRow * toRow))
        return parameters.spaceTapCost + parameters.spaceTapWeight * likelierRow
    }

    /// What `decide` would score `reading` at for these taps: its best alignment with the
    /// taps (one edit at most, apostrophes free) plus the word-pair cost, in nats. Nil when
    /// the model lacks the word or no alignment within the edits fits. Ported from Hex's
    /// `replaces(with:)`, which asks the same question for adaptive touch.
    public func cost(of reading: String, taps: [CGPoint], previous: String?, keys: Keys) -> Double? {
        guard !taps.isEmpty, let codes = model.encode(reading), let index = model.index(ofCodes: codes) else { return nil }
        let centres = codeCentres(keys)
        let costs = taps.map { tapCosts($0, centres: centres, keys: keys) }
        let prev = previous.flatMap { model.index(of: $0) }
        guard let spatial = search(OneWord(codes: codes), costs, range: 0..<costs.count, limit: 1,
                                   maxEdits: parameters.maxEdits).first?.1 else { return nil }
        return spatial + parameters.lmWeight * lmCost(index, after: prev)
    }

    /// Whether `decide` with `keys` would put `reading` (one word) in place of what you typed:
    /// it beats the literal by the margin. Nil for a two-word reading, which only `decide`
    /// can tell. Ported from Hex's `replaces(with:)` (#1014): Adaptive touch asks it with the
    /// stock centres, so a correction it applies is one the keyboard would apply anyway.
    /// It takes `decide`'s arguments plus the reading, hence one parameter over the lint's
    /// limit: a struct for this call alone would hide the parallel with `decide`.
    public func replaces( // swiftlint:disable:this function_parameter_count
        with reading: String, taps: [CGPoint], typed: String, literal: String? = nil, previous: String?,
        literalIsValid: Bool, keys: Keys
    ) -> Bool? {
        guard !reading.contains(" ") else { return nil }
        let literal = literal ?? typed
        guard taps.count == typed.count, !typed.isEmpty, let letters = model.encode(typed),
              !letters.contains(where: { $0 == model.apostropheCode }) else { return false }
        let centres = codeCentres(keys)
        let costs = taps.map { tapCosts($0, centres: centres, keys: keys) }
        let prev = previous.flatMap { model.index(of: $0) }
        var literalCost = 0.0
        for (i, code) in letters.enumerated() {
            let c = costs[i][Int(code)]
            guard c.isFinite else { return false }
            literalCost += c
        }
        let literalIndex = model.index(of: literal)
        literalCost += parameters.lmWeight * (literalIndex.map { lmCost($0, after: prev) }
            ?? (literalIsValid ? parameters.unknownValidCost : parameters.unknownCost))
        guard let readingCost = cost(of: reading, taps: taps, previous: previous, keys: keys) else { return false }
        var margin = (literalIndex != nil || literalIsValid) ? parameters.validMargin : parameters.autoMargin
        if Self.withoutAccents(reading) == Self.withoutAccents(literal) {
            margin = min(margin, parameters.accentMargin)
        }
        return literalCost - readingCost >= margin
    }

    /// One word, searched as a word list.
    private struct OneWord: SpatialWordList {
        let codes: [UInt8]
        var wordCount: Int { 1 }
        func length(_ i: Int) -> Int { codes.count }
        func byte(_ i: Int, _ depth: Int) -> Int { depth < codes.count ? Int(codes[depth]) : -1 }
    }

    /// A word that may stand alone in a split: two or more letters, or a common one-letter word.
    private func canStandAlone(_ i: Int) -> Bool {
        model.length(i) >= 2 || model.unigramCost(i) < parameters.oneLetterWordCost
    }
}
