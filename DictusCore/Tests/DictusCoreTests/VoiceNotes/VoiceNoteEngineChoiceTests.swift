// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteEngineChoiceTests.swift
import XCTest
@testable import DictusCore

/// Which engine reads a voice note in the app (#1084, PR 2): every row of the rule.
final class VoiceNoteEngineChoiceTests: XCTestCase {

    private func decide(_ language: VoiceNoteLanguage, apple: Bool, modelReady: Bool, warm: Bool = true,
                        covered: Bool) -> VoiceNoteEngineChoice.Decision {
        VoiceNoteEngineChoice.decide(language: language,
                                     dictationEngine: apple ? .apple(languageCode: "fr") : .downloadedModel,
                                     downloadedModel: modelReady ? "parakeet-tdt-0.6b-v3" : nil,
                                     downloadedModelWarm: warm,
                                     appleCoversFixedLanguage: covered)
    }

    // MARK: - The dictation runs the downloaded model: nothing changes

    func testDownloadedModelDictationKeepsItsEngineWhateverTheLanguage() {
        for language in [VoiceNoteLanguage.autoDetect, .fixed(.spanish)] {
            for modelReady in [true, false] {
                for covered in [true, false] {
                    let result = decide(language, apple: false, modelReady: modelReady, covered: covered)
                    XCTAssertEqual(result.choice, .dictationEngine)
                    XCTAssertEqual(result.reason, .dictationRunsDownloadedModel)
                }
            }
        }
    }

    // MARK: - Apple dictates, automatic detection

    func testAutoDetectWithADownloadedModelUsesIt() {
        let result = decide(.autoDetect, apple: true, modelReady: true, covered: true)
        XCTAssertEqual(result.choice, .downloadedModel)
        XCTAssertEqual(result.reason, .autoDetectUsesDownloadedModel)
    }

    func testAutoDetectWithoutADownloadedModelStaysOnApple() {
        let result = decide(.autoDetect, apple: true, modelReady: false, covered: true)
        XCTAssertEqual(result.choice, .dictationEngine)
        XCTAssertEqual(result.reason, .autoDetectWithoutDownloadedModel)
    }

    func testAutoDetectIgnoresAppleCoverage() {
        XCTAssertEqual(decide(.autoDetect, apple: true, modelReady: true, covered: false).choice, .downloadedModel)
        XCTAssertEqual(decide(.autoDetect, apple: true, modelReady: false, covered: false).choice, .dictationEngine)
    }

    // MARK: - Apple dictates, fixed language

    func testFixedLanguageAppleCoversStaysOnAppleEvenWithADownloadedModel() {
        for modelReady in [true, false] {
            let result = decide(.fixed(.spanish), apple: true, modelReady: modelReady, covered: true)
            XCTAssertEqual(result.choice, .dictationEngine)
            XCTAssertEqual(result.reason, .fixedLanguageCoveredByApple)
        }
    }

    func testFixedLanguageAppleCannotReadUsesTheDownloadedModel() {
        let result = decide(.fixed(.german), apple: true, modelReady: true, covered: false)
        XCTAssertEqual(result.choice, .downloadedModel)
        XCTAssertEqual(result.reason, .fixedLanguageNotCoveredUsesDownloadedModel)
    }

    func testFixedLanguageAppleCannotReadWithoutADownloadedModelStaysOnApple() {
        let result = decide(.fixed(.german), apple: true, modelReady: false, covered: false)
        XCTAssertEqual(result.choice, .dictationEngine)
        XCTAssertEqual(result.reason, .fixedLanguageNotCoveredWithoutDownloadedModel)
    }

    // MARK: - A downloaded model whose Core ML cache is cold

    func testColdModelUnderAutoDetectStaysOnAppleAndSchedulesTheCompile() {
        let result = decide(.autoDetect, apple: true, modelReady: true, warm: false, covered: true)
        XCTAssertEqual(result.choice, .dictationEngine)
        XCTAssertEqual(result.reason, .coldCache)
        XCTAssertTrue(result.compilesDownloadedModel)
    }

    func testWarmModelUnderAutoDetectIsUsedWithNoCompile() {
        let result = decide(.autoDetect, apple: true, modelReady: true, warm: true, covered: true)
        XCTAssertEqual(result.choice, .downloadedModel)
        XCTAssertFalse(result.compilesDownloadedModel)
    }

    func testColdModelForAFixedLanguageAppleCannotReadStaysOnAppleAndSchedulesTheCompile() {
        let result = decide(.fixed(.german), apple: true, modelReady: true, warm: false, covered: false)
        XCTAssertEqual(result.choice, .dictationEngine)
        XCTAssertEqual(result.reason, .coldCache)
        XCTAssertTrue(result.compilesDownloadedModel)
    }

