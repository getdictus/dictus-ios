// DictusCore/Sources/DictusCore/VocabularySceneScript.swift
// What the onboarding's vocabulary scene shows at each moment of its loop (#680).
import Foundation

/// The script of the vocabulary scene (#680, #649 decision 9.3, mock-up
/// `07b-scene-vocabulaire`): a term added to the real Vocabulary list.
///
/// THE STORY: the list holds two terms, each with *Replaces: …* and its switch. The
/// finger taps *Add a term*; the real editor sheet comes up (`VocabularyEditorView`); the
/// finger types the correct spelling, then what Dictus writes instead; *Save* lights up
/// once the term is typed, and the finger taps it. The sheet goes down
/// and the new term is in the list, switched on. It stays a while, then leaves, so the
/// loop starts again on the two terms it opened on.
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
        /// The editor's second field, what Dictus writes instead.
        case variantsField
        /// The editor's *Save*.
        case save
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// Whether the editor sheet is up.
        public let editorIsOpen: Bool
        /// The field with the cursor, nil for none.
        public let focusedField: Target?
        /// What the first field holds so far.
        public let term: String
        /// What the second field holds so far.
        public let variants: String
        /// Whether the editor's *Save* is enabled.
        public let canSave: Bool
        /// Whether the new term is in the list.
        public let newTermIsListed: Bool
        /// The finger, nil while it is off screen.
        public let finger: SceneTapFinger<Target>?
    }

    /// The beats, in seconds from the start of the loop.
    enum Beat {
        static let tapAdd = SceneTap(Target.addTerm, press: 0.9, release: 1.1)
        static let tapTerm = SceneTap(Target.termField, press: 1.9, release: 2.1)
        static let termTyping: ClosedRange<Double> = 2.2...3.3
        static let tapVariants = SceneTap(Target.variantsField, press: 3.9, release: 4.1)
        static let variantsTyping: ClosedRange<Double> = 4.2...5.6
        static let tapSave = SceneTap(Target.save, press: 6.3, release: 6.5)
        /// The new term leaves the list here, so the loop starts on two terms again.
        static let termRemoved: Double = 11.0
    }

    /// Every tap, in order. They never overlap (tested).
    static let taps: [SceneTap<Target>] = [Beat.tapAdd, Beat.tapTerm, Beat.tapVariants, Beat.tapSave]

    /// One pass: 11.6 s, inside decision 14's 10 to 20.
    public static let loopSeconds: Double = 11.6

    /// The moment shown with Reduce Motion on: the list with the new term in it, the
    /// frame mock-up 07b draws.
    public static let stillSeconds: Double = 8.5

    /// The scene at `time` seconds into the loop.
    ///
    /// - Parameters:
    ///   - term: the spelling the finger types, localized by the caller.
    ///   - variants: what it types in the second field.
    public static func frame(at time: Double, term: String, variants: String) -> Frame {
        let typedTerm = SceneTyping.typed(
            term, from: Beat.termTyping.lowerBound, to: Beat.termTyping.upperBound, at: time
        )
        let typedVariants = SceneTyping.typed(
            variants, from: Beat.variantsTyping.lowerBound, to: Beat.variantsTyping.upperBound, at: time
        )
        let editorIsOpen = time >= Beat.tapAdd.release && time < Beat.tapSave.release
        return Frame(
            editorIsOpen: editorIsOpen,
            focusedField: focusedField(at: time),
            term: typedTerm,
            variants: typedVariants,
            canSave: canSave(term: typedTerm, variants: typedVariants),
            newTermIsListed: time >= Beat.tapSave.release && time < Beat.termRemoved,
            finger: taps.finger(at: time)
        )
    }

    /// Whether the real editor would enable *Save* for these two fields: an entry
    /// `VocabularyEntry` accepts, variants optional (#819). The scene's term is never
    /// already in the list, so the duplicate check is moot.
    public static func canSave(term: String, variants: String) -> Bool {
        VocabularyEntry(term: term, variants: VocabularyEntry.variants(fromLine: variants)) != nil
    }

    private static func focusedField(at time: Double) -> Target? {
        switch time {
        case Beat.tapTerm.release..<Beat.tapVariants.release: return .termField
        case Beat.tapVariants.release..<Beat.tapSave.release: return .variantsField
        default: return nil
        }
    }
}
