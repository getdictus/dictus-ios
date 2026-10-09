// DictusApp/Onboarding/KeyboardSetupChecklistCard.swift
// The keyboard step's checklist, drawn: the dark card that floats over Settings (#682).
import SwiftUI
import DictusCore

/// The checklist card of mock-up `03b-pip-checklist-sur-reglages`: the Dictus icon and a
/// title, then the four taps to make in Settings, ticked as they are done.
///
/// WHY ONE VIEW FOR TWO RENDERERS: the same card is drawn inline by SwiftUI (the fallback,
/// on a device without Picture in Picture) and rendered frame by frame into the sample
/// buffers that Picture in Picture shows (`ChecklistFrameRenderer`). One view means the
/// two can never drift apart.
///
/// WHY FIXED COLOURS AND SIZES: the mock-up draws the card dark in light and dark mode
/// alike, as Wispr Flow's floating guide is, because it sits over whatever Settings looks
/// like. Its type does not follow Dynamic Type either: the card is rendered into a picture
/// of a fixed size that the Picture in Picture window scales, and text that grew would
/// overflow it. The card is full-bleed (square corners): the Picture in Picture window
/// rounds its own, and the inline container clips the same frame to a rounded card.
struct KeyboardSetupChecklistCard: View {
    /// One state per line, in `KeyboardSetupChecklistLine.allCases` order.
    let lines: [KeyboardSetupChecklistLineState]
    /// How far each line's tick has popped in, 0 to 1. A line that is not done, or done
    /// for a while, reads 1 (no animation).
    var tickProgress: [Double] = []

    /// The card's size in points. The Picture in Picture window takes its aspect ratio
    /// from the frames, so this is also the window's shape.
    static let size = CGSize(width: 300, height: 220)

    /// The card's fill: the app's dark, a shade deeper so it reads over the dark app too.
    static let background = Color(hex: 0x0F1728)

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
        .background(Self.background)
        .environment(\.colorScheme, .dark)
    }

    private func state(of line: KeyboardSetupChecklistLine) -> KeyboardSetupChecklistLineState {
        lines.indices.contains(line.rawValue) ? lines[line.rawValue] : .pending
    }

    private func progress(of line: KeyboardSetupChecklistLine) -> Double {
        tickProgress.indices.contains(line.rawValue) ? tickProgress[line.rawValue] : 1
    }

    private func row(_ line: KeyboardSetupChecklistLine) -> some View {
        let state = state(of: line)
        return HStack(spacing: 12) {
            badge(line, state: state)
            line.title
                .font(.system(size: 15, weight: state == .current ? .semibold : .regular))
                .foregroundStyle(textColor(for: state))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Green with a check once done, accent with the number while current, a faint disc
    /// with the number before.
    @ViewBuilder
    private func badge(_ line: KeyboardSetupChecklistLine, state: KeyboardSetupChecklistLineState) -> some View {
        let diameter: CGFloat = 26
        switch state {
        case .done:
            let progress = progress(of: line)
            Circle()
                .fill(Color.dictusSuccess)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        // The tick pops in: from half size to a slight overshoot, then
                        // settles. Driven by the frame clock, not a SwiftUI animation,
                        // because the frames sent to Picture in Picture are rendered one
                        // by one and SwiftUI animations do not run there.
                        .scaleEffect(Self.popScale(progress))
                        .opacity(min(1, progress * 2))
                )
        case .current:
            Text(verbatim: "\(line.rawValue + 1)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.dictusAccent))
        case .pending:
            Text(verbatim: "\(line.rawValue + 1)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }

    private func textColor(for state: KeyboardSetupChecklistLineState) -> Color {
        switch state {
        case .done: return Color.white.opacity(0.45)
        case .current: return .white
        case .pending: return Color.white.opacity(0.62)
        }
    }

    /// 0.5 → 1.15 over the first 70 % of the pop, then back to 1.
    static func popScale(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        if clamped < 0.7 {
            return 0.5 + (1.15 - 0.5) * (clamped / 0.7)
        }
        return 1.15 - 0.15 * ((clamped - 0.7) / 0.3)
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
        case .turnOnFullAccess:
            return Text("Turn on Full Access", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Full Access switch.")
        case .allowAndComeBack:
            return Text("Tap Allow, then come back", comment: "Checklist line over iOS Settings during keyboard setup (#682): confirm iOS's alert, then return to Dictus.")
        }
    }

    /// The same text as a string, for the VoiceOver label of the inline card.
    var spokenTitle: String {
        switch self {
        case .tapKeyboards:
            return String(localized: "Tap Keyboards", comment: "Checklist line over iOS Settings during keyboard setup (#682): tap the Keyboards row.")
        case .turnOnDictus:
            return String(localized: "Turn on Dictus", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Dictus keyboard switch.")
        case .turnOnFullAccess:
            return String(localized: "Turn on Full Access", comment: "Checklist line over iOS Settings during keyboard setup (#682): turn on the Full Access switch.")
        case .allowAndComeBack:
            return String(localized: "Tap Allow, then come back", comment: "Checklist line over iOS Settings during keyboard setup (#682): confirm iOS's alert, then return to Dictus.")
        }
    }
}
