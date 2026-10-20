// DictusCore/Tests/DictusCoreTests/ProScanGenerationTests.swift
// Only the latest of several overlapping entitlement scans publishes (#216).
import XCTest
@testable import DictusCore

final class ProScanGenerationTests: XCTestCase {

    func testASingleScanPublishes() {
        var generations = ProScanGeneration()
        let only = generations.begin()
        XCTAssertTrue(generations.mayPublish(only))
    }

    /// The race CodeRabbit found: an older scan finishing after a newer one started
    /// must not publish, whatever order they finish in.
    func testAnOlderScanFinishingLastIsDiscarded() {
        var generations = ProScanGeneration()
        let older = generations.begin()
        let newer = generations.begin()
        XCTAssertTrue(generations.mayPublish(newer))
        XCTAssertFalse(generations.mayPublish(older))
    }

    func testEachNewScanSupersedesTheLast() {
        var generations = ProScanGeneration()
        let first = generations.begin()
        let second = generations.begin()
        let third = generations.begin()
        XCTAssertEqual([first, second, third].map(generations.mayPublish), [false, false, true])
    }
}
