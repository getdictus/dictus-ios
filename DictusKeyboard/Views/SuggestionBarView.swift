// DictusKeyboard/Views/SuggestionBarView.swift
// Displays up to 3 word/accent suggestions in a horizontal row within the toolbar.
import SwiftUI
import DictusCore

/// A 3-slot suggestion bar that appears in the toolbar while the user is typing.
///
/// WHY a separate view:
/// The suggestion bar has its own layout logic (equal-width slots, dividers,
/// bold center slot) that would clutter ToolbarView. Extracting it keeps
/// both views focused on a single responsibility.
///
/// WHY .frame(maxWidth: .infinity) per slot:
/// This ensures all slots take equal width regardless of text length,
/// matching Apple's native keyboard suggestion bar layout.
///
/// Visual states per mode:
/// - completions: bold best completion in slot 1, others regular.
/// - corrections: quoted original in slot 0, bold correction in slot 1.
/// - predictions: all slots equal weight.
/// - undoAvailable: slot 0 is the "undo chip" — accent-tinted with an
///   undo arrow icon. It pulses briefly when a correction is applied (#224):
///   autocorrect fires no haptic, so this pulse is the correction feedback.
///   It says both "we corrected this" and "tap here to revert".
///
/// With "New suggestion bar" on in Settings › Keyboard › Experiments (#502), the bar draws
/// Apple's look instead (`capsuleBar`, at the end of this file): the same words in the same
/// slots, the word space will apply in a neutral capsule rather than in bold, the undo chip
/// a blue capsule of the same height.
struct SuggestionBarView: View {
    let suggestions: [String]
    let mode: SuggestionMode
    let onTap: (Int) -> Void

    /// True during the brief flash of the undo chip right after a correction.
    /// The chip rises to a stronger tint + slight scale, then eases back to
    /// its resting tint (which persists while undo is available).
    @State private var undoPulseActive = false

    /// Which look the bar draws: the capsules of the Experiments switch (#502) or the
    /// classic bar. Observed so a change read at the keyboard's appearance redraws the bar.
    @ObservedObject private var look = SuggestionBarLook.shared

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else if look.drawsCapsules {
            capsuleBar
        } else {
            HStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                    if index > 0 {
                        // Thin vertical divider between slots (Apple keyboard style)
                        Rectangle()
                            .fill(Color(.systemGray3))
                            .frame(width: 0.5)
                            .padding(.vertical, 8)
                    }

                    Button {
                        onTap(index)
                    } label: {
                        slotLabel(suggestion, at: index)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: suggestions)
            // The bar leaves the hierarchy between correction and undoAvailable
            // (suggestions are cleared, then repopulated async), so entry into
            // undo mode is usually a fresh onAppear. onChange covers in-place
            // transitions (e.g. predictions -> undoAvailable without emptying).
            .onAppear {
                if mode == .undoAvailable { triggerUndoPulse() }
            }
            .onChange(of: mode) { _, newMode in
                if newMode == .undoAvailable { triggerUndoPulse() }
            }
        }
    }

    // MARK: - Slot rendering

    /// Renders one suggestion slot. The undo chip (slot 0 in undo mode) gets
    /// dedicated styling; all other slots are plain text.
    @ViewBuilder
    private func slotLabel(_ suggestion: String, at index: Int) -> some View {
        if mode == .undoAvailable && index == 0 {
            undoChip(word: suggestion)
        } else {
            // In correction mode:
            //   index 0 = original word in quotes (tapping keeps it as-is)
            //   index 1 = bold correction (auto-applied on space)
            //   index 2 = alternative correction
            // In completion mode:
            //   index 1 = bold (best completion)
            //   others = regular weight
            // In prediction mode, and in candidates mode (typed word kept, #993):
            //   All equal weight -- no "auto-applied" word, all are suggestions
            // This matches standard iOS keyboard suggestion bar behavior.
            Text(displayText(suggestion, at: index))
                .font(.system(size: 15))
                .fontWeight(fontWeight(at: index))
                .foregroundColor(Color(.label))
        }
    }

    /// The undo chip: original word + undo arrow on an accent-tinted capsule.
    ///
    /// WHY a tinted chip instead of plain text (#224):
    /// Autocorrect no longer fires a haptic, so the bar is the only surface
    /// that signals "a word was just corrected". The persistent accent tint
    /// keeps the revert action discoverable for as long as undo is available;
    /// the entry pulse marks the moment of correction itself.
    private func undoChip(word: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 12, weight: .semibold))
            Text(word)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.dictusAccent)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.dictusAccent.opacity(undoPulseActive ? 0.35 : 0.12))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
        .scaleEffect(undoPulseActive ? 1.05 : 1.0)
    }

    /// Flashes the undo chip: instant rise (reads as an event, not a fade-in),
    /// then a ~0.45s ease back to the resting tint.
    ///
    /// WHY withTransaction for the rise:
    /// The enclosing bar animates on `suggestions` changes; disabling animations
    /// for the rise guarantees the flash starts at full strength immediately.
    private func triggerUndoPulse() {
        var rise = Transaction()
        rise.disablesAnimations = true
        withTransaction(rise) { undoPulseActive = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.45)) {
                undoPulseActive = false
            }
        }
    }

    /// In correction mode, the original word (index 0) is shown in quotes
    /// to indicate it's the "as-typed" option. Matches iOS native behavior
    /// where the unquoted bold center word is the one that gets auto-applied.
    private func fontWeight(at index: Int) -> Font.Weight {
        switch mode {
        case .predictions, .candidates:
            return .regular
        case .swipePreview:
            // The word so far, alone in the bar (#948).
            return .semibold
        case .undoAvailable:
            return index == 0 ? .semibold : .regular
        default:
            return index == 1 ? .semibold : .regular
        }
    }

    private func displayText(_ suggestion: String, at index: Int) -> String {
        if (mode == .corrections || mode == .candidates) && index == 0 {
            return "\u{201C}\(suggestion)\u{201D}"
        }
        return suggestion
    }
}

