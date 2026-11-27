import XCTest
@testable import DictusCore

/// #1083: after picking Apple on the Models screen, Home, the Debug export header and the
/// voice-note queue kept naming the downloaded Parakeet model. They all read
/// `ActiveSpeechEngine` now; these tests switch Parakeet → Apple → Parakeet and check the
/// source and each reader at every step.
final class ActiveSpeechEngineTests: XCTestCase {

    private let suiteName = "ActiveSpeechEngineTests"
    private var defaults: UserDefaults!
    private let parakeet = "parakeet-tdt-0.6b-v3"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// What the Models screen writes when the user taps a card: Apple's card writes the
    /// choice and its readiness record, a model card writes the choice back to the model.
    /// `activeModel` stays Parakeet throughout, as `ModelManager` keeps it.
    private func pick(_ choice: SpeechEngineChoice) {
        defaults.set(parakeet, forKey: SharedKeys.activeModel)
        defaults.set(true, forKey: SharedKeys.modelReady)
        if choice == .apple {
            AppleEngineReadinessRecord.write(.ready(languageCode: "fr"), to: defaults)
        }
        SpeechEngineChoice.write(choice, to: defaults)
    }

    private struct Readers: Equatable {
        let source: ActiveSpeechEngine?
        /// What Home's "Active model" card resolves, from `ModelManager`'s published state.
        let home: ActiveSpeechEngine?
        let exportHeaderModel: String
        let voiceNoteQueueEngine: SpeechEngine
    }

    private func readers() -> Readers {
        let source = ActiveSpeechEngine.current(defaults: defaults, dictationLanguageCode: "fr")
        let home = ActiveSpeechEngine.resolve(
            choice: SpeechEngineChoice.read(from: defaults),
            appleAvailability: AppleEngineReadinessRecord.availability(
                readyLanguage: AppleEngineReadinessRecord.readyLanguage(in: defaults), dictationLanguageCode: "fr"),
            downloadedModel: defaults.string(forKey: SharedKeys.activeModel))
        let header = PersistentLog.buildExportHeader(
            iosVersion: "26.7.3", appVersion: "2.0.3", buildNumber: "45", deviceModel: "iPhone",
            activeModel: PersistentLog.headerModel(defaults: defaults, dictationLanguageCode: "fr"))
        let model = header.components(separatedBy: "| Model: ").last?
            .components(separatedBy: CharacterSet(charactersIn: " \n")).first ?? ""
        // `VoiceNoteProcessor`'s call, its Whisper fallback included.
        let policy = VoiceNoteSettings().languagePolicy(
            activeEngine: source ?? ActiveSpeechEngine(engine: .whisperKit, identifier: "openai_whisper-small"),
            keyboardLanguage: .french)
        return Readers(source: source, home: home, exportHeaderModel: model, voiceNoteQueueEngine: policy.engine)
    }

    func testParakeetToAppleToParakeetEveryReaderFollows() {
        let parakeetReaders = Readers(source: ActiveSpeechEngine(engine: .parakeet, identifier: parakeet),
                                      home: ActiveSpeechEngine(engine: .parakeet, identifier: parakeet),
                                      exportHeaderModel: parakeet, voiceNoteQueueEngine: .parakeet)
        let appleReaders = Readers(source: .apple, home: .apple,
                                   exportHeaderModel: "apple-speechtranscriber", voiceNoteQueueEngine: .apple)

        pick(.downloadedModel)
        XCTAssertEqual(readers(), parakeetReaders, "Parakeet picked")

        pick(.apple)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.activeModel), parakeet,
                       "activeModel still names the downloaded model: the bug's trap")
        XCTAssertEqual(readers(), appleReaders, "Apple picked")

        pick(.downloadedModel)
        XCTAssertEqual(readers(), parakeetReaders, "Parakeet picked again")
    }

    /// Apple picked but not ready for this language (automatic detection, another
    /// language): the downloaded model dictates, so every reader names it.
    func testApplePickedButNotReadyNamesTheDownloadedModel() {
        pick(.apple)
        XCTAssertEqual(ActiveSpeechEngine.current(defaults: defaults, dictationLanguageCode: nil),
                       ActiveSpeechEngine(engine: .parakeet, identifier: parakeet))
        XCTAssertEqual(ActiveSpeechEngine.current(defaults: defaults, dictationLanguageCode: "de")?.engine, .parakeet)
        XCTAssertEqual(PersistentLog.headerModel(defaults: defaults, dictationLanguageCode: nil), parakeet)
    }

    /// Apple only (#1057): no downloaded model, Apple ready.
    func testAppleOnlyAndNothingAtAll() {
        XCTAssertNil(ActiveSpeechEngine.current(defaults: defaults, dictationLanguageCode: "fr"))
        XCTAssertEqual(PersistentLog.headerModel(defaults: defaults, dictationLanguageCode: "fr"), "none")
        AppleEngineReadinessRecord.write(.ready(languageCode: "fr"), to: defaults)
        SpeechEngineChoice.write(.apple, to: defaults)
        XCTAssertEqual(ActiveSpeechEngine.current(defaults: defaults, dictationLanguageCode: "fr"), .apple)
    }
}
