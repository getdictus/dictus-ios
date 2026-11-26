// DictusCore/Tests/DictusCoreTests/StopPostRollTests.swift
// The audio a stop keeps after its tap (#1085).
import XCTest
@testable import DictusCore

/// A tap that delivers 4096-frame buffers at 48 kHz (85.3 ms each), the shape of the real
/// one, with the main-thread gate the engine applies: a buffer is accumulated only while
/// the recording is open. The clock advances 10 ms per poll, like the real wait's sleep.
@MainActor
private final class FakeTap {
    static let bufferSeconds = 4096.0 / 48_000.0

    var clock: TimeInterval
    /// End of the next buffer the hardware will deliver.
    var nextBufferEnd: TimeInterval
    /// How long after its last sample a buffer reaches the main thread.
    let deliveryLatency: TimeInterval
    var deliversBuffers = true

    var isRecording = true
    var epoch = 0
    var accumulatedEnds: [TimeInterval] = []
    var collections = 0
    var polls = 0
    /// Runs at a given poll, to put a cancel or another stop in the middle of the wait.
    var onPoll: [Int: () -> Void] = [:]

    init(clock: TimeInterval, nextBufferEnd: TimeInterval, deliveryLatency: TimeInterval = 0.012) {
        self.clock = clock
        self.nextBufferEnd = nextBufferEnd
        self.deliveryLatency = deliveryLatency
    }

    func advance() {
        polls += 1
        clock += 0.010
        while deliversBuffers, nextBufferEnd + deliveryLatency <= clock {
            if isRecording { accumulatedEnds.append(nextBufferEnd) }
            nextBufferEnd += Self.bufferSeconds
        }
        onPoll[polls]?()
    }

    /// What `UnifiedAudioEngine.collectSamples()` does to the gate.
    func collect() {
        collections += 1
        epoch += 1
        isRecording = false
    }

    func wait(_ postRoll: StopPostRoll) async -> StopPostRoll.Outcome {
        let epochAtStop = epoch
        return await postRoll.wait(
            lastBufferEndEpoch: { self.accumulatedEnds.last },
            inputLive: { self.isRecording },
            isStillThisRecording: { self.epoch == epochAtStop },
            now: { self.clock },
            sleep: { self.advance() }
        )
    }
}

@MainActor
final class StopPostRollTests: XCTestCase {
    private let tap: TimeInterval = 1_800_000_000

    func testDeadlineIsThreeHundredMsAfterTheTap() {
        let postRoll = StopPostRoll(tapEpoch: tap, startEpoch: tap + 0.02)
        XCTAssertNil(postRoll.end(lastBufferEndEpoch: tap + 0.299, inputLive: true, now: tap + 0.31))
        XCTAssertEqual(postRoll.end(lastBufferEndEpoch: tap + 0.300, inputLive: true, now: tap + 0.31), .deadline)
    }

    /// The bug: a buffer still being filled at the tap was dropped. Here it ends 40 ms after
    /// the tap, holds the last 85 ms of speech before it, and must be in the recording, along
    /// with everything up to 300 ms after the tap.
    func testKeepsTheBufferInFlightAtTheTapAndTheWholeMargin() async {
        // Stop handled 20 ms after the tap, like `sinceTapMs=9..39` in the log.
        let fake = FakeTap(clock: tap + 0.020, nextBufferEnd: tap + 0.040)
        fake.accumulatedEnds = [tap + 0.040 - FakeTap.bufferSeconds]
        let postRoll = StopPostRoll(tapEpoch: tap, startEpoch: fake.clock)

        let outcome = await fake.wait(postRoll)

        XCTAssertEqual(outcome, .ended(.deadline))
        XCTAssertTrue(fake.accumulatedEnds.contains(tap + 0.040), "the in-flight buffer was dropped")
        let kept = postRoll.keptAfterTapMs(lastBufferEndEpoch: fake.accumulatedEnds.last) ?? -1
        XCTAssertGreaterThanOrEqual(kept, 300)
        XCTAssertLessThan(kept, 300 + Int(FakeTap.bufferSeconds * 1000) + 1)
        // Ends on the first buffer past the deadline, plus the delivery latency and one poll.
        XCTAssertLessThanOrEqual(fake.clock - tap, Double(kept) / 1000 + 0.012 + 0.010 + 0.001)
    }

