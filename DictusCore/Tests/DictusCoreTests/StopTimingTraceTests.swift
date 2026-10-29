// DictusCore/Tests/DictusCoreTests/StopTimingTraceTests.swift
// Tests for the stop-to-transcription timing trace (#862).
//
// What a reader of the log sees is one `stopTiming` line per step, each carrying the
// milliseconds since the keyboard's stop tap. These pin the arithmetic, the line, and
// the App Group hand-off that lets the app measure against the keyboard's tap.
import XCTest
@testable import DictusCore

final class StopTimingTraceTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        // A fresh, non-App-Group suite: the App Group container can hang `swift test` (#560).
        suiteName = "StopTimingTraceTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testSinceTapIsMillisecondsFromTheTap() {
        let tap = Date(timeIntervalSince1970: 1_800_000_000)
        let trace = StopTimingTrace.tapped(sessionID: "757C4494", at: tap)
        XCTAssertEqual(trace.sinceTapMs(at: tap), 0)
        XCTAssertEqual(trace.sinceTapMs(at: tap.addingTimeInterval(0.0379)), 37)
        XCTAssertEqual(trace.sinceTapMs(at: tap.addingTimeInterval(1.2)), 1200)
    }

    /// A wall clock that moved backwards shows as a negative number, not as zero.
    func testClockMovedBackIsReportedNotHidden() {
        let tap = Date(timeIntervalSince1970: 1_800_000_000)
        let trace = StopTimingTrace.tapped(sessionID: "757C4494", at: tap)
        XCTAssertEqual(trace.sinceTapMs(at: tap.addingTimeInterval(-0.25)), -250)
    }

    func testLineCarriesStepDelayAndSessionOnly() {
        let tap = Date(timeIntervalSince1970: 1_800_000_000)
        let event = StopTimingTrace.tapped(sessionID: "757C4494", at: tap)
            .event("samplesCollected", at: tap.addingTimeInterval(0.084))
        XCTAssertEqual(event.name, "stopTiming")
        XCTAssertEqual(event.subsystem, .dictation)
        XCTAssertEqual(event.level, .info)
        XCTAssertEqual(event.message, "step=samplesCollected sinceTapMs=84 sessionID=757C4494")
        let line = event.formatted()
        XCTAssertTrue(line.contains("INFO    [dictation] <"))
        XCTAssertTrue(line.hasSuffix("> stopTiming step=samplesCollected sinceTapMs=84 sessionID=757C4494"))
    }

    /// The app reads the tap the keyboard wrote, to the millisecond.
    func testHandOffRoundTripsThroughDefaults() {
        let written = StopTimingTrace(sessionID: "757C4494", tapEpoch: 1_800_000_000.123)
        written.write(to: defaults)
        let read = StopTimingTrace.take(from: defaults)
        XCTAssertEqual(read, written)
        XCTAssertEqual(read?.sinceTapMs(at: Date(timeIntervalSince1970: 1_800_000_000.5)), 377)
    }

    /// Taking the trace consumes it: a later stop that wrote none is not measured
    /// against an old tap.
    func testTakeConsumesTheTrace() {
        StopTimingTrace(sessionID: "757C4494", tapEpoch: 1_800_000_000).write(to: defaults)
        XCTAssertNotNil(StopTimingTrace.take(from: defaults))
        XCTAssertNil(StopTimingTrace.take(from: defaults))
        XCTAssertNil(defaults.object(forKey: SharedKeys.stopTapEpoch))
        XCTAssertNil(defaults.object(forKey: SharedKeys.stopTapSessionID))
    }

    func testNoTraceWhenNothingWasWritten() {
        XCTAssertNil(StopTimingTrace.take(from: defaults))
    }
}
