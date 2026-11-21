// DictusCore/Tests/DictusCoreTests/BilingualCheckTests.swift
// The bilingual check (#1015): keep rule, Hex's partner fallback and lean, the guard.
import XCTest
@testable import DictusCore

private let french = ShippedDictionaries.french
private let english = ShippedDictionaries.english

/// What each language's engine proposes for a word, as tables, and what was asked of it.
private final class Engines {
    var ownFixes: [String: String] = [:]
    var theirFixes: [String: String] = [:]
    private(set) var otherWasAsked = false
    private(set) var ownSawOtherKnows: Bool?

    func decide(_ word: String, before: String = "", active: StubEvidence = french,
                other: StubEvidence? = english) -> BilingualCheck.Decision {
        BilingualCheck.decide(
            word, before: before, active: active, other: other,
            own: { knows in
                self.ownSawOtherKnows = knows
                return self.ownFixes[word].map { .autocorrect($0, alternatives: []) }
            },
            theirs: {
                self.otherWasAsked = true
                return self.theirFixes[word].map { .autocorrect($0, alternatives: []) }
            }
        )
    }
}

final class BilingualCheckTests: XCTestCase {

    func testAWordTheOtherLanguageLikesBetterStaysAsTyped() {
        let engines = Engines()
        engines.ownFixes = ["call": "camp"]
        let decision = engines.decide("call")
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptForOther)
    }

    /// Where Hex's rule ("the other language knows it, so it stays") loses the accents.
    func testAnAccentTheActiveLanguagePutsBackIsKept() {
        let engines = Engines()
        engines.ownFixes = ["telephone": "téléphone"]
        engines.theirFixes = [:]
        let decision = engines.decide("telephone")
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "téléphone")
        XCTAssertEqual(decision.rule, .active)
    }

    func testATypoOnlyTheOtherLanguageFixesGetsItsFix() {
        let engines = Engines()
        engines.theirFixes = ["teh": "the"]
        let decision = engines.decide("teh")
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "the")
        XCTAssertEqual(decision.rule, .otherFixes)
    }

    func testAWordTheActiveLanguageHasIsNeverSentToTheOther() {
        let engines = Engines()
        engines.theirFixes = ["matin": "latin"]
        let decision = engines.decide("matin")
        XCTAssertNil(decision.proposal)
        XCTAssertFalse(engines.otherWasAsked)
    }

    func testAWordOnlyTheOtherLanguageHasIsLeftAlone() {
        let engines = Engines()
        engines.theirFixes = ["meeting": "meetings"]
        let decision = engines.decide("meeting", active: english, other: french)
        XCTAssertNil(decision.proposal)
        XCTAssertFalse(engines.otherWasAsked)
    }

    func testTheActiveEngineHearsThatTheOtherLanguageKnowsTheWord() {
        let engines = Engines()
        _ = engines.decide("call")
        XCTAssertEqual(engines.ownSawOtherKnows, true)
        _ = engines.decide("qzxjvkq")
        XCTAssertEqual(engines.ownSawOtherKnows, false)
    }

    func testOneLetterWordsStayTheActiveLanguages() {
        let engines = Engines()
        engines.theirFixes = ["z": "a"]
        XCTAssertNil(engines.decide("z").proposal)
        XCTAssertFalse(engines.otherWasAsked)
    }

    // MARK: Both languages fix the typo

    func testTheWordsBeforeChooseTheOtherLanguagesFix() {
        let engines = Engines()
        engines.ownFixes = ["jusge": "juste"]
        engines.theirFixes = ["jusge": "judge"]
        let decision = engines.decide("jusge", before: "see you tomorrow jusge")
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "judge")
        XCTAssertEqual(decision.rule, .otherByLean)
    }

    func testWithoutALeanTheActiveLanguageKeepsItsFix() {
        let engines = Engines()
        engines.ownFixes = ["jusge": "juste"]
        engines.theirFixes = ["jusge": "judge"]
        // "table" and "client" are words of both: no lean.
        let decision = engines.decide("jusge", before: "table client ")
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "juste")
        XCTAssertEqual(decision.rule, .active)
        // The partner's correction costs a second engine: not asked without a lean to it.
        XCTAssertFalse(engines.otherWasAsked)
    }

    func testFrenchWordsBeforeKeepTheFrenchFix() {
        let engines = Engines()
        engines.ownFixes = ["jusge": "juste"]
        engines.theirFixes = ["jusge": "judge"]
        XCTAssertEqual(engines.decide("jusge", before: "demain matin ").proposal?.autocorrection?.correction, "juste")
    }

    func testTheSameFixInBothLanguagesIsTheActiveOnes() {
        let engines = Engines()
        engines.ownFixes = ["Cmap": "camp"]
        engines.theirFixes = ["Cmap": "CAMP"]
        XCTAssertEqual(engines.decide("Cmap", before: "see you tomorrow ").rule, .active)
    }

    // MARK: Without a partner

    func testWithoutAPartnerTheActiveLanguageDecidesAlone() {
        let engines = Engines()
        engines.ownFixes = ["call": "camp"]
        let decision = engines.decide("call", other: nil)
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "camp")
        XCTAssertEqual(decision.rule, .alone)
        XCTAssertEqual(engines.ownSawOtherKnows, false)
    }

    func testADictionaryThatTakesAnyLettersIsNoPartner() {
        XCTAssertTrue(BilingualCheck.isWorking(english))
        var broken = english
        broken.words["qzxjvkq"] = -12
        XCTAssertFalse(BilingualCheck.isWorking(broken))
    }

    // MARK: Knowing a word

    func testAnElisionOfTheLanguageIsKnownWithItsWord() {
        XCTAssertTrue(BilingualCheck.knows("C'est", in: french))
        XCTAssertFalse(BilingualCheck.knows("c'est", in: english))
        XCTAssertFalse(BilingualCheck.knows("j'zz", in: french))
    }
}

