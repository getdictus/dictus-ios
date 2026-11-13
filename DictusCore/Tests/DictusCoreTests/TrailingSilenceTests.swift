// DictusCore/Tests/DictusCoreTests/TrailingSilenceTests.swift
// The room recorded after the last spoken word is cut, the words are not (#932).
import XCTest
@testable import DictusCore

final class TrailingSilenceTests: XCTestCase {

    private let rate = 16_000

    /// A 200 Hz tone at `dBFS` RMS: stands in for a voiced stretch.
    private func voice(seconds: Double, dBFS: Double) -> [Float] {
        let amplitude = pow(10, dBFS / 20) * 2.0.squareRoot()
        return (0..<Int(seconds * Double(rate))).map { index in
            Float(amplitude * sin(2 * .pi * 200 * Double(index) / Double(rate)))
        }
    }

    /// Deterministic noise at roughly `dBFS` RMS: a room.
    private func room(seconds: Double, dBFS: Double) -> [Float] {
        let amplitude = pow(10, dBFS / 20) * 3.0.squareRoot()
        var state: UInt32 = 932
        return (0..<Int(seconds * Double(rate))).map { _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(amplitude * (Double(state) / Double(UInt32.max) * 2 - 1))
        }
    }

    private func silence(seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * Double(rate)))
    }

    private func seconds(_ count: Int) -> Double { Double(count) / Double(rate) }

    private func mixed(_ a: [Float], _ b: [Float]) -> [Float] {
        zip(a, b).map { $0 + $1 }
    }

    func test_digitalSilenceAfterSpeech_isCutToHalfASecond() {
        let speech = voice(seconds: 4, dBFS: -20)
        let kept = TrailingSilence.speechEndSampleCount(in: speech + silence(seconds: 3))
        XCTAssertEqual(seconds(kept), 4.5, accuracy: 0.06)
    }

    func test_roomUnderTheWholeRecording_tailIsCut() {
        let words = voice(seconds: 1.5, dBFS: -20) + silence(seconds: 0.6) + voice(seconds: 1.5, dBFS: -20)
        let recorded = mixed(words + silence(seconds: 8), room(seconds: 11.6, dBFS: -45))
        let kept = TrailingSilence.speechEndSampleCount(in: recorded)
        XCTAssertEqual(seconds(kept), 4.1, accuracy: 0.06)
    }

    func test_pauseBetweenWords_isKept() {
        let words = voice(seconds: 1, dBFS: -20) + silence(seconds: 2) + voice(seconds: 1, dBFS: -20)
        let kept = TrailingSilence.speechEndSampleCount(in: words + silence(seconds: 3))
        XCTAssertEqual(seconds(kept), 4.5, accuracy: 0.06)
    }

    func test_softLastWord_isKept() {
        let speech = voice(seconds: 3, dBFS: -15) + voice(seconds: 0.8, dBFS: -33)
        let kept = TrailingSilence.speechEndSampleCount(in: speech + silence(seconds: 3))
        XCTAssertEqual(seconds(kept), 4.3, accuracy: 0.06)
    }

    func test_shortWord_keepsWhatWhisperNeedsToDecodeIt() {
        let kept = TrailingSilence.speechEndSampleCount(in: voice(seconds: 0.3, dBFS: -20) + silence(seconds: 3))
        XCTAssertEqual(seconds(kept), TrailingSilence.minimumKept, accuracy: 0.001)
    }

    func test_recordingEndingOnSpeech_isUntouched() {
        let speech = voice(seconds: 4, dBFS: -20)
        XCTAssertEqual(TrailingSilence.speechEndSampleCount(in: speech), speech.count)
    }

    func test_roomAsLoudAsTheVoice_nothingIsCut() {
        let recorded = mixed(voice(seconds: 3, dBFS: -20) + silence(seconds: 3), room(seconds: 6, dBFS: -30))
        XCTAssertEqual(TrailingSilence.speechEndSampleCount(in: recorded), recorded.count)
    }

    func test_allSilent_isUntouched() {
        let recorded = silence(seconds: 3)
        XCTAssertEqual(TrailingSilence.speechEndSampleCount(in: recorded), recorded.count)
    }

    func test_shorterThanAFrame_isUntouched() {
        let recorded = voice(seconds: 0.01, dBFS: -20)
        XCTAssertEqual(TrailingSilence.trimmed(recorded), recorded)
    }
}
