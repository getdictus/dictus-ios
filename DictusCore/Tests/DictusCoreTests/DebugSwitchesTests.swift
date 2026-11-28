// DictusCore/Tests/DictusCoreTests/DebugSwitchesTests.swift
// The journal's TJ SWITCHES line: its text, where the values come from, when it is written.
#if DEBUG
import XCTest
@testable import DictusCore

final class DebugSwitchesTests: XCTestCase {
    private let suiteName = "dictus.tests.debugSwitches"
    private var defaults: UserDefaults!  // swiftlint:disable:this implicitly_unwrapped_optional
    private let keys = DebugSwitches.keys

    override func setUpWithError() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        DebugSwitches.resetLogged()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        DebugSwitches.resetLogged()
    }

    func testTheLineNamesEachSwitchAndTheSource() {
        let all = DebugSwitches(spatial: true, adaptive: true, bilingual: true, source: .appGroup)
        XCTAssertEqual(all.line, "TJ SWITCHES spatial=on adaptive=on bilingual=on source=appGroup")
        let none = DebugSwitches(spatial: false, adaptive: false, bilingual: false, source: .default)
        XCTAssertEqual(none.line, "TJ SWITCHES spatial=off adaptive=off bilingual=off source=default")
    }

    func testTheSourceIsTheAppGroupOnceAnySwitchWasWritten() {
        XCTAssertEqual(DebugSwitches.source(of: keys, in: defaults), .default)
        // Written off still counts: the value read is the App Group's, not the default.
        defaults.set(false, forKey: SharedKeys.keyboardAdaptiveTouch)
        XCTAssertEqual(DebugSwitches.source(of: keys, in: defaults), .appGroup)
    }

    func testTheLineIsWrittenOncePerStartAndOncePerChange() {
        let on = DebugSwitches(spatial: true, adaptive: false, bilingual: true, source: .appGroup)
        XCTAssertTrue(DebugSwitches.shouldLog(on), "the first appearance")
        XCTAssertFalse(DebugSwitches.shouldLog(on), "the keyboard reappears, nothing changed")
        var off = on
        off.bilingual = false
        XCTAssertTrue(DebugSwitches.shouldLog(off), "a switch changed between appearances")
        XCTAssertFalse(DebugSwitches.shouldLog(off))
    }
}
#endif
