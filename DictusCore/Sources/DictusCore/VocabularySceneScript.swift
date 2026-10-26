// DictusCore/Sources/DictusCore/VocabularySceneScript.swift
// What the onboarding's vocabulary scene shows at each moment of its loop (#680, #829).
import Foundation

/// The script of the vocabulary scene (#680, #649 decision 9.3): a suggested term
/// accepted into the real Vocabulary list, the #512 flow (#829).
///
/// THE STORY: the list holds two terms, each with *Replaces: …* and its switch. The
/// finger taps *Analyze my transcriptions*; the suggestions sheet comes up
/// (`VocabularySuggestionsView`) with one word typed on the keyboard that Dictus writes
/// differently. The finger taps *Accept*; the review sheet comes up
/// (`VocabularyPairReviewView`, *Check the change*) with the term and its variant filled
/// in, and the finger taps *Add*. The review sheet goes down, the suggestion has left the
/// list, the finger taps *Done*, and the new term is in the Vocabulary list, switched on.
/// It stays a while, then leaves, so the loop starts again on the two terms it opened on.
///
/// WHY NOT THE MANUAL *Add a term* ANY MORE (#829): the line above the scene explains
/// that the keyboard learns words and Dictus suggests them. The scene shows that
/// suggestion being accepted, which nothing else in the onboarding shows.
public enum VocabularySceneScript {

    /// What the drawn finger taps.
    public enum Target: Hashable, Sendable {
        /// *Analyze my transcriptions*, under the list.
        case analyze
        /// The suggestion's *Accept*.
        case accept
        /// The review sheet's *Add*.
        case add
        /// The suggestions sheet's *Done*.
        case done
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// Whether the suggestions sheet is up.
        public let suggestionsAreOpen: Bool
        /// Whether the suggestion is still in that sheet: it leaves once accepted.
        public let suggestionIsListed: Bool
        /// Whether the review sheet is up, over the suggestions.
        public let reviewIsOpen: Bool
        /// Whether the new term is in the Vocabulary list.
        public let newTermIsListed: Bool
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    enum Beat {
        static let tapAnalyze = SceneTap(Target.analyze, press: 0.9, release: 1.1)
        static let tapAccept = SceneTap(Target.accept, press: 3.0, release: 3.2)
        static let tapAdd = SceneTap(Target.add, press: 5.6, release: 5.8)
        static let tapDone = SceneTap(Target.done, press: 7.2, release: 7.4)
        /// The new term leaves the list here, so the loop starts on two terms again.
        static let termRemoved: Double = 12.4
    }

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [Beat.tapAnalyze, Beat.tapAccept, Beat.tapAdd, Beat.tapDone]

    /// One pass: 13 s, inside decision 14's 10 to 20.
    public static let loopSeconds: Double = 13.0

    /// The moment shown with Reduce Motion on: the list with the accepted term in it.
    public static let stillSeconds: Double = 10.0

    /// The scene at `time` seconds into the loop.
    public static func frame(at time: Double) -> Frame {
        Frame(
            suggestionsAreOpen: time >= Beat.tapAnalyze.release && time < Beat.tapDone.release,
            suggestionIsListed: time < Beat.tapAdd.release,
            reviewIsOpen: time >= Beat.tapAccept.release && time < Beat.tapAdd.release,
            // The real store writes on *Add*, so the list behind the sheets already has it.
            newTermIsListed: time >= Beat.tapAdd.release && time < Beat.termRemoved,
            finger: taps.finger(at: time)
        )
    }
}
