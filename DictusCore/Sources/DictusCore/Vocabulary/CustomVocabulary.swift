// DictusCore/Sources/DictusCore/Vocabulary/CustomVocabulary.swift
// Who may use the vocabulary, and the one thing it does with it (#80).
import Foundation

/// The entitlement policy for custom vocabulary (#80).
///
/// A type rather than an `if` at the call site, for the reason
/// `HistoryAvailability` gives: an entitlement answered inline, in whichever
/// consumer happens to need it, is an entitlement the next consumer will answer
/// differently.
public enum VocabularyAvailability {

    /// Whether the user is paying for the vocabulary **and** has it switched on.
    ///
    /// `FeatureGate.isAvailable` and not `isProActive`, matching
    /// `HistoryAvailability.isEntitled`: `SharedKeys.vocabularyEnabled` is seeded to
    /// `true` by `ProStatusManager.seedFeatureTogglesIfNeeded`, and a subscriber who
    /// switched it off in Settings has said what they want.
    ///
    /// Turning it off stops the replacements. It does not delete anything — see
    /// `VocabularyStore`, where removal is ungated.
    public static var isEntitled: Bool {
        FeatureGate.isAvailable(.vocabulary)
    }
}

/// What the vocabulary does, behind one gate.
///
/// The consumer goes through here rather than reading the store directly, so the
/// entitlement is checked in one place and the "nothing stored" path is one
/// expression.
///
/// **It used to do two things.** The canonical term also joined the polish prompt
/// (#80 decision 7), which is what let an entry with no variants claim to protect a
/// spelling. #536 measured that on device — the correct spelling sat in the prompt
/// and Apple FM wrote `dictés` for `dictus` and left `Parakit V3` alone, while
/// `whisperflow`, in nobody's list, was corrected by the model's own priors — and a
/// competitor asking for phonetic repair in a tagged block scored 0/5 on the same
/// device. The term list is gone; a replacement is what an entry does.
public enum CustomVocabulary {

    /// Rewrite the engine's variants into the user's spellings.
    ///
    /// **Called at the consumer of `TranscriptionService.transcribe()`**, which is
    /// `DictationCoordinator` — upstream of both the in-app tail and the keyboard
    /// hand-off, and upstream of `VerbalPunctuationPrepass` and the polish. See
    /// `VocabularyReplacer` for why that position is the only correct one.
    ///
    /// Returns its input, unchanged and un-copied, for every user who is not
    /// entitled or has stored nothing. That identity is the issue's pre-registered
    /// bar.
    ///
    /// **This overload writes one line to the persistent log, always** — including
    /// when the feature is off, and including when nothing matched. The line carries
    /// counters and no text; see `LogEvent.vocabularyApplied` for why it is
    /// unconditional and why it can never carry a term.
    public static func corrected(_ text: String) -> String {
        let isEntitled = VocabularyAvailability.isEntitled
        let entries = isEntitled ? VocabularyStore.loadEntries().filter(\.isEnabled) : []
        let outcome = VocabularyReplacer.outcome(text, entries: entries)
        PersistentLog.log(.vocabularyApplied(
            enabled: isEntitled,
            entries: entries.count,
            replacements: outcome.replacements,
            chars: text.count
        ))
        return outcome.text
    }

    /// The same pass with the vocabulary supplied, and **no logging**.
    ///
    /// What the tests and the replay harness call: a suite that wrote to the App
    /// Group's debug log on every assertion would put noise into the artefact the
    /// log exists to keep readable.
    public static func corrected(_ text: String, entries: [VocabularyEntry]) -> String {
        VocabularyReplacer.apply(text, entries: entries)
    }
}
