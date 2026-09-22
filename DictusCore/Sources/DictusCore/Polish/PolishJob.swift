// DictusCore/Sources/DictusCore/Polish/PolishJob.swift
// One engine-facing transform, with the languages the passes around it need (#79).
import Foundation

/// Everything `PolishPipeline.transform` needs to run one dictation through the
/// engine and judge what comes back.
///
/// ### Why the two languages are separate fields
///
/// Until #79 they were the same value, called `target`, and the pipeline branched on
/// `mode == .auto` to decide whether to apply typography with it. Translation breaks
/// that: the deterministic typography post-pass keys on the **output** language,
/// which for a translation is the target rather than the input, while the prompt is
/// resolved for a language that may be neither. Making the caller state both removes
/// a branch that would otherwise have to grow a third case, and makes the rule
/// testable on its own.
public struct PolishJob: Equatable, Sendable {

    /// What the model is being asked to do.
    public let task: PolishTask

    /// The language the engine resolves its instructions for. On the per-language
    /// polish path this is the resolved polish target; on the auto path it is the
    /// placeholder the engine API requires and the prompt ignores; for a Smart Mode
    /// it is whichever of those the dictation was going to use, since a Smart Mode's
    /// prompt is language-agnostic.
    public let promptLanguage: SupportedLanguage

    /// The language whose typography the post-pass applies, or nil for none — in
    /// which case the decode restores newline markers and nothing else.
    ///
    /// Nil is not an omission. Per-language typography is tuned for the four tested
    /// languages and would mangle e.g. CJK full-width punctuation, so it stays off
    /// wherever the output language is genuinely unknown.
    public let typographyLanguage: SupportedLanguage?

    /// What the transcript was measured to be made of, as `NLLanguage` raw codes
    /// (`PolishLanguageMix.countedCodes`), or empty when nothing was readable.
    ///
    /// Not a language the pipeline writes in — the two above are. This is the one
    /// the user *spoke*, and the pipeline needs it for a single question it asks
    /// before the engine call: can this backend read that at all (#490). Empty is a
    /// valid, frequent value and always lets the call through.
    public let inputLanguageCodes: Set<String>

    /// The language the transcript is in, as an `NLLanguage` code, or nil when
    /// nothing is known (#587, decision 5): the transcription language the user
    /// forced, if they forced one, else the language detected in the transcript.
    ///
    /// A fourth language field, and not one of the three above, because none of them
    /// can say it. `promptLanguage` is one of the four tested languages, so it cannot
    /// name Danish; `typographyLanguage` is nil on the auto path by design; and
    /// `inputLanguageCodes` is a set, where a Smart Mode needs the one language whose
    /// worked examples it should show. See `transcriptLanguageCode(mode:detectedCode:)`.
    public let transcriptLanguageCode: String?

    public init(task: PolishTask,
                promptLanguage: SupportedLanguage,
                typographyLanguage: SupportedLanguage?,
                inputLanguageCodes: Set<String> = [],
                transcriptLanguageCode: String? = nil) {
        self.task = task
        self.promptLanguage = promptLanguage
        self.typographyLanguage = typographyLanguage
        self.inputLanguageCodes = inputLanguageCodes
        self.transcriptLanguageCode = transcriptLanguageCode
    }

    /// Build the job for one dictation, deriving the typography language from the
    /// task's contract.
    ///
    /// - Parameter languageAgnosticPath: true on the auto-detect path (#239), where
    ///   the output language is unknown, so per-language typography must stay off
    ///   unless the task itself names an output language.
    ///
    /// The rule, stated once: **a task that names a fixed output language gets that
    /// language's typography; every other task follows the path it is running on.**
    public init(task: PolishTask,
                promptLanguage: SupportedLanguage,
                languageAgnosticPath: Bool,
                inputLanguageCodes: Set<String> = [],
                transcriptLanguageCode: String? = nil) {
        let typography: SupportedLanguage?
        switch task.contract.outputLanguage {
        case .fixed(let language):
            typography = language
        case .polishTarget, .sameAsInput:
            typography = languageAgnosticPath ? nil : promptLanguage
        }
        self.init(
            task: task, promptLanguage: promptLanguage, typographyLanguage: typography,
            inputLanguageCodes: inputLanguageCodes, transcriptLanguageCode: transcriptLanguageCode
        )
    }

    /// The transcript's language as #587 decision 5 defines it: the language the user
    /// forced, if they forced one, else the detected one.
    ///
    /// Only `.explicit` counts as forced. `.followKeyboard` is the keyboard's language,
    /// which says what the user types in, not what they said; the transcript can be
    /// in another, and detection is the better witness of which.
    public static func transcriptLanguageCode(mode: TranscriptionLanguageMode,
                                              detectedCode: String?) -> String? {
        if case .explicit(let language) = mode { return language.rawValue }
        return detectedCode
    }

    /// This job with its task's worked examples resolved for its transcript language.
    /// What `PolishPipeline.transform` runs, so every later step sees one prompt.
    public func resolvingExamples() -> PolishJob {
        PolishJob(
            task: task.resolvingExamples(forTranscriptLanguage: transcriptLanguageCode),
            promptLanguage: promptLanguage, typographyLanguage: typographyLanguage,
            inputLanguageCodes: inputLanguageCodes, transcriptLanguageCode: transcriptLanguageCode
        )
    }
}
