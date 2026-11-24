// Ported from Hex (github.com/anomalyco/hex, branch dev @ 35b6f3c,
// ios/HEXShared/FullKeyboard/DeleteWordSwipe.swift), MIT, Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#609): it edits through `TextDocumentEditing` (#530) instead of Hex's
// engine, so `swift test` drives it; every edit is checked against the mirror and a mismatch
// stops the slide; a word the host's truncated context cut short is finished on the next
// move; and the character the touch-down deleted comes back with the first word.

import Foundation

/// Press backspace and slide left: each key width the finger travels left of where it went
/// down deletes one more word, sliding back right types those words back, and lifting the
/// finger keeps what is deleted. A word is a `DeleteWordBoundary` step.
///
/// WHY words are typed back rather than selected (#609): `UITextDocumentProxy` has no
/// equivalent of Android's `setSelection(start, end)`, so a keyboard cannot grow a host
/// selection the way HeliBoard does. Each word deleted is remembered, and sliding back types
/// it again. That is Hex's design, which Pierre tested and chose (2026-11-24). What can go
/// wrong with retyping is bounded here: only text this slide deleted is typed back, only
/// while the finger is down, and only while the mirror moves by exactly what each edit
/// implies. On the first edit it does not, the slide stops editing for the rest of the
/// touch (`isFrozen`), because what was typed back might no longer be what was deleted.
public final class DeleteWordSwipe {

    /// What one move did, for the caller's haptic tick per word and its suggestion refresh.
    public struct Change: Equatable {
        public var deletedWords = 0
        public var restoredWords = 0
        public var steps: Int { deletedWords + restoredWords }

        public init(deletedWords: Int = 0, restoredWords: Int = 0) {
            self.deletedWords = deletedWords
            self.restoredWords = restoredWords
        }
    }

    private let editor: TextDocumentEditing
    private let mirror: MirrorSyncState?
    private let startX: Double
    private let step: Double
    /// What each step deleted, oldest first; a slide back types the last one back.
    private var deleted: [String] = []
    /// The last step ran into the start of the context the host shared: its word may go on
    /// before it, and the next read, once the host has caught up, finishes it.
    private var pending: DeleteWordBoundary.Phase?
    /// The character the backspace's touch-down deleted, typed back with the first word so
    /// that sliding all the way back gives the text exactly as it was before the touch.
    private var touchDownDeletion: String?

    /// Once the finger is a key width left: the repeat stops and the slide owns delete.
    public private(set) var isActive = false
    /// An edit did not move the mirror by what it implied (#530): nothing more is edited
    /// until the finger lifts.
    public private(set) var isFrozen = false
    /// The text before the cursor when the slide took over, for the caller's bookkeeping.
    public private(set) var contextAtActivation: String?

    /// - Parameters:
    ///   - startX: where the finger went down, in the keyboard's coordinates.
    ///   - step: how far one word is: a letter key's width. Floored at one point.
    ///   - touchDownDeletion: the one character the touch-down's own deletion removed, if
    ///     the caller knows it for certain.
    public init(
        editor: TextDocumentEditing,
        mirror: MirrorSyncState?,
        startX: Double,
        step: Double,
        touchDownDeletion: String? = nil
    ) {
        self.editor = editor
        self.mirror = mirror
        self.startX = startX
        self.step = max(1, step)
        self.touchDownDeletion = touchDownDeletion
    }

    public var deletedWordCount: Int { deleted.count }

    /// The one character a backspace removed, read off the context before and after it:
    /// nil unless the text after is the text before less exactly its last character. A
    /// selection deleted leaves the text before the cursor as it was, and a mirror that
    /// missed the deletion (#530) does too, so neither is taken for a character.
    public static func touchDownDeletion(before: String?, after: String?) -> String? {
        guard let before, let last = before.last else { return nil }
        let after = after ?? ""
        guard before.count == after.count + 1, before.hasPrefix(after) else { return nil }
        return String(last)
    }

    /// The held backspace repeated before the slide began: the touch-down's character is no
    /// longer the one next to the cursor, so it is not typed back.
    public func forgetTouchDownDeletion() {
        touchDownDeletion = nil
    }

    /// The finger moved: delete or restore words until their count matches how far left it
    /// is. Nil until the slide is active.
    @discardableResult
    public func move(toX x: Double) -> Change? {
        let wanted = max(0, Int(((startX - x) / step).rounded(.down)))
        if !isActive {
            guard wanted > 0 else { return nil }
            isActive = true
            contextAtActivation = editor.contextBeforeInput
        }
        var change = Change()
        guard !isFrozen else { return change }
        finishPendingWord()
        while deleted.count < wanted, !isFrozen, deleteWord() {
            change.deletedWords += 1
        }
        while deleted.count > wanted, !isFrozen, let text = deleted.popLast() {
            pending = nil
            restore(text)
            change.restoredWords += 1
        }
        return change
    }

    /// The finger lifted, or the touch was cancelled: what is deleted stays deleted. A word
    /// still waiting on the host's context is finished first.
    public func finish() {
        if isActive, !isFrozen { finishPendingWord() }
        deleted.removeAll()
        pending = nil
        touchDownDeletion = nil
    }

    // MARK: - Edits

    private func deleteWord() -> Bool {
        guard let before = editor.contextBeforeInput,
              let span = DeleteWordBoundary.lastWord(in: before), span.length > 0 else { return false }
        var text = delete(span.length, from: before)
        if let character = touchDownDeletion {
            text += character
            touchDownDeletion = nil
        }
        deleted.append(text)
        pending = span.continuesIn
        return true
    }

    /// Finishes the last step's word if the host now shares what was before it.
    private func finishPendingWord() {
        guard let phase = pending, let last = deleted.last, let first = last.first else { return }
        // Nothing shared yet: the host has not caught up. Keep waiting rather than read an
        // empty context as the start of the document.
        guard let before = editor.contextBeforeInput, !before.isEmpty else { return }
        let span = DeleteWordBoundary.continuation(in: before, from: phase, following: first)
        pending = span.continuesIn
        guard span.length > 0 else { return }
        deleted[deleted.count - 1] = delete(span.length, from: before) + last
    }

    /// Deletes the last `count` graphemes of `before`, which must be the context just read,
    /// and returns them.
    private func delete(_ count: Int, from before: String) -> String {
        let text = String(before.suffix(count))
        for _ in 0..<count {
            editor.deleteBackward()
        }
        check(before: before.count, deleted: count, inserted: 0)
        return text
    }

    private func restore(_ text: String) {
        let before = editor.contextLength
        editor.insertText(text)
        check(before: before, deleted: 0, inserted: text.count)
    }

    /// Reports the edit to the mirror accounting and stops the slide on a mismatch. Read
    /// right after the edit, with nothing in between that yields the run loop (#530).
    private func check(before: Int, deleted: Int, inserted: Int) {
        let after = editor.contextLength
        let verdict = mirror?.observe(before: before, after: after, deleted: deleted, inserted: inserted)
            ?? MirrorSync.verdict(before: before, after: after, deleted: deleted, inserted: inserted)
        if verdict != .consistent { isFrozen = true }
    }
}
