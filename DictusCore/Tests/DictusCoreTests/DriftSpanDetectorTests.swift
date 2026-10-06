// DictusCore/Tests/DictusCoreTests/DriftSpanDetectorTests.swift
// Which stretches of a Parakeet first pass the #623 retry re-decodes.
import XCTest
@testable import DictusCore

final class DriftSpanDetectorTests: XCTestCase {

    // MARK: - Helpers

    /// One word per speech stretch of `SyntheticAudio.regularSpeech`, 0.1 s into it.
    private func pieces(stretches: Int, confidence: (Int) -> Float = { _ in 0.99 },
                        skipping skipped: Set<Int> = []) -> [DriftRetryPiece] {
        (0..<stretches).filter { !skipped.contains($0) }.map { index in
            let timing = DriftRetryTokenTiming(tokenId: index, token: " mot\(index)", startTime: 1.3 * Double(index) + 0.1,
                                               endTime: 1.3 * Double(index) + 0.5, confidence: confidence(index))
            return DriftRetryPiece(firstPass: timing)
        }
    }

    private func spans(_ pieces: [DriftRetryPiece], _ samples: [Float]) -> [DriftSpan] {
        DriftSpanDetector.spans(pieces: pieces, energy: SpeechEnergyProfile(samples: samples), totalSamples: samples.count)
    }

    private func isInPause(_ sample: Int, _ samples: [Float]) -> Bool {
        let frame = sample / SpeechEnergyProfile.hop
        return SpeechEnergyProfile(samples: samples).pauses.contains { $0.contains(frame) }
    }

    // MARK: - Words