final class LanguageLeanTests: XCTestCase {

    func testWordsOnlyTheOtherLanguageKnowsLeanToIt() {
        XCTAssertEqual(LanguageLean.lean(before: "see you tomorrow ", word: "x", active: french, other: english), 3)
        XCTAssertEqual(LanguageLean.lean(before: "demain matin ", word: "x", active: french, other: english), -2)
    }

    func testOnlyTheLastFourWordsCount() {
        let before = "demain matin demain matin sounds good see you "
        XCTAssertEqual(LanguageLean.lean(before: before, word: "x", active: french, other: english), 4)
    }

    func testTheWordBeingDecidedIsLeftOut() {
        XCTAssertEqual(LanguageLean.lean(before: "see tomorrow", word: "tomorrow", active: french, other: english), 1)
    }

    func testWordsBothOrNeitherKnowAndOneLetterWordsCountForNothing() {
        XCTAssertEqual(LanguageLean.lean(before: "table client zzkq a ", word: "x", active: french, other: english), 0)
    }
}

final class BilingualCheckAccentTests: XCTestCase {

    /// `avons reserve`: French puts the participle's accents back from the previous word;
    /// English `reserve` is likelier than French `réservé`, but not by the accent margin.
    func testAnAccentOnlyFixNeedsTheMarginToBeUndone() {
        var french = ShippedDictionaries.french
        french.words["réservé"] = -7.67
        var english = ShippedDictionaries.english
        english.words["reserve"] = -6.48
        let decision = BilingualCheck.decide(
            "reserve", before: "nous avons ", active: french, other: english,
            own: { _ in .autocorrect("réservé", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "réservé")
    }

    func testAWordFarLikelierInTheOtherLanguageBeatsTheAccents() {
        let decision = BilingualCheck.decide(
            "the", before: "", active: ShippedDictionaries.french, other: ShippedDictionaries.english,
            own: { _ in .autocorrect("thé", alternatives: []) }, theirs: { nil }
        )
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptForOther)
    }

    /// French offers `déclare` for `decalee` without writing it: English `declare` is the
    /// same word, accents aside, and must not be written either.
    func testThePartnerDoesNotWriteWhatTheActiveLanguageFoundTooUnsure() {
        let decision = BilingualCheck.decide(
            "decalee", before: "", active: ShippedDictionaries.french, other: ShippedDictionaries.english,
            own: { _ in .suggest(["déclare", "décale"]) }, theirs: { .autocorrect("declare", alternatives: []) }
        )
        XCTAssertEqual(decision.proposal, .suggest(["déclare", "décale"]))
        XCTAssertEqual(decision.rule, .active)
    }
}

final class BilingualCheckKnownWordTests: XCTestCase {

    /// English has `je`, rarely: the English window must not turn it into `Be`.
    func testAWordBothKnowButTheOtherFarBetterStays() {
        var english = ShippedDictionaries.english
        english.words["be"] = -3.0
        let decision = BilingualCheck.decide(
            "Je", before: "", active: english, other: ShippedDictionaries.french,
            own: { _ in .autocorrect("Be", alternatives: []) }, theirs: { nil }
        )
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptForOther)
    }

