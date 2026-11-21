// DictusCore/Tests/DictusCoreTests/AccentRestorationTests.swift
// Accent restoration on the corpus counts the keyboard's dictionaries were built from (#994).
import XCTest
@testable import DictusCore

/// Every count is copied from `DictusKeyboard/Resources/<lang>_frequency.json`, and every
/// test goes through `LogNormalizedFrequencyProvider`, so the rule sees the trie's own
/// scale: a test on raw counts would pass on a rule that compares stored values.
final class AccentRestorationTests: XCTestCase {

    private let french = LogNormalizedFrequencyProvider(rawFrequencies: [
        "arrive": 41_680, "arriv\u{00E9}": 17_151,
        "trouve": 24_824, "trouv\u{00E9}": 27_822,
        "couches": 938, "couch\u{00E9}s": 458,
        "oublie": 8_374, "oubli\u{00E9}": 13_194,
        "d\u{00E9}charge": 873, "d\u{00E9}charg\u{00E9}": 164,
        "r\u{00E9}serve": 2_182, "r\u{00E9}serv\u{00E9}": 1_372,
        "publie": 200, "publi\u{00E9}": 723,
        "calme": 8_916, "calm\u{00E9}": 418,
        "tr\u{00E8}s": 144_918,
    ], maxFrequency: 2_933_327)

    private let spanish = LogNormalizedFrequencyProvider(rawFrequencies: [
        "manana": 1_031, "ma\u{00F1}ana": 283_391,
        "numero": 5_609, "n\u{00FA}mero": 92_183,
        "estacion": 815, "estaci\u{00F3}n": 30_100,
        "esta": 1_051_900, "est\u{00E1}": 2_433_246, "\u{00E9}sta": 48_338,
        "llegue": 26_329, "llegu\u{00E9}": 19_194,
        "si": 2_348_665, "s\u{00ED}": 2_350_514,
        "tu": 1_618_746, "t\u{00FA}": 906_053,
    ], maxFrequency: 14_459_520)

    private func french(_ word: String, after previous: String? = nil) -> AccentRestoration.Decision {
        restoreAccents(profile: frenchProfile, word: word, previousWord: previous, provider: french)
    }

    private func spanish(_ word: String, after previous: String? = nil) -> AccentRestoration.Decision {
        restoreAccents(profile: spanishProfile, word: word, previousWord: previous, provider: spanish)
    }

    // MARK: - A participle after an auxiliary

    func testAParticipleAfterAnAuxiliaryGetsItsAccent() {
        XCTAssertEqual(french("arrive", after: "est"), .restore("arriv\u{00E9}"), "le train est arrivé")
        XCTAssertEqual(french("trouve", after: "a"), .restore("trouv\u{00E9}"), "elle a trouvé")
        XCTAssertEqual(french("oublie", after: "as"), .restore("oubli\u{00E9}"), "tu as oublié")
        XCTAssertEqual(french("reserve", after: "avons"), .restore("r\u{00E9}serv\u{00E9}"), "nous avons réservé")
        XCTAssertEqual(french("trouve", after: "j'ai"), .restore("trouv\u{00E9}"), "j'ai trouvé")
    }

    func testAnAdverbBetweenTheAuxiliaryAndTheParticipleStillCallsForIt() {
        XCTAssertEqual(french("couches", after: "d\u{00E9}j\u{00E0}"), .restore("couch\u{00E9}s"), "sont déjà couchés")
        XCTAssertEqual(french("couches", after: "deja"), .restore("couch\u{00E9}s"), "the adverb typed without its accent")
        XCTAssertEqual(french("decharge", after: "presque"), .restore("d\u{00E9}charg\u{00E9}"), "était presque déchargé")
    }

    // MARK: - Counter-cases: the typed word stays

