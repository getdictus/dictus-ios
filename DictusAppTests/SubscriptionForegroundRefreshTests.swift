// DictusAppTests/SubscriptionForegroundRefreshTests.swift
// A lifetime bought outside the app unlocks Pro on the foreground re-read (#900).
import XCTest
import StoreKitTest
import DictusCore
@testable import DictusApp

/// WHY a hosted app test and not a DictusCore test: `SKTestSession` needs a process
/// StoreKit treats as an app. Under `swift test` on macOS the purchase is refused with
/// `notEntitled` (measured 2026-11-04, Xcode 27.2), and `SubscriptionManager` lives in
/// DictusApp anyway. The simulator's runtime must match Xcode's: on iOS 26.5 under
/// Xcode 27.2 every `SKTestSession` call failed with `SKInternalErrorDomain` 3.
///
/// WHY the purchase can only reach the test's manager through `refreshEntitlements()`:
/// the manager is built with its listeners off, and its launch scan is awaited before
/// the purchase. The host app's own `SubscriptionManager` still listens and writes
/// `dictus.proActive` to the App Group, but it owns a different `ProStatusManager` and
/// cannot set this manager's `ownership`, which only this manager's scans publish, nor
/// this test's `ProStatusManager`, which re-reads the App Group only when its own
/// manager writes. So the App Group check alone would not isolate the path; the
/// `ownership` and `isPaid` checks do.
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

        // App open, nothing owned. Once the launch scan is done, nothing in this
        // manager scans again unless asked.
        let proStatus = ProStatusManager()
        let manager = SubscriptionManager(proStatus: proStatus, listensForUpdates: false)
        await manager.launchScan?.value
        XCTAssertFalse(proStatus.isPaid)
        XCTAssertEqual(manager.ownership?.ownsLifetime, false)

        // Bought off-device, as an offer code redeemed in the App Store would be.
        try await session.buyProduct(identifier: Self.lifetimeID)
        // StoreKit lists an off-device purchase a moment after `buyProduct` returns
        // (measured: a scan run at once still found nothing). Read here, by the test,
        // so the manager's state can still only change through the call below.
        try await Self.waitUntilStoreKitOwns(Self.lifetimeID)

        // What the `.active` scene phase runs.
        await manager.refreshEntitlements()
        XCTAssertEqual(manager.ownership?.ownsLifetime, true, "the foreground re-read missed the purchase")
        XCTAssertTrue(proStatus.isPaid)
        XCTAssertTrue(proStatus.isProActive)
        XCTAssertTrue(Self.appGroupProActive(), "dictus.proActive not written to the App Group")

        // Relaunch: fresh managers, the App Group read first, then the entitlements.
        let relaunchedStatus = ProStatusManager()
        XCTAssertTrue(relaunchedStatus.isPaid, "the App Group lost the entitlement")
        let relaunchedManager = SubscriptionManager(proStatus: relaunchedStatus, listensForUpdates: false)
        await relaunchedManager.launchScan?.value
        await relaunchedManager.refreshEntitlements()
        XCTAssertEqual(relaunchedManager.ownership?.ownsLifetime, true)
        XCTAssertTrue(relaunchedStatus.isPaid)
        XCTAssertTrue(relaunchedStatus.isProActive)
        XCTAssertTrue(Self.appGroupProActive())
    }

    /// Polls `Transaction.currentEntitlements` until it lists `productID`, failing
    /// after five seconds.
    private static func waitUntilStoreKitOwns(_ productID: String) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, transaction.productID == productID { return }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("StoreKit did not list \(productID) within 5 s")
    }

    /// Read through a fresh suite, as the keyboard extension would.
    private static func appGroupProActive() -> Bool {
        UserDefaults(suiteName: AppGroup.identifier)?.bool(forKey: SharedKeys.proActive) ?? false
    }
}
