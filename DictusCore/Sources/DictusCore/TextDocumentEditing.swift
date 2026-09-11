// DictusCore/Sources/DictusCore/TextDocumentEditing.swift
// The seam that lets the code which actually deletes text run on a Mac (#530).
//
// WHY THIS EXISTS:
// Four rounds of this issue shipped to a phone to find out whether they worked.
// The reason was structural: there is no test target in the Xcode project, and the
// sites that count characters and delete them live in DictusKeyboard, which imports
// UIKit. Every line that can destroy a user's text was unreachable from the only
// suite the repo has. `MirrorSync` had tests; the thing that deletes did not.
//
// This is the narrowest protocol those sites need. `UITextDocumentProxy` satisfies
// it already — it is adapted rather than extended, because Swift does not allow one
// protocol to be given a retroactive conformance to another.
//
// WHAT A FAKE MUST GET RIGHT, AND IT IS THE WHOLE POINT:
// A fake has to keep TWO strings — the document, and the mirror this protocol reads.
// #530 is the case where they disagree. A fake with one string asserts the mirror
// against itself, which is the exact blindness the bug is made of, so it would pass
// while the user's text was being destroyed. Assertions belong on the document.

import Foundation

/// Reading the tail, deleting one grapheme, inserting text: everything the
/// character-counting sites do to a document.
public protocol TextDocumentEditing: AnyObject {

    /// What the proxy reports lies before the cursor. This is the MIRROR, not the
    /// document — it is allowed to be wrong, and #530 is what happens when it is.
    var contextBeforeInput: String? { get }

    /// Removes one grapheme before the cursor.
    func deleteBackward()

    /// Inserts text at the cursor.
    func insertText(_ text: String)
}

public extension TextDocumentEditing {

    /// The mirror's length in graphemes — the unit a delete count is expressed in,
    /// since one `deleteBackward()` removes one grapheme.
    var contextLength: Int { contextBeforeInput?.count ?? 0 }
}
