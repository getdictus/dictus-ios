// DictusCore/Sources/DictusCore/Vocabulary/VocabularySuggestionAnalysis.swift
// One run of "Analyze my transcriptions": step 1's rows, then step 2's pairs (#512).
import Foundation

/// What the suggestions sheet shows, computed in one call that needs no main thread.
///
/// ### Why it is its own type
///
/// The sheet ran both miners on the main actor and froze for 0.5 to 2 s on a phone
/// with 50 to 80 dictations, on every vocabulary change. The work is pure except for
/// the dictionary predicate, so it moves here, the app calls it from a background
/// task, and only the predicate decides where it runs (`isKnownWord` may hop to the
/// main thread for `UITextChecker`).
public struct VocabularySuggestionAnalysis: Equatable, Sendable {

    /// Step 1's rows, minus any spelling already offered as a pair.
    public let stepOne: [VocabularySuggestion]

    /// Step 2's pairs (`VocabularyPairGenerator.suggestions`).
    public let pairs: [VocabularyPair]

    /// Run both miners. Returns nil when the task it runs in was cancelled between
    /// the two, so a superseded analysis never reaches the screen.
    public static func run(records: [TranscriptionRecord],
                           vocabulary: [VocabularyEntry],
                           learnedWords: [String],
                           ignored: Set<String>,
                           isKnownWord: @escaping (String) -> Bool) -> VocabularySuggestionAnalysis? {
        let stepOne = VocabularySuggestionMiner(isKnownWord: isKnownWord).suggestions(
            from: records,
            learnedWords: learnedWords,
            vocabulary: vocabulary,
            ignored: ignored
        )
        guard !Task.isCancelled else { return nil }
        // Step 1 first: a learned word it suggests is not a pair source (one word,
        // one rule; see `VocabularyPairGenerator.suggestions`).
        let pairs = VocabularyPairGenerator(isKnownWord: isKnownWord).suggestions(
            from: records,
            vocabulary: vocabulary,
            learnedWords: learnedWords,
            stepOne: stepOne,
            ignored: ignored
        )
        guard !Task.isCancelled else { return nil }
        // A spelling already offered as a pair is not offered again below as an
        // unknown word on its own.
        let offered = Set(pairs.map { VocabularySuggestionMiner.fold($0.observed) })
        return VocabularySuggestionAnalysis(
            stepOne: stepOne.filter { !$0.forms.contains { offered.contains(VocabularySuggestionMiner.fold($0)) } },
            pairs: pairs
        )
    }
}
