// DictusCore/Sources/DictusCore/TextCorrection/AccentExpander.swift
// Generates the accented spellings of a typed word that the dictionary has, and lets
// AccentRestoration pick one.
import Foundation

/// Tries adding accents to `word` and decides whether one of the resulting dictionary
/// words replaces it (`AccentRestoration`).
///
/// Examples (French): `"deja"` → `déjà`, `"apres"` → `après`, `"publie"` → kept
/// (`publié` is only 3.6x as frequent), `"arrive"` after `est` → `arrivé`.
///
/// Algorithm:
///   1. Find each position in `word` whose letter has accent variants in `profile.accentMap`.
///   2. Generate single-substitution candidates and double-substitution candidates,
///      then the length-changing ones of `profile.collapseRules`.
///   3. Keep the candidates the dictionary has, with their corpus counts.
///   4. Hand them, the typed word's own count when it is a word, and the participle
///      context of `previousWord` to `AccentRestoration.decide`.
///
/// WHY only single and double substitutions (not all combinations):
/// Real-world accented words rarely have more than two accented characters.
/// Generating all 2^N candidates is wasteful and risks false positives.
/// Empirically, "déjà", "après", "éléphant" — all double; nothing in our corpora
/// requires triple substitution.
///
/// WHY collapse rules are tried separately:
/// Single/double character substitutions preserve word length. Some accents
/// (German `ß`, replacing `ss`) require deleting a position, so they're
/// modeled as substring substitutions in `profile.collapseRules`. Each
/// collapse occurrence is tried independently against the dictionary.
///
/// - Parameters:
///   - profile: The active language's profile.
///   - word: The input word (any case), without any apostrophe prefix.
///   - previousWord: The word before it, for `profile.participleContext`.
///   - provider: Backend used to score candidates by frequency and existence.
public func restoreAccents(
    profile: LanguageProfile,
    word: String,
    previousWord: String? = nil,
    provider: FrequencyProvider
) -> AccentRestoration.Decision {
    guard provider.isReady else { return .keepTyped }
    let lowered = word.lowercased()
    guard lowered.count >= 2 else { return .keepTyped }

    let accentMap = profile.accentMap
    let collapseRules = profile.collapseRules
    guard !accentMap.isEmpty || !collapseRules.isEmpty else { return .keepTyped }

    var accentablePositions: [(Int, [Character])] = []
    let chars = Array(lowered)
    for (i, ch) in chars.enumerated() {
        if let accents = accentMap[ch] {
            accentablePositions.append((i, accents))
        }
    }

    var spellings: [AccentRestoration.Spelling] = []

    func checkCandidate(_ candidateWord: String) {
        guard provider.frequency(of: candidateWord) > 0 || provider.wordExists(candidateWord) else { return }
        spellings.append(.init(word: candidateWord, count: provider.corpusCount(of: candidateWord)))
    }

    // Single substitutions.
    for (pos, accents) in accentablePositions {
        for accent in accents {
            var candidate = chars
            candidate[pos] = accent
            checkCandidate(String(candidate))
        }
    }

    // Double substitutions (déjà, après, éléphant, etc.).
    if accentablePositions.count >= 2 {
        for i in 0..<accentablePositions.count {
            for j in (i + 1)..<accentablePositions.count {
                let (pos1, accents1) = accentablePositions[i]
                let (pos2, accents2) = accentablePositions[j]
                for a1 in accents1 {
                    for a2 in accents2 {
                        var candidate = chars
                        candidate[pos1] = a1
                        candidate[pos2] = a2
                        checkCandidate(String(candidate))
                    }
                }
            }
        }
    }

    // Length-changing collapses (German `ss → ß`).
    // For each rule, find every occurrence of the `from` substring in the
    // input and try substituting that single occurrence with `to`. We try one
    // occurrence at a time rather than all combinations because German words
    // with multiple `ss → ß` collapses in the same word are exceedingly rare.
    for rule in collapseRules {
        let from = rule.from
        let to = rule.to
        guard !from.isEmpty, lowered.count >= from.count else { continue }
        var searchStart = lowered.startIndex
        while let range = lowered.range(of: from, range: searchStart..<lowered.endIndex) {
            let candidate = lowered.replacingCharacters(in: range, with: to)
            checkCandidate(candidate)
            searchStart = lowered.index(after: range.lowerBound)
        }
    }

    let typed = provider.frequency(of: lowered) > 0
        ? AccentRestoration.Spelling(word: lowered, count: provider.corpusCount(of: lowered))
        : nil
    let participles = profile.participleContext.flatMap {
        $0.expectsParticiple(after: previousWord) ? $0 : nil
    }
    return AccentRestoration.decide(typed: typed, accented: spellings) { spelling in
        participles?.isParticiple(spelling.word, of: lowered) ?? false
    }
}
