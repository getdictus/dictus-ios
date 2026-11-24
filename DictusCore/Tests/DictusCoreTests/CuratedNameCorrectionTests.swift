// DictusCore/Tests/DictusCoreTests/CuratedNameCorrectionTests.swift
// A close typo of a curated name is corrected to it (`iphon` -> "iPhone"), and a
// common word, typed right or mistyped towards another word, never is.

import XCTest
@testable import DictusCore

final class CuratedNameCorrectionTests: XCTestCase {

    /// The neighbours the shipped dictionaries hold around the reported cases, and a
    /// few common words. Neither holds `iphone`; English holds no `whatsapp` or
    /// `youtube` either (2026-11-25).
    private let french: Set<String> = [
        "siphon", "foutu", "foutue", "coutume", "couture", "clou", "clous", "dites", "dicte", "dicté",
        "chat", "chats", "mai", "gai", "spot", "sportif", "phono", "whatsapp", "youtube", "le", "une",
    ]
    private let english: Set<String> = [
        "upon", "youth", "whats", "phone", "chat", "spot", "spots", "airport", "couture", "snapshot",
        "factbook", "cloud", "loud", "linked", "macro", "netflix", "gmail", "the", "and",
    ]

    private func target(_ typed: String, _ dictionary: Set<String>) -> String? {
        CuratedNameCorrection.target(for: typed, dictionaryKnows: dictionary.contains)
    }

    func testTheReportedTyposGiveTheNameInFrenchAndEnglish() {
        for dictionary in [french, english] {
            XCTAssertEqual(target("whatsap", dictionary), "WhatsApp")
            XCTAssertEqual(target("iphon", dictionary), "iPhone")
            XCTAssertEqual(target("youtub", dictionary), "YouTube")
        }
    }

    /// The case typed is ignored: the name's casing wins, as for a typed `Iphone`.
    func testASentenceStartCapitalGivesTheNamesCasing() {
        for dictionary in [french, english] {
            XCTAssertEqual(target("Whatsap", dictionary), "WhatsApp")
            XCTAssertEqual(target("Iphon", dictionary), "iPhone")
            XCTAssertEqual(target("Youtub", dictionary), "YouTube")
        }
    }

    func testACommonWordTypedRightIsNeverATarget() {
        for word in ["siphon", "foutu", "foutue", "coutume", "clous", "dites", "sportif", "whatsapp", "youtube"] {
            XCTAssertNil(target(word, french), word)
        }
        for word in ["upon", "youth", "whats", "phone", "airport", "couture", "snapshot", "linked", "netflix", "gmail"] {
            XCTAssertNil(target(word, english), word)
        }
    }

    /// Below five letters nothing is a target, a word or not: `gmai` is one letter
    /// from `mai` as much as from `gmail`.
    func testShortWordsAreNeverTargets() {
        for word in ["ipa", "ipad", "gmai", "you", "chat", "spot", "mac", "clou", "tikt", "dict"] {
            XCTAssertNil(target(word, english), word)
            XCTAssertNil(target(word, french), word)
        }
    }

    /// Two letters short is the dictionary's call: `youtu` is `youth` or `foutu`, `chatg`
    /// is `chat`, `whatsa` is `whats`.
    func testTwoLettersShortIsNoTarget() {
        for word in ["youtu", "chatg", "whatsa", "spoti", "macbo"] {
            XCTAssertNil(target(word, english), word)
            XCTAssertNil(target(word, french), word)
        }
    }

    func testAnotherOneEditTypoWinsOnlyWithNoDictionaryWordOneEditAway() {
        XCTAssertEqual(target("iphine", english), "iPhone")
        XCTAssertEqual(target("youtubr", french), "YouTube")
        XCTAssertEqual(target("facebool", english), "Facebook")
        // One edit from a common word as well: the trie decides.
        XCTAssertNil(target("youture", english), "couture")
        XCTAssertNil(target("youture", french), "couture")
        XCTAssertNil(target("snapchot", english), "snapshot")
        XCTAssertNil(target("facbook", english), "factbook")
        XCTAssertNil(target("airpors", english), "airport")
    }

    /// A curated name in the dictionary (`netflix` in English) does not block itself.
    func testANameInTheDictionaryDoesNotBlockItsOwnTypo() {
        XCTAssertEqual(target("netflux", english), "Netflix")
    }

    func testTheOneEditBranchNeedsTheFirstLetterAndALongName() {
        XCTAssertNil(target("uphone", english), "first letter")
        XCTAssertNil(target("ihone", english), "phone, and the first letter")
        XCTAssertNil(target("gmaol", english), "gmail is too short for one edit")
    }

    func testAPluralOrAnotherWordAfterTheNameIsNoTarget() {
        XCTAssertNil(target("iphones", english))
        XCTAssertNil(target("youtubes", french))
    }

    /// `discord` and `telegram` are words: their typos are the dictionary's.
    func testNamesThatAreAlsoWordsAreNeverTargets() {
        for word in ["discor", "discorf", "telegra", "telegran"] {
            XCTAssertNil(target(word, english), word)
            XCTAssertNil(target(word, french), word)
        }
    }

    func testOnlyLettersAreTargets() {
        XCTAssertNil(target("iphon3", english))
        XCTAssertNil(target("i-phon", english))
    }

    func testTheNeighbourSearchFindsEachKindOfEdit() {
        let known: (String) -> Bool = { ["phone", "siphon", "phono"].contains($0) }
        XCTAssertTrue(CuratedNameCorrection.hasDictionaryWordOneEditAway("iphone", dictionaryKnows: known), "deletion")
        XCTAssertTrue(CuratedNameCorrection.hasDictionaryWordOneEditAway("iphon", dictionaryKnows: known), "insertion")
        XCTAssertTrue(CuratedNameCorrection.hasDictionaryWordOneEditAway("phona", dictionaryKnows: known), "substitution")
        XCTAssertFalse(CuratedNameCorrection.hasDictionaryWordOneEditAway("iphine", dictionaryKnows: known))
    }
}
