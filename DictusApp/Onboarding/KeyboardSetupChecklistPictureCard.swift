// DictusApp/Onboarding/KeyboardSetupChecklistPictureCard.swift
// The checklist as the Picture in Picture window shows it: one step, wide and short (#682).
import SwiftUI
import DictusCore

/// The checklist drawn for the Picture in Picture window: the step to do now, large, and
/// four dots for where the user is.
///
/// WHY WIDE AND SHORT (decided by Pierre after the device test of 2026-10-10): the first
/// version drew the four lines, which made the window tall. Over Settings > Keyboards it
/// covered the Allow / Don't Allow buttons of the Full Access alert, the very tap it is
/// there to guide. The window takes its shape from the frames, so a frame about 3.2 times
/// as wide as it is tall gives a default window that leaves the middle of the screen free.
///
/// WHY ONE STEP: in a window that short, only one line is readable. The just-ticked step
/// stays up with a green check for a moment (`justTickedHold` in the player's clock),
/// then the next step takes its place, so a tick is still seen as it happens.
///
/// Fixed dark colours and fixed type, for the reasons `KeyboardSetupChecklistCard` gives:
/// the frame is a picture of a fixed size that the window scales.
struct KeyboardSetupChecklistPictureCard: View {
    /// One state per line, in `KeyboardSetupChecklistLine.allCases` order.
    let lines: [KeyboardSetupChecklistLineState]
    /// How far each line's tick has gone, 0 to 1; below 1 means "just ticked".
    var tickProgress: [Double] = []

    /// The frame's size in points; also the Picture in Picture window's aspect ratio.
    static let size = CGSize(width: 360, height: 112)

    var body: some View {
        let shown = shownLine
        HStack(spacing: 16) {
            badge(for: shown)

            VStack(alignment: .leading, spacing: 8) {
                shown.line.title
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)

                progressRow(highlighting: shown.line)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(KeyboardSetupChecklistCard.background)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Which line

    /// The line on screen, and whether it is shown as just ticked.
    private struct ShownLine {
        let line: KeyboardSetupChecklistLine
        /// Tick progress, when the line is shown because it was just ticked.
        let tick: Double?
    }

    /// The latest line still in its tick, else the current line, else the last line
    /// (everything done).
    private var shownLine: ShownLine {
        let all = KeyboardSetupChecklistLine.allCases
        if let justTicked = all.last(where: { state(of: $0) == .done && progress(of: $0) < 1 }) {
            return ShownLine(line: justTicked, tick: progress(of: justTicked))
        }
        if let current = all.first(where: { state(of: $0) == .current }) {
            return ShownLine(line: current, tick: nil)
        }
        if let pending = all.first(where: { state(of: $0) == .pending }) {
            return ShownLine(line: pending, tick: nil)
        }
        return ShownLine(line: .allowAndComeBack, tick: 1)
    }

    private func state(of line: KeyboardSetupChecklistLine) -> KeyboardSetupChecklistLineState {
        lines.indices.contains(line.rawValue) ? lines[line.rawValue] : .pending
    }

    private func progress(of line: KeyboardSetupChecklistLine) -> Double {
        tickProgress.indices.contains(line.rawValue) ? tickProgress[line.rawValue] : 1
    }

    // MARK: - Pieces

    /// The step number on the accent, or a green check that pops in when it was ticked.
    @ViewBuilder
    private func badge(for shown: ShownLine) -> some View {
        let diameter: CGFloat = 48
        if let tick = shown.tick {
            Circle()
                .fill(Color.dictusSuccess)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        // The pop runs over the first third of the hold.
                        .scaleEffect(KeyboardSetupChecklistCard.popScale(min(1, tick * 3)))
                )
        } else {
            Text(verbatim: "\(shown.line.rawValue + 1)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Color.dictusAccent))
        }
    }

    /// Four dots (green done, accent for the step shown, faint ahead), then "Step 3 of 4".
    private func progressRow(highlighting shown: KeyboardSetupChecklistLine) -> some View {
        let total = KeyboardSetupChecklistLine.allCases.count
        return HStack(spacing: 6) {
            ForEach(KeyboardSetupChecklistLine.allCases, id: \.self) { line in
                Capsule()
                    .fill(dotColor(line, shown: shown))
                    .frame(width: line == shown ? 18 : 8, height: 8)
            }
            Text("Step \(shown.rawValue + 1) of \(total)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.leading, 4)
        }
    }

    private func dotColor(_ line: KeyboardSetupChecklistLine, shown: KeyboardSetupChecklistLine) -> Color {
        if state(of: line) == .done { return .dictusSuccess }
        if line == shown { return .dictusAccent }
        return Color.white.opacity(0.18)
    }
}
