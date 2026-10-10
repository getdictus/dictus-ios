// DictusApp/Onboarding/KeyboardSetupChecklistPictureCard.swift
// The checklist as the Picture in Picture window shows it: three tight rows (#682).
import SwiftUI
import DictusCore

/// The checklist drawn for the Picture in Picture window: the three steps at once, in tight
/// rows, without a title.
///
/// WHY ALL THREE STEPS (decided by Pierre after the second device test, 2026-10-10): the
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
struct KeyboardSetupChecklistPictureCard: View {
    /// One state per line, in `KeyboardSetupChecklistLine.allCases` order.
    let lines: [KeyboardSetupChecklistLineState]
    /// How far each line's tick has popped in, 0 to 1.
    var tickProgress: [Double] = []

    /// The frame's size in points; also the Picture in Picture window's aspect ratio.
    static let size = CGSize(width: 360, height: 132)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(KeyboardSetupChecklistLine.allCases, id: \.self) { line in
                row(line)
            }
        }
        .padding(.horizontal, 18)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .leading)
        .background(KeyboardSetupChecklistCard.background)
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
            KeyboardSetupChecklistBadge(
                number: line.rawValue + 1,
                state: state,
                tickProgress: progress(of: line),
                diameter: 28
            )
            line.title
                .font(.system(size: 18, weight: state == .current ? .semibold : .regular))
                .foregroundStyle(KeyboardSetupChecklistBadge.textColor(for: state))
                // One line each, so the three rows keep the frame short; the longest
                // French line shrinks a little rather than wrapping.
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
