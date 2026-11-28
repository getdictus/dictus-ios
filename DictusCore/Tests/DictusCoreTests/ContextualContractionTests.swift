// DictusCore/Tests/DictusCoreTests/ContextualContractionTests.swift
// The English real-word contractions (#995): restored where the words before
// call for them, left alone where the typed word is meant.
import XCTest
@testable import DictusCore

final class ContextualContractionTests: XCTestCase {

    private func contraction(_ word: String, after previous: String?, atSentenceStart: Bool = false) -> String? {
        contextualContraction(
            profile: englishProfile, word: word, previousWord: previous, isAtSentenceStart: atSentenceStart
        )
    }

    // MARK: - ill / I'll

    func test_ill_atSentenceStart_isIll() {
        XCTAssertEqual(contraction("Ill", after: nil, atSentenceStart: true), "I'll")
        XCTAssertEqual(contraction("ill", after: "today", atSentenceStart: true), "I'll")
    }

    func test_ill_afterAClause_isIll() {
        // "in any case ill call you tomorrow"
        XCTAssertEqual(contraction("ill", after: "case"), "I'll")
        XCTAssertEqual(contraction("ill", after: "think"), "I'll")
    }

    func test_ill_afterBe_staysIll() {
        // "I'll be ill"
        XCTAssertNil(contraction("ill", after: "be"))
        XCTAssertNil(contraction("ill", after: "was"))
        XCTAssertNil(contraction("ill", after: "I\u{2019}m"))
        XCTAssertNil(contraction("ill", after: "mentally"))
        XCTAssertNil(contraction("ill", after: "felt"))
    }

    // MARK: - its / it's

    func test_its_atSentenceStart_isItIs() {
        XCTAssertEqual(contraction("Its", after: nil, atSentenceStart: true), "It's")
    }

    func test_its_midSentence_staysPossessive() {
        // "it has its own rules", "one of its"
        XCTAssertNil(contraction("its", after: "has"))
        XCTAssertNil(contraction("its", after: "of"))
    }

    /// What Apple's keyboard writes once the next word is typed: "the dog wagged its tail"
    /// keeps the possessive, "its raining" and "its a good idea" are "it's".
    func test_its_beforeAWordNoPossessiveTakes_isItIs() {
        XCTAssertEqual(contextualContraction(profile: englishProfile, word: "its", before: "raining"), "it's")
        XCTAssertEqual(contextualContraction(profile: englishProfile, word: "its", before: "a"), "it's")
        XCTAssertEqual(contextualContraction(profile: englishProfile, word: "Its", before: "Not"), "It's")
    }

    func test_its_beforeANounOrAdjective_staysPossessive() {
        for next in ["tail", "own", "new", "true", "collar", "employees", "best"] {
            XCTAssertNil(contextualContraction(profile: englishProfile, word: "its", before: next), next)
        }
        XCTAssertNil(contextualContraction(profile: englishProfile, word: "ill", before: "a"))
        XCTAssertNil(contextualContraction(profile: frenchProfile, word: "its", before: "a"))
    }

    // MARK: - were / we're

    func test_were_afterAClauseWord_isWeAre() {
        // "I'm afraid were going to be late"
        XCTAssertEqual(contraction("were", after: "afraid"), "we're")
        XCTAssertEqual(contraction("were", after: "hope"), "we're")
    }

    func test_were_afterItsSubject_staysWere() {
        // "we were", "they were"
        XCTAssertNil(contraction("were", after: "we"))
        XCTAssertNil(contraction("were", after: "they"))
        XCTAssertNil(contraction("were", after: "sure"))
    }

    func test_were_atSentenceStart_staysWere() {
        // "Were you there?"
        XCTAssertNil(contraction("Were", after: nil, atSentenceStart: true))
    }

    // MARK: - Scope

    func test_otherWordsAndLanguages_areLeftAlone() {
        XCTAssertNil(contraction("well", after: "think"))
        XCTAssertNil(contextualContraction(profile: frenchProfile, word: "ill", previousWord: nil, isAtSentenceStart: true))
    }

    func test_noPreviousWordMidSentence_leavesTheWord() {
        XCTAssertNil(contraction("ill", after: nil))
    }
}
