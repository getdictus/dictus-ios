// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteEngineChoiceTests.swift
import XCTest
@testable import DictusCore

/// Which engine reads a voice note in the app (#1084, PR 2): every row of the rule.
final class VoiceNoteEngineChoiceTests: XCTestCase {

    private func decide(_ language: VoiceNoteLanguage, apple: Bool, modelReady: Bool, warm: Bool = true,
                        covered: Bool) -> VoiceNoteEngineChoice.Decision {
        VoiceNoteEngineChoice.decide(language: language,
                                     dictationEngine: apple ? .apple(languageCode: "fr") : .downloadedModel,
                                     downloadedModelReady: modelReady, downloadedModelWarm: warm,
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
        return VoiceNoteEngineChoice.recordedLanguageCode(policy: policy, transcript: transcript)
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
}
