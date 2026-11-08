// DictusApp/Onboarding/SettingsChecklistPictureCard.swift
// A checklist as the Picture in Picture window shows it: three tight rows (#682, #706).
import SwiftUI
import DictusCore

/// A checklist drawn for the Picture in Picture window over Settings: every step at once,
/// in tight rows, without a title. The keyboard step (#682) and the Apple Intelligence
/// step (#706) each give it their lines.
///
/// WHY ALL THE STEPS (decided by Pierre after the second device test, 2026-10-10): the
/// previous version showed one step at a time. The Keyboards tap cannot be observed, so
/// once the user had tapped it, the window still said "1 Tap Keyboards" while the Dictus
/// switch was in front of them, and a user following only the window stopped there. With
/// every step on screen the next one is always readable, whatever the app can see.
///
/// WHY THIS SHAPE, ABOUT 2.7 : 1 (360 × 132 pt): the window takes its aspect ratio from
/// the frames. The first four-line card (300 × 220, about 1.4 : 1) made a default window
/// tall enough to cover the Allow / Don't Allow buttons of the Full Access alert, which sit
/// around 63 % of the screen height on an iPhone 15 Pro Max; the one-step 3.2 : 1 version
/// left them free (device test, 2026-10-10). Three rows with no header land in between,
/// at about half the first card's height for the same width.
///
/// Fixed dark colours and fixed type, as `KeyboardSetupChecklistCard`: the frame is a
/// picture of a fixed size that the window scales.
struct SettingsChecklistPictureCard: View {
    /// The text of each line, in order.
    let titles: [Text]
    /// One state per line, in the same order.
    let lines: [SettingsChecklistLineState]
    /// How far each line's tick has popped in, 0 to 1.
    var tickProgress: [Double] = []

    /// The frame's size in points; also the Picture in Picture window's aspect ratio.
    static let size = CGSize(width: 360, height: 132)

    /// The card's fill: the app's dark, a shade deeper so it reads over the dark app too.
    static let background = Color(hex: 0x0F1728)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(titles.indices, id: \.self) { index in
                row(index)
            }
        }
        .padding(.horizontal, 18)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .leading)
        .background(Self.background)
        .environment(\.colorScheme, .dark)
    }

    private func state(at index: Int) -> SettingsChecklistLineState {
        lines.indices.contains(index) ? lines[index] : .pending
    }

    private func progress(at index: Int) -> Double {
        tickProgress.indices.contains(index) ? tickProgress[index] : 1
    }

    private func row(_ index: Int) -> some View {
        let state = state(at: index)
        return HStack(spacing: 12) {
            SettingsChecklistBadge(
                number: index + 1,
                state: state,
                tickProgress: progress(at: index),
                diameter: 28
            )
            titles[index]
                .font(.system(size: 18, weight: state == .current ? .semibold : .regular))
                .foregroundStyle(SettingsChecklistBadge.textColor(for: state))
                // One line each, so the three rows keep the frame short; the longest
                // French lines shrink a little rather than wrapping.
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - Badge

/// A line's number disc, shared by the inline card and the Picture in Picture frames:
/// green with a check once done, accent with the number while current, a faint disc with
/// the number before.
struct SettingsChecklistBadge: View {
    let number: Int
    let state: SettingsChecklistLineState
    /// How far the tick has popped in, 0 to 1.
    let tickProgress: Double
    let diameter: CGFloat

    var body: some View {
        switch state {
        case .done:
            Circle()
                .fill(Color.dictusSuccess)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: diameter * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                        // The tick pops in: from half size to a slight overshoot, then
                        // settles. Driven by the frame clock, not a SwiftUI animation,
                        // because the frames sent to Picture in Picture are rendered one
                        // by one and SwiftUI animations do not run there.
                        .scaleEffect(Self.popScale(tickProgress))
                        .opacity(min(1, tickProgress * 2))
                )
        case .current:
            Text(verbatim: "\(number)")
                .font(.system(size: diameter * 0.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.dictusAccent))
        case .pending:
            Text(verbatim: "\(number)")
                .font(.system(size: diameter * 0.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }

    /// The line's text colour for its state.
    static func textColor(for state: SettingsChecklistLineState) -> Color {
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
