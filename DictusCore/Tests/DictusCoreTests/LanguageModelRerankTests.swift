// DictusCore/Tests/DictusCoreTests/LanguageModelRerankTests.swift
// Covers the language model's place in the space bar's decision (#996): its term in
// CorrectionRanking, the time budget it runs under, and the fields it may read.
import XCTest
@testable import DictusCore

final class LanguageModelRerankTests: XCTestCase {

    // MARK: - CorrectionRanking

    private func candidate(_ word: String, _ cost: Double, _ frequency: UInt16, model: Double = 0) -> CorrectionCandidate {
        CorrectionCandidate(word: word, cost: cost, frequency: frequency, languageModel: model)
    }

    /// `Je trouce`, as the trie offers it: `trouve` and `trouvé` are close readings, and
    /// without context the more frequent `trouvé` wins. The model's verdicts are relative
    /// to its favourite, which gets 0.
    private func trouce(trouve: Double, trouvé: Double) -> [CorrectionCandidate] {
        [candidate("trouve", 0.40, 44_534, model: trouve), candidate("trouvé", 0.55, 45_035, model: trouvé),
         candidate("trouver", 1.40, 45_145, model: -9), candidate("troupe", 1.00, 32_708, model: -9)]
    }

    func testWithoutWeightTheModelChangesNothing() {
        let candidates = trouce(trouve: 0, trouvé: -7)
        let plain = candidates.map { CorrectionCandidate(word: $0.word, cost: $0.cost, frequency: $0.frequency) }
        XCTAssertEqual(CorrectionRanking.rerank(candidates, languageModelWeight: 0), CorrectionRanking.decide(plain))
        XCTAssertEqual(CorrectionRanking.decide(plain).replacement, "trouvé")
    }

    func testTheModelPicksBetweenCloseReadings() {
        XCTAssertEqual(CorrectionRanking.rerank(trouce(trouve: 0, trouvé: -7), languageModelWeight: 0.05).replacement,
                       "trouve")
        XCTAssertEqual(CorrectionRanking.rerank(trouce(trouve: -7, trouvé: 0), languageModelWeight: 0.05).replacement,
                       "trouvé")
    }

    func testTheModelCanPickAFartherCandidate() {
        // `Lnction`: the trie's best is `onction`, a key closer than `fonction`.
        let candidates = [candidate("onction", 0.41, 17_635, model: -8), candidate("fonction", 1.41, 32_390, model: 0)]
        XCTAssertEqual(CorrectionRanking.rerank(candidates, languageModelWeight: 0).replacement, "onction")
        XCTAssertEqual(CorrectionRanking.rerank(candidates, languageModelWeight: 0.05).replacement, "fonction")
    }

    func testAKeptWordStaysKept() {
        // `Fràvhelent`: three readings as close as each other, so the typed word is kept.
        // However sure the model is, it does not turn the offer into a correction.
        let candidates = [candidate("franchement", 1.95, 35_659, model: 0),
                          candidate("gravement", 1.95, 30_580, model: -10), candidate("fraîchement", 1.95, 25_547, model: -10)]
        XCTAssertNil(CorrectionRanking.decide(candidates).replacement)
        XCTAssertNil(CorrectionRanking.rerank(candidates, languageModelWeight: 0.1).replacement)
    }

    func testReadingsTheModelLeavesTooCloseKeepTheRankingsPick() {
        // `qur`: `sur` and `que` are close; a model as unsure between them keeps `sur`.
        let candidates = [candidate("sur", 0.40, 55_999, model: 0), candidate("que", 0.40, 55_817, model: -0.1),
                          candidate("sûr", 0.55, 48_865, model: -0.2)]
        XCTAssertEqual(CorrectionRanking.rerank(candidates, languageModelWeight: 0.05).replacement, "sur")
    }

    // MARK: - KeyboardLanguageModel

    private final class FakeModel: LanguageModelScoring {
        var delay: TimeInterval = 0
        private(set) var requests = 0

        func logProbabilities(of readings: [String], after context: String) -> [Double]? {
            requests += 1
            Thread.sleep(forTimeInterval: delay)
            return readings.map { -Double($0.count) }
        }

        func nextWords(after context: String, limit: Int, isWord: (String) -> Bool) -> [String] {
            Thread.sleep(forTimeInterval: delay)
            return Array(["la", "le", "les", "un"].filter(isWord).prefix(limit))
        }
    }

