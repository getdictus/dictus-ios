// DictusCore/Sources/DictusCore/AccentPopupRelease.swift
// Whether a held letter's accent popup still types the letter where the finger is (#1089).
import Foundation

/// What the long-press accent popup offers when the finger is on none of its accents.
///
/// Until #1089 the answer was nothing: on iPhone a letter held past the popup's delay
/// (0.5 s) and released without picking an accent typed nothing, so a slow or firm tap on
/// e, a, u, i, o, y, c or n was lost. Users read that as having to "press harder" than on
/// Apple's keyboard. Apple's keeps the letter itself highlighted, and types it on release,
/// wherever the finger goes except down, away from the popup.
///
/// Measured on Apple's French AZERTY (iOS 26.5 simulator, 2026-11-27, « E » held 0.8 s,
/// its key 54 pt tall from y 590 to 644, the finger then moved and lifted): lifted in place,
/// 57, 117 or 317 pt higher, or 23 to 53 pt lower, it typed E; 56 pt lower or more, nothing.
/// The line falls half a key below the key's bottom edge.
public enum AccentPopupRelease {

    /// True while a finger at `fingerY` that is on none of the popup's accents still
    /// chooses the held letter: everywhere above a line half a key below the held key.
    ///
    /// - Parameters:
    ///   - fingerY: the finger's y, in the coordinates of the key's frame (y grows down).
    ///   - keyBottom: the held key's bottom edge (`maxY`).
    ///   - keyHeight: the held key's height.
    public static func keepsHeldLetter(fingerY: Double, keyBottom: Double, keyHeight: Double) -> Bool {
        fingerY <= keyBottom + keyHeight / 2
    }
}
