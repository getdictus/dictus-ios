// DictusCore/Tests/DictusCoreTests/Polish/InFlightCallsTests.swift
import XCTest
@testable import DictusCore

/// The voice note card's guard against running its mode twice (#648, 2026-10-09: a card
/// rebuilt while the mode was running started a second run that superseded the first).
@MainActor
final class InFlightCallsTests: XCTestCase {

    func testASecondCallerForTheSameKeyAwaitsTheFirstRunInsteadOfStartingOne() async {
        let calls = InFlightCalls<String, Int>()
        var started = 0
        let gate = AsyncGate()
        async let first = calls.run("note-mode") {
            started += 1
            await gate.wait()
            return 42
        }
        await Task.yield()
        XCTAssertTrue(calls.isRunning("note-mode"))
        async let second = calls.run("note-mode") {
            started += 1
            return -1
        }
        await Task.yield()
        gate.open()
        let results = await [first, second]
        XCTAssertEqual(results, [42, 42])
        XCTAssertEqual(started, 1)
        XCTAssertFalse(calls.isRunning("note-mode"))
    }

    func testDifferentKeysRunIndependently() async {
        let calls = InFlightCalls<String, String>()
        async let one = calls.run("note-A") { "A" }
        async let two = calls.run("note-B") { "B" }
        let results = await [one, two]
        XCTAssertEqual(results, ["A", "B"])
    }

    /// Once a run is over, the same key runs again: a retry after a failure is a new run.
    func testAFinishedKeyRunsAgain() async {
        let calls = InFlightCalls<String, Int>()
        var started = 0
        _ = await calls.run("k") { started += 1; return 1 }
        _ = await calls.run("k") { started += 1; return 2 }
        XCTAssertEqual(started, 2)
    }
}

/// A one-shot latch the test opens by hand.
@MainActor
private final class AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
