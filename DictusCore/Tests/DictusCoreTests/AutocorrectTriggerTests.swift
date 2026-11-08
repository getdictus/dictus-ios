// DictusCore/Tests/DictusCoreTests/AutocorrectTriggerTests.swift
// Autocorrect before a punctuation mark or a return, never inside a word (#872).

import XCTest
@testable import DictusCore

final class AutocorrectTriggerTests: XCTestCase {

    /// A document whose mirror always agrees with it.
    private final class Document: TextDocumentEditing {
        var text: String
        init(_ text: String) { self.text = text }
        var contextBeforeInput: String? { text.isEmpty ? nil : text }
        func deleteBackward() { if !text.isEmpty { text.removeLast() } }
        func insertText(_ inserted: String) { text += inserted }
    }

    /// What the bridge does when `key` is typed after `typed`: correct the word in
    /// front of the cursor without a space, then insert the key itself.
    private func type(_ key: String, after typed: String, correction: String) -> String {
        let document = Document(typed)
        if AutocorrectTrigger.commitsWord(key),
           let (_, word) = AutocorrectRejectionMemory.wordAtCursor(context: document.contextBeforeInput) {
            AutocorrectCountingSite.apply(
                editor: document, word: word, correction: correction, trailing: "",
                mirror: MirrorSyncState()
            )
        }
        document.insertText(key)
        return document.text
    }

    func testACommaCorrectsTheWordBeforeIt() {
        // Scenario 9.
        XCTAssertEqual(type(",", after: "la cuisinr", correction: "cuisine"), "la cuisine,")
    }

    func testAFullStopCorrectsTheWordBeforeIt() {
        XCTAssertEqual(type(".", after: "le bureai", correction: "bureau"), "le bureau.")
    }

    func testAQuestionMarkCorrectsTheWordBeforeIt() {
        XCTAssertEqual(type("?", after: "le bureai", correction: "bureau"), "le bureau?")
    }

    func testReturnCorrectsTheWordBeforeIt() {
        // Scenario 10.
        XCTAssertEqual(type("\n", after: "le bureai", correction: "bureau"), "le bureau\n")
    }

    func testEveryCommittingMarkIsListed() {
        for mark in [",", ".", ";", ":", "!", "?", "\n"] {
            XCTAssertTrue(AutocorrectTrigger.commitsWord(mark), mark)
        }
    }

    func testAnApostropheOrAHyphenNeverCorrects() {
        // `l'`, `aujourd'hui`, `peut-être`: the mark is inside a word.
        XCTAssertEqual(type("'", after: "aujourd", correction: "aujourd'hui"), "aujourd'")
        XCTAssertEqual(type("’", after: "aujourd", correction: "aujourd'hui"), "aujourd’")
        XCTAssertEqual(type("-", after: "peut", correction: "peu"), "peut-")
        XCTAssertFalse(AutocorrectTrigger.commitsWord(" "), "the space keeps its own path")
    }

    func testWithoutATrailingSpaceTheSiteWritesNoSpace() {
        let document = Document("la cuisinr")
        let outcome = AutocorrectCountingSite.apply(
            editor: document, word: "cuisinr", correction: "cuisine", trailing: "",
            mirror: MirrorSyncState()
        )
        XCTAssertEqual(outcome, .applied(deleted: 7))
        XCTAssertEqual(document.text, "la cuisine")
    }

    func testTheSpaceBarStillWritesItsSpace() {
        let document = Document("la cuisinr")
        AutocorrectCountingSite.apply(
            editor: document, word: "cuisinr", correction: "cuisine", mirror: MirrorSyncState()
        )
        XCTAssertEqual(document.text, "la cuisine ")
    }
}
