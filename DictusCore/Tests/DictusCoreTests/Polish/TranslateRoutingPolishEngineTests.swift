// DictusCore/Tests/DictusCoreTests/Polish/TranslateRoutingPolishEngineTests.swift
import XCTest
@testable import DictusCore

/// Translate on Apple's Translation framework, with Apple FM as its fallback (#648).
///
/// The framework is replaced by a scripted `TranslationFrameworkCall`, so every rule
/// below holds without Apple Intelligence: what is routed, every reason to fall back,
/// that a fallback never hands the raw back, and what the polish record calls the
/// engine that wrote the text.
final class TranslateRoutingPolishEngineTests: XCTestCase {

    /// The Apple FM side: records what it was asked and answers with a marker.
    private final class InnerEngine: PolishEngineProtocol, @unchecked Sendable {
        let identifier = "apple-fm"
        private(set) var calls = 0
        func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
            calls += 1
            return "FM(\(raw))"
        }
    }

    /// A framework that reports `status` and translates by tagging, or throws, or waits.
    private final class ScriptedFramework: @unchecked Sendable {
        var status: TranslationPairStatus = .installed
        var error: Error?
        var secondsPerChunk: Double = 0
        var echo = false
        private(set) var translated: [(String, TranslationLanguagePair)] = []
        private(set) var cancelled = false

        var call: TranslationFrameworkCall {
            TranslationFrameworkCall(
                status: { _ in self.status },
                session: { pair in
                    TranslationChunkSession(
                        translate: { chunk in
                            if self.secondsPerChunk > 0 {
                                try await Task.sleep(nanoseconds: UInt64(self.secondsPerChunk * 1_000_000_000))
                            }
                            if let error = self.error { throw error }
                            self.translated.append((chunk, pair))
                            return self.echo ? chunk : "TR(\(chunk))"
                        },
                        cancel: { self.cancelled = true }
                    )
                }
            )
        }
    }

    private let translateEN = PolishTask.smart(SmartModeCatalogue.translate(to: .english))

    private func engine(_ inner: InnerEngine, _ framework: ScriptedFramework,
                        budget: TranslationTimeBudget = .keyboard) -> TranslateRoutingPolishEngine {
        TranslateRoutingPolishEngine(wrapping: inner, budget: budget, appState: { "test" }, framework: framework.call)
    }

    // MARK: - Routing

    func testTranslateRunsOnTheFrameworkWithTheKnownSourceAndIsLabelledSo() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        let output = try await engine(inner, framework).polishLabelled(
            raw: "bonjour", targetLanguage: .french, task: translateEN, sourceLanguageCode: "fr"
        )
        XCTAssertEqual(output, PolishEngineOutput(text: "TR(bonjour)", engine: "translation.highFidelity"))
        XCTAssertEqual(framework.translated.first?.1.source, "fr")
        XCTAssertEqual(framework.translated.first?.1.target, .english)
        XCTAssertEqual(inner.calls, 0)
    }

    func testEveryOtherTaskGoesStraightToAppleFMAndKeepsItsLabel() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        for task in [PolishTask.natural, .smart(SmartModeCatalogue.notes)] {
            let output = try await engine(inner, framework).polishLabelled(
                raw: "bonjour", targetLanguage: .french, task: task, sourceLanguageCode: "fr"
            )
            XCTAssertEqual(output, PolishEngineOutput(text: "FM(bonjour)", engine: "apple-fm"))
        }
        XCTAssertTrue(framework.translated.isEmpty)
    }

    func testTheIdentifierStaysAppleFMSoTheAvailabilityGateIsUnchanged() {
        XCTAssertEqual(engine(InnerEngine(), ScriptedFramework()).identifier, "apple-fm")
    }

    // MARK: - Fallback: Apple FM, never the raw

    private func assertFallsBackToAppleFM(source: String?,
                                          configure: (ScriptedFramework) -> Void = { _ in },
                                          file: StaticString = #filePath, line: UInt = #line) async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        configure(framework)
        let output = try await engine(inner, framework).polishLabelled(
            raw: "texte", targetLanguage: .french, task: translateEN, sourceLanguageCode: source
        )
        XCTAssertEqual(output, PolishEngineOutput(text: "FM(texte)", engine: "apple-fm"), file: file, line: line)
        XCTAssertEqual(inner.calls, 1, file: file, line: line)
    }

    func testAnUnknownSourceFallsBack() async throws {
        try await assertFallsBackToAppleFM(source: nil)
    }

    /// English into English is the existing Apple FM path, which polishes it.
    func testSourceEqualToTargetFallsBack() async throws {
        try await assertFallsBackToAppleFM(source: "en")
        try await assertFallsBackToAppleFM(source: "en-US")
    }

    func testAPairNotInstalledFallsBack() async throws {
        try await assertFallsBackToAppleFM(source: "fr") { $0.status = .notInstalled }
        try await assertFallsBackToAppleFM(source: "fr") { $0.status = .unsupported }
    }

    func testAnOSWithoutTheStrategyFallsBack() async throws {
        try await assertFallsBackToAppleFM(source: "fr") { $0.status = .unknown }
    }

    /// The device test saw `notInstalled` thrown on a pair reported `installed`.
    func testAnErrorAfterAnInstalledVerdictStillFallsBack() async throws {
        struct NotInstalledAfterAll: Error {}
        try await assertFallsBackToAppleFM(source: "fr") { $0.error = NotInstalledAfterAll() }
    }

    /// The framework returns its input, without an error, when told the wrong source.
    func testAnAnswerIdenticalToTheInputFallsBackInsteadOfInsertingTheRaw() async throws {
        try await assertFallsBackToAppleFM(source: "fr") { $0.echo = true }
    }

    // MARK: - Chunks and budgets

    /// Each `<<NL>>` line and each sentence group is its own call, and the marker
    /// survives between them.
    func testALongInputIsTranslatedChunkByChunkAndReassembled() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        let budget = TranslationTimeBudget(chunkCharacters: 30, perChunkSeconds: 5, overallFloorSeconds: 5,
                                           overallSecondsPerCharacter: 0, overallCeilingSeconds: 5,
                                           fallsBackOnTimeout: false)
        let raw = "Première phrase assez longue. Deuxième phrase assez longue.<<NL>>Une autre ligne."
        let output = try await engine(inner, framework, budget: budget).polishLabelled(
            raw: raw, targetLanguage: .french, task: translateEN, sourceLanguageCode: "fr"
        )
        XCTAssertEqual(output.text, "TR(Première phrase assez longue.) TR(Deuxième phrase assez longue.)"
                       + "<<NL>>TR(Une autre ligne.)")
        XCTAssertEqual(framework.translated.count, 3)
    }

    /// The keyboard falls back to Apple FM on its 8 s budget, as it always did.
    func testAKeyboardTimeoutFallsBackToAppleFM() async throws {
        let budget = TranslationTimeBudget(chunkCharacters: 800, perChunkSeconds: 1, overallFloorSeconds: 1,
                                           overallSecondsPerCharacter: 0, overallCeilingSeconds: 1,
                                           fallsBackOnTimeout: true)
        let inner = InnerEngine(), framework = ScriptedFramework()
        framework.secondsPerChunk = 3
        let output = try await engine(inner, framework, budget: budget).polishLabelled(
            raw: "texte", targetLanguage: .french, task: translateEN, sourceLanguageCode: "fr"
        )
        XCTAssertEqual(output, PolishEngineOutput(text: "FM(texte)", engine: "apple-fm"))
        XCTAssertTrue(framework.cancelled)
    }

    /// DictusApp does not hand a text the framework merely needed more time for to the
    /// slower Apple FM (#648 problem 1b): the mode fails, and the card offers a retry.
    func testAnAppTimeoutFailsInsteadOfFallingBack() async {
        let budget = TranslationTimeBudget(chunkCharacters: 800, perChunkSeconds: 1, overallFloorSeconds: 1,
                                           overallSecondsPerCharacter: 0, overallCeilingSeconds: 1,
                                           fallsBackOnTimeout: false)
        let inner = InnerEngine(), framework = ScriptedFramework()
        framework.secondsPerChunk = 3
        do {
            _ = try await engine(inner, framework, budget: budget).polishLabelled(
                raw: "texte", targetLanguage: .french, task: translateEN, sourceLanguageCode: "fr"
            )
            XCTFail("an app timeout must not produce text")
        } catch {
            XCTAssertEqual(error as? TranslateRoutingPolishEngine.TranslationTimedOut, .init(seconds: 1))
        }
        XCTAssertEqual(inner.calls, 0)
    }

    func testTheAppBudgetScalesWithTheInputBetweenItsFloorAndCeiling() {
        XCTAssertEqual(TranslationTimeBudget.app.overallSeconds(forCharacters: 200), 30)
        XCTAssertEqual(TranslationTimeBudget.app.overallSeconds(forCharacters: 4_198), 84)
        XCTAssertEqual(TranslationTimeBudget.app.overallSeconds(forCharacters: 40_000), 300)
        XCTAssertEqual(TranslationTimeBudget.keyboard.overallSeconds(forCharacters: 4_198), 8)
        XCTAssertFalse(TranslationTimeBudget.app.fallsBackOnTimeout)
        XCTAssertTrue(TranslationTimeBudget.keyboard.fallsBackOnTimeout)
    }

    /// The framework has no window, so a Translate task is never refused up front; the
    /// Apple FM check is made only if the call falls back, and refuses rather than throws
    /// mid-generation.
    func testContextFitIsTheFrameworksForTranslateAndAppleFMsOnFallback() async {
        final class TightEngine: PolishEngineProtocol, @unchecked Sendable {
            let identifier = "apple-fm"
            private(set) var calls = 0
            func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
                calls += 1
                return raw
            }
            func contextFit(input: String, targetLanguage: SupportedLanguage, task: PolishTask) -> PolishContextFit {
                .exceeds(estimatedTokens: 5_000, budgetTokens: 4_000)
            }
        }
        let tight = TightEngine(), framework = ScriptedFramework()
        let routed = TranslateRoutingPolishEngine(wrapping: tight, budget: .keyboard, appState: { "test" },
                                                  framework: framework.call)
        XCTAssertEqual(routed.contextFit(input: "x", targetLanguage: .french, task: translateEN), .fits)
        XCTAssertNotEqual(routed.contextFit(input: "x", targetLanguage: .french, task: .natural), .fits)

        framework.status = .notInstalled
        do {
            _ = try await routed.polishLabelled(raw: "texte", targetLanguage: .french, task: translateEN,
                                                sourceLanguageCode: "fr")
            XCTFail("a fallback that does not fit must not reach Apple FM")
        } catch {
            XCTAssertEqual(routed.failureReason(for: error), .exceededContextWindowSize)
        }
        XCTAssertEqual(tight.calls, 0)
    }

    func testEachDeclineHasTheLogSlugTheReadersGrepFor() {
        typealias Decline = TranslateRoutingPolishEngine.Decline
        XCTAssertEqual(Decline.noSourceLanguage.slug, "noSourceLanguage")
        XCTAssertEqual(Decline.sameLanguage.slug, "sameLanguage")
        XCTAssertEqual(Decline.osBelow26_4.slug, "osBelow26.4")
        XCTAssertEqual(Decline.notInstalled(.notInstalled).slug, "notInstalled")
        XCTAssertEqual(Decline.deadline(8).slug, "deadline8s")
        XCTAssertEqual(Decline.error("error:notInstalled").slug, "error:notInstalled")
        XCTAssertEqual(Decline.untranslated.slug, "untranslated")
    }

    func testAnErrorBecomesASlugWithoutItsMessage() {
        struct SomeError: Error {}
        XCTAssertEqual(TranslateRoutingPolishEngine.slug(of: SomeError()), "error:SomeError")
    }

    // MARK: - The polish record

    /// The record's `engine` field is what wrote the text, through the real pipeline.
    func testThePipelineReportsTheEngineThatProducedTheOutput() async {
        let job = PolishJob(task: translateEN, promptLanguage: .french, languageAgnosticPath: false,
                            inputLanguageCodes: ["fr"], transcriptLanguageCode: "fr")
        let raw = "je suis en retard j'arrive dans quinze minutes"

        let translated = ScriptedFramework()
        let viaFramework = await PolishPipeline.transform(
            preprocessed: raw, engine: engine(InnerEngine(), translated), job: job
        )
        XCTAssertEqual(viaFramework.producedBy, "translation.highFidelity")

        let missing = ScriptedFramework()
        missing.status = .notInstalled
        let viaFallback = await PolishPipeline.transform(
            preprocessed: raw, engine: engine(InnerEngine(), missing), job: job
        )
        XCTAssertEqual(viaFallback.producedBy, "apple-fm")
    }

    func testTheLogLineCarriesEveryFieldAReaderNeeds() {
        let event = LogEvent.translateEngineCall(
            strategy: "highFidelity", status: "installed", source: "fr", target: "en", outcome: "translated",
            reason: "-", chunks: 1, ms: 4153, process: "KBD", appState: "extension",
            memBeforeMB: 21, memPeakMB: 22, memAfterMB: 22
        )
        XCTAssertEqual(event.name, "translateEngineCall")
        XCTAssertEqual(
            event.message,
            "engine=translation strategy=highFidelity status=installed source=fr target=en outcome=translated "
                + "reason=- chunks=1 ms=4153 process=KBD appState=extension memMB=21/22/22"
        )
    }
}