    func testAConjugatedVerbAfterItsSubjectStays() {
        XCTAssertEqual(french("arrive", after: "il"), .keepTyped, "il arrive")
        XCTAssertEqual(french("trouve", after: "je"), .keepTyped, "je trouve")
        XCTAssertEqual(french("oublie", after: "j'"), .keepTyped, "j'oublie")
        XCTAssertEqual(french("arrive"), .keepTyped, "no previous word")
    }

    func testWordsThatAreNotAuxiliariesDoNotCallForAParticiple() {
        XCTAssertEqual(french("arrive", after: "tout"), .keepTyped, "tout arrive: `tout` is also a pronoun")
        XCTAssertEqual(french("arrive", after: "l'\u{00E9}t\u{00E9}"), .keepTyped, "l'été arrive: `été` is also the noun")
    }

    func testAnAdjectiveAfterAnAuxiliaryStaysWhenItsParticipleIsRare() {
        XCTAssertEqual(french("calme", after: "est"), .keepTyped, "il est calme: `calmé` is 0.05x `calme`")
    }

    func testABareWordStaysUnlessTheAccentedOneIsTenTimesAsFrequent() {
        XCTAssertEqual(french("publie"), .keepTyped, "je publie: `publié` is 3.6x")
        XCTAssertEqual(spanish("esta"), .keepTyped, "esta noche: `está` is 2.3x")
        XCTAssertEqual(spanish("llegue"), .keepTyped, "puede que llegue: `llegué` is 0.7x")
        XCTAssertEqual(spanish("si"), .keepTyped, "si hace buen tiempo")
        XCTAssertEqual(spanish("tu"), .keepTyped, "tu nombre")
    }

    // MARK: - Without context, the counts decide

    func testAMuchMoreFrequentAccentedSpellingReplacesARareBareWord() {
        XCTAssertEqual(spanish("manana"), .restore("ma\u{00F1}ana"), "275x")
        XCTAssertEqual(spanish("numero"), .restore("n\u{00FA}mero"), "16x")
        XCTAssertEqual(spanish("estacion"), .restore("estaci\u{00F3}n"), "37x")
    }

    func testAWordTheDictionaryLacksTakesItsOnlyAccentedSpelling() {
        XCTAssertEqual(french("tres"), .restore("tr\u{00E8}s"))
    }

    // MARK: - Two accented spellings

    func testTwoEquallyLikelyAccentedSpellingsAreOfferedNotWritten() {
        XCTAssertEqual(french("reserve"), .ambiguous(["r\u{00E9}serve", "r\u{00E9}serv\u{00E9}"]),
                       "nous avons reserve with no context: 1.6x apart")
    }

    func testAClearlyMoreFrequentAccentedSpellingIsWritten() {
        XCTAssertEqual(french("decharge"), .restore("d\u{00E9}charge"), "la décharge: 5.3x")
    }

    // MARK: - The rule itself

    func testTheTypedWordWinsAnythingUnderTenTimesItsCount() {
        let typed = AccentRestoration.Spelling(word: "abc", count: 100)
        XCTAssertEqual(AccentRestoration.decide(typed: typed, accented: [.init(word: "\u{00E1}bc", count: 999)]),
                       .keepTyped)
        XCTAssertEqual(AccentRestoration.decide(typed: typed, accented: [.init(word: "\u{00E1}bc", count: 1_000)]),
                       .restore("\u{00E1}bc"))
    }

    func testTiesAreBrokenByTheWordSoTheOutcomeNeverDependsOnOrder() {
        let spellings: [AccentRestoration.Spelling] = [.init(word: "b\u{00E9}", count: 0), .init(word: "b\u{00E8}", count: 0)]
        XCTAssertEqual(AccentRestoration.decide(typed: nil, accented: spellings),
                       AccentRestoration.decide(typed: nil, accented: spellings.reversed()))
    }

    func testNoAccentedSpellingKeepsTheTypedWord() {
        XCTAssertEqual(AccentRestoration.decide(typed: nil, accented: []), .keepTyped)
    }
}
