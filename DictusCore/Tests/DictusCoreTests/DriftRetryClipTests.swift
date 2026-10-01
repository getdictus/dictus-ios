// DictusCore/Tests/DictusCoreTests/DriftRetryClipTests.swift
// The nine re-decode clips of a #623 retry span, and what is kept of each.
import XCTest
@testable import DictusCore

final class DriftRetryClipTests: XCTestCase {

    private let second = 16_000

    // MARK: - Grid

    func testASpanGetsNineClipsOfRealAudioAroundIt() {
        let span = DriftSpan(start: 10 * second, end: 15 * second)
        let clips = DriftRetryClip.grid(for: span, totalSamples: 60 * second)
        XCTAssertEqual(clips.count, 9)
        XCTAssertEqual(Set(clips.map(\.start)), [160_000, 160_000 - 7_680, 160_000 - 23_040], "L = 0, 0.48, 1.44 s")
        XCTAssertEqual(Set(clips.map(\.end)), [240_000 + 3_840, 240_000 + 11_520, 240_000 + 23_040], "R = 0.24, 0.72, 1.44 s")
        // Left context outer, right context inner.
        XCTAssertEqual(clips[0].start, 160_000)
        XCTAssertEqual(clips[1].start, 160_000)
        XCTAssertEqual(clips[3].start, 152_320)
    }

    /// The left context is decoded and thrown away, minus the 0.32 s tolerance before the span.
    func testOnlyAClipWithLeftContextDropsTokens() {
        let span = DriftSpan(start: 10 * second, end: 15 * second)
        let clips = DriftRetryClip.grid(for: span, totalSamples: 60 * second)
        XCTAssertNil(clips[0].emitFromFrame, "starts at the span: nothing to drop")
        XCTAssertEqual(clips[3].emitFromFrame, 125 - 4)
        XCTAssertEqual(clips[8].emitFromFrame, 125 - 4)
    }

    func testTheLeftContextStopsAtTheStartOfTheCall() {
        let clips = DriftRetryClip.grid(for: DriftSpan(start: 5_120, end: 5 * second), totalSamples: 60 * second)
        XCTAssertEqual(clips.map(\.start).min(), 0)
        XCTAssertEqual(clips[8].emitFromFrame, 0, "never before the clip's own first frame")
    }

    /// v2: with no audio to the right, the clip end is trimmed instead, so the grid still
    /// holds three distinct ends rather than one end three times.
    func testASpanEndingTheCallTrimsTheClipEndInstead() {
        let total = 20 * second + 333
        let clips = DriftRetryClip.grid(for: DriftSpan(start: 12 * second, end: total), totalSamples: total)
        XCTAssertEqual(clips.map(\.end), [total, total - 3_840, total - 7_680, total, total - 3_840, total - 7_680,
                                          total, total - 3_840, total - 7_680])
    }

    func testAnEndTrimNeverLeavesLessThanHalfASecondOfSpan() {
        let total = 10 * second
        let start = total - 4_000
        let clips = DriftRetryClip.grid(for: DriftSpan(start: start, end: total), totalSamples: total)
        XCTAssertTrue(clips.allSatisfy { $0.end >= start + 8_000 || $0.end == total })
    }

    // MARK: - Samples

    func testAShortClipIsZeroPaddedToOneSecond() {
        let audio = [Float](repeating: 0.5, count: 2 * second)
        let clip = DriftRetryClip(start: 0, end: 4_000, emitFromFrame: nil)
        let samples = clip.samples(from: audio)
        XCTAssertEqual(samples.count, 16_000)
        XCTAssertEqual(samples[3_999], 0.5)
        XCTAssertEqual(samples[4_000], 0)
    }

    /// The edge rule can ask for half a second past a span that ends the call.
    func testAClipNeverReadsPastTheAudio() {
        let audio = [Float](repeating: 0.5, count: 20_000)
        let samples = DriftRetryClip(start: 16_000, end: 24_000, emitFromFrame: nil).samples(from: audio)
        XCTAssertEqual(samples.count, 16_000)
        XCTAssertEqual(samples[3_999], 0.5)
        XCTAssertEqual(samples[4_000], 0)
    }

    // MARK: - Candidate tokens

    private func timing(_ token: String, at seconds: Double, confidence: Float = 0.95) -> DriftRetryTokenTiming {
        DriftRetryTokenTiming(tokenId: 0, token: token, startTime: seconds, endTime: seconds + 0.16, confidence: confidence)
    }

    /// FluidAudio reports a token one frame before the decoder emitted it; the candidate is
    /// placed back on the decoder's frame, in call time.
    func testCandidateTokensAreMovedToTheDecoderFrameInCallTime() {
        let span = DriftSpan(start: 128_000, end: 192_000)  // frames 100..150
        let clip = DriftRetryClip(start: 128_000, end: 196_000, emitFromFrame: nil)
        let pieces = clip.candidate(from: [timing(" bonjour", at: 0.8)], span: span)
        XCTAssertEqual(pieces.map(\.frame), [100 + 10 + 1])
    }

    func testLeftContextTokensAreDropped() {
        let span = DriftSpan(start: 128_000, end: 192_000)  // frames 100..150
        let clip = DriftRetryClip(start: 128_000 - 23_040, end: 196_000, emitFromFrame: 96)  // starts at frame 82
        let pieces = clip.candidate(from: [
            timing(" avant", at: 0.4),      // frame 82 + 5 + 1 = 88: context
            timing(" bord", at: 1.04),      // frame 82 + 13 + 1 = 96: inside the tolerance, kept
            timing(" milieu", at: 2.4),     // frame 82 + 30 + 1 = 113
        ], span: span)
        XCTAssertEqual(pieces.map(\.token), [" bord", " milieu"])
    }

    func testCandidateKeepsWholeWordsWithinTheToleranceOnly() {
        let span = DriftSpan(start: 128_000, end: 192_000)  // frames 100..150
        let clip = DriftRetryClip(start: 128_000, end: 230_000, emitFromFrame: nil)
        let pieces = clip.candidate(from: [
            timing(" dans", at: 3.6),       // frame 100 + 45 + 1 = 146
            timing("ant", at: 4.24),        // 154 finishes a word that started inside: kept
            timing(" proche", at: 4.24),    // 154 = e + 4 frames, the first frame past the tolerance: out
            timing(" loin", at: 5.0),       // 164: out
        ], span: span)
        XCTAssertEqual(pieces.map(\.token), [" dans", "ant"])
    }

    func testALeadingFullStopIsThePreviousSentencesAndIsDropped() {
        let span = DriftSpan(start: 128_000, end: 192_000)
        let clip = DriftRetryClip(start: 128_000, end: 196_000, emitFromFrame: nil)
        let pieces = clip.candidate(from: [timing(".", at: 0.1), timing(" Ensuite", at: 0.4)], span: span)
        XCTAssertEqual(pieces.map(\.token), [" Ensuite"])
    }
}
