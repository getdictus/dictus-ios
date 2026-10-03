// DictusCore/Sources/DictusCore/Design/DictusLogoGeometry.swift
// The logo's proportions, read from the app icon, in one place.
import CoreGraphics

/// The Dictus logo's geometry, copied from the app icon (`assets/brand/appicon-dark.svg`).
///
/// WHY ratios and not point values:
/// The SVG draws on an 80×80 canvas, so its numbers (a 9-wide bar, a 4.5 corner radius,
/// a 7.5 gap) only mean something relative to each other. Copying one of them as a
/// point value is what gave the in-app logo square-ish bar ends (#636): a 4.5 pt radius
/// on a 12 pt bar is 37.5 % of the width, where the icon has 50 % (a full semicircle).
/// Every view that draws the logo derives its sizes from the height of the tallest bar
/// through the functions below, so it matches the icon at any size.
///
/// WHY no `#if os(iOS)` (unlike the SwiftUI views next to it):
/// these are plain numbers. Keeping them platform-free lets the macOS `swift test` check
/// them, and lets the widget extension read them without any SwiftUI environment.
public enum DictusLogoGeometry {
    // MARK: - Source values (SVG units, 80×80 viewBox)

    /// Height of the tallest (center) bar. Every other value is divided by this one.
    public static let referenceBarHeight: CGFloat = 42
    /// Width of each bar. Its corner radius is half of it: the bars are capsules.
    public static let referenceBarWidth: CGFloat = 9
    /// Horizontal gap between two bars.
    public static let referenceGap: CGFloat = 7.5
    /// Side of the app icon tile.
    public static let referenceTileSide: CGFloat = 80
    /// Corner radius of the app icon tile.
    public static let referenceTileCornerRadius: CGFloat = 18
    /// Width of the tile's faint accent stroke.
    public static let referenceTileStrokeWidth: CGFloat = 1

    // MARK: - Ratios

    /// Bar heights relative to the tallest bar, left to right: 18 / 42, 42 / 42, 27 / 42.
    public static let barHeightRatios: [CGFloat] = [18 / 42, 1, 27 / 42]
    /// Bar width relative to the tallest bar (≈ 0.214).
    public static let barWidthRatio: CGFloat = referenceBarWidth / referenceBarHeight
    /// Gap relative to the tallest bar (≈ 0.179).
    public static let gapRatio: CGFloat = referenceGap / referenceBarHeight

    // MARK: - Derived sizes

    /// Bar width for a logo whose tallest bar is `height` points.
    public static func barWidth(forHeight height: CGFloat) -> CGFloat {
        height * barWidthRatio
    }

    /// Gap between bars for a logo whose tallest bar is `height` points.
    public static func gap(forHeight height: CGFloat) -> CGFloat {
        height * gapRatio
    }

    /// Total width of the three bars and their two gaps. With the icon's numbers
    /// (3 × 9 + 2 × 7.5 = 42) it equals the height: the logo fits a square.
    public static func logoWidth(forHeight height: CGFloat) -> CGFloat {
        3 * barWidth(forHeight: height) + 2 * gap(forHeight: height)
    }

    /// Side of an app-icon-style tile around a logo whose tallest bar is `height` points.
    public static func tileSide(forHeight height: CGFloat) -> CGFloat {
        height * referenceTileSide / referenceBarHeight
    }

    /// Corner radius of a tile of side `side` (22.5 % of the side).
    public static func tileCornerRadius(forSide side: CGFloat) -> CGFloat {
        side * referenceTileCornerRadius / referenceTileSide
    }

    /// Accent stroke width of a tile of side `side`.
    public static func tileStrokeWidth(forSide side: CGFloat) -> CGFloat {
        side * referenceTileStrokeWidth / referenceTileSide
    }
}
