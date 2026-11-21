// DictusCore/Tests/DictusCoreTests/WaveformFeedTests.swift
// Tests for WaveformFeed — the in-keyboard waveform must advance with the audio, not with
// how the WebView happens to batch its messages (spike).
import XCTest
@testable import DictusCore

final class WaveformFeedTests: XCTestCase {

    /// A deterministic, speech-like signal: a 220 Hz tone whose loudness swells.
    private func signal(count: Int) -> [Float] {
        (0..<count).map { index in
            let t = Float(index) / 16_000
            return sin(2 * .pi * 220 * t) * (0.1 + 0.3 * abs(sin(2 * .pi * 1.5 * t)))
        }
    }

    /// The defect: the same audio delivered as one burst or as many small chunks must
    /// draw the same bars.
    func testChunkingDoesNotChangeTheLevels() {
        let audio = signal(count: 16_000)
        var oneBurst = WaveformFeed()
        oneBurst.append(audio)

        var smallChunks = WaveformFeed()
        var index = 0
        let sizes = [341, 1024, 4096, 17, 2000, 680]
        var turn = 0
        while index < audio.count {
            let end = min(index + sizes[turn % sizes.count], audio.count)
            smallChunks.append(Array(audio[index..<end]))
            index = end
            turn += 1
        }
        XCTAssertEqual(oneBurst.snapshot(), smallChunks.snapshot())
        XCTAssertEqual(oneBurst.sampleCount, smallChunks.sampleCount)
    }

    /// One app tap buffer, cut as `UnifiedAudioEngine.makeWaveformBuckets` cuts it: six
    /// buckets of 227 samples, then the 3-sample remainder as a seventh.
    func testOneBlockIsCutLikeTheAppTapBuffer() {
        XCTAssertEqual(WaveformFeed.buckets(from: signal(count: WaveformFeed.blockSize)).count, 7)
    }

    func testIncompleteBlockWaits() {
        var feed = WaveformFeed()
        feed.append(signal(count: WaveformFeed.blockSize - 1))
        XCTAssertEqual(feed.snapshot(), Array(repeating: 0, count: WaveformFeed.barCount))
        feed.append(signal(count: 1))
        XCTAssertNotEqual(feed.snapshot(), Array(repeating: 0, count: WaveformFeed.barCount))
    }

    func testSnapshotAlwaysHasThirtyLevelsInRange() {
        var feed = WaveformFeed()
        feed.append(signal(count: 48_000))
        let levels = feed.snapshot()
        XCTAssertEqual(levels.count, WaveformFeed.barCount)
        XCTAssertTrue(levels.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    func testPCM16MatchesFloatInput() {
        let audio = signal(count: 4_000).map { (($0 * 32_768).rounded()) / 32_768 }
        var data = Data()
        for sample in audio {
            var value = Int16(max(-32_768, min(32_767, sample * 32_768))).littleEndian
            data.append(Data(bytes: &value, count: 2))
        }
        var fromFloat = WaveformFeed()
        fromFloat.append(audio)
        var fromPCM = WaveformFeed()
        fromPCM.append(pcm16: data)
        XCTAssertEqual(fromFloat.snapshot(), fromPCM.snapshot())
    }
}
