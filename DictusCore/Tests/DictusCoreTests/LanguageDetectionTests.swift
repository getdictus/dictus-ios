// DictusCore/Tests/DictusCoreTests/LanguageDetectionTests.swift
// The bilingual keyboard's language detection (#1009): pair, scale, vote, window, keep rule.
import XCTest
@testable import DictusCore

private let french = ShippedDictionaries.french
private let english = ShippedDictionaries.english
// swiftlint:disable:next force_unwrapping
private let frenchFirst = KeyboardLanguagePair(primary: .french, secondary: .english)!

private func vote(_ word: String, after previous: String? = nil) -> Double {
    WordLanguageVote.vote(for: word, after: previous, primary: french, secondary: english)
}

/// Types `message` word by word into `window` and returns the language each word was decided in.
private func type(_ message: String, into window: inout LanguageWindow) -> [SupportedLanguage] {
    var previous: String?
    return message.components(separatedBy: " ").map { word in
        window.push(vote(word, after: previous))
        previous = word
        return window.language
    }
}

final class KeyboardLanguagePairTests: XCTestCase {

    func testFrenchAndEnglishPairInEitherOrder() {
        XCTAssertEqual(KeyboardLanguagePair(primary: .french, secondary: .english)?.secondary, .english)
        XCTAssertEqual(KeyboardLanguagePair(primary: .english, secondary: .french)?.secondary, .french)
    }

    func testNoSecondLanguageOrTheSameOneIsMonolingual() {
        XCTAssertNil(KeyboardLanguagePair(primary: .french, secondary: nil))
        XCTAssertNil(KeyboardLanguagePair(primary: .french, secondary: .french))
    }

    func testAPairNobodyMeasuredIsNotOffered() {
        XCTAssertNil(KeyboardLanguagePair(primary: .french, secondary: .spanish))
        XCTAssertEqual(KeyboardLanguagePair.secondaries(for: .german), [])
    }

    func testOtherLanguage() {
        XCTAssertEqual(frenchFirst.other(than: .french), .english)
        XCTAssertEqual(frenchFirst.other(than: .english), .french)
    }
}

final class TrieFrequencyScaleTests: XCTestCase {

    func testTheTopWordReadsZeroAndTheBottomMinusTheLogOfTheTopCount() {
        let scale = TrieFrequencyScale(topCount: 2_900_000)
        XCTAssertEqual(scale.logFrequency(stored: 65535), 0, accuracy: 1e-9)
        XCTAssertEqual(scale.logFrequency(stored: 0), -log(2_900_001), accuracy: 1e-9)
    }

    /// The same stored height is a rarer word in the bigger corpus: compared raw, the
    /// English Google Books counts made `projet` and `client` look English.
    func testTheSameStoredFrequencyIsRarerInTheBiggerCorpus() {
        let subtitles = TrieFrequencyScale(topCount: 2_900_000)
        let books = TrieFrequencyScale(topCount: 23_000_000_000)
        XCTAssertGreaterThan(subtitles.logFrequency(stored: 45000), books.logFrequency(stored: 45000))
    }
}

final class WordLanguageVoteTests: XCTestCase {

    func testAWordOnlyOneLanguageHasVotesItAtTheClip() {
        XCTAssertEqual(vote("oui"), 4)
        XCTAssertEqual(vote("tomorrow"), -4)
    }

    func testAWordBothLanguagesHaveVotesNearZero() {
        XCTAssertEqual(vote("table"), -0.15, accuracy: 0.01)
        XCTAssertEqual(vote("on"), 0.45, accuracy: 0.01)
    }

    func testFrenchWordsVoteFrenchOnTheSharedScale() {
        XCTAssertGreaterThan(vote("projet"), 3)
        XCTAssertEqual(vote("client"), -0.64, accuracy: 0.01)
    }

    /// Pierre's French typos from 2026-11-20, which the English keyboard turned into
    /// `Oki` and `judge`: each language reaches its own correction, and French's is the
    /// more likely word.
    func testATypoVotesForTheLanguageWhoseCorrectionIsMoreLikely() {
        XCTAssertEqual(vote("Oji"), 4)
        XCTAssertEqual(vote("jusge"), 2.55, accuracy: 0.01)
    }

