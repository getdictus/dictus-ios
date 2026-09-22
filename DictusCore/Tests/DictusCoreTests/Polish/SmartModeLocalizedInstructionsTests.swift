// DictusCore/Tests/DictusCoreTests/Polish/SmartModeLocalizedInstructionsTests.swift
// A Smart Mode's worked examples follow the transcript's language (#587, decision 5 step 2).
import XCTest
@testable import DictusCore

/// The seam that lets a mode carry one prompt per transcript language, and the one
/// rule that decides which is sent.
///
/// Mode-neutral on purpose: `Structuré` and `Résumé` (#571) both fill the table, and
/// this suite pins the mechanism they share rather than either mode's text.
final class SmartModeLocalizedInstructionsTests: XCTestCase {

    private let prompt = SmartModePrompt(
        instructions: "fallback", userInstruction: "u", outputMarker: "m",
        localizedInstructions: ["de": "deutsch", "zh-Hant": "traditional", "zh": "chinese", "pt": "portugues"]
    )

    private func mode(_ prompt: SmartModePrompt) -> SmartMode {
        SmartMode(id: "probe", displayName: "Probe", icon: "text.alignleft", prompt: prompt,
                  contract: SmartModeCatalogue.structured.contract, floorBehaviour: .insertRawText)
    }

    // MARK: - Which prompt

    func testTheExactCodeWins() {
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "de"), "deutsch")
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "zh-Hant"), "traditional")
    }

    /// `NLLanguageRecognizer` answers `zh-Hans` and a region-tagged code can reach the
    /// table; a mode keyed on base subtags must still be found.
    func testTheBaseSubtagIsTheSecondChoice() {
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "zh-Hans"), "chinese")
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "pt-BR"), "portugues")
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "pt_PT"), "portugues")
    }

    /// `no` is Norwegian too: a transcript labelled with the macrolanguage code gets
    /// the Bokmål set, stored under `nb`, rather than the fallback.
    func testNorwegianUnderNoReachesTheBokmalSet() {
        let norwegian = SmartModePrompt(
            instructions: "fallback", userInstruction: "u", outputMarker: "m",
            localizedInstructions: ["nb": "bokmal"]
        )
        XCTAssertEqual(norwegian.instructions(forTranscriptLanguage: "no"), "bokmal")
        XCTAssertEqual(norwegian.instructions(forTranscriptLanguage: "no-NO"), "bokmal")
        XCTAssertEqual(norwegian.instructions(forTranscriptLanguage: "nb"), "bokmal")
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "no"), "fallback")
    }

    /// No language known, or one the mode has no set for: the measured fallback, never
    /// a neighbouring language's examples.
    func testAnUnknownOrMissingLanguageGetsTheFallback() {
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: nil), "fallback")
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "da"), "fallback")
        let plain = SmartModePrompt(instructions: "only", userInstruction: "u", outputMarker: "m")
        XCTAssertEqual(plain.instructions(forTranscriptLanguage: "de"), "only")
    }

    // MARK: - The record

    /// The resolved record is the same mode: same identifier (the metrics key), same
    /// contract, same user turn. Only the system prompt moved.
    func testResolvingSwapsOnlyTheSystemPrompt() {
        let resolved = mode(prompt).resolvingExamples(forTranscriptLanguage: "de")
        XCTAssertEqual(resolved.id, "probe")
        XCTAssertEqual(resolved.prompt.instructions, "deutsch")
        XCTAssertEqual(resolved.prompt.userInstruction, "u")
        XCTAssertEqual(resolved.prompt.outputMarker, "m")
        XCTAssertEqual(resolved.contract, SmartModeCatalogue.structured.contract)
        XCTAssertEqual(resolved.floorBehaviour, .insertRawText)
        XCTAssertEqual(mode(prompt).resolvingExamples(forTranscriptLanguage: "da"), mode(prompt))
    }

    func testTheFreePolishIsNeverResolved() {
        XCTAssertEqual(PolishTask.natural.resolvingExamples(forTranscriptLanguage: "de"), .natural)
        XCTAssertEqual(PolishTask.auto.resolvingExamples(forTranscriptLanguage: "ja"), .auto)
    }

    /// A snapshot written before #587 has no table and decodes to one prompt for every
    /// language; a record written now keeps its table across the App Group.
    func testThePromptDecodesWithoutTheTableAndRoundTripsWithIt() throws {
        let json = #"{"instructions":"i","userInstruction":"u","outputMarker":"m"}"#
        let old = try JSONDecoder().decode(SmartModePrompt.self, from: Data(json.utf8))
        XCTAssertNil(old.localizedInstructions)
        XCTAssertEqual(old.instructions(forTranscriptLanguage: "de"), "i")

        let decoded = try JSONDecoder().decode(SmartModePrompt.self, from: JSONEncoder().encode(prompt))
        XCTAssertEqual(decoded, prompt)
    }

    // MARK: - Which language

    /// Decision 5: the language the user forced, if they forced one, else the detected
    /// one. Following the keyboard is not forcing.
    func testTheForcedLanguageOutranksDetection() {
        XCTAssertEqual(PolishJob.transcriptLanguageCode(mode: .explicit(.english), detectedCode: "fr"), "en")
        XCTAssertEqual(PolishJob.transcriptLanguageCode(mode: .autoDetect, detectedCode: "da"), "da")
        XCTAssertEqual(PolishJob.transcriptLanguageCode(mode: .followKeyboard, detectedCode: "de"), "de")
        XCTAssertNil(PolishJob.transcriptLanguageCode(mode: .autoDetect, detectedCode: nil))
    }

    // MARK: - What the engine is sent

    /// The pipeline resolves before the engine, so the engine is handed the German
    /// prompt for a German transcript — and the fallback when no language is known.
    func testThePipelineSendsTheTranscriptLanguagesPrompt() async {
        let engine = InstructionsRecordingEngine()
        let task = PolishTask.smart(mode(prompt))
        let raw = "Ich lasse dich mal schauen, es ist die letzte Transkription."
        _ = await PolishPipeline.transform(
            preprocessed: raw, engine: engine,
            job: PolishJob(task: task, promptLanguage: .german, languageAgnosticPath: false,
                           transcriptLanguageCode: "de")
        )
        _ = await PolishPipeline.transform(
            preprocessed: raw, engine: engine,
            job: PolishJob(task: task, promptLanguage: .german, languageAgnosticPath: false)
        )
        XCTAssertEqual(engine.sent, ["deutsch", "fallback"])
    }
}

/// Records the system prompt of every task it is asked to run, and echoes the input.
private final class InstructionsRecordingEngine: PolishEngineProtocol, @unchecked Sendable {
    let identifier = "instructions-recording"
    private let lock = NSLock()
    private var recorded: [String] = []

    var sent: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        record(task.smartMode?.prompt.instructions ?? "")
        return raw
    }

    private func record(_ instructions: String) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(instructions)
    }
}
