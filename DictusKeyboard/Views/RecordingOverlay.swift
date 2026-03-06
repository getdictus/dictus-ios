// DictusKeyboard/Views/RecordingOverlay.swift
import SwiftUI

/// Full-screen recording overlay that replaces the keyboard during active recording.
/// Shows an animated waveform, elapsed timer, and cancel/stop controls.
///
/// WHY this replaces the keyboard:
/// Wispr Flow-inspired design — when recording, the keyboard area transforms into
/// an immersive recording UI. This prevents accidental key presses during dictation
/// and provides clear visual feedback that the mic is active.
struct RecordingOverlay: View {
    let waveformEnergy: [Float]
    let elapsedSeconds: Double
    let isTranscribing: Bool
    let onCancel: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack {
            // Dark immersive background
            Color.black.opacity(0.95)

            if isTranscribing {
                transcribingContent
            } else {
                recordingContent
            }
        }
    }

    // MARK: - Recording state

    private var recordingContent: some View {
        VStack(spacing: 16) {
            // Top bar: cancel (left) and stop (right)
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.white.opacity(0.7))
                }

                Spacer()

                Button(action: onStop) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Waveform visualization
            KeyboardWaveformView(energy: waveformEnergy)
                .frame(height: 60)
                .padding(.horizontal, 20)

            // Timer in MM:SS format
            Text(formattedTime)
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            // Status label
            Text("Listening...")
                .font(.system(size: 14))
                .foregroundColor(Color.white.opacity(0.5))

            Spacer()
        }
    }

    // MARK: - Transcribing state

    private var transcribingContent: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Processing...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Keyboard Waveform View

/// Waveform visualization adapted for the keyboard extension context.
/// Shows 30 vertical bars whose heights are driven by energy levels.
///
/// WHY a separate view from DictusApp's WaveformView:
/// The keyboard extension is a separate binary — it cannot import DictusApp code.
/// This is a self-contained waveform optimized for the smaller keyboard area.
private struct KeyboardWaveformView: View {
    let energy: [Float]

    /// Number of bars to display
    private let barCount = 30

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let value = energyValue(at: index)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(Double(0.3 + value * 0.7)))
                        .frame(width: barWidth(in: geometry), height: barHeight(value, in: geometry))
                        .frame(height: geometry.size.height, alignment: .center)
                        .animation(.easeOut(duration: 0.15), value: value)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Map energy array values to bar indices, distributing evenly.
    private func energyValue(at index: Int) -> Float {
        guard !energy.isEmpty else { return 0.05 }
        let mappedIndex = index * energy.count / barCount
        let clampedIndex = min(mappedIndex, energy.count - 1)
        return max(0.05, min(1.0, energy[clampedIndex]))
    }

    private func barWidth(in geometry: GeometryProxy) -> CGFloat {
        let totalSpacing = CGFloat(barCount - 1) * 2
        return (geometry.size.width - totalSpacing) / CGFloat(barCount)
    }

    private func barHeight(_ value: Float, in geometry: GeometryProxy) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight = geometry.size.height
        return minHeight + CGFloat(value) * (maxHeight - minHeight)
    }
}
