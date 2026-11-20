// DictusCore/Tests/DictusCoreTests/MemoryFootprintTests.swift
// `liveHeapKB` follows what is allocated, not what the allocator keeps (#992).

import XCTest
@testable import DictusCore

final class MemoryFootprintTests: XCTestCase {

    private let blockBytes = 8 * 1024 * 1024
    private let blockKB = 8 * 1024

    func testLiveHeapIsReadable() {
        XCTAssertGreaterThan(MemoryFootprint.liveHeapKB(), 0)
    }

    /// An 8 MB block shows up while held and is gone once freed. A retained buffer, the
    /// thing a leak is, therefore stays visible in this number; freed memory does not.
    func testLiveHeapRisesWhileABlockIsHeldAndFallsWhenItIsFreed() {
        let before = MemoryFootprint.liveHeapKB()

        let block = UnsafeMutableRawPointer.allocate(byteCount: blockBytes, alignment: 16)
        block.initializeMemory(as: UInt8.self, repeating: 1, count: blockBytes)
        let held = MemoryFootprint.liveHeapKB()
        block.deallocate()
        let after = MemoryFootprint.liveHeapKB()

        // Other threads of the test process allocate too: allow 1 MB either way.
        XCTAssertGreaterThanOrEqual(held - before, blockKB - 1024)
        XCTAssertLessThanOrEqual(abs(after - before), 1024)
    }
}