// MARK: - The capsule look (#502)

/// Whether the bar draws the capsule look, as the keyboard last read its Experiments switch.
///
/// WHY a shared observable rather than a parameter: the switch is read once per appearance
/// (`DictusKeyboardBridge.refreshExperiments`), like every other experiment, and only this
/// view draws differently. Holding the answer here keeps the toolbar and the root view, which
/// only relay suggestions, out of it. Main thread only, like the view that observes it.
final class SuggestionBarLook: ObservableObject {
    static let shared = SuggestionBarLook()

    @Published private(set) var drawsCapsules = KeyboardFeatureSettings.Defaults.suggestionCapsules

    /// Takes the switch as it acts on this build. Publishes only a change, so an appearance
    /// that changes nothing redraws nothing.
    func refresh(_ settings: KeyboardFeatureSettings) {
        let isOn = settings.isSuggestionCapsulesEffective
        if isOn != drawsCapsules { drawsCapsules = isOn }
    }
}

/// The bar as Apple draws it on iOS 26 and 27, measured on an iPhone 17 Pro simulator (iOS
/// 27.2, light and dark, 2026-11-26): SF 17 pt regular in a muted ink, 1 x 24 pt dividers, and
/// the word space will apply in a capsule the width of its slot, the dividers beside it hidden.
/// The translucent inks and fills are Hex's, which measured the same bar and reproduce Apple's
/// colours over any backdrop (anomalyco/hex@bfa25200aef7bce802c6c87aa9914dfd83626c69,
/// ios/HEXShared/FullKeyboard/FullKeyboardPalette.swift and KeyboardStripView.swift; MIT,
/// Copyright (c) 2026 Christopher Langton).
///
/// Display only: every slot shows the same word, in the same place, and a tap sends the same
/// index as in the classic bar. What is offered, applied and when is `SuggestionState`'s and
/// `DictusKeyboardBridge`'s, untouched.
private enum CapsuleMetrics {
    /// Apple's words: 17 pt regular, the one in the capsule included.
    static let fontSize: CGFloat = 17
    /// A long word shrinks to 15 pt before it truncates, as Hex's does: Dictus's slots are
    /// narrower than Apple's (the mic shares the bar).
    static let minimumScale: CGFloat = 15 / 17
    /// Apple's capsule is about 37 pt (112 px at 3x), its ends fully round. Dictus draws it
    /// 36 pt: the slot's tap target, and the height of the mic pill beside it in the same bar,
    /// which a 37 pt capsule would overshoot by half a point at each end.
    static let capsuleHeight: CGFloat = 36
    /// Apple's dividers: 1 x 24 pt.
    static let dividerWidth: CGFloat = 1
    static let dividerHeight: CGFloat = 24
}

