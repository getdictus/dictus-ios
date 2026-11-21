// DictusCore/Tests/DictusCoreTests/CorrectedWordAccentsTests.swift
// A trie correction goes through the accent pass with the previous word (#1006).
import XCTest
@testable import DictusCore

/// Counts from `DictusKeyboard/Resources/fr_frequency.json`, on the trie's log scale.
/// The proposals are what #997's trie pass gives for `zrrive` and `arribe` (device
/// follow-up of 2026-11-20).
final class CorrectedWordAccentsTests: XCTestCase {

    private let french = LogNormalizedFrequencyProvider(rawFrequencies: [
        "arrive": 41_680, "arriv\u{00E9}": 17_151,
        "trouve": 24_824, "trouv\u{00E9}": 27_822,
        "r\u{00E9}serve": 2_182, "r\u{00E9}serv\u{00E9}": 1_372,
    ], maxFrequency: 2_933_327)

    private let trieProposal = CorrectionProposal.autocorrect("arrive", alternatives: ["arriv\u{00E9}", "arriver"])

    private func restored(_ proposal: CorrectionProposal, after previous: String?) -> CorrectionProposal {
        CorrectedWordAccents.restored(proposal) {
            restoreAccents(profile: frenchProfile, word: $0, previousWord: previous, provider: french)
        }
    }

    func testACorrectionAfterAnAuxiliaryTakesTheParticipleAccent() {
        let expected = CorrectionProposal.autocorrect("arriv\u{00E9}", alternatives: ["arrive", "arriver"])
        XCTAssertEqual(restored(trieProposal, after: "est"), expected, "est zrrive")
        XCTAssertEqual(restored(trieProposal, after: "suis"), expected, "suis arribe")
    }

    func testACorrectionAfterASubjectStaysBare() {
        XCTAssertEqual(restored(trieProposal, after: "il"), trieProposal, "il zrrive")
        XCTAssertEqual(restored(trieProposal, after: nil), trieProposal, "zrrive alone")
    }

    func testTheBareFormIsOfferedWhenItWasNotAnAlternative() {
        let proposal = CorrectionProposal.autocorrect("trouve", alternatives: ["trouver", "troupe"])
        XCTAssertEqual(
            restored(proposal, after: "a"),
            .autocorrect("trouv\u{00E9}", alternatives: ["trouve", "trouver"]), "elle a trouvr"
        )
    }

    func testASuggestionIsLeftAsItIs() {
        let suggestion = CorrectionProposal.suggest(["arrive", "arriv\u{00E9}"])
        XCTAssertEqual(restored(suggestion, after: "est"), suggestion)
    }

    func testAnAmbiguousAccentLeavesTheCorrection() {
        let proposal = CorrectionProposal.autocorrect("reserve", alternatives: [])
        XCTAssertEqual(restored(proposal, after: nil), proposal, "réserve or réservé")
    }
}
