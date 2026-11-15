// DictusCore/Sources/DictusCore/Subscription/OfferCodeSheetOutcome.swift
// How Apple's offer code redemption sheet closed, for the log (#787).
import Foundation

/// How Apple's offer code redemption sheet closed.
///
/// WHY it exists: SwiftUI's `offerCodeRedemption` completion reports a user who
/// closes the sheet with its cross as a failure, `StoreKitError.userCancelled`
/// ("Demande annulée" on a French device, build 64efd44c, 2026-11-05). Logged as
/// `subscriptionError`, a plain close read as an ERROR in every exported log.
///
/// WHY error domain and code rather than StoreKit's types: DictusCore is linked by
/// the keyboard extension, which has no business with StoreKit (see `ProHub`).
/// `SubscriptionManager` bridges the error to `NSError` and passes its two fields.
public enum OfferCodeSheetOutcome: Equatable, Sendable {
    /// The sheet closed without an error. It does not say whether a code was redeemed:
    /// a redemption arrives as a transaction through `Transaction.updates`.
    case succeeded
    /// The user closed the sheet. Not a failure.
    case cancelled
    /// A real failure (network, StoreKit internal error), kept as an ERROR.
    case failed

    /// `(domain, code)` pairs that mean the user closed the sheet.
    ///
    /// - `StoreKit.StoreKitError` 3 is `StoreKitError.userCancelled` bridged to
    ///   `NSError` (measured on macOS 26 with Xcode 26.4; the test target pins it
    ///   against StoreKit itself, so a renumbering fails `swift test`).
    /// - `SKErrorDomain` 2 is StoreKit 1's `SKError.paymentCancelled`.
    /// - `NSCocoaErrorDomain` 3072 is `NSUserCancelledError`.
    static let cancellationCodes: Set<ErrorCode> = [
        ErrorCode(domain: "StoreKit.StoreKitError", code: 3),
        ErrorCode(domain: "SKErrorDomain", code: 2),
        ErrorCode(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
    ]

    struct ErrorCode: Hashable {
        let domain: String
        let code: Int
    }

    /// Classifies the sheet's completion. Pass `nil` for a success, or the failure's
    /// `NSError` domain and code.
    public static func classify(errorDomain: String?, code: Int) -> OfferCodeSheetOutcome {
        guard let errorDomain else { return .succeeded }
        return cancellationCodes.contains(ErrorCode(domain: errorDomain, code: code)) ? .cancelled : .failed
    }

    /// The `result=` value logged for a close that is not a failure.
    public var logResult: String? {
        switch self {
        case .succeeded: return "success"
        case .cancelled: return "cancelled"
        case .failed: return nil
        }
    }
}
