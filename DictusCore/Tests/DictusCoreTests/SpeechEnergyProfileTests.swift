// DictusCore/Tests/DictusCoreTests/SpeechEnergyProfileTests.swift
// The energy levels the #623 drift retry places its spans with.
import XCTest
@testable import DictusCore

final class SpeechEnergyProfileTests: XCTestCase {

    func testAPauseOfAtLeast150MillisecondsIsFound() {
        let samples = SyntheticAudio.samples([.speech(1.0), .pause(0.4), .speech(1.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        XCTAssertEqual(profile.pauses.count, 1)
        // The pause sits inside 1.0–1.4 s, minus the smoothing's bleed at each edge.
        let pause = profile.pauses[0]
        XCTAssertGreaterThanOrEqual(pause.lowerBound, 100)
        XCTAssertLessThanOrEqual(pause.upperBound, 140)
        XCTAssertGreaterThanOrEqual(pause.count, 15)
    }

    /// A breath between two words is not a place to cut.
    func testAShortDipIsNotAPause() {
        // The outer pauses give the recording a quiet floor to be measured against.
        let samples = SyntheticAudio.samples([.pause(1.0), .speech(1.0), .pause(0.15), .speech(1.0), .pause(1.0)])
        let pauses = SpeechEnergyProfile(samples: samples).pauses
        XCTAssertEqual(pauses.count, 2, "the two outer pauses only")
        XCTAssertFalse(pauses.contains { $0.contains(207) }, "nothing in the dip at 2.0–2.15 s")
    }

    func testLevelsAdaptToTheRecording() {
        let samples = SyntheticAudio.samples([.speech(2.0), .pause(1.0), .speech(2.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        // Speech at 0.1 amplitude is far above both levels; the quiet tone far below silence.
        XCTAssertEqual(profile.speechThreshold, 0.008, accuracy: 1e-9, "clamped to its ceiling")
        XCTAssertGreaterThan(profile.silenceThreshold, 0.001)
        XCTAssertLessThan(profile.silenceThreshold, 0.07)
    }

    func testDigitalSilenceHasNoSpeech() {
        let profile = SpeechEnergyProfile(samples: SyntheticAudio.samples([.silence(3.0)]))
        XCTAssertEqual(profile.speechFrameCount(fromSeconds: 0, toSeconds: 3, margin: 0.2), 0)
    }

    func testSpeechFramesAreCountedInsideTheMargins() {
        let samples = SyntheticAudio.samples([.pause(1.0), .speech(2.0), .pause(1.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        // 2 s of speech = 200 frames; the 0.2 s margins only cut into the quiet edges.
        XCTAssertEqual(Double(profile.speechFrameCount(fromSeconds: 0, toSeconds: 4, margin: 0.2)), 200, accuracy: 2)
        // A margin larger than the stretch counts nothing rather than crashing.
        XCTAssertEqual(profile.speechFrameCount(fromSeconds: 1, toSeconds: 1.3, margin: 0.2), 0)
    }

    func testCutPointLandsInThePauseNearestThePreferredTime() {
        // Pauses around 1.0–1.4 s and 2.4–2.8 s.
        let samples = SyntheticAudio.samples([.speech(1.0), .pause(0.4), .speech(1.0), .pause(0.4), .speech(1.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        let cut = profile.cutPoint(low: 0, high: 3.5, preferred: 2.5, fallbackLow: 0, fallbackHigh: 3.5)
        let seconds = Double(cut) / 16_000
        XCTAssertGreaterThan(seconds, 2.4)
        XCTAssertLessThan(seconds, 2.8)
        XCTAssertEqual(cut % 1_280, 0, "on the 80 ms encoder grid")
    }

    func testCutPointIgnoresAPauseOutsideTheRange() {
        let samples = SyntheticAudio.samples([.pause(1.0), .speech(1.0), .pause(0.4), .speech(3.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        // The pauses are at 0–1 s and ~2.2 s, outside [3, 4]: fall back to the quietest frame in [3.2, 3.6].
        let cut = profile.cutPoint(low: 3, high: 4, preferred: 3.5, fallbackLow: 3.2, fallbackHigh: 3.6)
        let seconds = Double(cut) / 16_000
        XCTAssertGreaterThanOrEqual(seconds, 3.2)
        XCTAssertLessThanOrEqual(seconds, 3.6)
        XCTAssertEqual(cut % 1_280, 0)
    }

    func testCutPointWithAnEmptyFallbackRangeKeepsThePreferredTime() {
        // Digital silence is one long pause whose quietest point is its first frame, outside [1, 1.5].
        let samples = SyntheticAudio.samples([.silence(2.0)])
        let profile = SpeechEnergyProfile(samples: samples)
        let cut = profile.cutPoint(low: 1, high: 1.5, preferred: 1.0, fallbackLow: 1.5, fallbackHigh: 1.0)
        XCTAssertEqual(cut, 16_640, "1.0 s put on the encoder grid: 12.5 frames rounds to 13")
    }

    func testAlignmentRoundsToTheNearestEncoderFrame() {
        XCTAssertEqual(SpeechEnergyProfile.alignedToEncoderFrame(1_279), 1_280)
        XCTAssertEqual(SpeechEnergyProfile.alignedToEncoderFrame(1_919), 1_280)
        XCTAssertEqual(SpeechEnergyProfile.alignedToEncoderFrame(1_921), 2_560)
        XCTAssertEqual(SpeechEnergyProfile.alignedToEncoderFrame(0), 0)
    }
}
