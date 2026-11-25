// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteClaimTests.swift
import XCTest
@testable import DictusCore

/// One transcriber per shared voice note, and the recovery of a claim the share extension
/// can no longer honour (#1056, #992 review).
final class VoiceNoteClaimTests: XCTestCase {

    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("voice-note-claims-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testFirstClaimWins() {
        let id = UUID()
        XCTAssertEqual(VoiceNoteClaim.claim(id, as: .shareExtension, in: directory), .shareExtension)
        XCTAssertEqual(VoiceNoteClaim.claim(id, as: .app, in: directory), .shareExtension)
        XCTAssertEqual(VoiceNoteClaim.current(id, in: directory), .shareExtension)
    }

    func testClaimingAgainAsTheOwnerStillAnswersTheOwner() {
        let id = UUID()
        XCTAssertEqual(VoiceNoteClaim.claim(id, as: .app, in: directory), .app)
        XCTAssertEqual(VoiceNoteClaim.claim(id, as: .app, in: directory), .app)
    }

    func testUnclaimedNoteHasNoOwner() {
        XCTAssertNil(VoiceNoteClaim.current(UUID(), in: directory))
        XCTAssertNil(VoiceNoteClaim.age(UUID(), in: directory))
    }

    func testConcurrentClaimsHaveExactlyOneWinner() {
        let id = UUID()
        let directory = self.directory!
        let lock = NSLock()
        var winners: [VoiceNoteClaim.Owner] = []
        DispatchQueue.concurrentPerform(iterations: 40) { index in
            let owner: VoiceNoteClaim.Owner = index.isMultiple(of: 2) ? .app : .shareExtension
            let result = VoiceNoteClaim.claim(id, as: owner, in: directory)
            lock.lock()
            if result == owner { winners.append(owner) }
            lock.unlock()
        }
        // Every caller of the winning side reads itself as the owner; the other side never.
        XCTAssertEqual(Set(winners).count, 1)
        XCTAssertEqual(Set(winners).first, VoiceNoteClaim.current(id, in: directory))
    }

    // MARK: - Release

    func testReleaseOnlyByTheOwner() {
        let id = UUID()
        VoiceNoteClaim.claim(id, as: .shareExtension, in: directory)
        XCTAssertFalse(VoiceNoteClaim.release(id, as: .app, in: directory))
        XCTAssertEqual(VoiceNoteClaim.current(id, in: directory), .shareExtension)
        XCTAssertTrue(VoiceNoteClaim.release(id, as: .shareExtension, in: directory))
        XCTAssertNil(VoiceNoteClaim.current(id, in: directory))
    }

    func testReleasedNoteCanBeClaimedByTheApp() {
        // The extension failed and gave the note back: the app transcribes it.
        let id = UUID()
        VoiceNoteClaim.claim(id, as: .shareExtension, in: directory)
        VoiceNoteClaim.release(id, as: .shareExtension, in: directory)
        XCTAssertEqual(VoiceNoteClaim.claim(id, as: .app, in: directory), .app)
    }

    // MARK: - Heartbeat and abandonment

    func testFreshClaimIsInProgress() {
        XCTAssertEqual(VoiceNoteClaim.extensionClaimState(age: 0), .inProgress)
        XCTAssertEqual(VoiceNoteClaim.extensionClaimState(age: 30), .inProgress)
    }

    func testClaimUntouchedPastTheTimeoutIsAbandoned() {
        XCTAssertEqual(VoiceNoteClaim.extensionClaimState(age: 30.5), .abandoned)
        XCTAssertEqual(VoiceNoteClaim.extensionClaimState(age: 3600), .abandoned)
    }

    func testUnreadableAgeIsAbandonedNotAWaitForever() {
        XCTAssertEqual(VoiceNoteClaim.extensionClaimState(age: nil), .abandoned)
    }

    func testTouchResetsTheAge() throws {
        let id = UUID()
        VoiceNoteClaim.claim(id, as: .shareExtension, in: directory)
        let old = Date().addingTimeInterval(-120)
        VoiceNoteClaim.touch(id, in: directory, now: old)
        let staleAge = try XCTUnwrap(VoiceNoteClaim.age(id, in: directory))
        XCTAssertGreaterThan(staleAge, 100)
        VoiceNoteClaim.touch(id, in: directory)
        let freshAge = try XCTUnwrap(VoiceNoteClaim.age(id, in: directory))
        XCTAssertLessThan(freshAge, 5)
    }

    func testAppTakesOverAnAbandonedClaim() {
        let id = UUID()
        VoiceNoteClaim.claim(id, as: .shareExtension, in: directory)
        XCTAssertTrue(VoiceNoteClaim.takeOver(id, in: directory))
        XCTAssertEqual(VoiceNoteClaim.current(id, in: directory), .app)
        // A late extension cannot undo the takeover.
        XCTAssertFalse(VoiceNoteClaim.release(id, as: .shareExtension, in: directory))
        XCTAssertEqual(VoiceNoteClaim.current(id, in: directory), .app)
    }

    // MARK: - Prune

    func testPruneRemovesOnlyOldClaims() {
        let old = UUID()
        let fresh = UUID()
        VoiceNoteClaim.claim(old, as: .app, in: directory)
        VoiceNoteClaim.claim(fresh, as: .shareExtension, in: directory)
        VoiceNoteClaim.touch(old, in: directory, now: Date().addingTimeInterval(-2 * 3600))
        VoiceNoteClaim.prune(in: directory)
        XCTAssertNil(VoiceNoteClaim.current(old, in: directory))
        XCTAssertEqual(VoiceNoteClaim.current(fresh, in: directory), .shareExtension)
    }
}
