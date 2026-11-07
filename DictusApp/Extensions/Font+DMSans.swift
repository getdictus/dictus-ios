// DictusApp/Extensions/Font+DMSans.swift
// DM Sans, the brand typeface, bundled under DictusApp/Fonts (SIL OFL 1.1).
import SwiftUI

/// The DM Sans weights bundled with the app, by PostScript name.
///
/// WHY static files and not the variable font: `Font.custom` resolves a PostScript
/// name to one face, and a variable font's named instances are not reliably reachable
/// that way. Five static faces cost ~390 KB and always resolve.
enum DMSansWeight: String {
    case extraLight = "DMSans-ExtraLight"
    case regular = "DMSans-Regular"
    case medium = "DMSans-Medium"
    case semiBold = "DMSans-SemiBold"
    case bold = "DMSans-Bold"
}

extension Font {
    /// DM Sans at `size` points for the default text size, scaled with Dynamic Type
    /// like `textStyle` is.
    ///
    /// Used by the paywall only for now (#913); the rest of the app moves in #918.
    static func dmSans(_ weight: DMSansWeight, size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}
