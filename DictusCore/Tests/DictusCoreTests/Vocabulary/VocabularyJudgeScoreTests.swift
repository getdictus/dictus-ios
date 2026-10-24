// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyJudgeScoreTests.swift
// The labelled pairs file and the step 2 go/no-go (#512), model-free.
import XCTest
import PolishFidelity

final class VocabularyJudgeScoreTests: XCTestCase {

    // MARK: - The file

    func testALineRoundTripsThroughTheParser() throws {
        let line = VocabularyPairsFile.line(
            id: VocabularyPairsFile.pairID(0), canonical: "Claude Code",
            observed: "cloud code", sentence: "j'utilise cloud code | tous les jours"
        )
        XCTAssertEqual(line, "P01 | Claude Code | cloud code | j'utilise cloud code | tous les jours")
        let parsed = try VocabularyPairsFile.parse(VocabularyPairsFile.header + "\n" + "v " + line + "\n")
        XCTAssertEqual(parsed, [VocabularyPairsFile.Entry(
            id: "P01", canonical: "Claude Code", observed: "cloud code",
            sentence: "j'utilise cloud code | tous les jours", isTrue: true
        )], "the sentence is the last field and may hold the separator")
    }

    func testLabelsAreReadAndAMissingOneIsNil() throws {
        let text = """
        v P01 | Hermes | airmes | l'airmes est prêt
        F  P02 | Claude | clode | le clode
        P03 | Parakeet | para kit | un para kit
        """
        XCTAssertEqual(try VocabularyPairsFile.parse(text).map(\.isTrue), [true, false, nil])
    }

    func testAMalformedLineIsRefusedWithItsNumber() {
        XCTAssertThrowsError(try VocabularyPairsFile.parse("# header\n\nv P01 Hermes airmes")) { error in
            XCTAssertEqual(error as? VocabularyPairsFile.ParseError, .malformed(lineNumber: 3))
        }
        XCTAssertThrowsError(try VocabularyPairsFile.parse("x P01 | a | b | c"),
                             "a label other than v or f is not a label")
    }

    func testADuplicateIDIsRefused() {
        XCTAssertThrowsError(try VocabularyPairsFile.parse("v P01 | a | b | c\nf P01 | a | d | c")) { error in
            XCTAssertEqual(error as? VocabularyPairsFile.ParseError, .duplicateID("P01"))
        }
    }

    func testACanonicalWithTheSeparatorIsNotWritable() {
        XCTAssertFalse(VocabularyPairsFile.isWritable(canonical: "A | B"))
        XCTAssertFalse(VocabularyPairsFile.isWritable(canonical: "A\nB"))
        XCTAssertTrue(VocabularyPairsFile.isWritable(canonical: "Node.js"))
    }

    // MARK: - Readings

    func testThreeAgreeingRunsAreAReading() {
        XCTAssertEqual(VocabularyJudgeReading(runs: [true, true, true]), .yes)
        XCTAssertEqual(VocabularyJudgeReading(runs: [false, false, false]), .no)
    }

    func testAnyDisagreementOrFailureIsAnError() {
        XCTAssertEqual(VocabularyJudgeReading(runs: [true, false, true]), .inconsistent)
        XCTAssertEqual(VocabularyJudgeReading(runs: [true, nil, true]), .failed)
        XCTAssertEqual(VocabularyJudgeReading(runs: []), .failed)
    }

    // MARK: - The verdict, rule by rule

    private func labels(true trueCount: Int, of total: Int = 20) -> [Bool] {
        Array(repeating: true, count: trueCount) + Array(repeating: false, count: total - trueCount)
    }

    func testSeventeenTrueShipsTheGeneratorWithoutTheJudge() throws {
        XCTAssertTrue(VocabularyJudgeVerdict.labelsSettle(trueCount: 17, total: 20))
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 17), readings: nil))
        XCTAssertEqual(verdict.decision, .generatorAloneJudgeNotCalled)
        XCTAssertFalse(verdict.judgeRan)
    }

    func testSixteenTrueNeedsTheJudge() {
        XCTAssertFalse(VocabularyJudgeVerdict.labelsSettle(trueCount: 16, total: 20))
        XCTAssertNil(VocabularyJudgeVerdict(labels: labels(true: 16), readings: nil),
                     "no verdict without the judge once the labels do not settle it")
    }

    func testAJudgeAtEightyPercentOnBothSidesPasses() throws {
        // 10 true, 10 false: keeps 8 of 10, rejects 8 of 10.
        let readings: [VocabularyJudgeReading] =
            Array(repeating: .yes, count: 8) + [.no, .inconsistent]
            + Array(repeating: .no, count: 8) + [.yes, .failed]
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 10), readings: readings))
        XCTAssertEqual(verdict.trueKept, 8)
        XCTAssertEqual(verdict.falseRejected, 8)
        XCTAssertEqual(verdict.decision, .generatorWithJudge)
    }

    func testAJudgeBelowEightyOnOneSideFailsAndFourteenTrueShipsTheGeneratorAlone() throws {
        // 14 true, 6 false: keeps all 14, rejects 4 of 6 (66 %).
        let readings: [VocabularyJudgeReading] =
            Array(repeating: .yes, count: 14) + Array(repeating: .no, count: 4) + [.yes, .yes]
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 14), readings: readings))
        XCTAssertEqual(verdict.decision, .generatorAloneJudgeFailed)
    }

    func testAFailedJudgeBelowFourteenTrueDropsTheStep() throws {
        let readings = Array(repeating: VocabularyJudgeReading.inconsistent, count: 20)
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 13), readings: readings))
        XCTAssertEqual(verdict.decision, .stepDropped)
    }

    func testAJudgeWithNoTruePairToKeepDoesNotPass() throws {
        let readings = Array(repeating: VocabularyJudgeReading.no, count: 20)
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 0), readings: readings))
        XCTAssertEqual(verdict.decision, .stepDropped, "rejecting everything is not judging")
    }

    func testAShortFileUsesTheSameShares() throws {
        // 9 of 10 is 90 %, above 17 of 20; 8 of 10 is 80 %, below it.
        XCTAssertTrue(VocabularyJudgeVerdict.labelsSettle(trueCount: 9, total: 10))
        XCTAssertFalse(VocabularyJudgeVerdict.labelsSettle(trueCount: 8, total: 10))
        let verdict = try XCTUnwrap(VocabularyJudgeVerdict(labels: labels(true: 9, of: 10), readings: nil))
        XCTAssertFalse(verdict.isBriefSample)
    }
}
