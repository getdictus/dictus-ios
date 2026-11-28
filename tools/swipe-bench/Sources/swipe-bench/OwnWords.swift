// tools/swipe-bench/Sources/swipe-bench/OwnWords.swift
// The own-words runs (#1090): the user's words swiped mid-sentence, and what they cost the
// dictionary's words. `--own-words` turns them on; see the README.
import CoreGraphics
import DictusCore
import Foundation

/// What the user taught the keyboard, as the keyboard's stores would hold it: learned words
/// as typed with their usage counts (`UserDictionary`), contact names (`SupplementaryLexicon`).
/// The same set for every language, as the store has no language tag (ADR 0004).
enum OwnWordsSet {
    /// Adopted (typed twice or more): read by a swipe, written as typed.
    static let adopted: [(typed: String, uses: Int)] = [
        ("Apple", 2), ("WisprFlow", 3), ("Titus", 2), ("Gwendal", 4), ("Kubernetes", 2), ("Figma", 5)
    ]

    /// Typos learned and then typed again, so adopted: the worst a learned word can do to a
    /// swipe. Most draw the very path of a common word, a double letter or an accent or an
    /// apostrophe apart (« realy », « tambien », « vieleicht », « quil »): the decoder has
    /// only the word model to tell them apart.
    static let adoptedTypos: [(typed: String, uses: Int)] = [
        ("bonjoru", 2), ("mainteant", 2), ("quil", 2), ("toujour", 2),
        ("realy", 2), ("becuase", 2), ("thier", 2), ("dont", 2),
        ("tambien", 2), ("despues", 2), ("porfavor", 2),
        ("vieleicht", 2), ("nich", 2), ("wiso", 2)
    ]

    /// Typos learned on one refusal (#872), never typed again: no swipe may read them.
    static let learnedOnce: [(typed: String, uses: Int)] = [
        ("crayin", 1), ("mercu", 1), ("helo", 1), ("thnaks", 1), ("graicas", 1), ("danle", 1)
    ]

    /// Contact names (lexicon words).
    static let contacts = ["Zofiak", "Maëlle", "Oriane"]

    /// Every learned word, as `UserDictionary.allLearnedWords` and `casing(of:)` give them.
    static var learned: [String: SwipeOwnWords.Learned] {
        var words: [String: SwipeOwnWords.Learned] = [:]
        for (typed, uses) in adopted + adoptedTypos + learnedOnce {
            words[typed.lowercased()] = SwipeOwnWords.Learned(uses: uses, casing: typed)
        }
        return words
    }

    static var lexicon: SupplementaryLexicon {
        SupplementaryLexicon(entries: contacts.map { (userInput: $0, documentText: $0) })
    }

    /// The words the keyboard hands the decoder (`DictusKeyboardBridge.swipeTypingOwnWords`).
    static var words: [String] {
        SwipeOwnWords.words(learnedUses: learned.mapValues(\.uses), lexiconWords: lexicon.lowercasedWords)
    }

    /// The words the learned-words run swipes, as they must come out mid-sentence: the
    /// adopted learned words, the contacts, and three of `CuratedNames`.
    static let targets = adopted.map(\.typed) + contacts + ["Dictus", "WhatsApp", "Netflix"]
}

extension SwipeDecoder {
    /// This decoder with the own words added, as `SwipeTypingController.syncOwnWords` adds them.
    func withOwnWords(_ words: [String]) -> SwipeDecoder {
        var decoder = self
        var extra = extraWords
        SwipeOwnWords.add(words, to: &extra, model: model)
        decoder.extraWords = extra
        return decoder
    }
}

/// A reading as the keyboard writes it mid-sentence: `SwipeOwnWords.written`, then no
/// sentence capital. The dictionary check the lexicon asks for is the model's here: the bench
/// has no spellcheck trie.
func writtenMidSentence(_ reading: String, model: SpatialDecoderModel) -> String {
    let lexicon = OwnWordsSet.lexicon, learned = OwnWordsSet.learned
    let written = SwipeOwnWords.written(
        reading,
        lexiconDecision: { lexicon.decision(for: $0, isDictionaryWord: model.contains($0)) },
        learned: { learned[$0] }
    )
    return SwipeTypingText.cased(written, capital: false, capsLock: false)
}

