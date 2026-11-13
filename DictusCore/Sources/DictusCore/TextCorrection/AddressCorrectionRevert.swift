// DictusCore/Sources/DictusCore/TextCorrection/AddressCorrectionRevert.swift
// Undoes a punctuation-mark correction that turned out to sit inside an address (#919).
import Foundation

/// Puts back the word a punctuation mark corrected, once the key typed right after
/// the mark shows the mark sat inside an address (#919).
///
/// At the full stop of `helene.` nothing yet says an address follows, so the word is
/// corrected like `bonjoru.` is. The `b` glued after it does: the correction is
/// undone before the `b` is written, giving `helene.b`. Nothing is learned and no
/// refusal is remembered, since the user refused nothing.
public enum AddressCorrectionRevert {

    /// Restores `original` in place of `corrected` when the context ends with the
    /// correction and an address separator, and `next` glued after them makes the
    /// typed text an address. Returns true when the text was put back.
    @discardableResult
    public static func apply(
        editor: TextDocumentEditing,
        original: String,
        corrected: String,
        next: String,
        mirror: MirrorSyncState
    ) -> Bool {
        guard next.count == 1, let key = next.first, AddressLikeToken.continuesAddress(key),
              let context = editor.contextBeforeInput, let mark = context.last,
              AddressLikeToken.separators.contains(mark), AutocorrectTrigger.commitsWord(String(mark))
        else { return false }

        let written = corrected + String(mark)
        let typed = original + String(mark)
        guard context.hasSuffix(written),
              AddressLikeToken.atCursor(String(context.dropLast(written.count)) + typed, followedBy: next),
              case .ok(let deleteCount) = MirrorGatedReplacement.check(
                  mirrorSuspect: mirror.isSuspect, context: context, word: written
              )
        else { return false }

        let before = editor.contextLength
        for _ in 0..<deleteCount {
            editor.deleteBackward()
        }
        editor.insertText(typed)
        mirror.observe(before: before, after: editor.contextLength, deleted: deleteCount, inserted: typed.count)

        #if DEBUG
        MirrorProbe.shared.record(.replace(deleted: deleteCount, inserted: typed))
        MirrorProbe.shared.probe(event: "address-revert", mirror: editor.contextBeforeInput)
        AutocorrectDebugLog.autocorrectRevertedInAddress(original: original, corrected: corrected)
        #endif
        return true
    }
}
