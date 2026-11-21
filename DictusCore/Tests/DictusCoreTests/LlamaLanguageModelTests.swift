import XCTest
@testable import DictusCore

/// The llama.cpp model on a real GGUF file (#996). Skipped unless this build has llama.cpp
/// (tools/keyboard-lm/build-llama.sh) and `KEYBOARD_LM_MODEL` names a model file, so CI
/// never runs it.
final class LlamaLanguageModelTests: XCTestCase {

    private func model() throws -> LanguageModelScoring {
        guard LocalLanguageModel.isAvailable else { throw XCTSkip("built without llama.cpp") }
        guard let path = ProcessInfo.processInfo.environment["KEYBOARD_LM_MODEL"] else {
            throw XCTSkip("KEYBOARD_LM_MODEL is not set")
        }
        return try XCTUnwrap(LocalLanguageModel.open(path: path), "cannot open \(path)")
    }

    func testTheSentenceDecidesBetweenTwoSpellings() throws {
        let model = try model()
        let afterJe = try XCTUnwrap(model.logProbabilities(of: ["trouve", "trouvé"], after: "Je "))
        let afterJai = try XCTUnwrap(model.logProbabilities(of: ["trouve", "trouvé"], after: "J'ai "))
        XCTAssertGreaterThan(afterJe[0], afterJe[1])
        XCTAssertGreaterThan(afterJai[1], afterJai[0])
    }

    func testTheLikelyWordWinsAndEveryScoreIsALogProbability() throws {
        let model = try model()
        let scores = try XCTUnwrap(model.logProbabilities(of: ["cinéma", "voiture", "gentiment"], after: "Je vais au "))
        XCTAssertGreaterThan(scores[0], scores[1])
        XCTAssertGreaterThan(scores[0], scores[2])
        XCTAssertTrue(scores.allSatisfy { $0 < 0 })
    }

    func testTheCacheGivesTheSameScoresAsAFreshContext() throws {
        let model = try model()
        let first = try XCTUnwrap(model.logProbabilities(of: ["cinéma", "salon"], after: "Je vais au "))
        _ = model.logProbabilities(of: ["voiture"], after: "Il a pris la ")
        let again = try XCTUnwrap(model.logProbabilities(of: ["cinéma", "salon"], after: "Je vais au "))
        for (lhs, rhs) in zip(first, again) { XCTAssertEqual(lhs, rhs, accuracy: 0.01) }
    }

    func testNextWordsAreWholeWords() throws {
        let model = try model()
        let words = model.nextWords(after: "Thank you so much for ", limit: 3) { _ in true }
        XCTAssertEqual(words.count, 3)
        XCTAssertTrue(words.allSatisfy { !$0.contains(" ") && !$0.isEmpty })
        let onlyYour = model.nextWords(after: "Thank you so much for ", limit: 3) { $0 == "your" }
        XCTAssertEqual(onlyYour, ["your"])
    }
}