    func testWarmthIsNotReadWhereTheModelIsNotWanted() {
        // Apple covers the language, there is no model, or the dictation runs the model:
        // nothing to compile for a voice note.
        let rows = [
            decide(.fixed(.spanish), apple: true, modelReady: true, warm: false, covered: true),
            decide(.autoDetect, apple: true, modelReady: false, warm: false, covered: true),
            decide(.autoDetect, apple: false, modelReady: true, warm: false, covered: true)
        ]
        for row in rows {
            XCTAssertNotEqual(row.reason, .coldCache)
            XCTAssertFalse(row.compilesDownloadedModel)
        }
    }

    // MARK: - When the compile may run

    private func refusal(scheduled: Bool = true, active: Bool = true, status: DictationStatus = .idle,
                         pending: Bool = false, noteRunning: Bool = false) -> VoiceNoteModelCompileGate.Refusal? {
        VoiceNoteModelCompileGate.refusal(scheduled: scheduled, appIsActive: active, dictationStatus: status,
                                          keyboardDictationPending: pending, voiceNoteRunning: noteRunning)
    }

    func testCompileRunsInTheForegroundWhenNothingElseDoes() {
        XCTAssertNil(refusal())
    }

    func testCompileNeverRunsInTheBackground() {
        XCTAssertEqual(refusal(active: false), .appNotActive)
    }

    func testCompileNeverRunsDuringADictation() {
        for status in [DictationStatus.requested, .recording, .transcribing, .processing, .ready, .failed] {
            XCTAssertEqual(refusal(status: status), .dictationInProgress, "\(status)")
        }
    }

    func testCompileNeverRunsBeforeAKeyboardLaunchedDictation() {
        XCTAssertEqual(refusal(pending: true), .keyboardDictationPending)
    }

    func testCompileNeverRunsWhileAVoiceNoteTranscribes() {
        XCTAssertEqual(refusal(noteRunning: true), .voiceNoteInProgress)
    }

    func testNothingScheduledNothingRuns() {
        XCTAssertEqual(refusal(scheduled: false), .nothingScheduled)
    }

    // MARK: - The language a detecting model's note is recorded under

    func testSpanishTranscriptIsRecordedAsSpanish() {
        let transcript = "Hola, te escribo para confirmar la cena del sábado en casa de mamá. "
            + "Llegaremos hacia las ocho con el postre, y si necesitas algo más me avisas."
        XCTAssertEqual(VoiceNoteEngineChoice.detectedLanguageCode(in: transcript), "es")
    }

    func testFrenchTranscriptIsRecordedAsFrench() {
        let transcript = "Bonjour, je t'appelle pour confirmer le dîner de samedi chez maman. "
            + "Nous arriverons vers huit heures avec le dessert."
        XCTAssertEqual(VoiceNoteEngineChoice.detectedLanguageCode(in: transcript), "fr")
    }

    func testALanguageDictusDoesNotShipStaysAuto() {
        let transcript = "Ciao, ti scrivo per confermare la cena di sabato a casa della mamma. "
            + "Arriveremo verso le otto con il dolce, e se ti serve altro fammi sapere."
        XCTAssertNil(VoiceNoteEngineChoice.detectedLanguageCode(in: transcript))
    }

    func testNothingReadableStaysAuto() {
        XCTAssertNil(VoiceNoteEngineChoice.detectedLanguageCode(in: ""))
    }

    // MARK: - The record's language

    private let spanish = "Hola, te escribo para confirmar la cena del sábado en casa de mamá. "
        + "Llegaremos hacia las ocho con el postre."

    private func recorded(_ language: VoiceNoteLanguage, engine: SpeechEngine, transcript: String) -> String {
        let policy = TranscriptionLanguagePolicy(mode: language.transcriptionMode, keyboardLanguage: .french,
                                                 engine: engine, modelIdentifier: "m")
        return VoiceNoteEngineChoice.recordedLanguage(policy: policy, transcript: transcript).code
    }

    func testParakeetUnderAutoDetectRecordsTheDetectedLanguage() {
        XCTAssertEqual(recorded(.autoDetect, engine: .parakeet, transcript: spanish), "es")
        XCTAssertEqual(recorded(.autoDetect, engine: .whisperKit, transcript: spanish), "es")
    }

    func testAppleUnderAutoDetectKeepsTheAssumedDictationLanguage() {
        XCTAssertEqual(recorded(.autoDetect, engine: .apple, transcript: spanish), "fr")
    }

    func testAFixedLanguageIsRecordedAsFixed() {
        XCTAssertEqual(recorded(.fixed(.german), engine: .parakeet, transcript: spanish), "de")
    }

    func testNothingMeasuredKeepsAuto() {
        XCTAssertEqual(recorded(.autoDetect, engine: .parakeet, transcript: ""), TranscriptionRecord.autoDetectedCode)
    }

    // MARK: - PR #1095 review

