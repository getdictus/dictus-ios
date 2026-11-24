// DictusCore/Sources/DictusCore/AccentPopupFit.swift
// Width of one option in the long-press accent popup, so a long list stays on one row (#1042).
import Foundation

/// How wide each option of a long-press popup is drawn on iPhone.
///
/// The popup draws its options one key wide, side by side, plus a margin. Until #1042 no
/// list was longer than five, so that always fit. Apple's per-language lists run to twelve
/// options with the key's own (English `a`), and at one key wide ten already overflow the
/// keyboard: the tenth option was cut off. A second row is no way out on iPhone, because a
/// top-row key's popup would put it above the keyboard's frame, where an extension cannot
/// draw. Apple's keyboard keeps every one of these lists on one row (iOS 26.5, measured
/// 2026-11-24) by narrowing the options, and so does this.
public enum AccentPopupFit {

    /// The option width: a key's width while the row fits, else the width that makes
    /// `count` options and the popup's margin fill `availableWidth` exactly.
    ///
    /// - Parameters:
    ///   - keyWidth: the width an option is drawn at when there is room, one key.
    ///   - availableWidth: the room for the options: the keyboard's width, which the popup
    ///     cannot exceed, less the bubble's inset on each side (its corner radius).
    ///   - margin: what the popup adds around its options (`keyHorizontalMargin`).
    ///   - count: the number of options, the key's own included.
    public static func optionWidth(keyWidth: Double, availableWidth: Double, margin: Double, count: Int) -> Double {
        guard count > 0 else { return keyWidth }
        return min(keyWidth, (availableWidth - margin) / Double(count))
    }
}
