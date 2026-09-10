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
    ///   - mirrorArmed: `MirrorSyncState.isArmed`. While the mirror has been caught
    ///     holding characters the keyboard's own edits do not account for, this is
    ///     always false: the substitution deletes a character it counted off that
    ///     mirror, so it cannot be allowed to count.
    public static func shouldSubstitute(context: String?, mirrorArmed: Bool) -> Bool {
        guard !mirrorArmed else { return false }
        guard let text = context, text.count >= 2 else { return false }
        // Last char is a space, and the one before it is neither a space nor a
        // period — otherwise ". " would double a period or fire on triple spaces.
        guard text.hasSuffix(" ") else { return false }
        let beforeSpace = text[text.index(text.endIndex, offsetBy: -2)]
        return beforeSpace != " " && beforeSpace != "."
    }
}
