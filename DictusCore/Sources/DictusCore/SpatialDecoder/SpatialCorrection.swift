// DictusCore/Sources/DictusCore/SpatialDecoder/SpatialCorrection.swift
import CoreGraphics
import Foundation

/// The space bar's question to the spatial decoder (#1011), for one word as the document
/// has it: its case, its elided clitic ("J'aa"), and the taps that typed it.
public enum SpatialCorrection {
    /// The taps of one word and the keys they were made on.
    public struct Input: Equatable {
        public var taps: [CGPoint]
        public var keys: SpatialDecoder.Keys

        public init(taps: [CGPoint], keys: SpatialDecoder.Keys) {
            self.taps = taps
            self.keys = keys
        }
    }

    /// What the rest of the engine knows about the word.
    public struct Facts: Equatable {
        /// The word is a word already (the trie, the user's words): the margin is higher.
        public var isKnown: Bool
        /// The user taught the keyboard this word: the decoder is not asked (ADR 0004).
        public var isLearned: Bool
        /// The trie's correction from the letters, when it has one.
        public var trieCorrection: String?

        public init(isKnown: Bool, isLearned: Bool, trieCorrection: String? = nil) {
            self.isKnown = isKnown
            self.isLearned = isLearned
            self.trieCorrection = trieCorrection
        }
    }

    public struct Result: Equatable {
        /// What replaces the word, in the document's case ("J'ai", "Je pense").
        public var correction: String
        /// The other readings that beat the word, for the bar.
        public var alternatives: [String]
    }

    /// The decoder's replacement for `word`, or nil to leave the word to the rest of the
    /// engine. `input.taps` holds one point per character of `word`.
    ///
    /// When the trie corrects the word too, to another word, the decoder scores the trie's
    /// correction on the same taps and keeps whichever costs less. A correction it cannot
    /// score (more than one edit away, two words, a word its model lacks) stays the trie's:
    /// on Pierre's device sessions the trie was right in most such cases ("sats" -> "sais",
    /// "orzt" -> "est"), and the decoder's strength is where the trie keeps the word.
    public static func correct(
        _ word: String,
        previousWord: String?,
        input: Input,
        with decoder: SpatialDecoder,
        facts: Facts
    ) -> Result? {
        let (isKnown, isLearned) = (facts.isKnown, facts.isLearned)
        guard !isLearned, input.taps.count == word.count else { return nil }
        let chars = Array(word)
        // A capital inside the word (an acronym, "iPhone") is not the decoder's to read.
        guard chars.dropFirst().allSatisfy({ !$0.isUppercase }) else { return nil }
        let lowered = Array(word.lowercased())
        guard lowered.count == chars.count else { return nil }
        // Google Books keeps most elisions whole ("j'ai", "qu'il", "c'est") and splits off
        // "l'" and "d'" ("l'" + "homme"). So a word after a clitic the model has on its own
        // is read alone, with the clitic as the word before; any other word is read whole,
        // its apostrophes left out of the taps for the search to put back for free.
        let apostrophe = lowered.lastIndex(of: "'")
        var clitic = ""
        var tapRange = 0..<lowered.count
        if let apostrophe, apostrophe + 1 < lowered.count,
           decoder.model.contains(String(lowered[...apostrophe])) {
            clitic = String(chars[...apostrophe])
            tapRange = (apostrophe + 1)..<lowered.count
        }
        let readFrom = Array(tapRange)
        let kept = readFrom.filter { lowered[$0] != "'" }
        guard kept.count >= 2 else { return nil }
        let literal = String(lowered[tapRange])
        let previous = clitic.isEmpty ? previousWord?.lowercased() : clitic.lowercased()
        guard let decision = decoder.decide(
            taps: kept.map { input.taps[$0] }, typed: String(kept.map { lowered[$0] }), literal: literal,
            previous: previous, literalIsValid: isKnown, keys: input.keys
        ), let replacement = decision.replacement,
        // A change of accents alone is the accent rules' to make (#1000, #1008), which know
        // French grammar the word-pair model does not; and an accent typed with the accent
        // key was meant ("sôt" is "sont", never "sot").
        SpatialDecoder.withoutAccents(replacement) != SpatialDecoder.withoutAccents(literal) else { return nil }
        let taps = kept.map { input.taps[$0] }

        if let trie = facts.trieCorrection?.lowercased(), trie != clitic.lowercased() + replacement {
            // The trie's word in the decoder's terms: what follows the same clitic.
            guard trie.hasPrefix(clitic.lowercased()),
                  let best = decision.readings.first?.cost,
                  let rival = decoder.cost(of: String(trie.dropFirst(clitic.count)), taps: taps,
                                           previous: previous, keys: input.keys),
                  best < rival else { return nil }
        }

        let capitalised = chars.first?.isUppercase == true
        func display(_ reading: String) -> String {
            let whole = clitic + reading
            guard capitalised, let first = whole.first else { return whole }
            return first.uppercased() + whole.dropFirst()
        }
        let alternatives = decision.readings.map(\.text).filter { $0 != replacement }.map(display)
        return Result(correction: display(replacement), alternatives: alternatives)
    }
}