struct OwnWordsTally {
    var swiped = 0
    var first = 0
    var top4 = 0
    /// Swipes of a dictionary word whose first reading became an own word.
    var stolen: [String: Int] = [:]
    /// Readings, anywhere in the first four, that are a word learned once.
    var learnedOnceRead = 0
    var missed: [String: Int] = [:]
    var found: [String: Int] = [:]

    var row: String {
        let n = Double(max(1, swiped))
        return String(format: "%d | %.1f%% | %.1f%%", swiped, 100 * Double(first) / n, 100 * Double(top4) / n)
    }
}

/// Every own target word, swiped mid-sentence: put after the middle word of each of the first
/// `sentences` test sentences, with that word before it. Right only with its casing.
func runOwnTargets(_ o: Options, lang: String, style: String, decoder: SwipeDecoder, page: LetterPage, sentences count: Int,
                   writes: Bool) -> OwnWordsTally {
    guard let noise = Noise.named(style) else { fatalError("unknown style \(style)") }
    let centres = page.capsInPitches
    var rng = SplitMix64(seed: UInt64(o.seed * 7919 + (seedOffset[lang] ?? 0) + 1090))
    var tally = OwnWordsTally()
    let onceWords = Set(OwnWordsSet.learnedOnce.map { $0.typed.lowercased() })
    for sentence in sentences(o, lang).prefix(count) {
        let words = sentence.split(separator: " ").map(String.init)
        guard words.count >= 2 else { continue }
        let previous = words[(words.count - 1) / 2]
        for target in OwnWordsSet.targets {
            let sloppiness = exp(rng.gaussian() * noise.sloppiness)
            guard let sequence = SwipePaths.keySequence(target.lowercased(), centres: centres), sequence.count >= 2 else { continue }
            let (points, times) = SwipePaths.swipeTimed(sequence.compactMap { centres[$0] }, noise: noise, sloppiness: sloppiness,
                                                        rng: &rng, onLetter: page.onLetter)
            let cgPoints = points.map {
                CGPoint(x: min(max($0.0 * Double(page.pitch.width), 0), Double(page.width)), y: $0.1 * Double(page.pitch.height))
            }
            let readings = decoder.decode(cgPoints, times: times, keys: page.keys, previous: previous, limit: 4)
                .map { writes ? writtenMidSentence($0.text, model: decoder.model) : $0.text }
            tally.swiped += 1
            if readings.first == target {
                tally.first += 1
                tally.found[target, default: 0] += 1
            } else {
                tally.missed[target, default: 0] += 1
            }
            if readings.contains(target) { tally.top4 += 1 }
            tally.learnedOnceRead += readings.filter { onceWords.contains($0.lowercased()) }.count
        }
    }
    return tally
}

/// Which of a dictionary run's first readings an own word took: the logged readings of the
/// same swipes with and without the own words, compared line by line.
func stolenFirsts(without: [String], with: [String]) -> (stolen: [String: Int], learnedOnce: Int) {
    let own = Set(OwnWordsSet.words)
    let once = Set(OwnWordsSet.learnedOnce.map { $0.typed.lowercased() })
    var stolen: [String: Int] = [:]
    var learnedOnce = 0
    for (a, b) in zip(without, with) {
        let before = a.split(separator: "\t", omittingEmptySubsequences: false)
        let after = b.split(separator: "\t", omittingEmptySubsequences: false)
        guard before.count >= 3, after.count >= 3 else { continue }
        let readings = after[2].split(separator: "|").map(String.init)
        learnedOnce += readings.filter { once.contains($0) }.count
        let firstBefore = before[2].split(separator: "|").first.map(String.init)
        guard let firstAfter = readings.first, firstAfter != firstBefore, own.contains(firstAfter) else { continue }
        stolen["\(before[0]) → \(firstAfter)", default: 0] += 1
    }
    return (stolen, learnedOnce)
}
