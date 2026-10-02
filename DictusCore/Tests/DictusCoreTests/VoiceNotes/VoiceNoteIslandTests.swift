import XCTest
@testable import DictusCore

/// The island design of #620 (grilled 2026-10-01): the ring's set, batches, the
/// alert policy, and who draws the island for each dictation phase.
final class VoiceNoteIslandTests: XCTestCase {

    // MARK: - Ring

    func testOneSegmentPerNoteInShareOrderWithTheReadyCountInTheCentre() {
        var island = VoiceNoteIsland()
        let first = UUID(), second = UUID(), third = UUID()
        [first, second, third].forEach { island.add($0) }
        island.finish(second, succeeded: true)
        island.finish(third, succeeded: false)
        XCTAssertEqual(island.segments, [.pending, .ready, .failed])
        XCTAssertEqual(island.readyCount, 1)
        XCTAssertEqual(island.failedCount, 1)
    }

    func testReadingDecrementsAndTheRingGoesWhenAllIsRead() {
        var island = VoiceNoteIsland()
        let first = UUID(), second = UUID()
        island.add(first); island.add(second)
        island.finish(first, succeeded: true)
        island.finish(second, succeeded: true)
        XCTAssertEqual(island.readyCount, 2)
        island.markRead(first)
        XCTAssertEqual(island.readyCount, 1)
        island.markRead(second)
        XCTAssertTrue(island.isEmpty)
    }

    func testARunningNoteCannotBeReadAway() {
        var island = VoiceNoteIsland()
        let running = UUID()
        island.add(running)
        island.markRead(running)
        XCTAssertEqual(island.segments, [.pending])
    }

    func testTheReadyStateTimesOutButPendingNotesStay() {
        var island = VoiceNoteIsland()
        let done = UUID(), running = UUID()
        island.add(done); island.add(running)
        island.finish(done, succeeded: true)
        island.expireFinished()
        XCTAssertEqual(island.segments, [.pending])
        XCTAssertEqual(VoiceNoteIsland.readyLifetime, 300)
        XCTAssertEqual(VoiceNoteIsland.receivedDelay, 3)
    }

    // MARK: - Batches and the alert

    func testABatchDrainsWhenTheLastPendingNoteFinishes() {
        var island = VoiceNoteIsland()
        let first = UUID(), second = UUID()
        island.add(first); island.add(second)
        XCTAssertEqual(island.batch, 1, "both notes are one batch")
        XCTAssertFalse(island.finish(first, succeeded: true))
        XCTAssertTrue(island.finish(second, succeeded: false))
        XCTAssertTrue(island.batchSucceeded)

        island.add(UUID())
        XCTAssertEqual(island.batch, 2, "a note after the drain starts a new batch")
        XCTAssertFalse(island.batchSucceeded)
    }

    func testOneAlertPerBatchNeverPerNoteNeverOnReplay() {
        // Not drained: the first of two notes finishing does not alert.
        XCTAssertEqual(VoiceNoteAlertPolicy.decide(drained: false, batchSucceeded: true,
                                                   alreadyAlerted: false, dictationActive: false), .none)
        XCTAssertEqual(VoiceNoteAlertPolicy.decide(drained: true, batchSucceeded: true,
                                                   alreadyAlerted: false, dictationActive: false), .now)
        // Replay of the same batch.
        XCTAssertEqual(VoiceNoteAlertPolicy.decide(drained: true, batchSucceeded: true,
                                                   alreadyAlerted: true, dictationActive: false), .none)
        // Failures only: segments turn red, nothing expands.
        XCTAssertEqual(VoiceNoteAlertPolicy.decide(drained: true, batchSucceeded: false,
                                                   alreadyAlerted: false, dictationActive: false), .none)
    }

    func testTheAlertWaitsForARunningDictation() {
        XCTAssertEqual(VoiceNoteAlertPolicy.decide(drained: true, batchSucceeded: true,
                                                   alreadyAlerted: false, dictationActive: true), .afterDictation)
    }

    // MARK: - Who draws the island

    private let ready = VoiceNoteActivityContent(segments: [.ready])
    private let failed = VoiceNoteActivityContent(segments: [.ready, .failed])
    private let empty = VoiceNoteActivityContent(segments: [])

    /// Dictation behaves exactly as before #620 whenever no voice note is there.
    func testWithoutVoiceNotesEveryPhaseIsTheDictations() {
        for phase in [LiveActivityStateMachine.Phase.idle, .standby, .recording, .transcribing,
                      .processing, .ready, .failed] {
            XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: phase, voiceNote: nil), .dictation, "\(phase)")
            XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: phase, voiceNote: empty), .dictation, "\(phase)")
        }
    }

    func testAnActiveDictationOwnsTheIslandOverAnyVoiceNote() {
        for phase in [LiveActivityStateMachine.Phase.recording, .transcribing, .processing, .failed] {
            XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: phase, voiceNote: ready), .dictation, "\(phase)")
            XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: phase, voiceNote: failed), .dictation, "\(phase)")
        }
    }

    func testAVoiceNoteFailureBeatsTheDictationsSuccessButASuccessDoesNot() {
        XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: .ready, voiceNote: failed), .voiceNotes)
        XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: .ready, voiceNote: ready), .dictation)
    }

    func testStandbyBelongsToTheVoiceNotes() {
        XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: .standby, voiceNote: ready), .voiceNotes)
        XCTAssertEqual(LiveActivityRenderOwner.resolve(phase: .standby,
                                                       voiceNote: VoiceNoteActivityContent(segments: [.pending])), .voiceNotes)
    }

    // MARK: - Content

    func testContentCounts() {
        let content = VoiceNoteActivityContent(segments: [.ready, .pending, .failed, .ready])
        XCTAssertEqual(content.readyCount, 2)
        XCTAssertEqual(content.failedCount, 1)
        XCTAssertFalse(content.allFinished)
        XCTAssertTrue(VoiceNoteActivityContent(segments: [.ready, .failed]).allFinished)
    }

    func testTheEngineTimeoutHasOneHome() {
        XCTAssertEqual(WarmEngineTimeout.interval, 600)
    }
}
