// DictusCore/Sources/DictusCore/Vocabulary/VocabularyPairGenerator+Suggestions.swift
// The few pairs the app offers from the user's own spellings (#512, step 2 UI).
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
    public static let suggestionLimit = 10

    /// What **Analyze my transcriptions** offers, best first.
    ///
    /// ### Where the correct spelling comes from
    ///
    /// Only from what the user wrote themselves, never from History: first the
    /// Personal Vocabulary terms, then the words the keyboard learned from their
    /// typing (`UserDictionary`, stored lowercase). Every vocabulary pair ranks before
    /// every learned-word pair, since a term is a spelling the user wrote down on
    /// purpose; within a source, the generator's order (closest, more dictations,
    /// more occurrences, most recent).
    ///
    /// ### One word, one rule
    ///
    /// A learned word step 1 already suggests (`stepOne`, its paired rows) is not a
    /// canonical here at all. Step 1 is the stricter rule and was validated on device,
    /// so it keeps the word; dropping the word rather than single spans means the
    /// same word never shows in two sections, whatever its spellings.
    ///
    /// ### One row per word
    ///
    /// Only the best pair of each canonical is offered.
    ///
    /// No model judges the pairs: the thresholds above do, and the user confirms
    /// each one before anything is stored.
    public func suggestions(from records: [TranscriptionRecord],
                            vocabulary: [VocabularyEntry],
                            learnedWords: [String] = [],
                            stepOne: [VocabularySuggestion] = [],
                            ignored: Set<String>) -> [VocabularyPair] {
        let coveredByStepOne = stepOne.filter(\.isPaired).map(\.id)
        let found = pairs(
            from: records,
            vocabulary: vocabulary,
            learnedWords: learnedWords,
            ignored: ignored.union(coveredByStepOne),
            limit: .max
        )
        let kept = found.filter {
            $0.score <= Self.suggestionMaxScore && $0.dictationCount >= Self.suggestionMinDictations
        }
        // `pairs` is already in the generator's order: a stable split by source keeps it.
        let ordered = kept.filter { $0.source == .vocabulary } + kept.filter { $0.source == .learned }
        // One row per spelling, its best pair: two spellings of one word are two
        // guesses at the same mistake, and accepting one re-mines the other.
        var seen = Set<String>()
        let best = ordered.filter { seen.insert(VocabularySuggestionMiner.fold($0.canonical)).inserted }
        return Array(best.prefix(Self.suggestionLimit))
    }
}
