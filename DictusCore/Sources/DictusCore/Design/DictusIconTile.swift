#if os(iOS)
// DictusCore/Sources/DictusCore/Design/DictusIconTile.swift
// The app icon drawn in SwiftUI: the logo on its dark squircle tile.
import SwiftUI

/// The Dictus app icon, drawn in SwiftUI: `DictusLogo` centered on the icon's
/// dark gradient tile, with the faint accent stroke along its edge.
///
/// WHY a view and not the AppIcon image:
/// iOS does not expose an app's own icon as an image a view can load, and a copy
/// in an asset catalog would be a second source of truth to keep in sync. This view
/// reads the same ratios as the logo (`DictusLogoGeometry`), so it follows any change.
///
/// WHY the tile is sized from the logo:
/// The paywall used to wrap the logo in `.padding(20)`, which made the tile wider
/// than tall (about 92 × 88 pt) because the padding ignored the icon's proportions.
/// Here the side is `logoHeight × 80 / 42`, so the tile is square and the bars fill
/// it exactly as they fill the icon (#636).
///
/// Effects that belong to one screen (the paywall's blue glow) stay with the caller.
public struct DictusIconTile: View {
    /// Height of the logo's tallest bar. The tile's side derives from it.
    public var logoHeight: CGFloat

    public init(logoHeight: CGFloat) {
        self.logoHeight = logoHeight
    }

    public var body: some View {
        let side = DictusLogoGeometry.tileSide(forHeight: logoHeight)
        // WHY style: .continuous:
        // iOS masks app icons with a "squircle", whose curve eases into the straight
        // edge instead of meeting it at a sharp point like a plain circular corner.
        // `.continuous` draws that same curve, so the tile reads as the icon.
        let tileShape = RoundedRectangle(
            cornerRadius: DictusLogoGeometry.tileCornerRadius(forSide: side),
            style: .continuous
        )

        // Forcing the dark color scheme keeps DictusLogo's side bars white on the
        // dark tile in light mode too, matching the app icon.
        DictusLogo(height: logoHeight)
            .environment(\.colorScheme, .dark)
            .frame(width: side, height: side)
            .background(
                tileShape.fill(
                    // 135° in the SVG: from the top-left corner to the bottom-right one.
                    LinearGradient(
                        colors: [Color(hex: 0x0D2040), Color(hex: 0x071020)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                // The icon's faint accent rim, fading out toward the bottom-right.
                // strokeBorder draws inside the shape, so the tile keeps its size.
                tileShape.strokeBorder(
                    LinearGradient(
                        colors: [Color.dictusAccent.opacity(0.5), Color.dictusAccent.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: DictusLogoGeometry.tileStrokeWidth(forSide: side)
                )
            )
    }
}
#endif
