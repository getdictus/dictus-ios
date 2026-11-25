// DictusCore/Sources/DictusCore/DeviceNoun.swift
// The device's own name in user-facing copy: "iPhone" or "iPad" (#984).

import Foundation

/// The word the copy uses for the device the user is holding.
///
/// WHY a product name and not a localized word: Apple keeps "iPhone" and "iPad"
/// untranslated in every language Dictus ships (fr, en, es, de), so the catalog
/// carries the noun as a `%@` placeholder and each translation keeps its own
/// article around it ("cet %@", "dieses %@", "este %@"). Both nouns take the same
/// article and gender in those four languages, so one sentence serves both.
///
/// WHY the hardware identifier and not `UIDevice.userInterfaceIdiom`:
/// DictusApp is iPhone-only and runs on an iPad in compatibility mode, where the
/// idiom reports `.phone`. The identifier still says "iPad13,1" (same rule as
/// `DeviceCapabilities.isIPad`, #612).
public enum DeviceNoun {

    /// "iPad" when the hardware identifier names an iPad, "iPhone" otherwise.
    public static func name(forModelIdentifier identifier: String) -> String {
        identifier.hasPrefix("iPad") ? "iPad" : "iPhone"
    }

    /// The noun for this device, read once: the hardware does not change at runtime.
    public static let current: String = name(
        forModelIdentifier: DeviceCapabilities.current().deviceModelIdentifier
    )
}
