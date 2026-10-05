// DictusCore/Tests/DictusCoreTests/TranscriptionSearchTests.swift
// The History search rule (#621): what a query finds, and what it must not.
import XCTest
@testable import DictusCore

final class TranscriptionSearchTests: XCTestCase {

    private func record(_ text: String,
                        language: String = "fr",
                        engine: SpeechEngine = .whisperKit) -> TranscriptionRecord {
        TranscriptionRecord(
            text: text,
            language: language,
            durationSeconds: 3,
            sttProvider: engine.rawValue
        )
    }

    // MARK: - Case and diacritics

    func testUnaccentedLowercaseFindsAccentedWord() {
        XCTAssertTrue(TranscriptionSearch.matches(record("Je passe à l'école ce soir"), query: "ecole"))
    }

    func testCapitalisedUnaccentedFindsAccentedWord() {
        XCTAssertTrue(TranscriptionSearch.matches(record("Je passe à l'école ce soir"), query: "Ecole"))
    }

    func testUppercaseAccentedFindsLowercaseWord() {
        XCTAssertTrue(TranscriptionSearch.matches(record("Je passe à l'école ce soir"), query: "ÉCOLE"))
    }

    /// The other way round: a transcript that came out without its accents is still
    /// found by a user who types them.
    func testAccentedQueryFindsUnaccentedText() {
        XCTAssertTrue(TranscriptionSearch.matches(record("rendez-vous a l'ecole"), query: "école"))
    }

    func testOtherDiacriticsFold() {
        let text = record("Straße, niño, garçon, naïve, Müller")
        for query in ["nino", "garcon", "naive", "muller", "MÜLLER"] {
            XCTAssertTrue(TranscriptionSearch.matches(text, query: query), query)
        }
    }

    func testMatchesInsideAWord() {
        XCTAssertTrue(TranscriptionSearch.matches(record("Les écoliers sont partis"), query: "ecol"))
    }

    func testTextWithoutTheQueryIsNotFound() {
        XCTAssertFalse(TranscriptionSearch.matches(record("Rappeler le plombier demain"), query: "ecole"))
    }

    // MARK: - Empty query

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(TranscriptionSearch.matches(record("anything"), query: ""))
    }

    func testWhitespaceOnlyQueryMatchesEverything() {
        XCTAssertTrue(TranscriptionSearch.matches(record("anything"), query: "  \n "))
    }

    /// A trailing space from the keyboard must not hide a match at the end of a text.
    func testSurroundingWhitespaceInTheQueryIsIgnored() {
        XCTAssertTrue(TranscriptionSearch.matches(record("on se voit à l'école"), query: " ecole "))
    }

    // MARK: - Only the text is searched

    func testLanguageIsNotASearchTerm() {
        XCTAssertFalse(TranscriptionSearch.matches(record("Bonjour", language: "fr"), query: "fr"))
    }

    func testEngineIsNotASearchTerm() {
        XCTAssertFalse(TranscriptionSearch.matches(record("Bonjour", engine: .whisperKit),
                                                   query: SpeechEngine.whisperKit.rawValue))
    }

    func testVoiceNoteSummaryIsNotSearched() {
        let note = record("Le transcript du message")
            .withSummary("Résumé : rendez-vous à l'école", modeIdentifier: "summary")
        XCTAssertFalse(TranscriptionSearch.matches(note, query: "ecole"))
        XCTAssertTrue(TranscriptionSearch.matches(note, query: "transcript"))
    }

    // MARK: - Filter

    func testFilterKeepsTheGivenOrder() {
        let records = [
            record("école trois"),
            record("rien à voir"),
            record("Ecole deux"),
            record("ÉCOLE un")
        ]

        let found = TranscriptionSearch.filter(records, query: "ecole")

        XCTAssertEqual(found.map(\.text), ["école trois", "Ecole deux", "ÉCOLE un"])
    }

    func testFilterWithEmptyQueryReturnsEverything() {
        let records = [record("un"), record("deux"), record("trois")]

        XCTAssertEqual(TranscriptionSearch.filter(records, query: "").map(\.id), records.map(\.id),
                       "Clearing the field restores the whole list, in order.")
    }

    func testFilterWithNoMatchIsEmpty() {
        let records = [record("un"), record("deux")]

        XCTAssertTrue(TranscriptionSearch.filter(records, query: "zzz").isEmpty)
    }
}
