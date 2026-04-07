// DictusApp/Views/SwipeBackOverlayView.swift
// Full-screen overlay teaching the swipe-back gesture during cold start dictation.
import SwiftUI
import DictusCore

/// Full-screen overlay shown when the app is opened from the keyboard during cold start.
///
/// WHY Wispr Flow-style redesign (Phase 26):
/// A real user tester did not know the iOS swipe-back gesture existed. The overlay must
/// TEACH the gesture visually with an iPhone mockup, animated waveform, and a hand
/// showing the swipe direction — not just mention it in words.
///
/// WHY no parameters:
/// MainTabView calls `SwipeBackOverlayView()` with no arguments. Recording happens in
/// DictationCoordinator — this view is purely visual.
struct SwipeBackOverlayView: View {
    @State private var isWaveformAnimating = false
    @State private var swipeProgress: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0D2040), Color(hex: 0x071020)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Dictation in progress")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.top, 60)

                Spacer()

                // iPhone mockup with BrandWaveform-style bars
                IPhoneMockupView(isAnimating: isWaveformAnimating)
                    .frame(width: 180, height: 390)

                // Swipe hand gesture below the phone mockup
                SwipeHandView(progress: swipeProgress)
                    .frame(width: 120, height: 48)
                    .padding(.top, 4)

                // Empathetic explanation
                Text("We'd love to skip this step, but iOS requires opening Dictus to activate the microphone.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                Spacer()

                // Bottom instruction
                Text("Swipe right at the bottom of your screen\nto return to your app")
                    .font(.callout.weight(.medium))
                    .foregroundColor(.dictusAccent)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Waveform pulsing
            withAnimation(
                .easeInOut(duration: 0.7)
                .repeatForever(autoreverses: true)
            ) {
                isWaveformAnimating = true
            }
            // Hand swipe with natural acceleration
            startSwipeLoop()
        }
    }

    /// Repeating hand swipe animation with pause between cycles.
    ///
    /// WHY Timer-based instead of .repeatForever:
    /// .repeatForever(autoreverses: false) causes an instant jump-back that looks jarring.
    /// A Timer lets us: animate forward (1.2s) → pause (0.6s) → reset → repeat.
    /// The easeOut curve gives natural "fast start, gentle landing" like a real swipe.
    private func startSwipeLoop() {
        animateSwipeForward()
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                animateSwipeForward()
            }
        }
    }

    private func animateSwipeForward() {
        swipeProgress = 0
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.2)) {
            swipeProgress = 1
        }
    }
}

// MARK: - Swipe Hand View

/// Animated hand icon sliding right to teach the swipe-back gesture.
///
/// WHY hand.point.up instead of a circle:
/// User testing showed that a blue circle didn't communicate "swipe gesture" clearly.
/// A pointing finger is universally understood as "touch here and drag".
///
/// WHY timingCurve(0.4, 0, 0.2, 1):
/// This is a Material Design "emphasized" easing curve — slow start with acceleration
/// through the middle, then gentle deceleration. Feels like a natural human swipe
/// rather than a mechanical linear motion.
private struct SwipeHandView: View {
    var progress: CGFloat

    var body: some View {
        ZStack {
            // Hand icon — slides from left to right
            Image(systemName: "hand.point.up")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white.opacity(0.85))
                .offset(x: -30 + progress * 80)
                .opacity(1.0 - progress * 0.4)

            // Chevron trail behind the hand
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(
                        Color.dictusAccent.opacity(
                            (0.5 - Double(i) * 0.15) * Double(progress)
                        )
                    )
                    .offset(
                        x: -30 + progress * 80 - CGFloat(14 + i * 12)
                    )
            }
        }
    }
}

// MARK: - iPhone Mockup View

/// iPhone mockup with BrandWaveform-style bars and home indicator.
///
/// WHY 17 bars with brand color scheme:
/// Matches the real BrandWaveform visual identity — blue gradient center bars,
/// white opacity edge bars. 17 bars fit the 140pt width of the mockup cleanly.
///
/// WHY fixed bar heights instead of CGFloat.random:
/// SwiftUI recalculates random values on every frame, causing visual jitter.
/// Fixed constants give predictable, smooth pulsing animation.
private struct IPhoneMockupView: View {
    var isAnimating: Bool

    // 17 bars — symmetric: outer white → inner blue gradient → outer white
    private let barHeightsIdle: [CGFloat] = [
        6, 10, 5, 12, 8, 16, 22, 14, 28, 14, 22, 16, 8, 12, 5, 10, 6
    ]
    private let barHeightsActive: [CGFloat] = [
        12, 18, 10, 22, 16, 30, 40, 24, 46, 24, 38, 28, 14, 20, 8, 16, 10
    ]

    /// Bar colors matching BrandWaveform: gradient blue center, white opacity edges.
    private func barColor(at index: Int) -> some ShapeStyle {
        let center: CGFloat = 8 // center bar index (0-based, 17 bars)
        let distance = abs(CGFloat(index) - center) / center

        if distance < 0.35 {
            // Inner: brand blue
            return Color.dictusGradientStart
        } else if distance < 0.55 {
            // Transition: solid accent blue
            return Color.dictusAccent
        } else {
            // Outer: white with decreasing opacity
            let opacity = (1.0 - distance) * 0.7 + 0.2
            return Color.white.opacity(opacity)
        }
    }

    var body: some View {
        ZStack {
            // Device outline
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 2.5)

            VStack(spacing: 0) {
                // Dynamic Island — padded down from top
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 50, height: 14)
                    .padding(.top, 30)

                Spacer()

                // BrandWaveform-style bars
                HStack(spacing: 2) {
                    ForEach(0..<17, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(barColor(at: i))
                            .frame(
                                width: 3,
                                height: isAnimating
                                    ? barHeightsActive[i]
                                    : barHeightsIdle[i]
                            )
                    }
                }
                .animation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: isAnimating
                )

                // Listening label — FIXED position, only bars animate
                Text("Listening...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 10)

                Spacer()

                // Home indicator bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 60, height: 5)
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    SwipeBackOverlayView()
}
