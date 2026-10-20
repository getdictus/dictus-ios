#if os(iOS)
// DictusCore/Sources/DictusCore/Design/DictusLogo.swift
// Static 3-bar logo drawn with the app icon's proportions.
import SwiftUI

/// Static 3-bar logo component matching the Dictus app icon.
///
/// WHY separate from BrandWaveform:
/// BrandWaveform is a multi-bar audio visualizer for recording feedback.
/// DictusLogo is the actual logo: exactly 3 bars at brand proportions (18/42/27).
/// Used on HomeView, inside DictusIconTile (paywall hero) and in the keyboard's
/// voice note chip and reader.
///
/// WHY every size derives from `height` (#636):
/// The bar width, the gap and the corner radius all come from `DictusLogoGeometry`,
/// the app icon's ratios. A logo is a picture: it scales with the height its caller
/// gives it and keeps its shape at any size. Earlier versions used a fixed 4.5 pt
/// radius, a fixed 8 pt gap and a `@ScaledMetric` bar width that grew with Dynamic
/// Type, so the bars looked square-ended next to the icon and drifted further with
/// larger text sizes.
public struct DictusLogo: View {
    /// Height of the tallest bar (center). The logo is as wide as it is tall.
    public var height: CGFloat = 80

    public init(height: CGFloat = 80) {
        self.height = height
    }

    /// WHY @Environment colorScheme:
    /// Side bars use white in dark mode and gray in light mode for visibility.
    /// That is a deliberate departure from the icon (whose side bars are white on a
    /// dark tile): white bars would vanish on a light background. A caller drawing on
    /// a dark surface in light mode forces `.dark` (see DictusIconTile).
    @Environment(\.colorScheme) private var colorScheme

    /// Opacity for side bars (center uses gradient)
    private let opacities: [Double] = [0.45, 1.0, 0.65]

    public var body: some View {
        let barWidth = DictusLogoGeometry.barWidth(forHeight: height)

        // WHY Capsule rather than RoundedRectangle(cornerRadius:):
        // a Capsule's corner radius is always half its shorter side, so the bar ends
        // are full semicircles at every size, exactly like the icon's rx = width / 2.
        HStack(spacing: DictusLogoGeometry.gap(forHeight: height)) {
            ForEach(0..<3, id: \.self) { index in
                let barHeight = DictusLogoGeometry.barHeightRatios[index] * height
                if index == 1 {
                    // Center bar: brand blue gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.dictusGradientStart, .dictusGradientEnd],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: barHeight)
                } else {
                    // Side bars: adaptive color with brand opacity
                    // Gray in light mode (visible on light backgrounds), white in dark mode
                    let barColor: Color = colorScheme == .dark ? .white : .gray
                    Capsule()
                        .fill(barColor.opacity(opacities[index]))
                        .frame(width: barWidth, height: barHeight)
                }
            }
        }
        .frame(height: height)
    }
}
#endif
