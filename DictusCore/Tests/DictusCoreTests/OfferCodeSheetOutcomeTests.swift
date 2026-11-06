// DictusCore/Tests/DictusCoreTests/OfferCodeSheetOutcomeTests.swift
// Closing the offer code sheet with its cross is a close, not an error (#787).
import Foundation
import StoreKit
import XCTest
@testable import DictusCore

final class OfferCodeSheetOutcomeTests: XCTestCase {

    private func classify(_ error: Error) -> OfferCodeSheetOutcome {
        let nsError = error as NSError
        return OfferCodeSheetOutcome.classify(errorDomain: nsError.domain, code: nsError.code)
    }

    func testSuccessIsSucceeded() {
        let outcome = OfferCodeSheetOutcome.classify(errorDomain: nil, code: 0)
        XCTAssertEqual(outcome, .succeeded)
        XCTAssertEqual(outcome.logResult, "success")
    }

    /// The device log of 2026-11-05: the cross produced `StoreKitError.userCancelled`
    /// ("Demande annulée"), logged as `subscriptionError`. Bridged through StoreKit
    /// itself, so a change in how Apple numbers the case fails here.
    func testStoreKitUserCancelledIsCancelled() {
        let outcome = classify(StoreKitError.userCancelled)
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(outcome.logResult, "cancelled")
    }

    func testStoreKitOnePaymentCancelledIsCancelled() {
        XCTAssertEqual(classify(SKError(.paymentCancelled)), .cancelled)
    }

    func testCocoaUserCancelledIsCancelled() {
        XCTAssertEqual(classify(CocoaError(.userCancelled)), .cancelled)
    }

    /// Real failures keep their ERROR line.
    func testRealFailuresAreFailed() {
        let internalError = NSError(domain: "SKInternalErrorDomain", code: 12)
        XCTAssertEqual(classify(internalError), .failed)
        XCTAssertNil(OfferCodeSheetOutcome.failed.logResult)
        XCTAssertEqual(classify(StoreKitError.networkError(URLError(.notConnectedToInternet))), .failed)
        XCTAssertEqual(classify(URLError(.notConnectedToInternet)), .failed)
        XCTAssertEqual(classify(StoreKitError.unknown), .failed)
        // Same code as `userCancelled`, other domain.
        XCTAssertEqual(OfferCodeSheetOutcome.classify(errorDomain: "SKInternalErrorDomain", code: 3), .failed)
    }
}
