// DictusCore/Tests/DictusCoreTests/Polish/SmartModeAvailabilityDebugOverrideTests.swift
// The Debug-only Apple Intelligence override (#489) is honoured in Debug and ignored in Release.
//
// The key is spelled out here rather than read from `SharedKeys`, because in Release the
// constant does not exist: the test has to compile in both configurations to prove both
// halves (`swift test` runs Debug; `swift test -c release -Xswiftc -enable-testing` runs
// the other). It writes the real App Group suite, so setUp/tearDown remove the key.
import XCTest
@testable import DictusCore

final class SmartModeAvailabilityDebugOverrideTests: XCTestCase {

    private let key = "dictus.debugAppleIntelligenceForced"

    override func setUp() {
        super.setUp()
        AppGroup.defaults.removeObject(forKey: key)
    }

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: key)
        super.tearDown()
    }

    func testTheOverrideIsHonouredOnlyInDebugBuilds() {
        AppGroup.defaults.set(true, forKey: key)

        #if DEBUG
        XCTAssertEqual(SharedKeys.debugAppleIntelligenceForced, key)
        XCTAssertEqual(SmartModeAvailability.engineState, .available)
        #else
        // Release: the key has no reader, so the engine state is the device's own.
        XCTAssertEqual(SmartModeAvailability.engineState, PolishAvailability.state)
        #endif
    }

    func testWithoutTheKeyTheEngineStateIsTheDevicesOwn() {
        XCTAssertEqual(SmartModeAvailability.engineState, PolishAvailability.state)
    }
}
