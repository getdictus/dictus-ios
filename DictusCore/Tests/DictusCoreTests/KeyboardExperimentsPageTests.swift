// DictusCore/Tests/DictusCoreTests/KeyboardExperimentsPageTests.swift
// The Experiments row in Settings › Keyboard: a receipt StoreKit never names hides it.
import XCTest
@testable import DictusCore

/// `KeyboardFeatureSettingsTests` covers Debug, TestFlight, the App Store and a missing
/// receipt URL. This adds the last doubt the settings screen relies on: a receipt file
/// name that is neither `sandboxReceipt` nor `receipt` reads as the App Store build, so
/// a Release binary that cannot tell where it came from never shows the row.
final class KeyboardExperimentsPageTests: XCTestCase {

    func testAnUnknownReceiptNameHidesThePageInRelease() {
        let storeKit = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/X/StoreKit")
        for name in ["unexpected", "Receipt", "sandboxreceipt", ""] {
            let channel = BuildChannel.detect(isDebug: false, receiptURL: storeKit.appendingPathComponent(name))
            XCTAssertFalse(KeyboardFeatureSettings.isExperimentsPageVisible(on: channel), name)
        }
        XCTAssertFalse(KeyboardFeatureSettings.isExperimentsPageVisible(
            on: BuildChannel.detect(isDebug: false, receiptURL: URL(fileURLWithPath: "/"))))
    }
}
