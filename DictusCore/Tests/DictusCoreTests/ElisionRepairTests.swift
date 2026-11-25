// DictusCore/Tests/DictusCoreTests/ElisionRepairTests.swift
// French elisions typed with a wrong prefix, the key next to the apostrophe, or a space (#1006).
import XCTest
@testable import DictusCore

/// The cases come from a device test on 2026-11-20 (`qunil`, `qj'on`, `ce st`), and
/// the counter-cases from the issue.
final class ElisionRepairTests: XCTestCase {

    private let repair = frenchProfile.elisionRepair

    /// Words of the French dictionary these cases meet. `st`, `quil`, `qunil` are not in it.
    private let dictionary: Set<String> = [
        "il", "ils", "elle", "elles", "on", "un", "une", "est", "a", "ai", "es",
        "qu", "ce", "le", "quel", "quille", "cesse", "quoi", "non", "dans", "c",
    ]

    private func isWord(_ word: String) -> Bool { dictionary.contains(word) }

    func testFrenchHasTheRepairAndOtherLanguagesDoNot() {
        XCTAssertNotNil(frenchProfile.elisionRepair)
        XCTAssertNil(englishProfile.elisionRepair)
        XCTAssertNil(spanishProfile.elisionRepair)
        XCTAssertNil(germanProfile.elisionRepair)
    }

    // MARK: - A mistyped prefix before the apostrophe

    func testAKeyNextToUInQuIsRepaired() {
        XCTAssertEqual(repair?.repairPrefix("qj'on", isWord: isWord), "qu'on", "j sits under u on AZERTY")
        XCTAssertEqual(repair?.repairPrefix("qy'il", isWord: isWord), "qu'il")
        XCTAssertEqual(repair?.repairPrefix("qi'elle", isWord: isWord), "qu'elle")
        XCTAssertEqual(repair?.repairPrefix("q'il", isWord: isWord), "qu'il", "the u left out")
    }

    func testTheSingleLetterSlipsStillWork() {
        XCTAssertEqual(repair?.repairPrefix("v'est", isWord: isWord), "c'est")
        XCTAssertEqual(repair?.repairPrefix("x'est", isWord: isWord), "c'est")
        XCTAssertEqual(repair?.repairPrefix("h'ai", isWord: isWord), "j'ai")
        XCTAssertEqual(repair?.repairPrefix("b'est", isWord: isWord), "n'est")
        XCTAssertEqual(repair?.repairPrefix("y'es", isWord: isWord), "t'es")
    }

    func testAValidPrefixIsLeftToTheRestOfThePipeline() {
        for word in ["qu'il", "c'est", "j'ai", "l'on", "n'est"] {
            XCTAssertNil(repair?.repairPrefix(word, isWord: isWord), word)
        }
    }

    func testASlipBeforeANonWordIsNotRepaired() {
        XCTAssertNil(repair?.repairPrefix("qj'azxy", isWord: isWord))
        XCTAssertNil(repair?.repairPrefix("v'", isWord: isWord))
    }

    // MARK: - The key next to the apostrophe typed in its place

    func testTheNTypedForTheApostropheIsRepaired() {
        XCTAssertEqual(repair?.repairApostropheSlip("qunil"), "qu'il", "device test 2026-11-20")
        XCTAssertEqual(repair?.repairApostropheSlip("qunelle"), "qu'elle")
        XCTAssertEqual(repair?.repairApostropheSlip("qunon"), "qu'on")
        XCTAssertEqual(repair?.repairApostropheSlip("cnest"), "c'est")
        XCTAssertEqual(repair?.repairApostropheSlip("cnetait"), "c'\u{00E9}tait", "the accent comes back")
    }

    func testTheNSlipOnlyRepairsTheListedElisions() {
        // `dnas` is `dans` with two letters swapped, not `d'as`.
        for word in ["dnas", "snob", "qunique", "cnes", "quille", "quiz", "cesse"] {
            XCTAssertNil(repair?.repairApostropheSlip(word), word)
        }
    }

    // MARK: - A space typed for the apostrophe

    func testASpaceForTheApostropheIsRepaired() {
        XCTAssertEqual(repair?.joinAcrossSpace(previousWord: "qu", word: "il", isWord: isWord), "qu'il")
        XCTAssertEqual(repair?.joinAcrossSpace(previousWord: "qu", word: "elle", isWord: isWord), "qu'elle")
        XCTAssertEqual(repair?.joinAcrossSpace(previousWord: "qu", word: "on", isWord: isWord), "qu'on")
    }

    func testASpaceOneLetterOffIsRepaired() {
        XCTAssertEqual(
            repair?.joinAcrossSpace(previousWord: "ce", word: "st", isWord: isWord), "c'est",
            "device test 2026-11-20"
        )
        XCTAssertEqual(repair?.joinAcrossSpace(previousWord: "Ce", word: "st", isWord: isWord), "c'est")
    }

    func testTwoWordsThatStandOnTheirOwnAreLeftAlone() {
        XCTAssertNil(repair?.joinAcrossSpace(previousWord: "quel", word: "le", isWord: isWord), "quel le")
        XCTAssertNil(repair?.joinAcrossSpace(previousWord: "ce", word: "est", isWord: isWord), "ce est")
        XCTAssertNil(repair?.joinAcrossSpace(previousWord: "ce", word: "quoi", isWord: isWord))
    }

    func testABareOneLetterPrefixIsAWordOfItsOwn() {
        XCTAssertNil(
            repair?.joinAcrossSpace(previousWord: "C", word: "est", isWord: isWord),
            "le langage C est rapide"
        )
    }

    func testAContractionOnEitherSideIsLeftAlone() {
        XCTAssertNil(repair?.joinAcrossSpace(previousWord: "qu'il", word: "st", isWord: isWord))
        XCTAssertNil(repair?.joinAcrossSpace(previousWord: "ce", word: "s'il", isWord: isWord))
    }
}
