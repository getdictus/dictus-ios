// DictusCore/Tests/DictusCoreTests/PastAudioSegmentsTests.swift
// A segment timed after the end of the audio is dropped, the spoken ones are not (#953).
import XCTest
@testable import DictusCore

final class PastAudioSegmentsTests: XCTestCase {

    private typealias Segment = PastAudioSegments.Segment

    private func result(_ segments: [Segment]) -> PastAudioSegments.Result {
        PastAudioSegments.Result(text: segments.map(\.text).joined().trimmingCharacters(in: .whitespaces),
                                 segments: segments)
    }

    func test_segmentStartingAfterTheAudio_isDropped() {
        let spoken = Segment(start: 0, end: 13.8, text: " Est-ce que je publie aujourd'hui ou demain?")
        let invented = Segment(start: 14.42, end: 28.40, text: " – Le...")
        let outcome = PastAudioSegments.text(of: [result([spoken, invented])], audioSeconds: 14.41)
        XCTAssertEqual(outcome.text, "Est-ce que je publie aujourd'hui ou demain?")
        XCTAssertEqual(outcome.dropped, [invented])
    }

    func test_nothingDropped_keepsWhisperKitText() {
        let segments = [Segment(start: 0, end: 2, text: " Bonjour,"), Segment(start: 2, end: 4, text: " à demain.")]
        let whisperText = "Bonjour, à demain."
        let outcome = PastAudioSegments.text(of: [PastAudioSegments.Result(text: whisperText, segments: segments)],
                                             audioSeconds: 4.5)
        XCTAssertEqual(outcome.text, whisperText)
        XCTAssertEqual(outcome.dropped, [])
    }

    func test_wordStartingBeforeTheCut_isKept() {
        let spoken = Segment(start: 0, end: 3.5, text: " On se voit")
        let cutWord = Segment(start: 3.6, end: 4.0, text: " demain")
        let outcome = PastAudioSegments.text(of: [result([spoken, cutWord])], audioSeconds: 3.72)
        XCTAssertEqual(outcome.text, "On se voit demain")
        XCTAssertEqual(outcome.dropped, [])
    }

    func test_laterChunk_onlyItsLateSegmentIsDropped() {
        let first = result([Segment(start: 0, end: 28, text: " Première partie.")])
        let second = result([Segment(start: 28, end: 40, text: " Deuxième partie."),
                             Segment(start: 41, end: 52, text: " Merci.")])
        let outcome = PastAudioSegments.text(of: [first, second], audioSeconds: 40.5)
        XCTAssertEqual(outcome.text, "Première partie. Deuxième partie.")
        XCTAssertEqual(outcome.dropped.map(\.text), [" Merci."])
    }

    func test_chunkWithOnlyLateSegments_leavesNoDoubleSpace() {
        let first = result([Segment(start: 0, end: 10, text: " Début.")])
        let late = result([Segment(start: 12, end: 20, text: " Fin.")])
        let outcome = PastAudioSegments.text(of: [first, late], audioSeconds: 11)
        XCTAssertEqual(outcome.text, "Début.")
    }
}
