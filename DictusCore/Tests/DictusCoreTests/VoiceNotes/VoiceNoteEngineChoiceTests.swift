// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteEngineChoiceTests.swift
import XCTest
@testable import DictusCore

/// Which engine reads a voice note in the app (#1084, PR 2): every row of the rule.
final class VoiceNoteEngineChoiceTests: XCTestCase {

    private func decide(_ language: VoiceNoteLanguage, apple: Bool, modelReady: Bool,
                        covered: Bool) -> (choice: VoiceNoteEngineChoice, reason: VoiceNoteEngineChoice.Reason) {
        VoiceNoteEngineChoice.decide(language: language,
                                     dictationEngine: apple ? .apple(languageCode: "fr") : .downloadedModel,
                                     downloadedModelReady: modelReady, appleCoversFixedLanguage: covered)
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
