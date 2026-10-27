// DictusCore/Sources/DictusCore/VocabularySceneScript.swift
// What the onboarding's vocabulary scene shows at each moment of its loop (#680, #829).
import Foundation

/// The script of the vocabulary scene (#680, #649 decision 9.3): the two ways a term
/// reaches the real Vocabulary list, one after the other in one loop (#829).
///
/// THE STORY, PART 1, BY HAND: the list holds two terms, each with *Replaces: …* and its
/// switch. The finger taps *Add a term*; the real editor sheet comes up
/// (`VocabularyEditorView`); the finger types the correct spelling only and leaves *What
/// Dictus writes instead* empty, then taps *Save*. The term is listed with *Waiting for
/// misspellings* (#819): nobody has to guess how Dictus gets a word wrong.
///
/// PART 2, FROM A SUGGESTION (#512): the finger taps *Analyze my transcriptions*; the
/// suggestions sheet (`VocabularySuggestionsView`) shows a word typed on the keyboard that
/// Dictus writes differently. The finger taps *Accept*; the review sheet
/// (`VocabularyPairReviewView`, *Check the change*) shows the term and its variant, and the
/// finger taps *Add*. The suggestion leaves the sheet, the finger taps *Done*, and the
/// second term is in the list.
///
/// Both terms stay a while, then leave together, so the loop starts again on the two
/// terms it opened on.
///
/// WHY *SAVE* IS DECIDED BY `VocabularyEntry`: the real sheet saves any term the model
/// accepts, with or without a variant (#819), so its *Save* lights up with the first
/// field. The scene asks the model the same question rather than restating the rule, so
/// the drawing cannot light the button where the app would not.
public enum VocabularySceneScript {

    /// What the drawn finger taps.
    public enum Target: Hashable, Sendable {
        /// *Add a term*, under the list.
        case addTerm
        /// The editor's first field, the correct spelling.
        case termField
        /// The editor's *Save*.
        case save
        /// *Analyze my transcriptions*, under *Add a term*.
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
        /// Whether the editor sheet is up (part 1).
        public let editorIsOpen: Bool
        /// Whether the editor's first field has the cursor.
        public let termFieldIsFocused: Bool
        /// What the first field holds so far.
        public let term: String
        /// What the second field holds: always empty, the point of part 1.
        public let variants: String
        /// Whether the editor's *Save* is enabled.
        public let canSave: Bool
        /// Whether the term typed by hand is in the list, waiting for misspellings.
        public let manualTermIsListed: Bool
        /// Whether the suggestions sheet is up (part 2).
        public let suggestionsAreOpen: Bool
        /// Whether the suggestion is still in that sheet: it leaves once accepted.
        public let suggestionIsListed: Bool
        /// Whether the review sheet is up, over the suggestions.
        public let reviewIsOpen: Bool
        /// Whether the accepted term is in the list.
        public let suggestedTermIsListed: Bool
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    enum Beat {
        // Part 1, by hand.
        static let tapAddTerm = SceneTap(Target.addTerm, press: 0.9, release: 1.1)
        static let tapTerm = SceneTap(Target.termField, press: 1.9, release: 2.1)
        static let termTyping: ClosedRange<Double> = 2.2...3.1
        /// The empty variant field and its *Optional* footer are read before *Save*.
        static let tapSave = SceneTap(Target.save, press: 4.6, release: 4.8)
        // Part 2, from a suggestion.
        static let tapAnalyze = SceneTap(Target.analyze, press: 7.3, release: 7.5)
        static let tapAccept = SceneTap(Target.accept, press: 9.4, release: 9.6)
        static let tapAdd = SceneTap(Target.add, press: 12.0, release: 12.2)
        static let tapDone = SceneTap(Target.done, press: 13.6, release: 13.8)
        /// Both new terms leave the list here, so the loop starts on two terms again.
        static let termsRemoved: Double = 20.4
    }

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [
        Beat.tapAddTerm, Beat.tapTerm, Beat.tapSave,
        Beat.tapAnalyze, Beat.tapAccept, Beat.tapAdd, Beat.tapDone
    ]

    /// One pass: 21 s, both ways of adding a term.
    public static let loopSeconds: Double = 21.0

    /// The moment shown with Reduce Motion on: the list with both new terms, the one
    /// typed by hand waiting for misspellings and the accepted suggestion.
    public static let stillSeconds: Double = 17.0

    /// The scene at `time` seconds into the loop.
    ///
    /// - Parameter term: the spelling the finger types in part 1, one word.
    public static func frame(at time: Double, term: String) -> Frame {
        let typedTerm = SceneTyping.typed(
            term, from: Beat.termTyping.lowerBound, to: Beat.termTyping.upperBound, at: time
        )
        return Frame(
            editorIsOpen: time >= Beat.tapAddTerm.release && time < Beat.tapSave.release,
            termFieldIsFocused: time >= Beat.tapTerm.release && time < Beat.tapSave.release,
            term: typedTerm,
            variants: "",
            canSave: canSave(term: typedTerm, variants: ""),
            manualTermIsListed: time >= Beat.tapSave.release && time < Beat.termsRemoved,
            suggestionsAreOpen: time >= Beat.tapAnalyze.release && time < Beat.tapDone.release,
            suggestionIsListed: time < Beat.tapAdd.release,
            reviewIsOpen: time >= Beat.tapAccept.release && time < Beat.tapAdd.release,
            // The real store writes on *Add*, so the list behind the sheets already has it.
            suggestedTermIsListed: time >= Beat.tapAdd.release && time < Beat.termsRemoved,
            finger: taps.finger(at: time)
        )
    }

    /// Whether the real editor would enable *Save* for these two fields: an entry
    /// `VocabularyEntry` accepts, variants optional (#819). The scene's term is never
    /// already in the list, so the duplicate check is moot.
    public static func canSave(term: String, variants: String) -> Bool {
        VocabularyEntry(term: term, variants: VocabularyEntry.variants(fromLine: variants)) != nil
    }
}
