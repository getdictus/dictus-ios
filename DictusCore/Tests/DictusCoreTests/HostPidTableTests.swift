// DictusCore/Tests/DictusCoreTests/HostPidTableTests.swift
// The table may return nothing; it may never return the wrong thing (#23).
import XCTest
@testable import DictusCore

final class HostPidTableTests: XCTestCase {

    // MARK: - The property the type exists for

    /// The failure this whole design trades away. A pid learned for one app, recycled onto
    /// another, must never answer with the first app — even though nothing has told the
    /// table the process died, because inside a sandboxed extension nothing can.
    func testARecycledPidIsNeverAnsweredWithThePreviousApp() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 44177)
        XCTAssertEqual(table.bundleId(forPid: 44177), "com.apple.mobilenotes")

        // The user moves to another app. Notes dies; iOS hands 44177 to something else.
        // The arbiter is stale and never names the new host, so nothing corrects the
        // entry — which is precisely the case that must not open Notes.
        table.noteAppearance()
        XCTAssertNil(table.bundleId(forPid: 44177))
    }

    /// The same protection has to survive many appearances, not just the next one.
    func testAnOldEntryStaysUntrustedAcrossManyAppearances() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 44177)
        for _ in 0..<10 { table.noteAppearance() }
        XCTAssertNil(table.bundleId(forPid: 44177))
    }

    /// Re-confirmation is what restores trust: the arbiter naming the pid again in the
    /// current appearance is the only evidence available that it still means what it did.
    func testReconfirmationInTheCurrentAppearanceRestoresTheAnswer() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.MobileSMS", forPid: 500)
        table.noteAppearance()
        XCTAssertNil(table.bundleId(forPid: 500))

        table.record(bundleId: "com.apple.MobileSMS", forPid: 500)
        XCTAssertEqual(table.bundleId(forPid: 500), "com.apple.MobileSMS")
    }

    /// A pid the arbiter re-describes is a pid that was reused. The new word wins.
    func testAContradictionReplacesTheOldPairing() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 700)
        table.record(bundleId: "net.whatsapp.WhatsApp", forPid: 700)
        XCTAssertEqual(table.bundleId(forPid: 700), "net.whatsapp.WhatsApp")
    }

    // MARK: - The ordinary path still works

    func testAHostNamedInThisAppearanceIsAnswered() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "net.whatsapp.WhatsApp", forPid: 42)
        XCTAssertEqual(table.bundleId(forPid: 42), "net.whatsapp.WhatsApp")
    }

    func testSeveralHostsCoexistWithinOneAppearance() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 1)
        table.record(bundleId: "com.apple.MobileSMS", forPid: 2)
        XCTAssertEqual(table.bundleId(forPid: 1), "com.apple.mobilenotes")
        XCTAssertEqual(table.bundleId(forPid: 2), "com.apple.MobileSMS")
    }

    func testAnUnknownPidHasNoAnswer() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 1)
        XCTAssertNil(table.bundleId(forPid: 999))
    }

    // MARK: - Rubbish in

    /// An empty identifier or a non-positive pid means the arbiter answered with nothing.
    /// Storing either would put a value in the table that can never be right.
    func testNothingUsefulIsRecorded() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "", forPid: 10)
        table.record(bundleId: "com.apple.mobilenotes", forPid: 0)
        table.record(bundleId: "com.apple.mobilenotes", forPid: -1)
        XCTAssertEqual(table.count, 0)
        XCTAssertNil(table.bundleId(forPid: 10))
        XCTAssertNil(table.bundleId(forPid: 0))
    }

    // MARK: - Bounds and reporting

    func testTheTableIsBounded() {
        var table = HostPidTable()
        table.noteAppearance()
        for pid in 1...(HostPidTable.maxEntries + 20) {
            table.record(bundleId: "com.example.app\(pid)", forPid: pid)
        }
        XCTAssertEqual(table.count, HostPidTable.maxEntries)
        // The oldest went first, and the newest — which is the one about to be looked up
        // in practice — survived.
        XCTAssertNil(table.bundleId(forPid: 1))
        XCTAssertNotNil(table.bundleId(forPid: HostPidTable.maxEntries + 20))
    }

    /// The log line distinguishes "never heard of this process" from "heard of it in an
    /// appearance that has since been retired". Two different stories about one miss.
    func testHistoryOutlivesTrust() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 44177)
        table.noteAppearance()

        XCTAssertNil(table.bundleId(forPid: 44177))
        XCTAssertTrue(table.hasEverSeen(pid: 44177))
        XCTAssertFalse(table.hasEverSeen(pid: 999))
        XCTAssertEqual(table.count, 1)
        XCTAssertEqual(table.trustedCount, 0)
    }

    func testTrustedCountFollowsTheCurrentAppearance() {
        var table = HostPidTable()
        table.noteAppearance()
        table.record(bundleId: "a.b.c", forPid: 1)
        table.record(bundleId: "d.e.f", forPid: 2)
        XCTAssertEqual(table.trustedCount, 2)
        table.noteAppearance()
        XCTAssertEqual(table.trustedCount, 0)
        table.record(bundleId: "a.b.c", forPid: 1)
        XCTAssertEqual(table.trustedCount, 1)
        XCTAssertEqual(table.count, 2)
    }

    /// Nothing is trusted before the first appearance is noted — a harvest that somehow
    /// ran first must not produce an answer out of a generation nobody declared.
    func testAnEntryRecordedBeforeAnyAppearanceIsNotTrustedAfterOne() {
        var table = HostPidTable()
        table.record(bundleId: "com.apple.mobilenotes", forPid: 5)
        table.noteAppearance()
        XCTAssertNil(table.bundleId(forPid: 5))
    }
}