/// The language pair and the "not installed" notice (#648).
final class TranslationLanguageNoticeTests: XCTestCase {

    func testAPairNeedsTwoDifferentLanguages() {
        XCTAssertNotNil(TranslationLanguagePair(source: "fr", target: .english))
        XCTAssertNil(TranslationLanguagePair(source: "en", target: .english))
        XCTAssertNil(TranslationLanguagePair(source: "en-GB", target: .english))
    }

    func testOnlyTranslateModesNeedAPair() {
        for language in SupportedLanguage.allCases {
            let mode = SmartModeCatalogue.translate(to: language)
            XCTAssertEqual(TranslationLanguagePair.translateTarget(of: mode), language)
        }
        XCTAssertNil(TranslationLanguagePair(mode: SmartModeCatalogue.notes, source: "fr"))
        XCTAssertEqual(TranslationLanguagePair(mode: SmartModeCatalogue.translate(to: .german), source: "fr")?.target,
                       .german)
    }

    func testOnlyANotInstalledPairIsOwedANotice() throws {
        let pair = try XCTUnwrap(TranslationLanguagePair(source: "fr", target: .english))
        XCTAssertEqual(SmartModeAvailability.notice(pair: pair, status: .notInstalled),
                       .translationLanguageNotInstalled(pair))
        XCTAssertNil(SmartModeAvailability.notice(pair: pair, status: .installed))
        // Nothing to download: a notice would offer an action that does nothing.
        XCTAssertNil(SmartModeAvailability.notice(pair: pair, status: .unsupported))
        XCTAssertNil(SmartModeAvailability.notice(pair: pair, status: .unknown))
        XCTAssertNil(SmartModeAvailability.notice(pair: nil, status: .notInstalled))
    }