    /// `on` is common in both: the active language's fix stands when it likes it better.
    func testAWordBothKnowAsWellIsTheActiveLanguages() {
        let decision = BilingualCheck.decide(
            "on", before: "", active: ShippedDictionaries.english, other: ShippedDictionaries.french,
            own: { _ in .autocorrect("in", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "in")
    }
}

final class BilingualCheckOtherWordTests: XCTestCase {

    private func afraid(before: String) -> BilingualCheck.Decision {
        var english = ShippedDictionaries.english
        english.words["afraid"] = -7.66
        english.words["im"] = -6.43
        var french = ShippedDictionaries.french
        french.words["aurais"] = -4.52
        return BilingualCheck.decide(
            "afraid", before: before, active: french, other: english,
            own: { _ in .autocorrect("aurais", alternatives: []) }, theirs: { nil }
        )
    }

    /// Pierre's device session: a French window after a misread `Im` changed English
    /// `afraid` into common French `aurais`. After an English word, a word of English stays
    /// whatever the frequencies (Hex).
    func testAWordOfTheOtherLanguageAfterWordsOfItStays() {
        let decision = afraid(before: "Im ")
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptOtherWord)
    }

    /// Without words before, the frequencies decide: French `aurais` is likelier.
    func testWithoutWordsBeforeTheFrequenciesDecide() {
        XCTAssertEqual(afraid(before: "").proposal?.autocorrection?.correction, "aurais")
    }

    /// A typo that is a rare word of the other language, inside a sentence of the active
    /// one, is fixed: `boue` for `hour`, which Hex's rule kept.
    func testATypoThatIsARareWordOfTheOtherLanguageIsFixedInContext() {
        var french = ShippedDictionaries.french
        french.words["boue"] = -9.10
        var english = ShippedDictionaries.english
        english.words["hour"] = -6.20
        let decision = BilingualCheck.decide(
            "boue", before: "see you in an ", active: english, other: french,
            own: { _ in .autocorrect("hour", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "hour")
    }

    /// Hex's exception: after English words, English fixes French `le` ("fine for me").
    func testATwoLetterWordIsFixedWhenTheWordsBeforeLeanTheActiveLanguage() {
        let decision = BilingualCheck.decide(
            "le", before: "sounds good see you ", active: ShippedDictionaries.english, other: ShippedDictionaries.french,
            own: { _ in .autocorrect("me", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "me")
    }

    func testATwoLetterWordStaysWithoutEnglishWordsBefore() {
        var english = ShippedDictionaries.english
        english.words["me"] = -2.90
        let decision = BilingualCheck.decide(
            "le", before: "", active: english, other: ShippedDictionaries.french,
            own: { _ in .autocorrect("me", alternatives: []) }, theirs: { nil }
        )
        XCTAssertNil(decision.proposal)
    }

    /// An apostrophe makes another word: `s'hé` is no accent of `she`.
    func testAnElisionIsNotAnAccent() {
        var english = ShippedDictionaries.english
        english.words["she"] = -4.22
        let decision = BilingualCheck.decide(
            "she", before: "see you ", active: ShippedDictionaries.french, other: english,
            own: { _ in .autocorrect("s'hé", alternatives: []) }, theirs: { nil }
        )
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptOtherWord)
    }

    /// The English trie holds French words from books: a French correction of `fait`,
    /// which French has far more often, is French's to make.
    func testAWordTheActiveLanguageHasMoreIsTheActiveLanguages() {
        let decision = BilingualCheck.decide(
            "fait", before: "", active: ShippedDictionaries.french, other: ShippedDictionaries.english,
            own: { _ in .autocorrect("faut", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "faut")
    }
}

final class BilingualCheckOwnSpellingsTests: XCTestCase {

    /// `j'ai rate`: French has `rate` and `raté` and chose `raté`; English `rate`, common,
    /// does not overrule a choice between two French spellings.
    func testAnAccentChoiceBetweenTwoWordsOfTheActiveLanguageStands() {
        var french = ShippedDictionaries.french
        french.words["rate"] = -8.38
        french.words["raté"] = -7.02
        var english = ShippedDictionaries.english
        english.words["rate"] = -4.71
        let decision = BilingualCheck.decide(
            "rate", before: "j'ai ", active: french, other: english,
            own: { _ in .autocorrect("raté", alternatives: []) }, theirs: { nil }
        )
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "raté")
    }
}
