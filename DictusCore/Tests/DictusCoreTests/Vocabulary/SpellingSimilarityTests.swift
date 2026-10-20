// DictusCore/Tests/DictusCoreTests/Vocabulary/SpellingSimilarityTests.swift
// Which spellings the engine writes count as attempts at a word the user typed (#512).
import XCTest
@testable import DictusCore

final class SpellingSimilarityTests: XCTestCase {

    private func pairs(_ candidate: String, _ learned: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(SpellingSimilarity.pairScore(candidate: candidate, learned: learned),
                        "`\(candidate)` should pair with `\(learned)`", file: file, line: line)
    }

    private func doesNotPair(_ candidate: String, _ learned: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(SpellingSimilarity.pairScore(candidate: candidate, learned: learned),
                     "`\(candidate)` must not pair with `\(learned)`", file: file, line: line)
    }

    // MARK: - Real-shaped pairs

    func testAirmesIsHermes() {
        // Two substitutions in six letters: the case the edit distance alone misses.
        XCTAssertGreaterThan(SpellingSimilarity.editDistance("airmes", "hermes", atMost: 3), 1)
        XCTAssertEqual(SpellingSimilarity.phoneticKey("airmes"), SpellingSimilarity.phoneticKey("hermes"))
        pairs("airmes", "hermes")
        pairs("Airmès", "hermes")
    }

    func testFrenchAndEnglishSpellingsOfOneSoundPair() {
        pairs("parakit", "parakeet")
        pairs("clode", "claude")
        pairs("kubernetes", "cubernetes")
        pairs("fizer", "phiser")
        pairs("hermès", "hermes")
    }

    func testADroppedOrDoubledLetterInALongWordPairs() {
        pairs("whisperkitt", "whisperkit")
        pairs("testfligt", "testflight")
        pairs("dictuss", "dictus")
    }

    // MARK: - Negatives

    func testUnrelatedWordsDoNotPair() {
        doesNotPair("maison", "dictus")
        doesNotPair("parole", "parakeet")
        doesNotPair("hermine", "hermes")
        doesNotPair("trello", "hermes")
    }

    func testOrdinaryWordsThatOneEditApartDoNotPairThroughTheLooserBand() {
        // Pairs that a two-edit threshold at six letters would accept. Each is two
        // substitutions in a word of five or six letters, which stays at one edit.
        doesNotPair("pomme", "homard")
        doesNotPair("maison", "moisir")
        doesNotPair("dictee", "dictus")
    }

    func testShortWordsNeverPair() {
        doesNotPair("le", "les")
        doesNotPair("ai", "hi")
    }

    // MARK: - Spans

    func testAWordHeardAsTwoWordsMatchesBySkeletonOrSound() {
        XCTAssertTrue(SpellingSimilarity.spanMatches("whisper kit", learned: "whisperkit"))
        XCTAssertTrue(SpellingSimilarity.spanMatches("her mes", learned: "hermes"))
        XCTAssertTrue(SpellingSimilarity.spanMatches("air mes", learned: "hermes"))
        XCTAssertTrue(SpellingSimilarity.spanMatches("chat gpt", learned: "chatgpt"))
    }

    func testOrdinarySpansDoNotMatchByMereCloseness() {
        // One edit from `dictus` once joined, and two ordinary words: no edit distance
        // for spans, so no match.
        XCTAssertFalse(SpellingSimilarity.spanMatches("dit tus", learned: "dictus"))
        XCTAssertFalse(SpellingSimilarity.spanMatches("le mot", learned: "lemon"))
        XCTAssertFalse(SpellingSimilarity.spanMatches("de la", learned: "dela"),
                       "too short to stand for a word on its own")
    }

    // MARK: - The key

    func testThePhoneticKeyFoldsSilentLettersAndDoubles() {
        XCTAssertEqual(SpellingSimilarity.phoneticKey("Hermès"), "ermes")
        XCTAssertEqual(SpellingSimilarity.phoneticKey("claude"), SpellingSimilarity.phoneticKey("klod"))
        XCTAssertEqual(SpellingSimilarity.phoneticKey("parakeet"), SpellingSimilarity.phoneticKey("parakit"))
    }

    func testAllowedEditsGrowWithLength() {
        XCTAssertEqual(SpellingSimilarity.allowedEdits("dictus", "dictuss"), 1)
        XCTAssertEqual(SpellingSimilarity.allowedEdits("testflight", "testfligt"), 2)
        XCTAssertEqual(SpellingSimilarity.allowedEdits("kubernetesctl", "cubernetesctl"), 3)
    }
}