    /// A notice, never a refusal: the arming policy does not know about it.
    func testTheNoticeDoesNotTouchArmability() {
        XCTAssertEqual(
            SmartModeAvailability.armability(engineState: .available, engineIsRefusing: false, entitlement: .entitled),
            .armable
        )
    }

    func testTheNoticeHasAStableSlug() throws {
        let pair = try XCTUnwrap(TranslationLanguagePair(source: "fr", target: .spanish))
        XCTAssertEqual(SmartModeNotice.translationLanguageNotInstalled(pair).slug, "translationLanguageNotInstalled:fr>es")
    }
}

/// Sentence-aligned chunks for the Translation framework (#648).
final class TranslationChunkingTests: XCTestCase {

    func testSentencesAreGroupedUpToTheBudgetAndNeverCut() {
        let raw = "Un. Deux deux. Trois trois trois. Une phrase beaucoup plus longue que le budget entier."
        let chunks = TranslationChunking.chunks(raw, maxCharacters: 20)
        XCTAssertEqual(chunks, ["Un. Deux deux.", "Trois trois trois.",
                                "Une phrase beaucoup plus longue que le budget entier."])
    }

    func testLineBreakMarkersAreSeparatorsThatSurviveTheRoundTrip() {
        let raw = "Bonjour.<<NL>><<NL>>Au revoir."
        let pieces = TranslationChunking.pieces(raw, maxCharacters: 800)
        XCTAssertEqual(pieces.map(\.text), ["Bonjour.", "", "Au revoir."])
        XCTAssertEqual(TranslationChunking.join(pieces, translated: pieces.map(\.text)), raw)
    }

    func testAShortInputIsOneChunk() {
        XCTAssertEqual(TranslationChunking.chunks("je suis en retard j'arrive", maxCharacters: 800),
                       ["je suis en retard j'arrive"])
    }
}
