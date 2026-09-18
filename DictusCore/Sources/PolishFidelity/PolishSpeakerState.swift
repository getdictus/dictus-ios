// DictusCore/Sources/PolishFidelity/PolishSpeakerState.swift
// Axis 4: the sentence in which the speaker reports their own recall failing (#581).
import Foundation
import DictusCore

/// What axis 4 found about the closing sentence.
public enum PolishSpeakerStateVerdict: String, Equatable, Sendable {

    /// The output ends on a speaker-state sentence and the input has none. #581, and
    /// the bar is zero.
    case fabricated

    /// Both sides carry one. Rule 7 doing its job, which is #523's decision 7.
    case preserved

    /// The input carries one and the output does not, anywhere. Rule 7 violated —
    /// decision 7's bar from the other side, and the loss the reader cannot see.
    case dropped

    /// Neither side carries one. Nothing to say.
    case absent
}

/// Whether a text ends on the speaker saying, out loud, that something is missing.
///
/// ### Why this is one axis and not two checks
///
/// `preserved` and `fabricated` are the **same** match on the output. They are told
/// apart entirely by the input. That is not an implementation convenience, it is the
/// whole difficulty: rule 7 exists to keep such a sentence, so a check that flagged
/// every one of them would refuse the rule doing its job, and a check that flagged
/// none would miss #581. Only the pair is meaningful.
///
/// ### Why the off-domain defence does not cover this (#581)
///
/// `SmartModeStructuredPrompt`'s doc comment argues that its examples are safe because
/// they are deliberately off-domain — a house, a garden — so that on the residual
/// occasion a line is copied the user sees something obviously not theirs. That holds
/// for the *content* lines. It does not hold for the rule 7 clause, and the rule 7
/// clause is the one that leaked: `Il y avait un autre truc, mais ça m'échappe` names
/// no person and no domain, which is exactly what makes it fit onto the end of any
/// dictation there is. Off-domain protects against a **content** leak. It does nothing
/// against a **speaker-state** leak, because a sentence about the speaker's own memory
/// is on-domain for every dictation.
public enum PolishSpeakerState {

    /// The phrasings, as folded word sequences.
    ///
    /// ### What is in, and the line the list is drawn on
    ///
    /// A speaker-state sentence reports the speaker's **recall failing about content
    /// they meant to deliver**. `j'avais oublié de supprimer les logs` is not one: it
    /// reports a past omission, it is the content, and the reader loses nothing by
    /// reading it as written. So the list carries `j ai oublie un truc` and not
    /// `j ai oublie`, and the difference is the object.
    ///
    /// The four phrasings rule 7's instruction text names are all here, and so is the
    /// fifth that only exists in the worked example — which is #581's point: the model
    /// is shown five times over that an output of this mode may end on "there was
    /// something else", and the fifth showing is inside the one exemplar whose whole
    /// job is to be copied for its structure.
    ///
    /// Stored folded and pre-split because that is what `PolishLexicon` produces:
    /// `ça m'échappe` is `ca m echappe`, and an English contraction folds to two words,
    /// so `i can t remember` is the real shape of `I can't remember`.
    static let phrasings: [[String]] = [
        // French — recall failing
        "je ne me souviens", "je me souviens plus", "je ne me rappelle",
        "je me rappelle plus", "je ne sais plus", "ca m echappe", "ca m echappait",
        "ca me reviendra", "ca me revient pas",
        // French — something else was there
        "il y a un autre truc", "il y avait un autre truc",
        "il y a autre chose", "il y avait autre chose",
        "il y a un dernier truc", "il y avait un dernier truc",
        "j ai oublie un truc", "j ai oublie autre chose", "j oublie quelque chose",
        "je reviendrai la dessus", "j y reviendrai",
        // English
        "i don t remember", "i do not remember", "i can t remember",
        "i cannot remember", "it escapes me", "it slips my mind",
        "there was something else", "there s something else",
        "i ll come back to that", "i will come back to that",
        "i forgot something", "i forgot one thing"
    ].map { PolishLexicon.words(in: $0) }

    /// Whether any phrasing occurs in `text`.
    public static func occurs(in text: String) -> Bool {
        PolishStanceLexicon.occurrences(of: phrasings, in: PolishLexicon.words(in: text)) > 0
    }

    /// Whether the text's **last** sentence carries one.
    ///
    /// The brief's wording is *"whether the output **ends** on a sentence in which the
    /// speaker reports their own recall failing"*, and the position is the finding
    /// rather than a convenience: rule 7's leak is a locally plausible **completion**.
    /// A dictation that genuinely trails off ends that way; a fabrication is appended.
    /// A phrasing in the middle of an output is reported separately by
    /// `occurs(in:)` and is not what axis 4 counts.
    public static func closesOn(_ text: String) -> Bool {
        guard let last = PolishSegmentation.sentences(of: text).last else { return false }
        return occurs(in: last)
    }

    /// Axis 4, for one output against its input.
    ///
    /// The verdict reads the whole output and `closesOn(_:)` reads the position, and
    /// they are reported as two fields rather than folded into one. A fabrication in
    /// the body of an output is still a fabrication — calling it `absent` because it
    /// did not land last would be scoring the brief's *wording* instead of its
    /// question — while "ends on" is the shape #581 measured and the shape rule 7's
    /// leak takes, so the report has to be able to say which of the fabrications
    /// closed the text.
    public static func verdict(output: String, input: String) -> PolishSpeakerStateVerdict {
        switch (occurs(in: input), occurs(in: output)) {
        case (true, true): return .preserved
        case (true, false): return .dropped
        case (false, true): return .fabricated
        case (false, false): return .absent
        }
    }
}
