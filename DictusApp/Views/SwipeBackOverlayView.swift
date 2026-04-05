// DictusApp/Views/SwipeBackOverlayView.swift
// Full-screen Wispr Flow-style overlay teaching the swipe-back gesture during cold start.
import SwiftUI
import DictusCore

/// Full-screen overlay shown when the app is opened from the keyboard during cold start.
///
/// WHY Wispr Flow-style redesign (Phase 26):
/// A real user tester did not know the iOS swipe-back gesture existed. The overlay must
/// TEACH the gesture visually with an iPhone mockup, animated swipe circle, and empathetic
/// localized text -- not just mention it in words.
///
/// WHY no parameters:
/// MainTabView calls `SwipeBackOverlayView()` with no arguments. Recording happens in
/// DictationCoordinator -- this view is purely visual.
struct SwipeBackOverlayView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Brand gradient background matching the app icon gradient
            LinearGradient(
                colors: [Color(hex: 0x0D2040), Color(hex: 0x071020)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title at top
                Text("Dictation in progress")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.top, 60)

                Spacer()

                // iPhone mockup with waveform and swipe animation
                IPhoneMockupView(isAnimating: isAnimating)
                    .frame(width: 180, height: 390)

                // Empathetic explanation text below mockup
                Text("We'd love to skip this step, but iOS requires switching apps to activate the microphone.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 28)

                Spacer()

                // Bottom instruction pinned at bottom
                Text("Swipe right at the bottom of your screen")
                    .font(.callout.weight(.medium))
                    .foregroundColor(.dictusAccent)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - iPhone Mockup View

/// Wispr Flow-style iPhone mockup with simplified waveform bars and swipe gesture animation.
///
/// WHY simplified bars instead of real WaveformCanvasView:
/// The mockup is only 180pt wide -- real waveform data would be too small to be useful
/// and would add unnecessary memory/complexity. Animated bars communicate "app is listening"
/// without the overhead.
///
/// WHY fixed bar heights instead of CGFloat.random:
/// SwiftUI recalculates random values on every frame, causing visual jitter.
/// Fixed constants give predictable, smooth animation between idle and active states.
private struct IPhoneMockupView: View {
    var isAnimating: Bool

    // Fixed bar heights to avoid CGFloat.random jitter in view body
    private let barHeightsIdle: [CGFloat] = [8, 14, 6, 12, 10]
    private let barHeightsActive: [CGFloat] = [28, 38, 16, 34, 22]

    var body: some View {
        ZStack {
            // Device outline -- continuous corner style matches real iPhone
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 2.5)

            // Dynamic Island capsule at the top
            VStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 50, height: 14)
                    .padding(.top, 18)
                Spacer()
            }

            // Inner content: simplified waveform + "Listening..." label
            VStack(spacing: 12) {
                // Simplified waveform bars
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.dictusAccent)
                            .frame(
                                width: 4,
                                height: isAnimating
                                    ? barHeightsActive[i]
                                    : barHeightsIdle[i]
                            )
                    }
                }
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isAnimating
                )

                Text("Listening...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Home indicator + swipe animation at bottom
            VStack {
                Spacer()

                // Swipe gesture area
                ZStack {
                    // Animated accent circle sliding right
                    Circle()
                        .fill(Color.dictusAccent)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.dictusAccent.opacity(0.5), radius: 8)
                        .offset(x: isAnimating ? 50 : -30)

                    // Chevron trail fading behind the circle
                    ForEach(0..<2, id: \.self) { i in
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(
                                Color.dictusAccent.opacity(0.3 - Double(i) * 0.1)
                            )
                            .offset(
                                x: isAnimating
                                    ? CGFloat(25 - i * 14)
                                    : CGFloat(-35 - i * 14)
                            )
                    }
                }
                .padding(.bottom, 8)

                // Home indicator bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 60, height: 5)
                    .padding(.bottom, 14)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    SwipeBackOverlayView()
}
