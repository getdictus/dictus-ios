// DictusCore/Tests/DictusCoreTests/GermanCapitalsTests.swift
//
// German's capitals table (`de.capitals`, #948) on the model and table the keyboard ships.
import XCTest
@testable import DictusCore

final class GermanCapitalsTests: XCTestCase {
    private static func resource(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(name)").path
    }

    private func capitals() throws -> GermanCapitals {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.resource("de.hextm")), "no de.hextm")
        return try XCTUnwrap(GermanCapitals(path: Self.resource("de.capitals"), model: model), "no de.capitals")
    }

    /// Nouns take their capital wherever they stand; verbs, adjectives and function words
    /// stay lowercase.
    func testNounsTakeTheirCapitalAndOtherWordsDoNot() throws {
        let table = try capitals()
        for (word, written) in [("haus", "Haus"), ("straße", "Straße"), ("zeit", "Zeit"), ("mädchen", "Mädchen"),
                                ("krankenversicherung", "Krankenversicherung"), ("übung", "Übung")] {
            XCTAssertEqual(table.written(word, after: nil), written)
            XCTAssertEqual(table.written(word, after: "ich"), written, "after a non-determiner too")
        }
        for word in ["gehen", "groß", "schön", "weiß", "und", "nicht", "ich", "sie", "über", "für"] {
            XCTAssertEqual(table.written(word, after: nil), word)
            XCTAssertEqual(table.written(word, after: "das"), word, "not even after an article")
        }
    }

    /// A word that is a noun and a verb ("Leben"/"leben", "Frage"/"frage") is a noun after
    /// an article or a determiner only.
    func testANounThatIsAlsoAVerbNeedsADeterminer() throws {
        let table = try capitals()
        XCTAssertEqual(table.written("leben", after: "das"), "Leben")
        XCTAssertEqual(table.written("leben", after: "zu"), "leben")
        XCTAssertEqual(table.written("frage", after: "eine"), "Frage")
        XCTAssertEqual(table.written("frage", after: "ich"), "frage")
        XCTAssertEqual(table.written("essen", after: "beim"), "Essen")
        XCTAssertEqual(table.written("essen", after: nil), "essen")
    }

    /// What the bridge does with a swipe's readings: the word before is read from the text,
    /// lowercase, as the decoder reads it.
    func testReadingsAreWrittenAfterTheTextBefore() throws {
        let table = try capitals()
        XCTAssertEqual(table.written(["haus", "hass", "gehen"], before: "Ich sehe das "), ["Haus", "Hass", "gehen"])
        XCTAssertEqual(table.written(["leben"], before: "Das "), ["Leben"])
        XCTAssertEqual(table.written(["leben"], before: "Wir wollen "), ["leben"])
    }

    /// The table is German's: the bridge reads none for another language, and a word the
    /// model lacks is left as it is.
    func testAWordTheTableLacksIsLeftAsItIs() throws {
        let table = try capitals()
        XCTAssertNil(table.percent(of: "gehen"))
        XCTAssertEqual(table.written("xyzzy", after: nil), "xyzzy")
        XCTAssertEqual(table.written("Haus", after: nil), "Haus")
    }
}
