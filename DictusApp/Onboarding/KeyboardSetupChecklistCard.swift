// DictusApp/Onboarding/KeyboardSetupChecklistCard.swift
// The keyboard step's checklist, drawn: the dark card that floats over Settings (#682).
import SwiftUI
import DictusCore

/// The checklist card of mock-up `03b-pip-checklist-sur-reglages`: the Dictus icon and a
/// title, then the three taps to make in Settings, ticked as they are done (three since
/// the device test of 2026-10-10: Full Access and Allow are one line).
///
/// WHERE IT SHOWS: only in the fallback, inline under the drawn Settings page, when
/// Picture in Picture is unavailable or failed to start. The Picture in Picture window
/// draws the same states in a short, title-less form (`SettingsChecklistPictureCard`),
/// because a card with a title made the window tall enough to cover the Full Access
/// alert's buttons (device test, 2026-10-10).
///
/// WHY FIXED COLOURS AND SIZES: the mock-up draws the card dark in light and dark mode
/// alike, as Wispr Flow's floating guide is, because it sits over whatever Settings looks
/// like, and the Picture in Picture form keeps the same look. Its type does not follow
/// Dynamic Type, so the fixed frame never overflows. The card is full-bleed (square
/// corners); the inline container clips it to a rounded card.
struct KeyboardSetupChecklistCard: View {
    /// One state per line, in `KeyboardSetupChecklistLine.allCases` order.
    let lines: [SettingsChecklistLineState]
    /// How far each line's tick has popped in, 0 to 1. A line that is not done, or done
    /// for a while, reads 1 (no animation).
    var tickProgress: [Double] = []

    /// The card's size in points.
    static let size = CGSize(width: 300, height: 184)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DictusIconTile(logoHeight: 15)
                Text("Set up Dictus", comment: "Title of the checklist card that floats over iOS Settings during keyboard setup (#682).")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 2)

            ForEach(KeyboardSetupChecklistLine.allCases, id: \.self) { line in
                row(line)
            }
        }
        .padding(18)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(SettingsChecklistPictureCard.background)
        .environment(\.colorScheme, .dark)
    }

    private func state(of line: KeyboardSetupChecklistLine) -> SettingsChecklistLineState {
        lines.indices.contains(line.rawValue) ? lines[line.rawValue] : .pending
    }

    private func progress(of line: KeyboardSetupChecklistLine) -> Double {
        tickProgress.indices.contains(line.rawValue) ? tickProgress[line.rawValue] : 1
    }

    private func row(_ line: KeyboardSetupChecklistLine) -> some View {
        let state = state(of: line)
        return HStack(spacing: 12) {
            SettingsChecklistBadge(
                number: line.rawValue + 1,
                state: state,
                tickProgress: progress(of: line),
                diameter: 26
            )
            line.title
                .font(.system(size: 15, weight: state == .current ? .semibold : .regular))
                .foregroundStyle(SettingsChecklistBadge.textColor(for: state))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Copy

extension KeyboardSetupChecklistLine {
    /// The line's text, in the user's language.
    var title: Text {
        switch self {
        case .tapKeyboards:
            return Text("Tap Keyboards", comment: "Checklist line over iOS Settings during keyboard setup (#682): tap the Keyboards row.")
        case .turnOnDictus:
            return Text("Turn on Dictus", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Dictus keyboard switch.")
        case .turnOnFullAccessAndAllow:
            return Text("Turn on Full Access, then Allow", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Full Access switch, then confirm iOS's alert. One line in a small window: keep it short.")
        }
    }

    /// The same text as a string, for the VoiceOver label of the inline card.
    var spokenTitle: String {
        switch self {
        case .tapKeyboards:
            return String(localized: "Tap Keyboards", comment: "Checklist line over iOS Settings during keyboard setup (#682): tap the Keyboards row.")
        case .turnOnDictus:
            return String(localized: "Turn on Dictus", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Dictus keyboard switch.")
        case .turnOnFullAccessAndAllow:
            return String(localized: "Turn on Full Access, then Allow", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Full Access switch, then confirm iOS's alert. One line in a small window: keep it short.")
        }
    }
}
