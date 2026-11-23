// DictusCore/Tests/DictusCoreTests/TextReplacementTests.swift
// iOS text replacements expand as on Apple's keyboard (#1022): with autocorrect
// off and in any field but a secure or password one (gap 1), after a refusal at
// the same place (gap 3), and for a shortcut holding a digit (gap 4).
//
// The keyboard bridge asks `SupplementaryLexicon.expansion(ofShortcut:)` before its
// digit guard, gates the phrase on `HostFieldPolicy.textReplacementsAllowed` alone,
// and commits it through `AutocorrectRejectionMemory.commit(isTextReplacement:)`.
// These are the three pieces it decides with.

import XCTest
@testable import DictusCore

final class TextReplacementTests: XCTestCase {

    private let lexicon = SupplementaryLexicon(entries: [
        (userInput: "qqc", documentText: "quelque chose"),
        (userInput: "adr1", documentText: "12 rue de la Paix"),
        (userInput: "tel2", documentText: "06 12 34 56 78"),
        (userInput: "Zofiak", documentText: "Zofiak")
    ])

    private func policy(
        keyboard: HostFieldPolicy.KeyboardKind = .standard,
        content: HostFieldPolicy.ContentKind = .none,
        autocorrectionDisabled: Bool = false,
        spellCheckingDisabled: Bool = false,
        isSecureEntry: Bool = false
    ) -> HostFieldPolicy {
        HostFieldPolicy.evaluate(
            keyboard: keyboard,
            content: content,
            autocorrectionDisabled: autocorrectionDisabled,
            spellCheckingDisabled: spellCheckingDisabled,
            isSecureEntry: isSecureEntry
        )
    }

    // MARK: - Gap 1: autocorrect off, any non-secure field

    /// `autocorrectionType = .no` turns autocorrect off, not text replacements.
    func testFieldWithAutocorrectionOffStillExpandsShortcuts() {
        let field = policy(autocorrectionDisabled: true)
        XCTAssertFalse(field.autocorrectAllowed)
        XCTAssertTrue(field.textReplacementsAllowed)
    }

    func testEveryNonSecureFieldExpandsShortcuts() {
        let fields = [
            policy(),
            policy(spellCheckingDisabled: true),
            policy(keyboard: .webSearch),
            policy(keyboard: .url),
            policy(keyboard: .email),
            policy(keyboard: .twitter),
            policy(keyboard: .asciiCapable),
            policy(content: .username),
            policy(content: .url),
            policy(content: .email),
            policy(content: .oneTimeCode),
            policy(content: .other)
        ]
        for field in fields {
            XCTAssertTrue(field.textReplacementsAllowed, field.reason)
        }
    }

    func testSecureFieldNeverExpandsShortcuts() {
        XCTAssertFalse(policy(isSecureEntry: true).textReplacementsAllowed)
        XCTAssertFalse(policy(content: .password, isSecureEntry: true).textReplacementsAllowed)
    }

    /// A password field that is not marked secure (a "show password" toggle) is
    /// still a password field: `.password` and `.newPassword` both map here.
    func testPasswordFieldNeverExpandsShortcuts() {
        XCTAssertFalse(policy(content: .password).textReplacementsAllowed)
        XCTAssertFalse(policy(content: .password, autocorrectionDisabled: true).textReplacementsAllowed)
    }

    /// The flag adds to the policy and changes none of its other answers.
    func testAutocorrectAndSuggestionAnswersAreUnchanged() {
        let password = policy(content: .password, autocorrectionDisabled: true)
        XCTAssertFalse(password.autocorrectAllowed)
        XCTAssertFalse(password.suggestionsAllowed)
        XCTAssertEqual(password.reason, "autocorrectionType.no")
        XCTAssertEqual(policy(), .allowed)
    }

    /// The mention hold of #1004 rebuilds the policy: it must keep the flag.
    func testMentionHoldKeepsShortcutsOn() {
        var tracker = HostFieldPolicyTracker()
        let mention = "@\u{2068}Kevin LAGE\u{2069} "
        _ = tracker.policy(for: HostFieldTraits(), document: "doc", text: "")
        let held = tracker.policy(
            for: HostFieldTraits(autocorrectionDisabled: true), document: "doc", text: mention
        )
        XCTAssertTrue(held.textReplacementsAllowed)
    }

    // MARK: - Gap 3: a refusal does not turn a shortcut off

    private func commitShortcut(
        _ memory: AutocorrectRejectionMemory, _ context: String, isTextReplacement: Bool = true
    ) -> AutocorrectRejectionMemory.Decision {
        guard let (prefix, word) = AutocorrectRejectionMemory.wordAtCursor(context: context),
              let phrase = lexicon.expansion(ofShortcut: word) else {
            XCTFail("no shortcut at the end of \"\(context)\"")
            return .keep(countUsage: false)
        }
        return memory.commit(
            prefix: prefix, word: word, proposedCorrection: phrase, isTextReplacement: isTextReplacement
        )
    }

    private func newMemory() -> AutocorrectRejectionMemory {
        let memory = AutocorrectRejectionMemory()
        memory.enter(document: "doc-A")
        return memory
    }

