// DictusCore/Sources/DictusCore/Design/BrandWaveform.swift
// Multi-bar waveform with brand-inspired colors (blue gradient center, white opacity sides).
import SwiftUI

/// Multi-bar audio waveform styled with Dictus brand colors.
///
/// WHY multi-bar instead of 3-bar logo:
/// 3 bars felt static and logo-like, not like a real audio visualizer.
/// This uses 30 bars for fluid audio feedback, but keeps brand identity through
/// the color scheme: center bars use the blue gradient, outer bars use white at
/// decreasing opacity -- echoing the logo's asymmetric bar styling.
///
/// WHY GeometryReader for bar width:
/// Bar width adapts automatically to fit available space in each context.
/// The waveform fills the space whether it appears in the recording overlay
/// (full keyboard width), the HomeView card (narrower), or RecordingView (full screen).
public struct BrandWaveform: View {
    /// Array of energy levels (0.0-1.0) for each bar. Count determines bar count.
    public let energyLevels: [Float]

    /// Fixed height of the waveform container. Bars grow within this space.
    public var maxHeight: CGFloat = 80

    /// When true, generates a synthetic sinusoidal wave pattern instead of using energyLevels.
    /// WHY: During transcription processing, the audio engine is idle but we want continuous
    /// visual feedback. A traveling sine wave maintains waveform continuity from the recording
    /// state while indicating "processing" rather than "recording".
    public var isProcessing: Bool = false

    public init(energyLevels: [Float] = [], maxHeight: CGFloat = 80, isProcessing: Bool = false) {
        self.energyLevels = energyLevels
        self.maxHeight = maxHeight
        self.isProcessing = isProcessing
    }

    /// WHY @Environment colorScheme:
    /// Outer bars use white in dark mode (original) and gray in light mode.
    /// Without this, white bars on a light background are invisible.
    @Environment(\.colorScheme) private var colorScheme

    /// Number of bars to display.
    private let barCount = 30

    /// Consistent spacing between bars.
    private let barSpacing: CGFloat = 2

    public var body: some View {
        if isProcessing {
            // WHY TimelineView instead of withAnimation:
            // sin(2π*(x+0)) == sin(2π*(x+1)), so animating a phase from 0→1 produces
            // identical start/end values — SwiftUI sees no change and nothing moves.
            // TimelineView gives us a continuous clock to compute the phase from real time.
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate / 2.0
                waveformContent(processingPhase: phase)
            }
        } else {
            waveformContent(processingPhase: 0)
                .animation(.easeOut(duration: 0.08), value: energyLevels)
        }
    }

    /// Canvas-based rendering for 60fps waveform.
    ///
    /// WHY Canvas instead of ForEach + RoundedRectangle:
    /// ForEach creates 30 separate SwiftUI views, each with its own layout pass.
    /// Canvas renders all 30 bars in a single GPU draw call, which is significantly
    /// more efficient and eliminates frame drops during rapid energy level updates.
    ///
    /// WHY zero minHeight in non-processing mode:
    /// The old minHeight of 4pt caused visible micro-movements at zero energy,
    /// making the waveform appear "alive" even when silent. Setting minHeight = 0
    /// means bars completely disappear at zero energy -- perfectly still.
    private func waveformContent(processingPhase: Double) -> some View {
        Canvas { context, size in
            let totalSpacing = barSpacing * CGFloat(barCount - 1)
            let barWidth = max((size.width - totalSpacing) / CGFloat(barCount), 2)

            for index in 0..<barCount {
                let energy = energyForBar(at: index, processingPhase: processingPhase)
                // Zero minHeight when NOT processing -- bars disappear at zero energy
                let minHeight: CGFloat = isProcessing ? 4 : 0
                let height = max(minHeight + CGFloat(energy) * (maxHeight - minHeight), isProcessing ? 4 : 0)

                let x = CGFloat(index) * (barWidth + barSpacing)
                let y = (size.height - height) / 2
                let rect = CGRect(x: x, y: y, width: barWidth, height: max(height, 0))
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                context.fill(path, with: .color(resolvedBarColor(at: index)))
            }
        }
        .frame(height: maxHeight)
    }

    /// Map bar index to an energy value from the energyLevels array,
    /// or generate a synthetic sinusoidal value when in processing mode.
    ///
    /// WHY interpolation (normal mode):
    /// energyLevels may have fewer or more entries than barCount.
    /// We map each bar position proportionally into the array.
    ///
    /// WHY sinusoidal (processing mode):
    /// Creates a smooth traveling wave: each bar computes its energy from a sine
    /// function offset by processingPhase. The wave "moves" across the bars as
    /// processingPhase animates from 0 to 1.
    private func energyForBar(at index: Int, processingPhase: Double) -> Float {
        if isProcessing {
            let normalizedIndex = Double(index) / Double(max(barCount - 1, 1))
            let sineValue = sin(2 * .pi * (normalizedIndex + processingPhase))
            // Map sine (-1...1) to energy (0.2...0.7) for a subtle ambient effect
            return Float(0.2 + 0.25 * (sineValue + 1.0))
        }

        guard !energyLevels.isEmpty else { return 0 }
        let position = Float(index) / Float(max(barCount - 1, 1))
        let arrayIndex = position * Float(energyLevels.count - 1)
        let lower = Int(arrayIndex)
        let upper = min(lower + 1, energyLevels.count - 1)
        let fraction = arrayIndex - Float(lower)
        let value = energyLevels[lower] * (1 - fraction) + energyLevels[upper] * fraction
        return min(max(value, 0), 1)
    }

    /// Brand-inspired color resolved to a plain Color for Canvas rendering.
    ///
    /// WHY plain Color instead of ShapeStyle/LinearGradient:
    /// Canvas's `context.fill(path, with:)` accepts `Shading` not `ShapeStyle`.
    /// Per-path gradients aren't practical in Canvas. Instead, center bars use the
    /// brand blue midpoint color (dictusGradientStart) which is visually close to
    /// the old top-to-bottom gradient. A minor simplification for major perf gain.
    private func resolvedBarColor(at index: Int) -> Color {
        // Distance from center (0.0 = center, 1.0 = edge)
        let center = Float(barCount - 1) / 2.0
        let distanceFromCenter = abs(Float(index) - center) / center

        // Center bars: brand blue, edge bars: white/gray with decreasing opacity
        if distanceFromCenter < 0.4 {
            // Inner 40%: solid brand blue (midpoint of old gradient)
            return .dictusGradientStart
        } else {
            // Outer 60%: adaptive color with opacity decreasing toward edges
            let opacity = Double(1.0 - distanceFromCenter) * 0.9 + 0.15
            let barColor: Color = colorScheme == .dark ? .white : .gray
            return barColor.opacity(opacity)
        }
    }
}

#Preview("Idle") {
    ZStack {
        Color(hex: 0x0A1628).ignoresSafeArea()
        BrandWaveform(energyLevels: Array(repeating: Float(0), count: 30))
    }
}

#Preview("Active") {
    ZStack {
        Color(hex: 0x0A1628).ignoresSafeArea()
        BrandWaveform(energyLevels: (0..<30).map { i in
            Float.random(in: 0.2...0.8)
        })
    }
}

#Preview("Processing") {
    ZStack {
        Color(hex: 0x0A1628).ignoresSafeArea()
        BrandWaveform(maxHeight: 120, isProcessing: true)
            .opacity(0.3)
            .padding(.horizontal)
    }
}
