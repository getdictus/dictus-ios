// DictusCore/Sources/DictusCore/Vocabulary/VocabularyPairGenerator+Suggestions.swift
// The few pairs the app offers as new variants of a vocabulary term (#512, step 2 UI).
import Foundation

extension VocabularyPairGenerator {

    /// The closest a pair may be scored and still be offered: equal letters (0), equal
    /// sounds (1), or one or two edits (2, 3). `cloud code` for `Claude Code` is 3.
    /// Three edits, which `spanScore` allows from twelve letters up, is too loose to
    /// put in front of the user without a judge.
    public static let suggestionMaxScore = 3

    /// A span seen in one dictation only is not offered: one mishearing is a
    /// coincidence, the same one twice is the engine's habit.
    public static let suggestionMinDictations = 2

    /// The sheet shows few rows, so each one is worth reading.
    public static let suggestionLimit = 5

    /// What **Analyze my transcriptions** offers: new variants for the user's own
    /// vocabulary terms, closest first.
    ///
    /// ### Why vocabulary terms only
    ///
    /// A term is a spelling the user wrote down, so the canonical is certain and the
    /// only open question is the span. Learned words are left to step 1's paired
    /// section, which matches them more strictly; offering them here too would show the
    /// same word twice under two rules.
    ///
    /// No model judges the pairs: the cautious thresholds above do, and the user
    /// confirms each one before anything is stored.
    public func suggestions(from records: [TranscriptionRecord],
                            vocabulary: [VocabularyEntry],
                            ignored: Set<String>) -> [VocabularyPair] {
        Array(
            pairs(from: records, vocabulary: vocabulary, ignored: ignored, limit: .max)
                .filter {
                    $0.score <= Self.suggestionMaxScore
                        && $0.dictationCount >= Self.suggestionMinDictations
                }
                .prefix(Self.suggestionLimit)
        )
    }
}
