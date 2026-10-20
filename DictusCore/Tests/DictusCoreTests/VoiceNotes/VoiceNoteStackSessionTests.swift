import XCTest
@testable import DictusCore

/// The sequences of the af1985e5 device test, against the stack contract.
final class VoiceNoteStackSessionTests: XCTestCase {

    /// Notes shared at 1 s intervals, and the unread set the stores would report.
    private struct World {
        var shared: [VoiceNoteStackSession.Entry] = []
        var read: Set<UUID> = []

        mutating func share(_ count: Int) -> [UUID] {
            (0..<count).map { _ in
                let id = UUID()
                shared.append(.init(id: id, sharedAt: Date(timeIntervalSince1970: Double(shared.count))))
                return id
            }
        }

        var unread: [VoiceNoteStackSession.Entry] { shared.filter { !read.contains($0.id) } }
    }

    func testSharingFourShowsOneStackOfFourOldestFirst() {
        var world = World()
        let batch = world.share(4)
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread).cards, batch)
    }

    /// Maintainer decision (2026-10-01): closing marks every presented note read.
    func testDismissingAfterTheFirstCardLeavesNothingFromThatBatch() {
        var world = World()
        _ = world.share(4)
        let first = VoiceNoteStackSession(stackable: world.unread)
        world.read.insert(first.cards[0])            // the card on screen
        first.readOnDismiss.forEach { world.read.insert($0) }  // closed
        XCTAssertTrue(VoiceNoteStackSession(stackable: world.unread).cards.isEmpty)
    }

    func testFourSharedAlwaysMeansFourCards() {
        var world = World()
        _ = world.share(4)
        let first = VoiceNoteStackSession(stackable: world.unread)
        first.readOnDismiss.forEach { world.read.insert($0) }
        let next = world.share(4)
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread).cards, next)
    }

    func testNotesAppendedWhileOpenArePresentedTooAndReadOnClose() {
        var world = World()
        _ = world.share(1)
        var session = VoiceNoteStackSession(stackable: world.unread)
        let later = world.share(2)
        session.append(stackable: world.unread)
        XCTAssertTrue(Set(later).isSubset(of: Set(session.readOnDismiss)))
    }

    func testReadNotesNeverReappear() {
        var world = World()
        let batch = world.share(4)
        batch.forEach { world.read.insert($0) }
        let next = world.share(4)
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread).cards, next)
    }

    func testNotesFinishingWhileOpenAreAppendedOnceInOrder() {
        var world = World()
        let first = world.share(1)
        var session = VoiceNoteStackSession(stackable: world.unread)
        let later = world.share(3)
        // The same note reported twice (queue and History) during the hand-over.
        let duplicated = world.unread + [world.unread[2]]
        XCTAssertEqual(session.append(stackable: duplicated), later)
        XCTAssertEqual(session.cards, first + later)
        XCTAssertTrue(session.append(stackable: world.unread).isEmpty, "no duplicates on a second pass")
    }

    func testCardsReadDuringTheSessionStayUntilItCloses() {
        var world = World()
        let batch = world.share(2)
        var session = VoiceNoteStackSession(stackable: world.unread)
        world.read.insert(batch[0])
        session.append(stackable: world.unread)
        XCTAssertEqual(session.cards, batch, "nothing is removed under the user's finger")
    }

    func testALinkToAReadNoteOpensItAlone() {
        var world = World()
        let batch = world.share(2)
        world.read.insert(batch[0])
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread, focus: batch[0]).cards, [batch[0]])
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread, focus: batch[1]).cards, [batch[1]])
    }

    /// Device test of a5345688: three notes shared within one second were stacked
    /// newest first. Ties keep the order given, which is the share order.
    func testNotesSharedInTheSameSecondStayInShareOrder() {
        let sameSecond = Date(timeIntervalSince1970: 100)
        let ids = [UUID(), UUID(), UUID()]
        let session = VoiceNoteStackSession(stackable: ids.map { .init(id: $0, sharedAt: sameSecond) })
        XCTAssertEqual(session.cards, ids)
    }

    @MainActor
    func testHistoryBreaksSecondTiesByShareOrder() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = TranscriptionHistoryStore(fileURL: url, isEntitled: { true })
        let sameSecond = Date(timeIntervalSince1970: 100)
        // Appended in the order the queue finishes them, which is the share order.
        let shared = (0..<3).map { _ in
            TranscriptionRecord(text: "t", language: "fr", durationSeconds: 1, createdAt: sameSecond,
                                sttProvider: "PK", source: .sharedFile)
        }
        shared.forEach { store.append($0) }
        XCTAssertEqual(store.unreadVoiceNotes.map(\.id), shared.map(\.id))
        // Also after a reload, when the dates have been rounded to the second.
        XCTAssertEqual(TranscriptionHistoryStore(fileURL: url, isEntitled: { true }).unreadVoiceNotes.map(\.id),
                       shared.map(\.id))
    }

    func testVoiceNoteFilesKeepSubSecondShareTimesAndReadOldOnes() throws {
        let drop = VoiceNoteDrop(receivedAt: Date(timeIntervalSince1970: 100.25), format: .ogg, durationSeconds: nil)
        let decoded = try JSONDecoder.voiceNotes.decode(VoiceNoteDrop.self, from: JSONEncoder.voiceNotes.encode(drop))
        XCTAssertEqual(decoded.receivedAt.timeIntervalSince1970, 100.25, accuracy: 0.001)
        let old = #"{"id":"\#(UUID().uuidString)","receivedAt":"2026-10-01T20:50:37Z","format":"ogg"}"#
        XCTAssertNoThrow(try JSONDecoder.voiceNotes.decode(VoiceNoteDrop.self, from: Data(old.utf8)))
    }
}
