// DictusCore/Sources/DictusCore/AutoFullStop.swift
// Whether a second spacebar press becomes ". " (issue #530 extracted this decision).
//
// The rule itself is unchanged and is standard iOS behaviour: two spaces after a
// word character end the sentence. What #530 added is the mirror gate.
//
// WHY THE GATE IS HERE AND NOT ONLY AT THE CALL SITE:
// This is the second site the 2026-09-10 capture caught destroying text. It counts
// characters off `documentContextBeforeInput` exactly as autocorrect does, and on a
// desynced mirror it found a trailing space the document did not have: one spacebar
// press turned "Ok je vais" into "Ok je vai." — it deleted a real character and wrote
// a period over it. The gate belongs in the decision so it can be tested, rather than
// in the caller where only a device run could show it.

import Foundation

public enum AutoFullStop {

    /// Whether the caller must replace the trailing space with ". ".
    ///
    /// - Parameters:
    ///   - context: the live `documentContextBeforeInput`, read BEFORE the second
    ///     space is inserted — the buffer still ends `[char][space]`.
    ///   - mirrorSuspect: `MirrorSyncState.isSuspect`. While the mirror holds
    ///     characters the keyboard's own edits do not account for, this is always
    ///     false.
    ///
    /// WHY THIS ONE STILL REFUSES WHEN THE REPLACEMENT PATH NO LONGER DOES:
    /// #530's revised reaction corrects a delete COUNT by the known surplus, because
    /// a count only needs a length. This decision does not ask a length — it asks
    /// what the last two characters ARE. The surplus cannot answer that: the phantom
    /// is not necessarily at the tail, so the mirror's final space may be real or
    /// invented and nothing in the accounting distinguishes them. A wrong answer here
    /// deletes a real character and writes a period over it, which is how one
    /// spacebar press turned "Ok je vais" into "Ok je vai.". Refusal is the only
    /// correct reaction, and it costs a double space staying two spaces.
    public static func shouldSubstitute(context: String?, mirrorSuspect: Bool) -> Bool {
        guard !mirrorSuspect else { return false }
        guard let text = context, text.count >= 2 else { return false }
        // Last char is a space, and the one before it is neither a space nor a
        // period — otherwise ". " would double a period or fire on triple spaces.
        guard text.hasSuffix(" ") else { return false }
        let beforeSpace = text[text.index(text.endIndex, offsetBy: -2)]
        return beforeSpace != " " && beforeSpace != "."
    }
}
