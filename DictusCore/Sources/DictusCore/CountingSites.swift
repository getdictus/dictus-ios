// DictusCore/Sources/DictusCore/CountingSites.swift
// The two automatic sites that count characters off the proxy's mirror and then
// delete that many (#530).
//
// They live here rather than in DictusKeyboard for one reason: so they can be run
// against a fake document on a Mac, in milliseconds, without a phone. The decision
// AND the execution are both here — testing the decision alone is what let four
// rounds of this issue reach a device with green tests and destroy text anyway.
//
// What stays in the keyboard is everything these sites do not need: choosing the
// correction, host policy, the suggestion bar, undo state, capitalisation and the
// user dictionary.

import Foundation

/// Autocorrect-on-space: replace the typed word with its correction.
public enum AutocorrectCountingSite {

    /// What one attempt did.
    public enum Outcome: Equatable {
        /// The replacement ran, issuing `deleted` deleteBackward() calls.
        case applied(deleted: Int)
        /// Nothing was touched. `reason` is the slug the caller turns into its
        /// existing no-correction fall-through.
        case refused(reason: String)
    }

    /// Decides and performs the replacement.
    ///
    /// The order of operations is load-bearing and matches what shipped before this
    /// was extracted: read the mirror's length, delete, insert the correction, insert
    /// a space, then report the movement to the accounting. The two length reads
    /// bracket the whole edit inside one synchronous turn, which is what makes any
    /// discrepancy attributable to the mirror rather than to a host callback.
    ///
    /// - Parameters:
    ///   - editor: the live document. Its `contextBeforeInput` is the mirror.
    ///   - word: the word the pipeline intends to replace.
    ///   - correction: what to put in its place.
    ///   - previousWord: only for the DEBUG log.
    ///   - mirror: the surplus accounting, read for the decision and updated after.
    @discardableResult
    public static func apply(
        editor: TextDocumentEditing,
        word: String,
        correction: String,
        previousWord: String? = nil,
        mirror: MirrorSyncState
    ) -> Outcome {
        let suspect = mirror.isSuspect
        let liveContext = editor.contextBeforeInput

        switch MirrorGatedReplacement.check(
            mirrorSuspect: suspect, context: liveContext, word: word
        ) {
        case .failed(let reason):
            if suspect {
                mirror.noteSuppressedCorrection()
                #if DEBUG
                AutocorrectDebugLog.mirrorSuppressed(site: "autocorrect", word: word, reason: reason)
                #endif
            }
            return .refused(reason: reason)

        case .ok(let deleteCount):
            #if DEBUG
            AutocorrectDebugLog.applyBefore(
                word: word,
                correction: correction,
                prevWord: previousWord,
                contextTail: contextTail(liveContext)
            )
            #endif

            let mirrorBefore = editor.contextLength
            for _ in 0..<deleteCount {
                editor.deleteBackward()
            }
            #if DEBUG
            MirrorProbe.shared.record(.replace(deleted: deleteCount, inserted: ""))
            MirrorProbe.shared.probe(event: "autocorrect-deleted", mirror: editor.contextBeforeInput)
            AutocorrectDebugLog.applyAfterDelete(contextTail: contextTail(editor.contextBeforeInput))
            #endif

            editor.insertText(correction)
            editor.insertText(" ")
            mirror.observe(
                before: mirrorBefore,
                after: editor.contextLength,
                deleted: deleteCount,
                inserted: correction.count + 1
            )
            // The trailing space is a boundary this keyboard wrote, so anything the
            // mirror is still over-reporting now lies behind it (#530).
            mirror.noteBoundaryInserted(reason: "autocorrect-space", atLength: editor.contextLength)

            #if DEBUG
            MirrorProbe.shared.record(.insert(correction + " "))
            MirrorProbe.shared.probe(event: "autocorrect-applied", mirror: editor.contextBeforeInput)
            AutocorrectDebugLog.applyAfterInsert(contextTail: contextTail(editor.contextBeforeInput))
            AutocorrectDebugLog.autocorrectApplied(
                original: word, corrected: correction, prevWord: previousWord
            )
            #endif

            return .applied(deleted: deleteCount)
        }
    }

    /// Last ~30 characters of a context, for the DEBUG replacement logs.
    static func contextTail(_ context: String?) -> String {
        guard let context = context else { return "<nil>" }
        return String(context.suffix(30))
    }
}

/// Double space becomes ". ".
public enum AutoFullStopCountingSite {

    /// Performs the substitution if the rule and the mirror both allow it.
    /// Returns true when `". "` was written, so the caller knows not to insert a
    /// plain space itself.
    @discardableResult
    public static func apply(editor: TextDocumentEditing, mirror: MirrorSyncState) -> Bool {
        let context = editor.contextBeforeInput

        guard AutoFullStop.shouldSubstitute(context: context, mirrorSuspect: mirror.isSuspect) else {
            // Count only a real suppression: a press that WOULD have substituted had
            // the mirror been trustworthy. Asking the same question with the gate
            // open is what tells those apart from the ordinary "not a double space".
            if mirror.isSuspect,
               AutoFullStop.shouldSubstitute(context: context, mirrorSuspect: false) {
                mirror.noteSuppressedFullStop()
                #if DEBUG
                AutocorrectDebugLog.mirrorSuppressed(
                    site: "full-stop", word: "", reason: "surplus-is-a-length-not-a-position"
                )
                #endif
            }
            return false
        }

        let mirrorBefore = editor.contextLength
        editor.deleteBackward()
        editor.insertText(". ")
        mirror.observe(before: mirrorBefore, after: editor.contextLength, deleted: 1, inserted: 2)
        mirror.noteBoundaryInserted(reason: "full-stop-space", atLength: editor.contextLength)
        #if DEBUG
        MirrorProbe.shared.record(.replace(deleted: 1, inserted: ". "))
        #endif
        return true
    }
}
