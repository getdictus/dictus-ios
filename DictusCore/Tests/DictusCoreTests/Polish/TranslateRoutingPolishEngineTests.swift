// DictusCore/Tests/DictusCoreTests/Polish/TranslateRoutingPolishEngineTests.swift
import XCTest
@testable import DictusCore

/// The #648 device-test switch. Two promises are pinned here because a device session
/// cannot check them: with the switch untouched nothing changes, and a Translation
/// attempt that declines falls back to the shipped engine rather than handing the raw
/// back. Neither test reaches the framework itself — the declines below happen before
/// any availability read, so they hold on every machine.
final class TranslateRoutingPolishEngineTests: XCTestCase {

    /// Records what it was asked and answers with a marker the test can recognise.
    private final class InnerEngine: PolishEngineProtocol, @unchecked Sendable {
        let identifier = "apple-fm"
        private(set) var sources: [String?] = []
        func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
            sources.append(nil)
            return "INNER(\(raw))"
        }
        func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask,
                    sourceLanguageCode: String?) async throws -> String {
            sources.append(sourceLanguageCode)
            return "INNER(\(raw))"
        }
    }

    private let translateEN = PolishTask.smart(SmartModeCatalogue.translate(to: .english))

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: SharedKeys.debugTranslateEngine)
        super.tearDown()
    }

    func testAnUnsetSwitchReadsAsAppleFM() {
        AppGroup.defaults.removeObject(forKey: SharedKeys.debugTranslateEngine)
        XCTAssertEqual(TranslateEngineChoice.current, .appleFM)
        AppGroup.defaults.set("somethingElse", forKey: SharedKeys.debugTranslateEngine)
        XCTAssertEqual(TranslateEngineChoice.current, .appleFM)
    }

    func testOnAppleFMEveryCallIsForwardedWithItsSourceAndTheIdentifierIsTheInnerOne() async throws {
        TranslateEngineChoice.store(.appleFM)
        let inner = InnerEngine()
        let engine = TranslateRoutingPolishEngine(wrapping: inner, appState: { "test" })
        XCTAssertEqual(engine.identifier, "apple-fm")
        let output = try await engine.polish(raw: "bonjour", targetLanguage: .french, task: translateEN,
                                             sourceLanguageCode: "fr")
        XCTAssertEqual(output, "INNER(bonjour)")
        XCTAssertEqual(inner.sources, ["fr"])
    }

    func testANonTranslateTaskIsForwardedEvenWithAStrategySelected() async throws {
        TranslateEngineChoice.store(.translationHighFidelity)
        let inner = InnerEngine()
        let engine = TranslateRoutingPolishEngine(wrapping: inner, appState: { "test" })
        let output = try await engine.polish(raw: "bonjour", targetLanguage: .french, task: .natural,
                                             sourceLanguageCode: "fr")
        XCTAssertEqual(output, "INNER(bonjour)")
    }

    /// The framework refuses a same-language pair; the raw must not come back as is.
    func testSourceEqualToTargetFallsBackToTheShippedEngine() async throws {
        TranslateEngineChoice.store(.translationHighFidelity)
        let inner = InnerEngine()
        let engine = TranslateRoutingPolishEngine(wrapping: inner, appState: { "test" })
        let output = try await engine.polish(raw: "hello there", targetLanguage: .english, task: translateEN,
                                             sourceLanguageCode: "en")
        XCTAssertEqual(output, "INNER(hello there)")
    }

    func testAnUnknownSourceFallsBackToTheShippedEngine() async throws {
        TranslateEngineChoice.store(.translationLowLatency)
        let inner = InnerEngine()
        let engine = TranslateRoutingPolishEngine(wrapping: inner, appState: { "test" })
        let output = try await engine.polish(raw: "bonjour", targetLanguage: .french, task: translateEN,
                                             sourceLanguageCode: nil)
        XCTAssertEqual(output, "INNER(bonjour)")
    }

    func testEveryTranslateModeMapsToItsTarget() {
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(
                TranslateRoutingPolishEngine.translateTarget(of: .smart(SmartModeCatalogue.translate(to: language))),
                language
            )
        }
        XCTAssertNil(TranslateRoutingPolishEngine.translateTarget(of: .natural))
    }

    func testTheLogLineCarriesEveryFieldTheDeviceTestReads() {
        let event = LogEvent.translateEngineCall(
            strategy: "highFidelity", status: "installed", source: "fr", target: "en", outcome: "translated",
            reason: "-", ms: 812, process: "KBD", appState: "extension",
            memBeforeMB: 41, memPeakMB: 48, memAfterMB: 43
        )
        XCTAssertEqual(event.name, "translateEngineCall")
        XCTAssertEqual(
            event.message,
            "engine=translation strategy=highFidelity status=installed source=fr target=en outcome=translated "
                + "reason=- ms=812 process=KBD appState=extension memMB=41/48/43"
        )
    }

    func testAnErrorBecomesASlugWithoutItsMessage() {
        struct SomeError: Error {}
        XCTAssertEqual(TranslateRoutingPolishEngine.slug(of: SomeError()), "error:SomeError")
    }
}
