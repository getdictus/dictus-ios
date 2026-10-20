// DictusCore/Sources/DictusCore/Subscription/ProScanGeneration.swift
// Which of several overlapping entitlement scans may publish its result (#216).
import Foundation

/// Numbers the entitlement scans so only the latest one publishes.
///
/// WHY it exists: `SubscriptionManager` is `@MainActor`, but a scan suspends at
/// every StoreKit `await`, so scans started by launch, `Transaction.updates`, the
/// status listener, the Manage subscription recheck and a purchase interleave. A scan
/// that began before a cancellation and finished after a newer one would otherwise
/// write its older `isPaid` and `ownership` last, and the hub would show "Renews on"
/// after the user cancelled (CodeRabbit on PR #614). A newer scan always reads at
/// least as late as an older one, so the newest result is the one to keep.
public struct ProScanGeneration: Sendable {

    private var current = 0

    public init() {}

    /// Starts a scan and returns its number.
    public mutating func begin() -> Int {
        current += 1
        return current
    }

    /// Whether the scan numbered `generation` is still the latest one started, and
    /// may therefore publish.
    public func mayPublish(_ generation: Int) -> Bool {
        generation == current
    }
}
