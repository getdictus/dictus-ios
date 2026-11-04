// DictusCore/Tests/DictusCoreTests/BuildChannelTests.swift
// The test-build / App Store split and the DriftRetry log line it shapes (#861).
import XCTest
@testable import DictusCore

final class BuildChannelTests: XCTestCase {

    private let storeKit = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/X/StoreKit")

    // MARK: - Detection

    func testADebugBuildIsATestBuildWhateverItsReceipt() {
        XCTAssertEqual(BuildChannel.detect(isDebug: true, receiptURL: nil), .testBuild)
        XCTAssertEqual(BuildChannel.detect(isDebug: true, receiptURL: storeKit.appendingPathComponent("receipt")),
                       .testBuild)
    }

    func testASandboxReceiptIsATestBuild() {
        XCTAssertEqual(BuildChannel.detect(isDebug: false, receiptURL: storeKit.appendingPathComponent("sandboxReceipt")),
                       .testBuild)
    }

    func testAnAppStoreReceiptIsTheAppStore() {
        XCTAssertEqual(BuildChannel.detect(isDebug: false, receiptURL: storeKit.appendingPathComponent("receipt")),
                       .appStore)
    }

    /// No receipt URL at all, which is what the deprecated API would return if it
    /// stopped answering: the side that writes no text.
    func testNoReceiptURLIsTheAppStore() {
        XCTAssertEqual(BuildChannel.detect(isDebug: false, receiptURL: nil), .appStore)
    }

    // MARK: - The DriftRetry line in each channel

    private func line(_ channel: BuildChannel) -> String {
        LogEvent.driftRetrySpanReplaced(startMs: 11_520, endMs: 19_440, before: "english9 english10",
                                        after: "français français", channel: channel).payload()
    }

    func testATestBuildLogsTheSpanText() {
        XCTAssertTrue(line(.testBuild).hasSuffix(
            "driftRetrySpanReplaced startMs=11520 endMs=19440 before=\"english9 english10\" after=\"français français\""
        ), line(.testBuild))
        print("[#861 log sample testBuild] \(line(.testBuild))")
    }

    func testTheAppStoreLogsPositionsAndLengthsOnly() {
        XCTAssertTrue(line(.appStore).hasSuffix(
            "driftRetrySpanReplaced startMs=11520 endMs=19440 beforeLen=18 afterLen=17"
        ), line(.appStore))
        print("[#861 log sample appStore] \(line(.appStore))")
    }
}
