// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteAssumedLanguageTests.swift
import XCTest
@testable import DictusCore

/// A voice note read by Apple's engine under automatic detection (#1084): the record says
/// the language and engine that really ran, and carries the flag the card's line reads.
final class VoiceNoteAssumedLanguageTests: XCTestCase {

    private func policy(_ language: VoiceNoteLanguage, engine: SpeechEngine,
                        keyboard: SupportedLanguage = .french) -> TranscriptionLanguagePolicy {
        TranscriptionLanguagePolicy(mode: language.transcriptionMode, keyboardLanguage: keyboard,
                                    engine: engine, modelIdentifier: "m")
    }

    private func record(_ policy: TranscriptionLanguagePolicy) -> TranscriptionRecord {
        TranscriptionRecord(text: "Hola", policy: policy, duration: 42, source: .sharedFile)
    }

    // MARK: - The record

    func testAppleUnderAutoDetectRecordsTheKeyboardLanguageAsAssumed() {
        let saved = record(policy(.autoDetect, engine: .apple))
        XCTAssertEqual(saved.language, "fr")
        XCTAssertEqual(saved.sttProvider, "AP")
        XCTAssertTrue(saved.languageWasAssumed)
    }

    func testParakeetUnderAutoDetectStaysAutoAndDetected() {
        let saved = record(policy(.autoDetect, engine: .parakeet))
        XCTAssertEqual(saved.language, TranscriptionRecord.autoDetectedCode)
        XCTAssertEqual(saved.sttProvider, "PK")
        XCTAssertFalse(saved.languageWasAssumed)
    }

    func testWhisperUnderAutoDetectStaysAutoAndDetected() {
        let saved = record(policy(.autoDetect, engine: .whisperKit))
        XCTAssertEqual(saved.language, TranscriptionRecord.autoDetectedCode)
        XCTAssertFalse(saved.languageWasAssumed)
    }

    func testAppleWithAFixedLanguageRecordsThatLanguageNotAssumed() {
        let saved = record(policy(.fixed(.spanish), engine: .apple))
        XCTAssertEqual(saved.language, "es")
        XCTAssertEqual(saved.sttProvider, "AP")
        XCTAssertFalse(saved.languageWasAssumed)
    }

    // MARK: - What the engine is told

    func testAppleUnderAutoDetectIsHandedTheKeyboardLanguage() {
        let apple = policy(.autoDetect, engine: .apple, keyboard: .german)
        XCTAssertTrue(apple.languageIsAssumed)
        // No nil for the engine to fill in with a language of its own.
        XCTAssertEqual(apple.sttLanguageCode, "de")
        XCTAssertFalse(apple.insertsTranscriptionAsIs)
    }

    func testDetectingEnginesAreNotAssumed() {
        XCTAssertFalse(policy(.autoDetect, engine: .parakeet).languageIsAssumed)
        XCTAssertFalse(policy(.autoDetect, engine: .whisperKit).languageIsAssumed)
        XCTAssertNil(policy(.autoDetect, engine: .whisperKit).sttLanguageCode)
        XCTAssertFalse(policy(.fixed(.english), engine: .apple).languageIsAssumed)
        XCTAssertEqual(policy(.fixed(.english), engine: .apple).sttLanguageCode, "en")
    }

    // MARK: - Storage

    func testFlagSurvivesTheHistoryFile() throws {
        let saved = record(policy(.autoDetect, engine: .apple))
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: JSONEncoder().encode(saved))
        XCTAssertTrue(decoded.languageWasAssumed)
        XCTAssertEqual(decoded.language, "fr")
    }

    func testFlagIsWrittenOnlyWhenTrue() throws {
        let detected = record(policy(.autoDetect, engine: .parakeet))
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(detected), encoding: .utf8))
        XCTAssertFalse(json.contains("languageAssumed"))
    }

    func testRecordWrittenBeforeTheFlagReadsNotAssumed() throws {
        let old = """
        {"id":"\(UUID().uuidString)","text":"x","language":"auto","durationSeconds":3,
         "createdAt":0,"sttProvider":"PK","source":"sharedFile"}
        """
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: Data(old.utf8))
        XCTAssertFalse(decoded.languageWasAssumed)
    }

    // MARK: - The queue, History off

    func testNoteKeptInTheQueueCarriesTheFlag() {
        let note = VoiceNote(audioFileName: "a.m4a", format: .mpeg4)
        var queue = VoiceNoteQueue(notes: [note])
        queue.complete(note.id, transcript: "Hola", language: "fr", languageWasAssumed: true, savedToHistory: false)
        XCTAssertEqual(queue.note(id: note.id)?.language, "fr")
        XCTAssertEqual(queue.note(id: note.id)?.languageWasAssumed, true)
    }

    func testNoteWithADetectedLanguageCarriesNoFlag() {
        let note = VoiceNote(audioFileName: "a.m4a", format: .mpeg4)
        var queue = VoiceNoteQueue(notes: [note])
        queue.complete(note.id, transcript: "Hola", language: "auto", savedToHistory: false)
        XCTAssertNil(queue.note(id: note.id)?.languageWasAssumed)
    }

    // MARK: - The share extension's result

    func testExtensionResultCarriesTheFlag() throws {
        let result = VoiceNoteExtensionResult(id: UUID(), transcript: "Hola", language: "fr", durationSeconds: 4,
                                              savedToHistory: true, engine: "e", languageWasAssumed: true)
        let decoded = try JSONDecoder.voiceNotes.decode(VoiceNoteExtensionResult.self,
                                                        from: JSONEncoder.voiceNotes.encode(result))
        XCTAssertEqual(decoded.languageWasAssumed, true)
    }

    func testExtensionResultWrittenBeforeTheFlagStillReads() throws {
        let result = VoiceNoteExtensionResult(id: UUID(), transcript: "Hola", language: "fr", durationSeconds: 4,
                                              savedToHistory: true, engine: "e")
        let json = try XCTUnwrap(String(data: JSONEncoder.voiceNotes.encode(result), encoding: .utf8))
        XCTAssertFalse(json.contains("languageWasAssumed"))
        let decoded = try JSONDecoder.voiceNotes.decode(VoiceNoteExtensionResult.self, from: Data(json.utf8))
        XCTAssertNil(decoded.languageWasAssumed)
    }
}
