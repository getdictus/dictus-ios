// DictusCore/Sources/DictusCore/Subscription/ProStatusManager.swift
// Lightweight Pro status manager for App Group cross-process sync.
import Foundation
import SwiftUI

/// Manages Pro subscription status in App Group UserDefaults.
///
/// WHY ObservableObject with @Published:
/// SwiftUI views observe this to reactively show/hide Pro UI elements.
/// When SubscriptionManager (in DictusApp) calls setProActive(),
/// the @Published property triggers UI refresh across all observing views.
///
/// WHY separate from SubscriptionManager:
/// ProStatusManager lives in DictusCore (shared framework) so both the
/// main app AND the keyboard extension can read Pro status. SubscriptionManager
/// lives in DictusApp only (StoreKit is too heavy for the ~50MB keyboard extension).
@MainActor
public final class ProStatusManager: ObservableObject {
    @Published public private(set) var isProActive: Bool

    public init() {
        // Register defaults so per-feature toggles are ON by default
        // WHY registerDefaults: UserDefaults.bool(forKey:) returns false for unset keys.
        // Pro features should be enabled by default when user subscribes -- they can
        // then toggle individual features off in Settings if desired.
        let defaults = AppGroup.defaults
        defaults.register(defaults: [
            SharedKeys.smartModeEnabled: true,
            SharedKeys.historyEnabled: true,
            SharedKeys.vocabularyEnabled: true,
        ])

        // During beta, always return true -- all features unlocked
        if ProConfig.isBeta {
            self.isProActive = true
            return
        }
        self.isProActive = AppGroup.defaults.bool(forKey: SharedKeys.proActive)
    }

    /// Called by SubscriptionManager after transaction updates (DictusApp only).
    ///
    /// WHY write to App Group AND update @Published:
    /// App Group write makes it visible to keyboard extension on next read.
    /// @Published update triggers immediate SwiftUI refresh in the main app.
    public func setProActive(_ active: Bool) {
        AppGroup.defaults.set(active, forKey: SharedKeys.proActive)
        AppGroup.defaults.synchronize()
        isProActive = active || ProConfig.isBeta
    }

    /// Lightweight static read for keyboard extension (no StoreKit, no ObservableObject).
    ///
    /// WHY static: The keyboard extension doesn't need reactive updates --
    /// it reads Pro status once at viewDidLoad/viewWillAppear. A static method
    /// avoids instantiating an ObservableObject in the memory-constrained extension.
    nonisolated public static var isProActiveStatic: Bool {
        ProConfig.isBeta || AppGroup.defaults.bool(forKey: SharedKeys.proActive)
    }
}
