// DictusAppTests/SubscriptionForegroundRefreshTests.swift
// A lifetime bought outside the app unlocks Pro on the foreground re-read (#900).
import XCTest
import StoreKitTest
import DictusCore
@testable import DictusApp

/// WHY a hosted app test and not a DictusCore test: `SKTestSession` needs a process
/// StoreKit treats as an app. Under `swift test` on macOS the purchase is refused with
/// `notEntitled` (measured 2026-11-04, Xcode 27.2), and `SubscriptionManager` lives in
/// DictusApp anyway. So this runs with `xcodebuild test` on a simulator, which the CI
/// does not do. The simulator's runtime must match Xcode's: on iOS 26.5 under Xcode 27.2
/// every `SKTestSession` call failed with `SKInternalErrorDomain` 3 (same day).
///
/// WHY the waits: only the latest entitlement scan publishes (`ProScanGeneration`), and
/// the launch scan and the `Transaction.updates` listener start scans of their own, so
/// `refreshEntitlements()` can return having been superseded. The test waits for the
/// published state, bounded. In this process the listener hears the purchase too, so
/// the test proves the outcome of a return to the foreground, not which scan won.
@MainActor
final class SubscriptionForegroundRefreshTests: XCTestCase {
    private static let lifetimeID = "solutions.pivi.dictus.pro.lifetime2"

    private var session: SKTestSession?

    override func setUp() async throws {
        let session = try SKTestSession(configurationFileNamed: "StoreKitConfig")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        self.session = session
        AppGroup.defaults.set(false, forKey: SharedKeys.proActive)
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        AppGroup.defaults.set(false, forKey: SharedKeys.proActive)
    }

    func testLifetimeBoughtOutsideTheAppUnlocksProOnForegroundAndAfterRelaunch() async throws {
        XCTAssertEqual(ProProductID.lifetime, Self.lifetimeID)
        let session = try XCTUnwrap(session)

        // App open, nothing owned.
        let proStatus = ProStatusManager()
        let manager = SubscriptionManager(proStatus: proStatus)
        await manager.refreshEntitlements()
        try await Self.wait { proStatus.hasResolvedEntitlements }
        XCTAssertFalse(proStatus.isPaid)
        XCTAssertFalse(Self.appGroupProActive())

        // Bought off-device, as an offer code redeemed in the App Store would be.
        try await session.buyProduct(identifier: Self.lifetimeID)

        // What the `.active` scene phase runs.
        await manager.refreshEntitlements()
        try await Self.wait { manager.ownership?.ownsLifetime == true }
        XCTAssertTrue(proStatus.isPaid)
        XCTAssertTrue(proStatus.isProActive)
        XCTAssertEqual(manager.ownership?.ownsLifetime, true)
        XCTAssertTrue(Self.appGroupProActive(), "dictus.proActive not written to the App Group")

        // Relaunch: fresh managers, the App Group read first, then the entitlements.
        let relaunchedStatus = ProStatusManager()
        XCTAssertTrue(relaunchedStatus.isPaid, "the App Group lost the entitlement")
        let relaunchedManager = SubscriptionManager(proStatus: relaunchedStatus)
        await relaunchedManager.refreshEntitlements()
        try await Self.wait { relaunchedManager.ownership != nil }
        XCTAssertTrue(relaunchedStatus.isPaid)
        XCTAssertTrue(relaunchedStatus.isProActive)
        XCTAssertEqual(relaunchedManager.ownership?.ownsLifetime, true)
        XCTAssertTrue(Self.appGroupProActive())
    }

    /// Polls `condition` until it holds, failing after five seconds.
    private static func wait(_ condition: () -> Bool,
                             file: StaticString = #filePath,
                             line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("condition not met within 5 s", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Read through a fresh suite, as the keyboard extension would.
    private static func appGroupProActive() -> Bool {
        UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: SharedKeys.proActive) ?? false
    }
}
