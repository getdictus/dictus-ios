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

    func testDismissingAfterTheFirstCardLeavesThreeForTheNextActivation() {
        var world = World()
        let batch = world.share(4)
        let first = VoiceNoteStackSession(stackable: world.unread)
        world.read.insert(first.cards[0])       // the card on screen
        XCTAssertEqual(VoiceNoteStackSession(stackable: world.unread).cards, Array(batch.dropFirst()))
    }

    func testFourMoreAfterThreeGenuinelyUnseenMakesSevenAndNoMore() {
        var world = World()
        let batch = world.share(4)
        world.read.insert(batch[0])
        let next = world.share(4)
        let session = VoiceNoteStackSession(stackable: world.unread)
        XCTAssertEqual(session.cards, Array(batch.dropFirst()) + next)
        XCTAssertEqual(session.cards.count, 7)
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
}