    func testAWordIsItsPiecesWithTheMinimumConfidenceAndNoPunctuation() {
        let words = DriftSpanDetector.words(of: [
            SyntheticTokens.piece(" bon", frame: 0, confidence: 0.9),
            SyntheticTokens.piece("jour", frame: 2, confidence: 0.4),
            SyntheticTokens.piece(",", frame: 4, confidence: 0.1),
            SyntheticTokens.piece(" monde", frame: 6, confidence: 0.95),
        ])
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].confidence, 0.4, "the weakest piece, never the comma")
        XCTAssertEqual(words[0].start, 0, accuracy: 1e-9)
        XCTAssertEqual(words[0].end, 0.32, accuracy: 1e-9, "last piece start + its duration")
        XCTAssertEqual(words[1].confidence, 0.95)
    }

    // MARK: - No trigger

    /// The clean case, and the one that decides the cost: nothing to re-decode.
    func testAConfidentTranscriptHasNoSpan() {
        let samples = SyntheticAudio.regularSpeech(stretches: 12)
        XCTAssertTrue(spans(pieces(stretches: 12), samples).isEmpty)
    }

    /// #554 logged 0.512 on a one-word dictation: a flat threshold would retry every one.
    func testFewerThanThreeWordsNeverTrigger() {
        let samples = SyntheticAudio.regularSpeech(stretches: 2)
        XCTAssertTrue(spans(pieces(stretches: 2, confidence: { _ in 0.1 }), samples).isEmpty)
    }

    func testOneWeakWordAmongConfidentOnesDoesNotTrigger() {
        let samples = SyntheticAudio.regularSpeech(stretches: 12)
        XCTAssertTrue(spans(pieces(stretches: 12, confidence: { $0 == 5 ? 0.3 : 0.99 }), samples).isEmpty)
    }

    // MARK: - Confidence region

    func testALowConfidenceRunBecomesOneSpanEdgedOnPauses() throws {
        let samples = SyntheticAudio.regularSpeech(stretches: 20)
        // Six words at 0.77: exactly one six-word window falls under 0.80.
        let low = 9...14
        let result = spans(pieces(stretches: 20, confidence: { low.contains($0) ? 0.77 : 0.99 }), samples)
        XCTAssertEqual(result.count, 1)
        let span = try XCTUnwrap(result.first)
        // Covers the weak words, starts and ends in a pause, on the 80 ms grid.
        XCTAssertLessThanOrEqual(Double(span.start) / 16_000, 1.3 * 9 + 0.1)
        XCTAssertGreaterThanOrEqual(Double(span.end) / 16_000, 1.3 * 14 + 0.5)
        XCTAssertGreaterThan(Double(span.start) / 16_000, 1.3 * 8 + 0.5, "the confident word before stays out")
        XCTAssertTrue(isInPause(span.start, samples))
        XCTAssertTrue(isInPause(span.end, samples))
        XCTAssertEqual(span.start % 1_280, 0)
        XCTAssertEqual(span.end % 1_280, 0)
    }

    /// Every window touching a run of weak words is marked, so the region spreads past
    /// them; long enough, it is split rather than re-decoded in one clip.
    func testAWideLowConfidenceRegionIsSplit() {
        let samples = SyntheticAudio.regularSpeech(stretches: 20)
        let result = spans(pieces(stretches: 20, confidence: { (9...11).contains($0) ? 0.3 : 0.99 }), samples)
        XCTAssertEqual(result.count, 2, "words 5–15 marked: ~13 s, over the 11 s ceiling")
    }

    func testRegionsCloserThanHalfASecondMerge() {
        // Two weak runs of three words, separated by confident words packed into 0.4 s.
        var words: [DriftSpanDetector.Word] = []
        for index in 0..<10 { words.append(.init(start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4, confidence: (3...5).contains(index) ? 0.1 : 0.99)) }
        for index in 0..<7 { words.append(.init(start: 4.9 + Double(index) * 0.05, end: 4.95 + Double(index) * 0.05, confidence: 0.99)) }
        for index in 0..<10 { words.append(.init(start: 5.6 + Double(index) * 0.5, end: 6.0 + Double(index) * 0.5, confidence: (3...5).contains(index) ? 0.1 : 0.99)) }
        let separate = DriftSpanDetector.confidenceRegions(words: words)
        XCTAssertEqual(separate.count, 2, "two runs of marked words")
        let silence = SpeechEnergyProfile(samples: SyntheticAudio.samples([.silence(12)]))
        let merged = DriftSpanDetector.regions(words: words, energy: silence, duration: 12)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.start, separate.first?.start)
        XCTAssertEqual(merged.first?.end, separate.last?.end)
    }

    // MARK: - Gap region

    /// Dropped content: speech the first pass emitted nothing for.
    func testAWordFreeStretchHoldingSpeechIsASpan() throws {
        let samples = SyntheticAudio.regularSpeech(stretches: 12)
        let result = spans(pieces(stretches: 12, skipping: [4, 5, 6]), samples)
        XCTAssertEqual(result.count, 1)
        let span = try XCTUnwrap(result.first)
        XCTAssertLessThanOrEqual(Double(span.start) / 16_000, 1.3 * 4)
        XCTAssertGreaterThanOrEqual(Double(span.end) / 16_000, 1.3 * 6 + 1.0)
    }

    func testAWordFreeStretchOfSilenceIsNotASpan() {
        let samples = SyntheticAudio.samples([.speech(1.0), .pause(4.0), .speech(1.0)])
        let words = [
            DriftRetryPiece(firstPass: DriftRetryTokenTiming(tokenId: 0, token: " un", startTime: 0.1, endTime: 0.9, confidence: 0.99)),
            DriftRetryPiece(firstPass: DriftRetryTokenTiming(tokenId: 1, token: " deux", startTime: 5.1, endTime: 5.9, confidence: 0.99)),
        ]
        XCTAssertTrue(spans(words, samples).isEmpty)
    }

    func testAGapShorterThanTwoSecondsIsNotASpan() {
        let samples = SyntheticAudio.regularSpeech(stretches: 12)
        // The 2.2 s hole around a skipped stretch holds ~1.3 s of speech, under the 1.5 s floor.
        XCTAssertTrue(spans(pieces(stretches: 12, skipping: [5]), samples).isEmpty)
    }

    /// A first pass that returned nothing over audible speech is one long gap.
    func testAnEmptyFirstPassOverSpeechIsRetried() {
        let samples = SyntheticAudio.regularSpeech(stretches: 4)
        XCTAssertFalse(spans([], samples).isEmpty)
    }

    func testAnEmptyFirstPassOverSilenceIsNot() {
        XCTAssertTrue(spans([], SyntheticAudio.samples([.silence(2.0)])).isEmpty, "the warm inference's case")
    }

    // MARK: - Span geometry

    func testARegionReachingTheEndKeepsTheEndOfTheCall() throws {
        let samples = SyntheticAudio.regularSpeech(stretches: 12)
        // The last three stretches have no word: a gap region that ends at the end of the call.
        let result = spans(pieces(stretches: 12, skipping: [9, 10, 11]), samples)
        let last = try XCTUnwrap(result.last)
        XCTAssertEqual(last.end, samples.count)
    }

    func testALongSpanIsSplitIntoPiecesThatFitTheModelWindow() {
        let samples = SyntheticAudio.regularSpeech(stretches: 24)
        let result = spans(pieces(stretches: 24, confidence: { _ in 0.2 }), samples)
        XCTAssertGreaterThan(result.count, 2)
        for span in result {
            let seconds = Double(span.end - span.start) / 16_000
            XCTAssertLessThanOrEqual(seconds, 11.0)
            XCTAssertGreaterThanOrEqual(seconds, 2.0 - 0.08, "never a sliver")
        }
        for (left, right) in zip(result, result.dropFirst()) {
            XCTAssertEqual(left.end, right.start, "split pieces stay contiguous")
        }
    }
}
