// DictusAppTests/UnitTestHostGuardTests.swift
// The app's own subscription manager stays off StoreKit when the app hosts the tests.
import XCTest
import DictusCore
@testable import DictusApp

/// WHY this test: on a freshly erased simulator, any StoreKit call the host app makes
/// before `SKTestSession` exists binds the whole process to Sandbox, and
/// `SubscriptionForegroundRefreshTests` then reads nothing (measured 2026-11-24: 86 of 86
/// queries on Sandbox, against 41 of 41 on XcodeTest once the configuration existed). If
/// a future Xcode stopped setting `XCTestConfigurationFilePath`, this fails by name
/// instead of the StoreKit test failing for a reason nothing points at.
@MainActor
final class UnitTestHostGuardTests: XCTestCase {
    func testTheAppKnowsItIsTheUnitTestHost() {
        XCTAssertTrue(DictusApp.isUnitTestHost)
    }

    func testAManagerThatDoesNotScanAtLaunchStartsNoLaunchScan() {
        let manager = SubscriptionManager(
            proStatus: ProStatusManager(),
            listensForUpdates: false,
            scansAtLaunch: false
        )
        XCTAssertNil(manager.launchScan)
    }
}
