// DictusCore/Sources/DictusCore/Subscription/ProConfig.swift
// Compile-time configuration for Pro subscription and beta state.
import Foundation

/// Configuration for Pro subscription behavior.
///
/// WHY a simple Bool instead of runtime detection:
/// The user decided on a simple isBeta flag -- flip to false and ship an update.
/// TestFlight builds use the TESTFLIGHT compiler flag (Active Compilation Conditions
/// in Xcode build settings) to always keep beta mode on.
/// App Store builds set isBeta = false to enable the paywall purchase flow.
///
/// WHY not appStoreReceiptURL path checking:
/// Runtime TestFlight detection via receipt URL is fragile across iOS versions.
/// Compiler flags are reliable and validated at build time.
public enum ProConfig {
    #if TESTFLIGHT
    /// TestFlight builds always have beta enabled -- testers keep free access.
    public static let isBeta = true
    #else
    /// Change to `false` for App Store release to enable the purchase flow.
    public static let isBeta = true
    #endif
}