    private func loaded(_ fake: FakeModel, budget: TimeInterval? = 0.015) -> KeyboardLanguageModel {
        let model = KeyboardLanguageModel(budget: budget)
        model.load { fake }
        model.waitForQueue()
        return model
    }

    func testNoAnswerBeforeTheModelIsLoaded() {
        let model = KeyboardLanguageModel()
        XCTAssertFalse(model.isLoaded)
        XCTAssertNil(model.logProbabilities(of: ["la"], after: "Je vois "))
        XCTAssertNil(model.nextWords(after: "Je vois ", limit: 3))
    }

    func testAnAnswerWithinTheBudget() {
        let model = loaded(FakeModel())
        XCTAssertEqual(model.logProbabilities(of: ["la", "les"], after: "Je vois "), [-2, -3])
        XCTAssertEqual(model.nextWords(after: "Je vois ", limit: 2), ["la", "le"])
    }

    func testASlowModelGivesNothingInTimeAndItsAnswerToTheNextCaller() {
        let fake = FakeModel()
        fake.delay = 0.1
        let model = loaded(fake)
        let start = Date()
        XCTAssertNil(model.logProbabilities(of: ["la"], after: "Je vois "))
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.08, "the caller waited past its budget")
        model.waitForQueue()
        // The space bar asks what the bar asked: the late answer is there, and the model is not asked again.
        XCTAssertEqual(model.logProbabilities(of: ["la"], after: "Je vois "), [-2])
        XCTAssertEqual(fake.requests, 1)
    }

    func testAWaitingRequestIsReplacedByANewerOne() {
        let fake = FakeModel()
        fake.delay = 0.05
        let model = loaded(fake, budget: 0.01)
        _ = model.logProbabilities(of: ["a"], after: "x ")
        _ = model.logProbabilities(of: ["b"], after: "x ")
        _ = model.logProbabilities(of: ["c"], after: "x ")
        model.waitForQueue()
        // `a` was running and `b` waited behind it until `c` replaced it.
        XCTAssertEqual(fake.requests, 2)
    }

    func testUnloadingTurnsTheModelOff() {
        let model = loaded(FakeModel())
        model.unload()
        XCTAssertFalse(model.isLoaded)
        XCTAssertNil(model.logProbabilities(of: ["la"], after: "Je vois "))
    }

    func testAFailedLoadLeavesTheModelOff() {
        let model = KeyboardLanguageModel()
        model.load { nil }
        model.waitForQueue()
        XCTAssertFalse(model.isLoaded)
    }

    // MARK: - LanguageModelContext

    private let secure = HostFieldPolicy.evaluate(keyboard: .standard, content: .none, autocorrectionDisabled: false,
                                                  spellCheckingDisabled: false, isSecureEntry: true)
    private let password = HostFieldPolicy.evaluate(keyboard: .standard, content: .password, autocorrectionDisabled: false,
                                                    spellCheckingDisabled: false, isSecureEntry: false)

    func testTheModelReadsNothingInASecureOrPasswordField() {
        XCTAssertNil(LanguageModelContext.text(before: "trouce", in: "Je trouce", policy: secure))
        XCTAssertNil(LanguageModelContext.text(beforeCursor: "Je trouve ", policy: secure))
        XCTAssertNil(LanguageModelContext.text(before: "trouce", in: "Je trouce", policy: password))
    }

    func testTheModelReadsTheParagraphBeforeTheWord() {
        XCTAssertEqual(LanguageModelContext.text(before: "trouce", in: "Bonjour.\nJe trouce", policy: .allowed), "Je ")
        XCTAssertEqual(LanguageModelContext.text(before: "Lnction", in: "Lnction", policy: .allowed), "")
        XCTAssertEqual(LanguageModelContext.text(beforeCursor: "Salut\nJe vais au ", policy: .allowed), "Je vais au ")
        XCTAssertNil(LanguageModelContext.text(before: "trouce", in: "Je trouve", policy: .allowed))
    }

    func testALongParagraphIsCutAtAWord() {
        let long = String(repeating: "mot ", count: 100) + "fin "
        let text = try? XCTUnwrap(LanguageModelContext.text(beforeCursor: long, policy: .allowed))
        XCTAssertLessThanOrEqual(text?.count ?? .max, LanguageModelContext.maxCharacters)
        XCTAssertEqual(text?.first, "m")
        XCTAssertTrue(text?.hasSuffix("fin ") == true)
    }
}
