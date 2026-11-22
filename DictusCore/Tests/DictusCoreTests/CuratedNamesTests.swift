// DictusCore/Tests/DictusCoreTests/CuratedNamesTests.swift
// App and brand names: "Dictus" is never corrected to "Rictus", and a curated
// casing wins over a contact's ("iphone" became "Iphone" on device).

import XCTest
@testable import DictusCore

final class CuratedNamesTests: XCTestCase {

    func testDictusIsNeverCorrected() {
        XCTAssertEqual(CuratedNames.decision(for: "Dictus"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "DICTUS"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "dictus"), .replace(with: "Dictus"))
    }

    func testLowercaseAndAutocapitalizedFormsTakeTheBrandCasing() {
        XCTAssertEqual(CuratedNames.decision(for: "iphone"), .replace(with: "iPhone"))
        XCTAssertEqual(CuratedNames.decision(for: "Iphone"), .replace(with: "iPhone"))
        XCTAssertEqual(CuratedNames.decision(for: "whatsapp"), .replace(with: "WhatsApp"))
        XCTAssertEqual(CuratedNames.decision(for: "Whatsapp"), .replace(with: "WhatsApp"))
        XCTAssertEqual(CuratedNames.decision(for: "gmail"), .replace(with: "Gmail"))
    }

    func testBrandCasingAndAllCapsAreKeptAsTyped() {
        XCTAssertEqual(CuratedNames.decision(for: "iPhone"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "WhatsApp"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "IPHONE"), .keep)
    }

    /// "a telegram", "discord between them": the name is protected, the word is not recased.
    func testNamesThatAreAlsoWordsAreKeptAsTyped() {
        for word in ["Discord", "discord", "Telegram", "telegram"] {
            XCTAssertEqual(CuratedNames.decision(for: word), .keep, word)
        }
    }

    func testOtherWordsAreLeftToThePipeline() {
        XCTAssertNil(CuratedNames.decision(for: "rictus"))
        XCTAssertNil(CuratedNames.decision(for: "phone"))
        XCTAssertNil(CuratedNames.decision(for: "dictu"))
    }

    func testEveryNameHasOneKeyAndOneList() {
        let recasedKeys = CuratedNames.recased.map { $0.lowercased() }
        let keptKeys = CuratedNames.keptAsTyped.map { $0.lowercased() }
        XCTAssertEqual(Set(recasedKeys).count, recasedKeys.count)
        XCTAssertTrue(Set(recasedKeys).isDisjoint(with: keptKeys))
        XCTAssertTrue(recasedKeys.allSatisfy { !$0.contains(" ") })
    }

    // MARK: - Through the lexicon

    func testCuratedCasingWinsOverAContact() {
        let lexicon = SupplementaryLexicon(entries: [(userInput: "Iphone", documentText: "Iphone")])
        XCTAssertEqual(lexicon.decision(for: "iphone", isDictionaryWord: false), .replace(with: "iPhone"))
        XCTAssertEqual(lexicon.decision(for: "iphone", isDictionaryWord: true), .replace(with: "iPhone"))
    }

    func testEmptyLexiconStillProtectsCuratedNames() {
        XCTAssertEqual(SupplementaryLexicon.empty.decision(for: "Dictus", isDictionaryWord: false), .keep)
    }

    /// The user's own text replacement outranks the shipped list, as on Apple's keyboard.
    func testTextReplacementWinsOverACuratedName() {
        let lexicon = SupplementaryLexicon(entries: [(userInput: "dictus", documentText: "Dictus, le clavier")])
        XCTAssertEqual(
            lexicon.decision(for: "dictus", isDictionaryWord: false),
            .replace(with: "Dictus, le clavier")
        )
    }
}