    /// A cancel during the post-roll takes the recording: the wait gives it up and the stop
    /// collects nothing, so the cancel's own collection is the only one.
    func testCancelDuringThePostRollAbandonsIt() async {
        let fake = FakeTap(clock: tap + 0.020, nextBufferEnd: tap + 0.040)
        fake.onPoll[5] = { fake.collect() }  // `cancelDictation` → `collectSamples()`
        let outcome = await fake.wait(StopPostRoll(tapEpoch: tap, startEpoch: fake.clock))

        XCTAssertEqual(outcome, .abandoned)
        XCTAssertEqual(fake.collections, 1)
        XCTAssertEqual(fake.polls, 5)
    }

    /// `cancelDictation` also cancels the stop's task: that alone ends the wait.
    func testCancelledTaskAbandonsAtOnce() async {
        let fake = FakeTap(clock: tap, nextBufferEnd: tap + 0.040)
        let postRoll = StopPostRoll(tapEpoch: tap, startEpoch: tap)
        let task = Task { await fake.wait(postRoll) }
        task.cancel()
        let outcome = await task.value
        XCTAssertEqual(outcome, .abandoned)
    }

    /// A new recording started during the post-roll (the coordinator refuses one, this is
    /// the engine's own guard) is not this stop's: its samples are never collected by it.
    func testRecordingReplacedDuringThePostRollIsNotCollected() async {
        let fake = FakeTap(clock: tap + 0.020, nextBufferEnd: tap + 0.040)
        fake.onPoll[3] = {
            fake.collect()
            fake.epoch += 1  // `startRecording`
            fake.isRecording = true
        }
        let outcome = await fake.wait(StopPostRoll(tapEpoch: tap, startEpoch: fake.clock))
        XCTAssertEqual(outcome, .abandoned)
    }

    /// An interruption tears the input down before it stops the dictation: nothing more can
    /// arrive, so the stop collects at once what the recording holds.
    func testInputAlreadyStoppedEndsWithoutWaiting() async {
        let fake = FakeTap(clock: tap + 0.005, nextBufferEnd: tap + 0.040)
        fake.isRecording = false
        let outcome = await fake.wait(StopPostRoll(tapEpoch: tap, startEpoch: fake.clock))
        XCTAssertEqual(outcome, .ended(.inputStopped))
        XCTAssertEqual(fake.polls, 0)
    }

    /// Buffers that stop arriving (a dead engine) end the wait 400 ms past the deadline.
    func testGivesUpWhenNoBufferReachesTheDeadline() async {
        let fake = FakeTap(clock: tap + 0.020, nextBufferEnd: tap + 0.040)
        fake.deliversBuffers = false
        let outcome = await fake.wait(StopPostRoll(tapEpoch: tap, startEpoch: fake.clock))
        XCTAssertEqual(outcome, .ended(.timeout))
        XCTAssertEqual(fake.clock - tap, 0.700, accuracy: 0.011)
    }

    /// A tap the app heard 2 s late: its deadline is behind it, and the buffer it already
    /// holds proves the margin, so the stop does not wait at all.
    func testLateTapWithTheMarginAlreadyRecordedDoesNotWait() async {
        let fake = FakeTap(clock: tap + 2.0, nextBufferEnd: tap + 2.05)
        fake.accumulatedEnds = [tap + 1.96]
        let postRoll = StopPostRoll(tapEpoch: tap, startEpoch: fake.clock)
        let outcome = await fake.wait(postRoll)
        XCTAssertEqual(outcome, .ended(.deadline))
        XCTAssertEqual(fake.polls, 0)
        XCTAssertEqual(postRoll.giveUpEpoch, tap + 2.4, accuracy: 1e-9)
    }

    func testLogLine() {
        let postRoll = StopPostRoll(tapEpoch: tap, startEpoch: tap + 0.02)
        let event = postRoll.event(lastBufferEndEpoch: tap + 0.3417, buffers: 4, outcome: .ended(.deadline), sessionID: "757C4494")
        XCTAssertEqual(event.name, "stopTiming")
        XCTAssertEqual(event.subsystem, .dictation)
        XCTAssertEqual(event.message, "step=postRoll keptAfterTapMs=341 buffers=4 ended=deadline sessionID=757C4494")

        let none = postRoll.event(lastBufferEndEpoch: nil, buffers: 0, outcome: .abandoned, sessionID: "app")
        XCTAssertEqual(none.message, "step=postRoll keptAfterTapMs=none buffers=0 ended=abandoned sessionID=app")
    }
}
