// DictusApp/Views/KeyboardModePicker.swift
// Reusable keyboard mode picker with segmented control and miniature previews.
import SwiftUI
import DictusCore

/// Segmented picker for selecting keyboard mode with a non-interactive miniature preview.
///
/// WHY reusable component:
/// This picker appears in both SettingsView and onboarding (ModeSelectionPage).
/// Extracting it into a single component ensures consistent look and behavior,
/// and any future design changes only need to happen in one place.
///
/// WHY @Binding var selectedMode: String (not KeyboardMode):
/// @AppStorage stores the raw String value. Binding directly to the raw value
/// avoids an unnecessary conversion layer in every parent that uses @AppStorage.
struct KeyboardModePicker: View {

    @Binding var selectedMode: String

    var body: some View {
        VStack(spacing: 16) {
            // Segmented picker with display names from KeyboardMode enum
            Picker("Mode", selection: $selectedMode) {
                ForEach(KeyboardMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            // Non-interactive miniature preview of the selected mode
            previewForMode
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dictusBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.dictusAccent.opacity(0.15), lineWidth: 1)
                )
                .allowsHitTesting(false)
        }
    }

    // MARK: - Preview Router

    /// Routes to the correct miniature preview based on the selected mode.
    ///
    /// WHY switch on rawValue:
    /// selectedMode is a String from @AppStorage. We compare against KeyboardMode
    /// raw values to determine which preview to show.
    @ViewBuilder
    private var previewForMode: some View {
        switch selectedMode {
        case KeyboardMode.micro.rawValue:
            microModePreview
        case KeyboardMode.emojiMicro.rawValue:
            emojiModePreview
        default:
            fullModePreview
        }
    }

    // MARK: - Micro Mode Preview

    /// Large centered mic circle with a small globe icon in bottom-left.
    /// Represents the minimal dictation-first layout.
    private var microModePreview: some View {
        ZStack {
            // Large mic button
            Circle()
                .fill(Color.dictusAccent)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                )

            // Globe icon bottom-left
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(8)
                    Spacer()
                }
            }
        }
        .padding(12)
    }

    // MARK: - Emoji Mode Preview

    /// Grid of colored rounded rectangles (emoji placeholders) with a toolbar bar
    /// at the top containing a mic circle. Represents the emoji + mic layout.
    private var emojiModePreview: some View {
        VStack(spacing: 6) {
            // Toolbar bar with mic
            HStack {
                Spacer()
                Circle()
                    .fill(Color.dictusAccent)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    )
                Spacer()
            }
            .frame(height: 28)

            // Emoji grid placeholder — 3 rows x 6 columns of colored blocks
            let emojiColors: [Color] = [
                .yellow, .orange, .red, .pink, .purple, .blue,
                .green, .mint, .cyan, .indigo, .brown, .yellow,
                .orange, .red, .green, .blue, .purple, .pink,
            ]

            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(emojiColors[row * 6 + col].opacity(0.6))
                            .frame(height: 22)
                    }
                }
            }
        }
        .padding(12)
    }

    // MARK: - Full Mode Preview

    /// Four rows of small rounded rectangles (key placeholders) with a toolbar bar at top.
    /// Represents the full AZERTY/QWERTY keyboard layout.
    private var fullModePreview: some View {
        VStack(spacing: 4) {
            // Toolbar bar
            HStack {
                Spacer()
                Circle()
                    .fill(Color.dictusAccent)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    )
                Spacer()
            }
            .frame(height: 24)

            // Key rows — 10, 10, 9, 5 keys mimicking AZERTY layout proportions
            let keyCounts = [10, 10, 9, 5]
            ForEach(0..<keyCounts.count, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<keyCounts[row], id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 18)
                    }
                }
            }
        }
        .padding(12)
    }
}
