// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteRouteTests.swift
import XCTest
@testable import DictusCore

/// Who transcribes a shared voice note (#1056): the app, the share extension with Apple's
/// model, or nobody yet (today's route), and the 5-minute cap.
final class VoiceNoteRouteTests: XCTestCase {

    private let appleLocales = ["fr-FR", "en-US", "es-ES", "it-IT"]

    private func route(appTookIt: Bool = false,
                       language: VoiceNoteLanguage = .autoDetect,
                       keyboard: SupportedLanguage = .french,
                       major: Int = 26,
                       available: Bool = true,
                       locales: [String]? = nil,
                       installed: Bool? = true,
                       seconds: TimeInterval? = 60) -> VoiceNoteRoute {
        VoiceNoteRoute.decide(.init(
            appTookIt: appTookIt,
            system: .init(majorVersion: major, speechTranscriberAvailable: available,
                          supportedLocales: locales ?? appleLocales),
            voiceNoteLanguage: language,
            keyboardLanguage: keyboard,
            modelInstalled: installed,
            longestKnownSeconds: seconds
        ))
    }

    // MARK: - The app first

    func testAppThatTookTheNoteKeepsIt() {
        XCTAssertEqual(route(appTookIt: true), .appTookIt)
        // Whatever Apple's state: a live app transcribes with the user's model, and waits
        // for it when it compiles (Pierre, 2026-11-25).
        XCTAssertEqual(route(appTookIt: true, major: 18, available: false, installed: false, seconds: 900), .appTookIt)
    }

    // MARK: - The extension

    func testAutoDetectUsesTheDictationLanguage() {
        XCTAssertEqual(route(language: .autoDetect, keyboard: .spanish),
                       .shareExtension(languageCode: "es", source: .dictationLanguage))
    }

    func testFixedVoiceNoteLanguageWins() {
        XCTAssertEqual(route(language: .fixed(.english), keyboard: .french),
                       .shareExtension(languageCode: "en", source: .voiceNoteLanguage))
    }

    // MARK: - Apple not ready: today's route

    func testOlderThanIOS26OpensTheApp() {
        XCTAssertEqual(route(major: 18), .openApp(.systemTooOld))
    }

    func testNoSpeechTranscriberOpensTheApp() {
        XCTAssertEqual(route(available: false), .openApp(.speechTranscriberUnavailable))
    }

    func testLanguageAppleDoesNotListOpensTheApp() {
        XCTAssertEqual(route(keyboard: .german), .openApp(.languageNotCovered("de")))
        XCTAssertEqual(route(language: .fixed(.german)), .openApp(.languageNotCovered("de")))
    }

    func testModelNotInstalledOpensTheApp() {
        XCTAssertEqual(route(installed: false), .openApp(.modelNotInstalled("fr")))
    }

    func testModelNotAskedYetReadsAsNotInstalled() {
        // The caller's first pass: it asks Apple's inventory only on this answer.
        XCTAssertEqual(route(installed: nil), .openApp(.modelNotInstalled("fr")))
    }

    func testModelIsNotAskedWhenAnEarlierStepRefuses() {
        // No `.modelNotInstalled` answer, so the caller never calls `AssetInventory`.
        XCTAssertEqual(route(major: 18, installed: nil), .openApp(.systemTooOld))
        XCTAssertEqual(route(keyboard: .german, installed: nil), .openApp(.languageNotCovered("de")))
    }

    // MARK: - The 5-minute cap

    func testCapIsFiveMinutes() {
        XCTAssertEqual(VoiceNoteRoute.extensionCap, 300)
    }

    func testFiveMinutesExactlyStaysInTheExtension() {
        XCTAssertEqual(route(seconds: 300), .shareExtension(languageCode: "fr", source: .dictationLanguage))
        // The decoder's one-second tolerance: 5:00.4 is a 5-minute note.
        XCTAssertEqual(route(seconds: 300.4), .shareExtension(languageCode: "fr", source: .dictationLanguage))
    }

    func testOverFiveMinutesOpensTheAppWithItsReason() {
        XCTAssertEqual(route(seconds: 302), .openApp(.overExtensionCap(seconds: 302)))
        XCTAssertEqual(route(seconds: 9 * 60), .openApp(.overExtensionCap(seconds: 540)))
    }

    func testUnknownDurationIsLeftToTheDecoder() {
        XCTAssertEqual(route(seconds: nil), .shareExtension(languageCode: "fr", source: .dictationLanguage))
    }

    func testCapReasonOnlyWhenAppleWouldHaveTranscribed() {
        // A long note on an iPhone where Apple is not ready says why Apple is not ready,
        // not "too long": the cap sentence would promise something that would not happen.
        XCTAssertEqual(route(installed: false, seconds: 900), .openApp(.modelNotInstalled("fr")))
        XCTAssertEqual(route(available: false, seconds: 900), .openApp(.speechTranscriberUnavailable))
    }

    func testExceedsExtensionCap() {
        XCTAssertFalse(VoiceNoteRoute.exceedsExtensionCap(300))
        XCTAssertFalse(VoiceNoteRoute.exceedsExtensionCap(301))
        XCTAssertTrue(VoiceNoteRoute.exceedsExtensionCap(301.5))
    }

    // MARK: - Log names

    func testLogNames() {
        XCTAssertEqual(VoiceNoteRoute.appTookIt.logName, "appTookIt")
        XCTAssertEqual(VoiceNoteRoute.shareExtension(languageCode: "fr", source: .dictationLanguage).logName, "shareExtension")
        XCTAssertEqual(VoiceNoteRoute.OpenAppReason.overExtensionCap(seconds: 302).logName, "overExtensionCap(302s)")
        XCTAssertEqual(VoiceNoteRoute.OpenAppReason.modelNotInstalled("fr").logName, "modelNotInstalled(fr)")
    }
}

/// The result file the share extension leaves for the app.
final class VoiceNoteExtensionResultTests: XCTestCase {

    private var storage: VoiceNoteStorage!
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("extension-result-\(UUID())")
        storage = VoiceNoteStorage(root: root)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testRoundTrip() throws {
        let id = UUID()
        let result = VoiceNoteExtensionResult(id: id, transcript: "Bonjour", language: "fr", durationSeconds: 12,
                                              savedToHistory: true, engine: "apple-speechtranscriber",
                                              transcribedAt: Date(timeIntervalSince1970: 1_000))
        try result.write(to: storage)
        XCTAssertEqual(VoiceNoteExtensionResult.read(id, from: storage), result)
    }

    func testMissingResultReadsNil() {
        XCTAssertNil(VoiceNoteExtensionResult.read(UUID(), from: storage))
    }

    func testRemove() throws {
        let id = UUID()
        try VoiceNoteExtensionResult(id: id, transcript: "x", language: "fr", durationSeconds: 1,
                                     savedToHistory: false, engine: "e").write(to: storage)
        VoiceNoteExtensionResult.remove(id, from: storage)
        XCTAssertNil(VoiceNoteExtensionResult.read(id, from: storage))
    }

    func testWriteFailsWhenTheDirectoryCannotBeCreated() throws {
        // A file where the directory should be: the write throws, which the extension
        // turns into "give the note back to the app" (#992 review).
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("ExtensionResults"))
        XCTAssertThrowsError(try VoiceNoteExtensionResult(id: UUID(), transcript: "x", language: "fr", durationSeconds: 1,
                                                          savedToHistory: false, engine: "e").write(to: storage))
    }
}
