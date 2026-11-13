// DictusCore/Tests/DictusCoreTests/AddressLikeTokenTests.swift
// A word inside an e-mail address or a URL is never autocorrected (#919).

import XCTest
@testable import DictusCore

final class AddressLikeTokenTests: XCTestCase {

    // MARK: - The rule

    /// Every prefix of `address` from its first glued separator on is an address,
    /// which is what the keyboard sees one key at a time.
    private func assertAddressFromFirstGluedCharacter(_ address: String, line: UInt = #line) {
        let characters = Array(address)
        guard let first = characters.firstIndex(where: AddressLikeToken.separators.contains) else {
            return XCTFail("\(address) has no separator", line: line)
        }
        for end in (first + 2)...characters.count {
            let prefix = String(characters[0..<end])
            XCTAssertTrue(AddressLikeToken.matches(prefix), "\(prefix)", line: line)
        }
    }

    func testEmailAddressesAreAddressesFromTheirFirstGluedCharacter() {
        assertAddressFromFirstGluedCharacter("helene.bethmont@gmail.com")
        assertAddressFromFirstGluedCharacter("john_doe@example.fr")
        assertAddressFromFirstGluedCharacter("prénom.nom@exemple.fr")
        assertAddressFromFirstGluedCharacter("helene.+tag@example.com")
    }

    func testURLsAreAddressesWithOrWithoutAScheme() {
        assertAddressFromFirstGluedCharacter("https://github.com/x")
        assertAddressFromFirstGluedCharacter("www.getdictus.com")
        assertAddressFromFirstGluedCharacter("getdictus.com/fr")
        XCTAssertTrue(AddressLikeToken.matches("www."))
        XCTAssertTrue(AddressLikeToken.matches("WWW.Example.com"))
        XCTAssertTrue(AddressLikeToken.matches("https:/"))
        XCTAssertTrue(AddressLikeToken.matches("bethmont@"))
    }

    func testSentencePunctuationIsNotAnAddress() {
        for token in ["Bonjour.", "etc.", "etc.,", "M.", "Bonjour...", "Quoi?!", "note:",
                      "aujourd'hui", "peut-être", "l'adresse", "dit-il.", "»."] {
            XCTAssertFalse(AddressLikeToken.matches(token), token)
        }
    }

    func testTheTokenIsReadFromTheLastWhitespace() {
        XCTAssertTrue(AddressLikeToken.atCursor("écrivez à helene.bethmont@gmail"))
        XCTAssertTrue(AddressLikeToken.atCursor("va sur www", followedBy: "."))
        XCTAssertTrue(AddressLikeToken.atCursor("Ligne\nhelene.b"))
        XCTAssertFalse(AddressLikeToken.atCursor("helene.bethmont@gmail.com puis bonjoru", followedBy: "."))
        XCTAssertFalse(AddressLikeToken.atCursor("M. Dupont"))
        XCTAssertFalse(AddressLikeToken.atCursor("Bonjour. ", followedBy: "C"))
        XCTAssertFalse(AddressLikeToken.atCursor("", followedBy: "."))
    }

    // MARK: - Typed key by key

    /// A document whose mirror always agrees with it.
    private final class Document: TextDocumentEditing {
        var text = ""
        var contextBeforeInput: String? { text.isEmpty ? nil : text }
        func deleteBackward() { if !text.isEmpty { text.removeLast() } }
        func insertText(_ inserted: String) { text += inserted }
    }

    /// What the keyboard does for each key, in `DictusKeyboardBridge`'s order: put back
    /// a correction the key shows was inside an address, then correct the word before
    /// a committing mark unless the token is an address, then insert the key.
    /// `corrections` stands in for the spell checker.
    private func type(_ keys: String, corrections: [String: String]) -> String {
        let document = Document()
        let mirror = MirrorSyncState()
        var pendingUndo: (original: String, corrected: String)?
        for character in keys {
            let key = String(character)
            if let undo = pendingUndo, AddressCorrectionRevert.apply(
                editor: document, original: undo.original, corrected: undo.corrected, next: key, mirror: mirror
            ) {
                pendingUndo = nil
            }
            if AutocorrectTrigger.commitsWord(key) || key == " " {
                pendingUndo = nil
                if !AddressLikeToken.atCursor(document.text, followedBy: key),
                   let (_, word) = AutocorrectRejectionMemory.wordAtCursor(context: document.contextBeforeInput),
                   let correction = corrections[word],
                   case .applied = AutocorrectCountingSite.apply(
                       editor: document, word: word, correction: correction, trailing: "", mirror: mirror
                   ) {
                    pendingUndo = key == " " ? nil : (word, correction)
                }
            }
            document.insertText(key)
        }
        return document.text
    }

    private let corrections = [
        "helene": "Hélène", "gmail": "Gmail", "bethmont": "Bethmont", "john": "John",
        "https": "Huttes", "www": "Www", "github": "GitHub", "getdictus": "Getdictus",
        "prénom": "Prénom", "bonjoru": "bonjour", "Bonjoru": "Bonjour"
    ]

    func testAnEmailAddressTypedKeyByKeyStaysAsTyped() {
        for address in ["helene.bethmont@gmail.com", "john_doe@example.fr", "prénom.nom@gmail.com"] {
            XCTAssertEqual(type("Écrire à \(address) demain", corrections: corrections),
                           "Écrire à \(address) demain")
        }
    }

    func testAURLTypedKeyByKeyStaysAsTyped() {
        for url in ["https://github.com/x", "www.getdictus.com", "getdictus.com/fr"] {
            XCTAssertEqual(type("Voir \(url) ici", corrections: corrections), "Voir \(url) ici")
        }
    }

    func testTheFirstSegmentIsCorrectedAtTheMarkThenPutBackByTheNextKey() {
        XCTAssertEqual(type("helene.", corrections: corrections), "Hélène.")
        XCTAssertEqual(type("helene.b", corrections: corrections), "helene.b")
        XCTAssertEqual(type("https:", corrections: corrections), "Huttes:")
        XCTAssertEqual(type("https:/", corrections: corrections), "https:/")
    }

    func testASentenceEndedByAFullStopKeepsItsCorrection() {
        XCTAssertEqual(type("Je dis bonjoru. Ensuite", corrections: corrections), "Je dis bonjour. Ensuite")
        XCTAssertEqual(type("Bonjoru.", corrections: corrections), "Bonjour.")
        XCTAssertEqual(type("M. Dupont, etc. bonjoru, ", corrections: corrections), "M. Dupont, etc. bonjour, ")
    }

    func testAMarkThatIsNotASeparatorPutsNothingBack() {
        XCTAssertEqual(type("bonjoru,b", corrections: corrections), "bonjour,b")
        XCTAssertEqual(type("bonjoru.,", corrections: corrections), "bonjour.,")
    }

    func testNothingIsPutBackWhenTheTextNoLongerEndsWithTheCorrection() {
        let document = Document()
        document.text = "Hélène. "
        XCTAssertFalse(AddressCorrectionRevert.apply(
            editor: document, original: "helene", corrected: "Hélène", next: "b", mirror: MirrorSyncState()
        ))
        XCTAssertEqual(document.text, "Hélène. ")
    }
}
