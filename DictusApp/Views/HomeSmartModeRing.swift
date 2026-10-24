// DictusApp/Views/HomeSmartModePicker.swift
// The home mic's Smart Mode chip and the picker it opens (issue #489).
import SwiftUI
import DictusCore

/// The visible half of the home mic's Smart Mode surface: the armed mode, named, beside
/// the mic, and the way into the picker.
///
/// ### Why a chip as well as the badge
///
/// The badge on the mic is what the user sees out of the corner of the eye, and it is
/// the keyboard pill's own badge. It cannot be the control that changes the mode: it is
/// a 24 pt disc on the 72 pt button whose tap starts a dictation, and a target that
/// small inside that button would take record taps and miss its own. And in Normal there
/// is no badge at all, so a user who never armed anything would have nothing to tap.
///
/// The chip is always there while the surface is offered, says the mode in words — the
/// sentence #489 found missing — and is the picker's entry point. The long press on the
/// mic is the accelerator, not the only door (#489 acceptance 3).
struct HomeSmartModeChip: View {

    /// The mode the next dictation runs, or nil for Normal.
    let mode: SmartMode?

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(HomeSmartModePicker.name(of: mode))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            // Accent while a mode is in force, so the one state the user has to notice
            // is the one that stands out; Normal reads as plain text.
            .foregroundColor(mode == nil ? .primary : .dictusAccent)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .dictusGlass(in: Capsule())
            // The capsule is 32 pt tall; the touch target is Apple's 44.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.94))
        .accessibilityLabel(Text("Smart Mode"))
        .accessibilityValue(Text(HomeSmartModePicker.spokenName(of: mode)))
        .accessibilityIdentifier("home.smartMode")
    }
}

/// The keyboard's long-press fan, drawn on the home screen (#489).
///
/// ### Same rows, same tags, its own gesture
///
/// The rows, their order, their tags and what each may do are `SmartModeHomePicker`'s,
/// which builds them with the fan's own functions. This view draws them the way
/// `SmartModeFanView` does — a glass capsule per row, icon and name centred, the check,
/// `Off` and `PRO` tags, the Dictus Pro row in the paywall's gradient — so the menu
/// reads as the same object in both places.
///
/// What differs is the gesture, and on purpose. The fan is a drag: the finger went down
/// on a 36 pt pill and has nowhere else to go. Here the picker stays open and each row is
/// a plain button, which is what makes it reachable from the chip and from VoiceOver at
/// all — the fan's gesture-only design is #397's problem, and this surface does not
/// inherit it.
///
/// ### Rows grow upward, Normal nearest the mic
///
/// The fan deploys downward from a mic at the top of the keyboard, Normal first because
/// the nearest row is the cheapest to reach. The home mic sits at the bottom of the
/// screen, so the same rule puts Normal at the bottom of this column, against the mic,
/// and the modes above it in the fan's order going away from the thumb.
struct HomeSmartModePicker: View {

    let picker: SmartModeHomePicker

