// DictusCore/Tests/DictusCoreTests/DriftRetryTests.swift
// The #623 drift retry end to end, with a fake decoder in place of FluidAudio.
import XCTest
@testable import DictusCore

final class DriftRetryTests: XCTestCase {

    /// Counts calls and answers every clip with the same tokens.
    private final class FakeDecoder {
        var calls = 0
        var clipLengths: [Int] = []
        let answer: ([Float]) -> [DriftRetryTokenTiming]

        init(answer: @escaping ([Float]) -> [DriftRetryTokenTiming]) { self.answer = answer }

        func decode(_ clip: [Float]) async throws -> [DriftRetryTokenTiming] {
            calls += 1
            clipLengths.append(clip.count)
            return answer(clip)
        }
    }

    /// 20 one-second stretches, one word in each; the words of stretches 9–14 drifted.
    ///
    /// At 0.77 exactly one six-word window falls under 0.80, so the region is those six
    /// words (~7 s once snapped to pauses): one span, nine decodes.
    private let samples = SyntheticAudio.regularSpeech(stretches: 20)
    private let drifted: Set<Int> = [9, 10, 11, 12, 13, 14]
    private let driftConfidence: Float = 0.77

    private func firstPass(confidence: (Int) -> Float) -> [DriftRetryTokenTiming] {
        SyntheticTokens.timings((0..<20).map { index in
            (text: drifted.contains(index) ? "english\(index)" : "mot\(index)", start: 1.3 * Double(index) + 0.1,
             confidence: confidence(index))
        })
    }

    /// A word every 0.4 s across the whole clip, as a decoder that heard French would answer.
    private func confidentFrench(_ clip: [Float]) -> [DriftRetryTokenTiming] {
        let seconds = Double(clip.count) / 16_000
        return stride(from: 0.0, to: seconds - 0.3, by: 0.4).enumerated().map { index, start in
            DriftRetryTokenTiming(tokenId: 1_000 + index, token: " français", startTime: start, endTime: start + 0.3,
                                  confidence: 0.98)
        }
    }

    // MARK: - Clean

    /// The case that decides the cost: no span, no decode, the first pass byte for byte.
    func testACleanDictationIsNeverReDecoded() async throws {
        let timings = firstPass { _ in 0.99 }
        let text = SyntheticTokens.text(of: timings)
        let decoder = FakeDecoder(answer: confidentFrench)
        let outcome = try await DriftRetry.run(samples: samples, firstPassText: text, firstPassTimings: timings,
                                               decode: decoder.decode)
        XCTAssertEqual(outcome, DriftRetryOutcome(text: text, spans: 0, wins: 0))
        XCTAssertEqual(decoder.calls, 0)
    }

    // MARK: - Drifted

    func testADriftedSpanIsReDecodedNineTimesAndTheConfidentReadingWins() async throws {
        let timings = firstPass { self.drifted.contains($0) ? self.driftConfidence : 0.99 }
        let decoder = FakeDecoder(answer: confidentFrench)
        let outcome = try await DriftRetry.run(samples: samples, firstPassText: SyntheticTokens.text(of: timings),
                                               firstPassTimings: timings, decode: decoder.decode)
        XCTAssertEqual(outcome.spans, 1)
        XCTAssertEqual(outcome.wins, 1)
        XCTAssertEqual(decoder.calls, 9)
        XCTAssertFalse(outcome.text.contains("english"), "the drifted words are gone")
        XCTAssertTrue(outcome.text.contains("français"))
        XCTAssertTrue(outcome.text.hasPrefix("mot0 mot1 mot2 mot3"), "outside the span, the first pass is untouched")
        XCTAssertTrue(outcome.text.hasSuffix("mot17 mot18 mot19"))
        // Every clip fits one encoder window: span ≤ 11 s plus at most 1.44 s on each side.
        XCTAssertTrue(decoder.clipLengths.allSatisfy { $0 <= 240_000 })
    }

    /// When no re-decode beats the first pass, the dictation comes back exactly as it was,
    /// spacing included: the retry spent time and changed nothing.
    func testWhenTheFirstPassWinsTheTextIsUntouched() async throws {
        let timings = firstPass { self.drifted.contains($0) ? self.driftConfidence : 0.99 }
        let text = SyntheticTokens.text(of: timings)
        let decoder = FakeDecoder { clip in
            [DriftRetryTokenTiming(tokenId: 7, token: " bruit", startTime: 0.5, endTime: 0.7, confidence: 0.1)]
        }
        let outcome = try await DriftRetry.run(samples: samples, firstPassText: text, firstPassTimings: timings,
                                               decode: decoder.decode)
        XCTAssertEqual(outcome, DriftRetryOutcome(text: text, spans: 1, wins: 0))
        XCTAssertEqual(decoder.calls, 9)
    }

    func testEmptyReDecodesKeepTheFirstPass() async throws {
        let timings = firstPass { self.drifted.contains($0) ? self.driftConfidence : 0.99 }
        let text = SyntheticTokens.text(of: timings)
        let outcome = try await DriftRetry.run(samples: samples, firstPassText: text, firstPassTimings: timings) { _ in [] }
        XCTAssertEqual(outcome.text, text)
        XCTAssertEqual(outcome.wins, 0)
    }

    // MARK: - Refusals

    /// Timings that do not spell the text would place every span wrong.
    func testTimingsThatDoNotMatchTheTextAreRefusedBeforeAnyDecode() async {
        let timings = firstPass { _ in 0.3 }
        let decoder = FakeDecoder(answer: confidentFrench)
        do {
            _ = try await DriftRetry.run(samples: samples, firstPassText: "autre chose", firstPassTimings: timings,
                                         decode: decoder.decode)
            XCTFail("expected a refusal")
        } catch {
            XCTAssertEqual(error as? DriftRetryError, .firstPassTokensDoNotMatchText)
        }
        XCTAssertEqual(decoder.calls, 0)
    }

    /// No timings at all on a non-empty transcript is the same refusal, not one long gap.
    func testMissingTimingsAreRefused() async {
        do {
            _ = try await DriftRetry.run(samples: samples, firstPassText: "du texte", firstPassTimings: []) { _ in [] }
            XCTFail("expected a refusal")
        } catch {
            XCTAssertEqual(error as? DriftRetryError, .firstPassTokensDoNotMatchText)
        }
    }

    func testADecoderFailureIsThrownToTheCaller() async {
        struct Boom: Error {}
        let timings = firstPass { self.drifted.contains($0) ? self.driftConfidence : 0.99 }
        do {
            _ = try await DriftRetry.run(samples: samples, firstPassText: SyntheticTokens.text(of: timings),
                                         firstPassTimings: timings) { _ in throw Boom() }
            XCTFail("expected the decoder's error")
        } catch {
            XCTAssertTrue(error is Boom)
        }
    }

    func testACancelledTaskStopsBeforeTheFirstSpan() async {
        let timings = firstPass { self.drifted.contains($0) ? self.driftConfidence : 0.99 }
        let text = SyntheticTokens.text(of: timings)
        let samples = self.samples
        let task = Task { () -> Int in
            // Cancelled from inside, before the retry starts: no race with the scheduler.
            withUnsafeCurrentTask { $0?.cancel() }
            var calls = 0
            _ = try await DriftRetry.run(samples: samples, firstPassText: text, firstPassTimings: timings) { _ in
                calls += 1
                return []
            }
            return calls
        }
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError) }
    }
}