    /// Comment 1: the note keeps the model its warmth was checked for.
    func testTheDecisionKeepsTheCheckedModelForEveryChunk() {
        let warm = decide(.autoDetect, apple: true, modelReady: true, warm: true, covered: true)
        XCTAssertEqual(warm.downloadedModel, "parakeet-tdt-0.6b-v3")
        XCTAssertEqual(warm.modelToLoad, "parakeet-tdt-0.6b-v3")

        // Cold: the identity is the one to compile, never one to load.
        let cold = decide(.autoDetect, apple: true, modelReady: true, warm: false, covered: true)
        XCTAssertEqual(cold.downloadedModel, "parakeet-tdt-0.6b-v3")
        XCTAssertNil(cold.modelToLoad)

        // The dictation's engine: nothing to load.
        XCTAssertNil(decide(.fixed(.spanish), apple: true, modelReady: true, covered: true).modelToLoad)
        XCTAssertNil(decide(.autoDetect, apple: false, modelReady: true, covered: true).modelToLoad)
    }

    /// Comment 2: a model scheduled while another compiles stays scheduled.
    func testAFinishedCompileClearsOnlyTheModelItCompiled() {
        var schedule = VoiceNoteCompileSchedule()
        XCTAssertTrue(schedule.schedule("parakeet-tdt-0.6b-v3"))
        XCTAssertFalse(schedule.schedule("parakeet-tdt-0.6b-v3"))
        // The user picks Whisper while Parakeet compiles; a cold note schedules it.
        XCTAssertTrue(schedule.schedule("openai_whisper-small"))
        schedule.finished("parakeet-tdt-0.6b-v3")
        XCTAssertEqual(schedule.model, "openai_whisper-small")
        schedule.finished("openai_whisper-small")
        XCTAssertNil(schedule.model)
    }

    /// Comment 4: a detected language is shown, not a Smart Mode target.
    func testADetectedLanguageKeepsTheAutomaticSmartModePolicy() {
        XCTAssertEqual(VoiceNoteEngineChoice.smartModeLanguageMode(recordedLanguage: "es", languageWasDetected: true),
                       .autoDetect)
    }

    func testAFixedOrAssumedLanguageKeepsItsExplicitTarget() {
        XCTAssertEqual(VoiceNoteEngineChoice.smartModeLanguageMode(recordedLanguage: "es", languageWasDetected: false),
                       .explicit(.spanish))
    }

    func testAutoAndUnknownCodesStayAutomatic() {
        XCTAssertEqual(VoiceNoteEngineChoice.smartModeLanguageMode(
            recordedLanguage: TranscriptionRecord.autoDetectedCode, languageWasDetected: false), .autoDetect)
        XCTAssertEqual(VoiceNoteEngineChoice.smartModeLanguageMode(recordedLanguage: "it", languageWasDetected: false),
                       .autoDetect)
    }

    func testTheRecordSaysWhenItsLanguageWasDetected() {
        let policy = TranscriptionLanguagePolicy(mode: .autoDetect, keyboardLanguage: .french,
                                                 engine: .parakeet, modelIdentifier: "m")
        let recorded = VoiceNoteEngineChoice.recordedLanguage(policy: policy, transcript: spanish)
        XCTAssertEqual(recorded.code, "es")
        XCTAssertTrue(recorded.detected)

        let fixed = TranscriptionLanguagePolicy(mode: .explicit(.german), keyboardLanguage: .french,
                                                engine: .parakeet, modelIdentifier: "m")
        XCTAssertFalse(VoiceNoteEngineChoice.recordedLanguage(policy: fixed, transcript: spanish).detected)
        XCTAssertFalse(VoiceNoteEngineChoice.recordedLanguage(policy: policy, transcript: "").detected)
    }

    func testTheDetectedMarkerSurvivesTheHistoryFileAndIsAbsentOtherwise() throws {
        let detected = TranscriptionRecord(text: "Hola", language: "es", durationSeconds: 3, sttProvider: "PK",
                                           source: .sharedFile, languageWasDetected: true)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: JSONEncoder().encode(detected))
        XCTAssertTrue(decoded.languageWasDetected)

        let plain = TranscriptionRecord(text: "Hola", language: "es", durationSeconds: 3, sttProvider: "PK")
        let json = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
        XCTAssertFalse(json.contains("languageDetected"))
        XCTAssertFalse(try JSONDecoder().decode(TranscriptionRecord.self, from: Data(json.utf8)).languageWasDetected)
    }

    func testTheQueueKeepsTheDetectedMarkerForANoteHistoryDidNotTake() {
        let note = VoiceNote(audioFileName: "a.m4a", format: .mpeg4)
        var queue = VoiceNoteQueue(notes: [note])
        queue.complete(note.id, transcript: "Hola", language: "es", languageWasDetected: true, savedToHistory: false)
        XCTAssertEqual(queue.note(id: note.id)?.languageWasDetected, true)
    }
}
