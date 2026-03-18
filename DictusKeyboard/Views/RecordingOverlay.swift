// DictusKeyboard/Views/RecordingOverlay.swift
import SwiftUI
import DictusCore

/// Full-screen recording overlay that replaces the keyboard during active recording.
/// Shows different visual states based on DictationStatus:
/// - .requested: flat waveform bars, "Démarrage..." text, cancel-only button
/// - .recording: live waveform, elapsed timer, cancel + stop buttons
/// - .transcribing: shimmer waveform, "Transcription..." text
///
/// WHY this replaces the keyboard:
/// Wispr Flow-inspired design -- when recording, the keyboard area transforms into
/// an immersive recording UI. This prevents accidental key presses during dictation
/// and provides clear visual feedback that the mic is active.
///
/// WHY single BrandWaveform (not one per switch branch):
/// The old design had 3 separate BrandWaveform instances in requestedContent,
/// recordingContent, and transcribingContent. When status changed (requested→recording
/// →transcribing), SwiftUI created the new branch's BrandWaveform BEFORE destroying
/// the old one. Each BrandWaveform runs a TimelineView with its own CADisplayLink.
/// Ghost views accumulated across status transitions, producing paired heartbeats
/// and eventually 4+ concurrent animation loops that consumed the frame budget.
/// A single BrandWaveform at a fixed structural position survives all status changes
/// without recreation — SwiftUI just updates its properties in place.
struct RecordingOverlay: View {
    let dictationStatus: DictationStatus
    let waveformEnergy: [Float]
    let elapsedSeconds: Double
    let onCancel: () -> Void
    let onStop: () -> Void

    /// Adaptive foreground color -- dark on light keyboard, light on dark keyboard.
    @Environment(\.colorScheme) private var colorScheme

    /// Timer font size scales with Dynamic Type.
    ///
    /// WHY @ScaledMetric:
    /// Keyboard extensions should respect Dynamic Type. Using @ScaledMetric makes
    /// the timer font size scale proportionally with the user's text size setting,
    /// while keeping monospaced design for proper digit alignment.
    @ScaledMetric private var timerFontSize: CGFloat = 20

    private var foregroundColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.15)
    }

    private var secondaryForeground: Color {
        colorScheme == .dark ? Color.white.opacity(0.5) : Color(white: 0.15).opacity(0.5)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: varies by state but has consistent height
            topBar

            // SINGLE BrandWaveform — never recreated on status change.
            // WHY outside the switch: SwiftUI preserves @State (displayLevels,
            // renderTick, CADisplayLink) when a view stays at the same structural
            // position. Only .id(waveformRefreshID) can force recreation, which
            // is gated to keyboard reappear events only.
            GeometryReader { geo in
                VStack(spacing: 8) {
                    Spacer(minLength: 0)

                    // WHY no .id(waveformRefreshID):
                    // The old .id() modifier forced view recreation on keyboard reappear,
                    // intended to get a fresh CADisplayLink. But during cold start, rapid
                    // appear/disappear cycles caused a storm of .id() changes, creating
                    // ghost BrandWaveform instances with orphaned CADisplayLinks (visible
                    // as multiple simultaneous heartbeats in logs). The overlay's
                    // conditional rendering already recreates BrandWaveform on each
                    // show/hide cycle, and onAppear resets the killed flag, making .id()
                    // unnecessary.
                    BrandWaveform(
                        energyLevels: dictationStatus == .requested ? [] : waveformEnergy,
                        maxHeight: geo.size.height * 0.7,
                        isProcessing: dictationStatus == .transcribing
                    )
                    .padding(.horizontal, 2)

                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            // Footer: varies by state
            footer
        }
        .background(Color.clear)
        .onAppear {
            PersistentLog.log(.overlayBodyEvaluated(
                status: dictationStatus.rawValue,
                showsOverlay: true,
                energyCount: waveformEnergy.count
            ))
        }
    }

    // MARK: - Top bar (varies by state)

    /// Top bar with recording control buttons.
    /// WHY @ViewBuilder: Each state shows different buttons but reserves the same
    /// vertical space (36pt pill + 6pt vertical padding = 48pt total), so the
    /// BrandWaveform below never shifts vertically during state transitions.
    @ViewBuilder
    private var topBar: some View {
        switch dictationStatus {
        case .requested:
            // Cancel only (no stop button -- nothing to stop yet)
            HStack {
                PillButton(icon: "xmark", color: secondaryForeground) {
                    HapticFeedback.recordingStopped()
                    onCancel()
                }
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.trailing, 17)
            .padding(.vertical, 6)

        case .transcribing:
            // Reserve same height as button row so waveform doesn't shift
            Color.clear
                .frame(height: 36)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

        default:
            // Cancel (left) and validate (right) -- pill-shaped Liquid Glass buttons
            HStack {
                PillButton(icon: "xmark", color: secondaryForeground) {
                    HapticFeedback.recordingStopped()
                    onCancel()
                }

                Spacer()

                PillButton(icon: "checkmark", color: .dictusSuccess) {
                    HapticFeedback.recordingStopped()
                    onStop()
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 17)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Footer (varies by state)

    /// Footer with status text and optional timer.
    /// WHY matching heights: Each state reserves the same total footer height
    /// (timer line + caption line + padding) so the BrandWaveform above never
    /// shifts vertically during state transitions.
    @ViewBuilder
    private var footer: some View {
        switch dictationStatus {
        case .requested:
            // Reserve timer height (invisible) so waveform doesn't shift
            Color.clear
                .frame(height: timerFontSize)
                .padding(.bottom, 4)

            Text("Démarrage...")
                .font(.dictusCaption)
                .foregroundColor(secondaryForeground)
                .padding(.bottom, 8)

        case .transcribing:
            // Reserve timer height (invisible) so waveform doesn't shift
            Color.clear
                .frame(height: timerFontSize)
                .padding(.bottom, 4)

            Text("Transcription...")
                .font(.dictusCaption)
                .foregroundColor(secondaryForeground)
                .padding(.bottom, 8)

        default:
            Text(formattedTime)
                .font(.system(size: timerFontSize, weight: .medium, design: .monospaced))
                .foregroundColor(foregroundColor)
                .padding(.bottom, 4)

            Text("En écoute...")
                .font(.dictusCaption)
                .foregroundColor(secondaryForeground)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Pill Button

    /// Pill-shaped recording control button with Liquid Glass styling.
    ///
    /// WHY pill shape instead of SF Symbol circles:
    /// The old xmark.circle.fill / checkmark.circle.fill were small and hard to tap.
    /// Pill buttons (56x36) match the toolbar mic button shape, create visual consistency
    /// across the recording UI, and provide a larger hit target.
    private struct PillButton: View {
        let icon: String
        let color: Color
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 56, height: 36)
                    .contentShape(Rectangle())
                    .dictusGlass(in: Capsule())
            }
            .buttonStyle(GlassPressStyle())
        }
    }
}