    func testAWordReachedOnlyByCorrectionCountsBelowItsCorrection() {
        XCTAssertEqual(WordLanguageVote.evidence(for: "jusge", after: nil, in: french), -4.07 - 3, accuracy: 1e-9)
    }

    func testAWordALanguageCannotReachScoresTheFloor() {
        XCTAssertEqual(WordLanguageVote.evidence(for: "tomorrow", after: nil, in: french), -16)
    }

    func testAnElisionCountsForTheLanguageThatHasIt() {
        let bare = WordLanguageVote.evidence(for: "est", after: nil, in: french)
        XCTAssertEqual(WordLanguageVote.evidence(for: "c'est", after: nil, in: french), bare + 3, accuracy: 1e-9)
        XCTAssertEqual(WordLanguageVote.evidence(for: "c'est", after: nil, in: english),
                       WordLanguageVote.evidence(for: "est", after: nil, in: english))
    }

    func testAContractionTheLanguageExpandsCountsAsAnElision() {
        XCTAssertEqual(WordLanguageVote.evidence(for: "cest", after: nil, in: french), -0.64 + 3, accuracy: 1e-9)
    }

    func testTheBigramAfterThePreviousWordAddsUpToTwo() {
        let alone = WordLanguageVote.evidence(for: "soir", after: nil, in: french)
        XCTAssertEqual(WordLanguageVote.evidence(for: "soir", after: "ce", in: french), alone + 2 * 0.76, accuracy: 1e-9)
    }
}

final class LanguageWindowTests: XCTestCase {

    func testANewWindowIsInThePrimaryLanguage() {
        XCTAssertEqual(LanguageWindow(pair: frenchFirst).language, .french)
        // swiftlint:disable:next force_unwrapping
        XCTAssertEqual(LanguageWindow(pair: KeyboardLanguagePair(primary: .english, secondary: .french)!).language, .english)
    }

    func testOneClearlySecondaryWordDoesNotFlipTheWindowAndTwoDo() {
        var window = LanguageWindow(pair: frenchFirst)
        window.push(-4)
        XCTAssertEqual(window.language, .french)
        window.push(-4)
        XCTAssertEqual(window.language, .english)
    }

    func testTheWindowComesBackOnlyPastTheThresholdTowardThePrimary() {
        var window = LanguageWindow(pair: frenchFirst)
        window.push(-4)
        window.push(-4)
        window.push(4)
        XCTAssertEqual(window.language, .english)
        window.push(4)
        XCTAssertEqual(window.language, .french)
    }

    func testEnglishInsertsDoNotFlipAFrenchSentence() {
        for sentence in ["c'est trop cool", "on se fait un call demain matin", "le meeting est décalé"] {
            var window = LanguageWindow(pair: frenchFirst)
            XCTAssertEqual(Set(type(sentence, into: &window)), [.french], sentence)
        }
    }

    /// The study's mixed run, sentences 11 and 12: the first two English words are still
    /// decided French (`good` is one of the run's wrong words), the third is English.
    func testAnEnglishMessageAfterAFrenchOneFlipsByItsThirdWord() {
        var window = LanguageWindow(pair: frenchFirst)
        XCTAssertEqual(Set(type("oui je regarde ça ce soir", into: &window)), [.french])
        XCTAssertEqual(type("sounds good see you tomorrow", into: &window),
                       [.french, .french, .english, .english, .english])
    }
}

final class BilingualKeepRuleTests: XCTestCase {

    func testACommonEnglishWordKeepsOverAFrenchCorrection() {
        XCTAssertTrue(BilingualKeepRule.keepsTyped("call", over: "camp", active: french, other: english))
        XCTAssertTrue(BilingualKeepRule.keepsTyped("The", over: "Thé", active: french, other: english))
    }

    func testAnEnglishWordRarerThanTheFrenchCorrectionIsCorrected() {
        XCTAssertFalse(BilingualKeepRule.keepsTyped("telephone", over: "téléphone", active: french, other: english))
    }

    func testAWordTheActiveLanguageHasIsNotTheRulesToKeep() {
        XCTAssertFalse(BilingualKeepRule.keepsTyped("table", over: "tablé", active: french, other: english))
    }

    func testAWordNeitherLanguageHasIsCorrected() {
        XCTAssertFalse(BilingualKeepRule.keepsTyped("forard", over: "forage", active: french, other: english))
    }
}
