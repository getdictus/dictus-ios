// DictusCore/Tests/DictusCoreTests/CIWiringProbeTests.swift
// TEMPORARY (#534): a deliberately failing test that proves the CI "DictusCore Tests"
// check is wired to the suite. Reverted before merge; never ship this file.
import XCTest

final class CIWiringProbeTests: XCTestCase {

    func testDeliberateFailureProvesCIRunsTheSuite() {
        XCTFail("Deliberate failure for #534: the DictusCore Tests check must go red")
    }
}