    /// The expansion is erased with backspace and the shortcut typed again at the
    /// same place: it expands again. Before #1022 the second commit was `.keepAndLearn`.
    func testShortcutExpandsAgainAfterItsExpansionWasErased() {
        let memory = newMemory()
        XCTAssertEqual(commitShortcut(memory, "Je veux qqc"), .correct)
        memory.correctionApplied(prefix: "Je veux ", corrected: "quelque chose")

        // Backspace from "Je veux quelque chose " down to "Je veux ": a refusal.
        var text = "Je veux quelque chose "
        var refused: String?
        while text.count > "Je veux ".count {
            let before = text
            text.removeLast()
            refused = memory.textDeleted(before: before, after: text) ?? refused
        }
        XCTAssertEqual(refused, "quelque chose")
        XCTAssertTrue(memory.isRejected(prefix: "Je veux "))

        XCTAssertEqual(commitShortcut(memory, "Je veux qqc"), .correct)
    }

    /// The Undo chip restores the shortcut; committed again at that place, it expands.
    func testShortcutExpandsAgainAfterUndo() {
        let memory = newMemory()
        memory.correctionApplied(prefix: "Je veux ", corrected: "quelque chose")
        memory.correctionUndone(prefix: "Je veux ", original: "qqc")

        XCTAssertEqual(commitShortcut(memory, "Je veux qqc"), .correct)
        // Nothing restored is left to learn at that place.
        XCTAssertNil(memory.movingOn(context: "Je veux qqc suite"))
    }

    /// Tapping the quoted shortcut keeps it that once; typed again, it expands.
    func testShortcutExpandsAgainAfterTheTypedWordWasKept() {
        let memory = newMemory()
        XCTAssertTrue(memory.typedWordKept(prefix: "Je veux ", word: "qqc", rowWord: "qqc"))
        XCTAssertEqual(commitShortcut(memory, "Je veux qqc"), .correct)
    }

    func testManyRefusalsNeverTurnAShortcutOff() {
        let memory = newMemory()
        for _ in 0..<5 {
            memory.correctionApplied(prefix: "Je veux ", corrected: "quelque chose")
            memory.correctionUndone(prefix: "Je veux ", original: "qqc")
            XCTAssertEqual(commitShortcut(memory, "Je veux qqc"), .correct)
        }
    }

    /// Regression guard: an ordinary correction refused at a place is still kept
    /// and learned there (#872). Only a text replacement is exempt.
    func testOrdinaryCorrectionIsStillKeptAfterARefusal() {
        let memory = newMemory()
        memory.correctionApplied(prefix: "Je veux ", corrected: "quelque chose")
        memory.correctionUndone(prefix: "Je veux ", original: "qqc")
        XCTAssertEqual(commitShortcut(memory, "Je veux qqc", isTextReplacement: false), .keepAndLearn)
    }

    // MARK: - Gap 4: shortcuts with a digit

    func testShortcutWithADigitExpands() {
        XCTAssertEqual(lexicon.expansion(ofShortcut: "adr1"), "12 rue de la Paix")
        XCTAssertEqual(lexicon.expansion(ofShortcut: "tel2"), "06 12 34 56 78")
        XCTAssertEqual(lexicon.decision(for: "adr1", isDictionaryWord: false), .replace(with: "12 rue de la Paix"))
    }

    /// The bridge reads the word with `wordAtCursor`: the digit belongs to it, so the
    /// whole shortcut is looked up, and not only its letters.
    func testWordAtCursorKeepsTheDigitOfAShortcut() {
        XCTAssertEqual(AutocorrectRejectionMemory.wordAtCursor(context: "mon adresse : adr1")?.word, "adr1")
        XCTAssertEqual(AutocorrectRejectionMemory.wordAtCursor(context: "Appelle le tel2")?.word, "tel2")
        XCTAssertEqual(AutocorrectRejectionMemory.wordAtCursor(context: "Appelle le tel2")?.prefix, "Appelle le ")
    }

    func testCapitalizedShortcutWithADigitCapitalizesThePhrase() {
        let digits = SupplementaryLexicon(entries: [(userInput: "ad2", documentText: "second address")])
        XCTAssertEqual(digits.expansion(ofShortcut: "Ad2"), "Second address")
        XCTAssertEqual(digits.expansion(ofShortcut: "AD2"), "Second address")
    }

    // MARK: - What a shortcut is

    /// Only a shortcut expands outside autocorrect. A contact's casing (`zofiak` ->
    /// "Zofiak") and a curated name (`iphone` -> "iPhone") stay autocorrections, off
    /// when autocorrect is off.
    func testContactAndCuratedNamesAreNotShortcuts() {
        XCTAssertNil(lexicon.expansion(ofShortcut: "zofiak"))
        XCTAssertNil(lexicon.expansion(ofShortcut: "iphone"))
        XCTAssertNil(lexicon.expansion(ofShortcut: "quelque"))
        XCTAssertNil(SupplementaryLexicon.empty.expansion(ofShortcut: "qqc"))
    }

    func testShortcutDecisionIsUnchanged() {
        XCTAssertEqual(lexicon.expansion(ofShortcut: "Qqc"), "Quelque chose")
        XCTAssertEqual(lexicon.decision(for: "qqc", isDictionaryWord: true), .replace(with: "quelque chose"))
        XCTAssertEqual(lexicon.decision(for: "Qqc", isDictionaryWord: false), .replace(with: "Quelque chose"))
    }
}