    let onChoose: (SmartModeFanEntry) -> Void

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let line = footnote {
                Text(line)
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.dictusBackground)
                    )
                    .padding(.bottom, 2)
            }

            ForEach(picker.entries.reversed()) { entry in
                if case .pro = entry {
                    proRow
                } else {
                    row(entry)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // The two-finger scrub, VoiceOver's own "go back", closes the picker.
        .accessibilityAction(.escape, onDismiss)
        .accessibilityIdentifier("home.smartModePicker")
    }

    // MARK: - Rows

    /// One mode row, or Normal. See `SmartModeFanView.row` for the shape's reasoning.
    private func row(_ entry: SmartModeFanEntry) -> some View {
        let isEnabled = picker.canChoose(entry)
        let tag = picker.tag(for: entry)
        return Button {
            onChoose(entry)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .font(.system(size: 17, weight: .medium))
                Text(Self.name(of: entry.smartMode))
                    .font(.system(size: 17, weight: tag == .effective ? .semibold : .regular))
                    .lineLimit(1)
                marker(tag)
            }
            // The row in force is the one in the accent, like the fan's highlighted row;
            // the others read as plain glyphs, which is #399's lesson about three blue
            // rows that all looked chosen.
            .foregroundColor(isEnabled ? (tag == .effective ? .dictusAccent : .primary) : .secondary)
            // The content dims, not the capsule: a dimmed capsule lets the dashboard read
            // through it.
            .opacity(isEnabled ? 1 : 0.4)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(rowSurface(isHighlighted: tag == .effective))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .accessibilityLabel(Text(Self.spokenName(of: entry.smartMode)))
        .accessibilityValue(Text(verbatim: tagLabel(tag) ?? ""))
        .accessibilityAddTraits(tag == .effective ? .isSelected : [])
        .accessibilityIdentifier("home.smartModePicker.\(entry.id)")
    }

    /// The Dictus Pro row: the paywall's gradient and a chevron, because it is the one
    /// row that leaves this screen. `SmartModeFanView.proRow`'s shape.
    private var proRow: some View {
        Button {
            onChoose(.pro)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                Text("Dictus Pro")
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.dictusGradientStart, .dictusGradientEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(rowSurface(isHighlighted: false))
            .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .accessibilityIdentifier("home.smartModePicker.pro")
    }

    @ViewBuilder
    private func marker(_ tag: SmartModeFanRowTag?) -> some View {
        switch tag {
        case .effective:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
        case .inactive, .pro:
            if let label = tagLabel(tag) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(Capsule().fill(Color.secondary.opacity(0.18)))
            }
        case nil:
            EmptyView()
        }
    }

    /// The word a tag says, shared by the drawing and VoiceOver. Nil for the check,
    /// which VoiceOver hears as the row's selected trait instead.
    private func tagLabel(_ tag: SmartModeFanRowTag?) -> String? {
        switch tag {
        case .inactive:
            return String(
                localized: "Off",
                comment: "Marker on the Smart Mode fan row the user armed, when that mode will not run and the dictation goes in as Normal."
            )
        case .pro:
            return String(
                localized: "PRO",
                comment: "Tag on a Smart Mode fan row that is behind the Dictus Pro subscription. Identical in French today, and in the catalog so a future locale can change it."
            )
        case .effective, nil:
            return nil
        }
    }

    /// Glass at rest, washed accent on the row in force. `SmartModeFanView.rowSurface`,
    /// on an opaque base: the fan's rows stand on the keyboard, these stand on the dimmed
    /// dashboard, whose cards read through bare glass (simulator capture, 2026-10-24).
    private func rowSurface(isHighlighted: Bool) -> some View {
        Capsule()
            .fill(Color.dictusAccent.opacity(isHighlighted ? 0.25 : 0))
            .dictusGlass(in: Capsule())
            .background(Capsule().fill(Color.dictusBackground))
    }

    // MARK: - Copy

    /// The line above the rows, if any: why modes are greyed, or why Normal is alone.
    private var footnote: String? {
        if let reason = picker.unavailableReason {
            return Self.reasonText(reason)
        }
        if picker.nothingPinned {
            return String(localized: "No modes pinned. The keyboard will offer only Normal.")
        }
        return nil
    }

    /// A mode's short name, the fan's: "→ EN", "List", or "Normal".
    static func name(of mode: SmartMode?) -> String {
        mode?.localizedDisplayName
            ?? String(
                localized: "Normal",
                comment: "The Smart Mode fan row that clears the armed mode and returns to the free polish."
            )
    }

    /// The name VoiceOver reads: the mode list's, where a translation is "Translate → EN"
    /// rather than an arrow and two letters.
    static func spokenName(of mode: SmartMode?) -> String {
        mode.map(SmartModeListView.listName(for:)) ?? name(of: nil)
    }

    /// Why no mode may be armed, in the app's words.
    ///
    /// The keyboard's `localizedReason` is the model and cannot be called from here: it
    /// lives in the other target, whose string catalog is its own. Where the app already
    /// has a sentence for the reason it is reused; the rest are the keyboard's sentences.
    /// `.notSubscribed` never reaches here with a sentence to say — the Dictus Pro row is
    /// the message, and with nothing on sale the picker does not exist.
    static func reasonText(_ reason: SmartModeUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return String(localized: "Turn on Apple Intelligence in iOS Settings to use Smart Modes.")
        case .modelNotReady:
            return String(
                localized: "Apple Intelligence is still downloading. Smart Modes will work once it finishes.",
                comment: "Shown in the Smart Mode fan while the on-device model is downloading."
            )
        case .deviceNotEligible:
            return String(localized: "Smart Modes need Apple Intelligence, which this iPhone does not support. Your choices are saved for a device that does.")
        case .osTooOld:
            return String(
                localized: "Smart Modes need iOS 26 or later.",
                comment: "Shown in the Smart Mode fan when the OS predates Apple Foundation Models."
            )
        case .sdkMissing:
            return String(
                localized: "Smart Modes are not available in this build.",
                comment: "Shown in the Smart Mode fan when the build has no FoundationModels SDK."
            )
        case .engineRefusing:
            return String(
                localized: "Apple Intelligence is busy right now. Smart Modes will come back shortly.",
                comment: "Shown in the Smart Mode fan while the process is rate-limited."
            )
        case .switchedOff:
            return String(localized: "Smart Modes are off. Your modes are kept for when you turn them back on.")
        case .notSubscribed, .other:
            return String(
                localized: "Smart Modes are unavailable right now.",
                comment: "Shown in the Smart Mode fan for an unavailability reason this build does not recognise."
            )
        }
    }
}
