// DictusApp/Onboarding/KeyboardSetupChecklistInline.swift
// The checklist in the page, for the fallback only (#682).
import SwiftUI
import DictusCore

/// The checklist card in the page, shown only when Picture in Picture will not carry it
/// (`KeyboardSetupChecklistPlayer.showsInlineCard`). On the Picture in Picture path the page
/// shows nothing extra: the drawn Settings page already numbers the steps.
struct KeyboardSetupChecklistInline: View {
    @ObservedObject var player: KeyboardSetupChecklistPlayer

    private static let cornerRadius: CGFloat = 22

    var body: some View {
        KeyboardSetupChecklistCard(lines: player.lines, tickProgress: player.tickProgress)
        .frame(width: KeyboardSetupChecklistCard.size.width, height: KeyboardSetupChecklistCard.size.height)
        .background(KeyboardSetupChecklistCard.background)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// "Set up Dictus. Tap Keyboards, done. …" read in one go, with the ticked state.
    private var accessibilityText: String {
        let title = String(localized: "Set up Dictus", comment: "Title of the checklist card that floats over iOS Settings during keyboard setup (#682).")
        let done = String(localized: "done", comment: "VoiceOver state of a ticked line of the keyboard setup checklist (#682).")
        let lineTexts = KeyboardSetupChecklistLine.allCases.map { line -> String in
            let isDone = player.lines.indices.contains(line.rawValue) && player.lines[line.rawValue] == .done
            return isDone ? "\(line.spokenTitle), \(done)" : line.spokenTitle
        }
        return ([title] + lineTexts).joined(separator: ". ")
    }
}
