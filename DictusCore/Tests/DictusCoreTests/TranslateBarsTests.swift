// DictusCore/Tests/DictusCoreTests/TranslateBarsTests.swift
import XCTest
@testable import PolishFidelity

/// The Translate bench's scorer (#648). Pinned because its verdicts are what the
/// research report counts, and its redaction is what keeps a private fixture's words
/// out of a public repository.
final class TranslateBarsTests: XCTestCase {

    private func decode(_ json: String...) throws -> TranslateBarSet {
        try TranslateBarSet.decode(json.map { Data($0.utf8) })
    }

    func testAForbiddenSpanFailsAndNamesWhatItFound() {
        let bars = TranslateBars(id: "x", critical: [
            TranslateBarCheck(label: "move on to, not skip", forbid: "(?i)skip(ping)?[^.]{0,15}marketing")
        ])
        let score = TranslateScore.score(output: "I want to skip the marketing phase.", bars: bars)
        XCTAssertEqual(score.critical, ["move on to, not skip [found \"skip the marketing\"]"])
    }

    func testAMissingRequiredSpanFails() {
        let bars = TranslateBars(id: "x", keep: [TranslateBarCheck(label: "Hugo", require: "Hugo")])
        XCTAssertEqual(TranslateScore.score(output: "Hi Alex.", bars: bars).keep, ["Hugo [missing]"])
        XCTAssertEqual(TranslateScore.score(output: "Hi Hugo.", bars: bars).keep, [])
    }

    func testACheckWithBothPassesOnlyWhenBothHold() {
        let check = TranslateBarCheck(label: "had the meeting", require: "(?i)\\bhad\\b",
                                      forbid: "(?i)made the appointment")
        let bars = TranslateBars(id: "x", critical: [check])
        XCTAssertEqual(TranslateScore.score(output: "I just had the meeting.", bars: bars).critical, [])
        XCTAssertEqual(TranslateScore.score(output: "I had made the appointment.", bars: bars).critical.count, 1)
        XCTAssertEqual(TranslateScore.score(output: "The meeting went well.", bars: bars).critical.count, 1)
    }

    /// The private fixture is split across a public and a private file on purpose, so
    /// two entries with one id must add up rather than the second replacing the first.
    func testEntriesSharingAnIDAreMergedAndTheSharedAdditionsApplyToEveryFixture() throws {
        let set = try decode(
            #"[{"id": "*", "add": [{"label": "placeholder", "forbid": "\\["}]},"#
                + #" {"id": "f", "critical": [{"label": "public", "forbid": "no longer"}]}]"#,
            #"[{"id": "f", "keep": [{"label": "private", "require": "GDP"}]}]"#
        )
        let bars = set.bars(for: "f")
        XCTAssertEqual(bars.critical?.map(\.label), ["public"])
        XCTAssertEqual(bars.keep?.map(\.label), ["private"])
        XCTAssertEqual(bars.add?.map(\.label), ["placeholder"])
        XCTAssertEqual(set.bars(for: "other").add?.map(\.label), ["placeholder"])
    }

    func testAnInvalidPatternIsRefusedAtDecode() {
        XCTAssertThrowsError(try decode(#"[{"id": "f", "keep": [{"label": "bad", "require": "(unclosed"}]}]"#))
    }

    /// What a committed capture may carry for a private fixture: the counts, the public
    /// critical spans, and none of the output's or the private bars' words.
    func testRedactionKeepsCountsAndPublicSpansAndDropsEverythingElse() {
        var score = TranslateScore()
        score.drop = ["private tic [found \"words\"]"]
        score.keep = ["the private fact [missing]"]
        score.add = ["sign-off [found \"Best regards\"]"]
        score.critical = ["more than 60 [found \"no longer\"]"]
        let redacted = score.redacted()
        XCTAssertEqual(redacted.drop, [TranslateScore.privateCheck])
        XCTAssertEqual(redacted.keep, [TranslateScore.privateCheck])
        XCTAssertEqual(redacted.add, ["sign-off [found]"])
        XCTAssertEqual(redacted.critical, score.critical)
    }

    func testTheOutputLanguageIsRead() {
        let score = TranslateScore.score(
            output: "I wanted to get your opinion on a new feature I am developing.",
            bars: TranslateBars(id: "x")
        )
        XCTAssertEqual(score.outputLanguage, "en")
    }
}
