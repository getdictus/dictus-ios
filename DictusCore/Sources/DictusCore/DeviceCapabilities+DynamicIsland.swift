// DictusCore/Sources/DictusCore/DeviceCapabilities+DynamicIsland.swift
// Whether this iPhone has a Dynamic Island, read from its model identifier (#681).
import Foundation

public extension DeviceCapabilities {

    /// Whether this device has a Dynamic Island, so the onboarding's "how to stop Dictus"
    /// step shows the island and not the Lock Screen (#681, #649 decision 19).
    ///
    /// WHY A TABLE OF MODELS WITHOUT ONE: there is no public API that says whether an
    /// island is there. The model identifier is the one fact the app can read
    /// (`deviceModelIdentifier`), so the rule is a list on it. It lists the models
    /// WITHOUT an island and not the ones with it, so that any identifier it does not
    /// know, which in practice is an iPhone released after this table, counts as having
    /// one: every iPhone since the 15 has one, the e models apart.
    ///
    /// WHY THE IPAD PREFIX: Dictus is an iPhone app, but it runs on an iPad in
    /// compatibility mode (#612), and no iPad has an island. Every iPad is a known model
    /// without one, so the whole product line answers false rather than falling into the
    /// "unknown, so a future iPhone" branch it does not belong to.
    var hasDynamicIsland: Bool {
        if deviceModelIdentifier.hasPrefix("iPad") { return false }
        return !Self.identifiersWithoutDynamicIsland.contains(deviceModelIdentifier)
    }

    /// The iPhones that run iOS 17 (Dictus's floor) and have no Dynamic Island: a notch,
    /// or a Home button.
    ///
    /// Checked on 2026-10-12, model by model, against two Apple sources:
    /// - the identifier ↔ model pairs from Xcode 27.0's device table
    ///   (`Platforms/iPhoneOS.platform/usr/standalone/device_traits.db`, `Devices`);
    /// - the display line of each model on "Identify your iPhone model"
    ///   (https://support.apple.com/en-us/108044), which says "with the Dynamic Island"
    ///   for every model that has one, and on the tech specs page linked from it.
    ///
    /// Not listed, because they cannot install Dictus: the iPhone X and everything older
    /// (iOS 16 at most).
    static let identifiersWithoutDynamicIsland: Set<String> = [
        // iPhone XS, XS Max (two variants), XR: notch (2018).
        "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8",
        // iPhone 11, 11 Pro, 11 Pro Max: notch (2019).
        "iPhone12,1", "iPhone12,3", "iPhone12,5",
        // iPhone SE (2nd generation): Home button (2020).
        "iPhone12,8",
        // iPhone 12 mini, 12, 12 Pro, 12 Pro Max: notch (2020).
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",
        // iPhone 13 Pro, 13 Pro Max, 13 mini, 13: notch (2021).
        "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5",
        // iPhone SE (3rd generation): Home button (2022).
        "iPhone14,6",
        // iPhone 14, 14 Plus: notch (2022). The 14 Pro and Pro Max have the island.
        "iPhone14,7", "iPhone14,8",
        // iPhone 16e: notch (2025).
        "iPhone17,5",
        // iPhone 17e: notch (2026). Its tech specs (https://support.apple.com/126470) list
        // the same 2532 × 1170 display as the 16e's and no Dynamic Island.
        "iPhone18,5",
    ]
}