private extension SuggestionBarView {

    /// What sits in a capsule. A plain slot is tap-only; only these two are something more.
    enum CapsuleKind { case none, pending, undo }

    /// The slot space will apply gets the neutral capsule: index 1 of `.corrections`, the one
    /// `handleSpace` commits, and the swiped word while the finger is down, which goes in on
    /// lift. Completions, candidates and predictions are tap-only (ADR 0004), so none of
    /// them is marked. The undo chip is slot 0 of `.undoAvailable`.
    func capsuleKind(at index: Int) -> CapsuleKind {
        switch mode {
        case .corrections: return index == 1 ? .pending : .none
        case .swipePreview: return .pending
        case .undoAvailable: return index == 0 ? .undo : .none
        default: return .none
        }
    }

    var capsuleBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                if index > 0 {
                    // Always laid out, hidden beside a capsule as Apple's are: a divider that
                    // came and went with the capsule would move the slots by a point.
                    Rectangle()
                        .fill(dividerInk)
                        .frame(width: CapsuleMetrics.dividerWidth, height: CapsuleMetrics.dividerHeight)
                        .opacity(capsuleKind(at: index - 1) == .none && capsuleKind(at: index) == .none ? 1 : 0)
                }

                Button {
                    onTap(index)
                } label: {
                    capsuleSlot(suggestion, at: index)
                        .frame(maxWidth: .infinity)
                        // The classic bar's tap target, unchanged: the capsule is drawn inside it.
                        .frame(height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: suggestions)
        .onAppear {
            if mode == .undoAvailable { triggerUndoPulse() }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .undoAvailable { triggerUndoPulse() }
        }
    }

    @ViewBuilder
    func capsuleSlot(_ suggestion: String, at index: Int) -> some View {
        switch capsuleKind(at: index) {
        case .none:
            capsuleText(displayText(suggestion, at: index))
                .foregroundColor(wordInk)
                .padding(.horizontal, 6)
        case .pending:
            capsuleText(displayText(suggestion, at: index))
                .foregroundColor(pendingInk)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .frame(height: CapsuleMetrics.capsuleHeight)
                .background(Capsule().fill(pendingFill))
        case .undo:
            capsuleUndoChip(word: suggestion)
        }
    }

    func capsuleText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: CapsuleMetrics.fontSize, weight: .regular))
            .lineLimit(1)
            .minimumScaleFactor(CapsuleMetrics.minimumScale)
    }

    /// The undo chip as the pending word's capsule: same height, same round ends, the width of
    /// its slot, and the blue that says it is a button (#502). The arrow leads, as on the
    /// dictation undo beside it. The entry pulse is the classic chip's.
    func capsuleUndoChip(word: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .medium))
            capsuleText(word)
        }
        .foregroundColor(.dictusAccent)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: CapsuleMetrics.capsuleHeight)
        .background(
            Capsule().fill(Color.dictusAccent.opacity(undoPulseActive ? 0.35 : 0.12))
        )
        .scaleEffect(undoPulseActive ? 1.05 : 1.0)
    }

    // Apple's inks over its platter, light (226,227,232) and dark (32,32,32): words
    // (74,74,76) / (162,162,162), dividers (211,212,217) / (49,49,51), the capsule
    // (235,237,240) under (44,46,49) / (115,115,115) under white. As Hex writes them.

    var isDark: Bool { colorScheme == .dark }
    var wordInk: Color { isDark ? Color(white: 1, opacity: 0.58) : Color(white: 0, opacity: 0.67) }
    var dividerInk: Color { isDark ? Color(white: 1, opacity: 0.075) : Color(white: 0, opacity: 0.066) }
    var pendingFill: Color { isDark ? Color(white: 1, opacity: 0.37) : Color(white: 1, opacity: 0.33) }
    var pendingInk: Color { isDark ? .white : Color(white: 0, opacity: 0.81) }
}
