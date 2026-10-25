// DictusCore/Tests/DictusCoreTests/WarmEngineTimeoutTests.swift
// The inactivity timeout setting (#380): presets, storage, fallback.
import XCTest
@testable import DictusCore

final class WarmEngineTimeoutTests: XCTestCase {

    // A throwaway suite, not the App Group: `swift test` must never touch the
    // group container (#560).
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WarmEngineTimeoutTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Presets

    func testTheSevenPresetsInPickerOrder() {
        XCTAssertEqual(WarmEngineTimeoutOption.allCases, [
            .immediately, .oneMinute, .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour, .unlimited,
        ])
    }

    func testEachPresetMapsToItsInterval() {
        XCTAssertEqual(WarmEngineTimeoutOption.immediately.interval, 0)
        XCTAssertEqual(WarmEngineTimeoutOption.oneMinute.interval, 60)
        XCTAssertEqual(WarmEngineTimeoutOption.fiveMinutes.interval, 300)
        XCTAssertEqual(WarmEngineTimeoutOption.tenMinutes.interval, 600)
        XCTAssertEqual(WarmEngineTimeoutOption.thirtyMinutes.interval, 1800)
        XCTAssertEqual(WarmEngineTimeoutOption.oneHour.interval, 3600)
        XCTAssertNil(WarmEngineTimeoutOption.unlimited.interval)
    }

    func testUnlimitedArmsNoTimer() {
        XCTAssertNil(WarmEngineTimeoutOption.unlimited.idleTimerInterval)
    }

    func testImmediatelyArmsOnlyTheDefaultWindowAsABackstop() {
        // The release itself comes from the dictation's end: arming 0 when the samples
        // are collected would release the engine before the transcription has run.
        XCTAssertEqual(WarmEngineTimeoutOption.immediately.idleTimerInterval, 600)
    }

    func testTimedPresetsArmTheirOwnInterval() {
        for option in [WarmEngineTimeoutOption.oneMinute, .fiveMinutes, .tenMinutes, .thirtyMinutes, .oneHour] {
            XCTAssertEqual(option.idleTimerInterval, option.interval, "\(option)")
        }
    }

    // MARK: - Storage

    func testAFreshInstallGetsTenMinutes() {
        XCTAssertEqual(WarmEngineTimeout.option(in: defaults), .tenMinutes)
        XCTAssertEqual(WarmEngineTimeout.option(in: defaults).interval, 600)
    }

    func testAnUnknownStoredValueFallsBackToTenMinutes() {
        defaults.set("fortyTwoMinutes", forKey: SharedKeys.warmEngineTimeout)
        XCTAssertEqual(WarmEngineTimeout.option(in: defaults), .tenMinutes)
    }

    func testEveryPresetRoundTripsThroughTheSharedKey() {
        for option in WarmEngineTimeoutOption.allCases {
            defaults.set(option.rawValue, forKey: SharedKeys.warmEngineTimeout)
            XCTAssertEqual(WarmEngineTimeout.option(in: defaults), option)
        }
    }

    func testTheStoredFormatIsStable() {
        // Raw values are what users' App Groups hold; renaming one silently resets their choice.
        XCTAssertEqual(SharedKeys.warmEngineTimeout, "dictus.warmEngineTimeout")
        XCTAssertEqual(WarmEngineTimeoutOption.allCases.map(\.rawValue), [
            "immediately", "oneMinute", "fiveMinutes", "tenMinutes", "thirtyMinutes", "oneHour", "unlimited",
        ])
    }
}
