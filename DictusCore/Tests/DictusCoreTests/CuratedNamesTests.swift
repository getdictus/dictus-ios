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

    /// A name written all lowercase keeps a sentence-start capital. No shipped name is
    /// written that way yet, so the rule is asked with its casing.
    func testANameWrittenLowercaseKeepsTheSentenceStartCapital() {
        XCTAssertEqual(CuratedNames.decision(for: "Gitlab", casing: "gitlab"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "gitlab", casing: "gitlab"), .keep)
        XCTAssertEqual(CuratedNames.decision(for: "Gitlab", casing: "GitLab"), .replace(with: "GitLab"))
    }

    // MARK: - After a correction (Titus, 2026-11-24)

    // The dictionary holds every word lowercase, so these are what the trie proposes
    // for the misspelling, capitalized at a sentence start as `AOSPTrieEngine.check` does.

    func testAMisspelledNameIsCorrectedToItsCasing() {
        XCTAssertEqual(CuratedNames.casing(of: "whatsapp"), "WhatsApp", "whatsap")
        XCTAssertEqual(CuratedNames.casing(of: "iphone"), "iPhone", "iphon")
        XCTAssertEqual(CuratedNames.casing(of: "youtube"), "YouTube", "youtub")
    }

    func testAMisspelledNameAtASentenceStartTakesItsCasing() {
        XCTAssertEqual(CuratedNames.casing(of: "Whatsapp"), "WhatsApp", "Whatsap")
        XCTAssertEqual(CuratedNames.casing(of: "Iphone"), "iPhone", "Iphon")
        XCTAssertEqual(CuratedNames.casing(of: "Youtube"), "YouTube", "Youtub")
    }

    func testACorrectionToAnOrdinaryWordIsUnchanged() {
        for correction in ["maison", "Maison", "phone", "the", "l'iphone", ""] {
            XCTAssertEqual(CuratedNames.casing(of: correction), correction, correction)
        }
    }

    func testACorrectionAlreadyInTheNamesCasingIsUnchanged() {
        for correction in ["WhatsApp", "iPhone", "YouTube", "WHATSAPP", "telegram", "Discord"] {
            XCTAssertEqual(CuratedNames.casing(of: correction), correction, correction)
        }
    }

    /// A split correction holds the name next to another word.
    func testEachWordOfASplitCorrectionIsRecased() {
        XCTAssertEqual(CuratedNames.casing(of: "the whatsapp"), "the WhatsApp")
        XCTAssertEqual(CuratedNames.casing(of: "mon iphone"), "mon iPhone")
    }

    func testTheProposalCarriesTheCasingToEveryWordTheBarShows() {
        XCTAssertEqual(
            CorrectionProposal.autocorrect("whatsapp", alternatives: ["whatsapps", "youtube"]).inCuratedCasing,
            .autocorrect("WhatsApp", alternatives: ["whatsapps", "YouTube"])
        )
        XCTAssertEqual(
            CorrectionProposal.suggest(["iphone", "phone"]).inCuratedCasing,
            .suggest(["iPhone", "phone"])
        )
        XCTAssertEqual(
            CorrectionProposal.autocorrect("maison", alternatives: []).inCuratedCasing,
            .autocorrect("maison", alternatives: [])
        )
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
