// DictusApp/Onboarding/SmartModesScene.swift
// The Smart Modes scene: the keyboard's long-press fan, drawn and looping (#679).
import SwiftUI
import DictusCore

/// The onboarding step that plays the Smart Modes scene (#679, mock-up
/// `05-scene-smart-modes`). The pick of three modes comes right after it.
struct SmartModesScenePage: View {
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void

    /// The fan the scene draws, its translation row picked for the language the user said
    /// they speak (`SmartModesSceneScript.entries`). Read once: it was written on the
    /// language screen and does not change while this page is on screen.
    private let entries = SmartModesSceneScript.entries(
        spokenLanguage: AppGroup.defaults.string(forKey: SharedKeys.spokenLanguage)
    )

    /// The layout the keyboard at rest is drawn in: the one the language screen set.
    private let layout = LayoutType.active

    var body: some View {
        OnboardingScenePage(
            title: Text("One long press, one Smart Mode",
                        comment: "Onboarding Smart Modes scene: title (#679)."),
            line: Text("Hold the mic, slide to a mode, let go. Dictus writes in that mode.",
                       comment: "Onboarding Smart Modes scene: the line under the title, describing the long-press gesture on the keyboard's mic (#679)."),
            loopSeconds: SmartModesSceneScript.loopSeconds,
            stillSeconds: SmartModesSceneScript.stillSeconds,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) { time in
            SmartModesScene(time: time, entries: entries, layout: layout)
        }
    }
}

/// The scene: a Messages-like host above the Dictus keyboard, and a finger performing the
/// long-press fan (`SmartModesSceneScript`).
///
/// WHY DRAWN AT THE KEYBOARD'S REAL SIZE, THEN SCALED: the fan has to read as the real one
/// (#649 decision 13: the app's own screens are shown as they are today). Its proportions
/// are the keyboard's own numbers, written in points for a 402 pt wide iPhone, and the
/// whole screen is scaled down to the card as one picture. Nothing is resized piecemeal,
/// so the rows, the pill and the text keep the keyboard's ratios exactly.
///
/// WHAT IS REAL AND WHAT IS DRAWN: the mic pill and its badge are the keyboard's own
/// `AnimatedMicButton`; the rows, the toolbar and the keys repeat `SmartModeFanView` and
/// `ToolbarView`, which live in the keyboard target the app cannot import, with the same
/// fonts, paddings and glass; which row is lit and what the toolbar's centre shows come
/// from DictusCore (`SmartModeFanLayout`, `ToolbarCentreSlot`), exactly as the keyboard
/// decides them. Only iOS's own parts are invented: the host app and the bar under the
/// keyboard with the globe.
struct SmartModesScene: View {
    /// Seconds into the loop.
    let time: Double
    /// The fan's rows (`SmartModesSceneScript.entries`).
    let entries: [SmartModeFanEntry]
    /// The layout of the keys at rest.
    let layout: LayoutType

    private typealias Metrics = SmartModesSceneMetrics

    var body: some View {
        let frame = SmartModesSceneScript.frame(
            at: time,
            entryCount: entries.count,
            fanAreaHeight: Metrics.fanAreaHeight,
            micY: Metrics.micCentre.y - Metrics.keyboardTop - Metrics.toolbarHeight
        )
        GeometryReader { geometry in
            screen(frame)
                .frame(width: Metrics.screenWidth, height: Metrics.screenHeight)
                .scaleEffect(geometry.size.width / Metrics.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Metrics.screenWidth / Metrics.screenHeight, contentMode: .fit)
    }

    // MARK: - Screen

    private func screen(_ frame: SmartModesSceneScript.Frame) -> some View {
        let armed = frame.armedIndex.flatMap { entries.indices.contains($0) ? entries[$0].smartMode : nil }
        return VStack(spacing: 0) {
            SceneMessagesHost()
                .frame(height: Metrics.hostHeight)

            VStack(spacing: 0) {
                SceneToolbar(isFanOpen: frame.isFanOpen, armed: armed)
                    .frame(height: Metrics.toolbarHeight)

                ZStack {
                    if frame.isFanOpen {
                        SceneFan(
                            entries: entries,
                            highlightedIndex: frame.highlightedIndex,
                            armedIdentifier: armed?.id
                        )
                        .transition(.opacity)
                    } else {
                        SceneKeys(layout: layout)
                            .transition(.opacity)
                    }
                }
                .frame(height: Metrics.fanAreaHeight)

                SceneSystemBar()
                    .frame(height: Metrics.systemBarHeight)
            }
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: Metrics.keyboardCornerRadius,
                    topTrailingRadius: Metrics.keyboardCornerRadius,
                    style: .continuous
                )
                .fill(Self.backdrop)
            )
        }
        .background(SceneMessagesHost.background)
        .overlay(alignment: .topLeading) {
            if let finger = frame.finger {
                SceneFinger(isPressed: finger.isPressed)
                    .opacity(finger.opacity)
                    .position(fingerPoint(finger))
            }
        }
        .animation(.easeOut(duration: 0.18), value: frame.isFanOpen)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: frame.armedIndex)
    }

    /// The finger's centre on the screen: from the mic to the middle of the rows' width,
    /// moving down and a little left as a thumb does.
    private func fingerPoint(_ finger: SmartModesSceneScript.Finger) -> CGPoint {
        let startX = Metrics.micCentre.x
        let endX = Metrics.screenWidth * 0.62
        return CGPoint(
            x: startX + (endX - startX) * CGFloat(finger.travel),
            y: Metrics.keyboardTop + Metrics.toolbarHeight + finger.y
        )
    }

    /// iOS's keyboard backdrop behind the Dictus keyboard, as mock-up 05 draws it: the
    /// system's light grey, the app's dark navy.
    static let backdrop = Color(light: Color(hex: 0xD2D5DB), dark: Color(hex: 0x1B1F2A))
}

// MARK: - Metrics

/// The keyboard's real numbers, in points, for the standard iPhone class.
///
/// WHY COPIED: they live in the keyboard target (`ToolbarView`, `KeyMetrics`), which the
/// app cannot import. Each one names its source, so a change there is a search away.
enum SmartModesSceneMetrics {
    /// The width the mock-ups are drawn at (iPhone 16 Pro / 17, 402 × 874 pt).
    static let screenWidth: CGFloat = 402

    /// The host app above the keyboard: an empty conversation, then its input bar.
    static let conversationHeight: CGFloat = 92
    static let inputBarHeight: CGFloat = 60
    static var hostHeight: CGFloat { conversationHeight + inputBarHeight }

    /// `ToolbarView.toolbarHeight`, its top padding and its side padding.
    static let toolbarHeight: CGFloat = 52
    static let toolbarTopPadding: CGFloat = 4
    static let toolbarSidePadding: CGFloat = 12
    /// `ToolbarView.micPillWidth` and `iconDiameter`: the ☰ capsule's size.
    static let pillWidth: CGFloat = 56
    static let pillHeight: CGFloat = 36

    /// `KeyMetrics`, standard class.
    static let keyHeight: CGFloat = 43
    static let rowSpacing: CGFloat = 11
    static let keySpacing: CGFloat = 6
    static let rowSidePadding: CGFloat = 4
    static let keyCornerRadius: CGFloat = 8

    /// The height the fan's rows divide: the four key rows they replace. 205 pt, the
    /// standard iPhone figure `SmartModeFanLayout.rowHeight` is measured against.
    static var fanAreaHeight: CGFloat { keyHeight * 4 + rowSpacing * 3 }

    /// iOS's bar under a third-party keyboard on a Face ID iPhone: the globe and the
    /// dictation mic, then the home indicator.
    static let systemBarHeight: CGFloat = 64
    /// The keyboard's top corners on iOS 26.
    static let keyboardCornerRadius: CGFloat = 18

    static var keyboardTop: CGFloat { hostHeight }
    static var screenHeight: CGFloat { hostHeight + toolbarHeight + fanAreaHeight + systemBarHeight }

    /// The mic pill's centre: the `AnimatedMicButton` halo (`DictusHalo.size`, 66 pt wide)
    /// sits against the toolbar's trailing padding, centred in the bar below its top
    /// padding.
    static var micCentre: CGPoint {
        let halo = DictusHalo.size(isPill: true)
        return CGPoint(
            x: screenWidth - toolbarSidePadding - halo.width / 2,
            y: keyboardTop + toolbarTopPadding + (toolbarHeight - toolbarTopPadding) / 2
        )
    }
}

// MARK: - Host

/// A Messages-like host: an empty conversation and the input bar. iOS's own UI, so drawn
/// (#649 decision 13), in the mock-up's colours.
private struct SceneMessagesHost: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Self.field))
                    .overlay(Circle().strokeBorder(Self.fieldBorder, lineWidth: 1))

                HStack {
                    // The host's own placeholder, the same word in every language iOS
                    // ships, so not localized.
                    Text(verbatim: "iMessage")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                    Image(systemName: "mic")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Capsule().fill(Self.field))
                .overlay(Capsule().strokeBorder(Self.fieldBorder, lineWidth: 1))
            }
            .padding(.horizontal, 12)
            .frame(height: SmartModesSceneMetrics.inputBarHeight)
        }
    }

    /// The conversation: white on light, black on dark, as Messages is.
    static let background = Color(light: .white, dark: .black)
    private static let field = Color(light: .white, dark: Color(hex: 0x181F2B))
    private static let fieldBorder = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x232B3B))
}

// MARK: - Toolbar

/// `ToolbarView.dictationBar`: ☰, the centre slot, the mic pill.
private struct SceneToolbar: View {
    let isFanOpen: Bool
    /// The armed mode, nil for none.
    let armed: SmartMode?

    private typealias Metrics = SmartModesSceneMetrics

    var body: some View {
        // What the centre shows is the keyboard's own decision, made in DictusCore. A new
        // user's keyboard has no message, no undo and no suggestions in an empty field.
        let slot = ToolbarCentreSlot.resolve(
            isChoosingMode: isFanOpen,
            errorMessage: nil,
            offersDictationUndo: false,
            hasSuggestions: false,
            dictationUnavailable: false,
            polishUnavailable: false,
            armedModeName: armed?.localizedDisplayName,
            armedModeIsEffective: true,
            offersPanelHint: false,
            offersDiscoveryHint: false
        )
        HStack {
            if !slot.evictsHamburger {
                hamburger
            }
            centre(slot)
            // The keyboard's own mic pill, badge included.
            AnimatedMicButton(
                status: .idle,
                isPill: true,
                badge: armed?.badge,
                animatesIdleGlow: false,
                onTap: {}
            )
        }
        .padding(.horizontal, Metrics.toolbarSidePadding)
        .padding(.top, Metrics.toolbarTopPadding)
    }

    /// `ToolbarView.hamburgerButton`'s look.
    private var hamburger: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(.dictusPillIconSecondary)
            .frame(width: Metrics.pillWidth, height: Metrics.pillHeight)
            .dictusGlass(in: Capsule())
            .frame(width: max(Metrics.pillWidth, 44), height: 44)
    }

    @ViewBuilder
    private func centre(_ slot: ToolbarCentreSlot) -> some View {
        switch slot {
        case .choosingMode:
            // `ToolbarView.fanTitle`. Same key and same French as the keyboard's catalog.
            label(icon: "sparkles", Text("Choose a Smart Mode",
                                         comment: "Toolbar title shown while the long-press Smart Mode fan is open. Same text as the keyboard's (#679)."))
        case .armedMode(let name):
            // `ToolbarView.armedModeLabel`.
            label(icon: armed?.icon ?? "sparkles", Text(verbatim: name))
        default:
            Spacer()
        }
    }

    private func label(icon: String, _ text: Text) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            text
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.dictusAccent)
        .padding(.leading, 6)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fan

/// `SmartModeFanView`'s rows: a glass capsule per row, the lit one washed in the accent,
/// the check on the row that will run.
private struct SceneFan: View {
    let entries: [SmartModeFanEntry]
    let highlightedIndex: Int?
    /// The armed mode's identifier, nil for none (Normal runs).
    let armedIdentifier: String?

    private var rowHeight: CGFloat {
        SmartModeFanLayout.rowHeight(
            availableHeight: SmartModesSceneMetrics.fanAreaHeight,
            entryCount: entries.count,
            showsReason: false
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                row(entry, isHighlighted: index == highlightedIndex)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func row(_ entry: SmartModeFanEntry, isHighlighted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.icon)
                .font(.system(size: 17, weight: .medium))
            Text(name(entry))
                .font(.system(size: 17, weight: isHighlighted ? .semibold : .regular))
                .lineLimit(1)
            // The tag rule is the keyboard's: a subscriber's fan (the trial lends the
            // modes) marks only the row that will run.
            if SmartModeFanLayout.tag(
                for: entry,
                armedIdentifier: armedIdentifier,
                effectiveIdentifier: armedIdentifier ?? SmartModeFanEntry.normal.id,
                modesRequirePro: false,
                marksTrialPro: false
            ) == .effective {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
            }
        }
        .foregroundColor(isHighlighted ? .dictusAccent : .primary)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight)
        .background(
            Capsule()
                .fill(Color.dictusAccent.opacity(isHighlighted ? 0.25 : 0))
                .dictusGlass(in: Capsule())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
        )
    }

    private func name(_ entry: SmartModeFanEntry) -> String {
        entry.smartMode?.localizedDisplayName
            ?? String(localized: "Normal",
                      comment: "The Smart Mode fan row that clears the armed mode and returns to the free polish. Same text as the keyboard's (#679).")
    }
}

// MARK: - Keys

/// The keyboard at rest: three letter rows and the bottom row, at `KeyMetrics`' sizes,
/// in the vendored theme's key colours.
private struct SceneKeys: View {
    let layout: LayoutType

    private typealias Metrics = SmartModesSceneMetrics

    var body: some View {
        let rows = KeyboardLetterRows.rows(for: layout)
        let width = Metrics.screenWidth - Metrics.rowSidePadding * 2
        // Every key as wide as one key of a ten-key row; shorter rows are centred.
        let keyWidth = (width - Metrics.keySpacing * 9) / 10
        VStack(spacing: Metrics.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: Metrics.keySpacing) {
                    if index == 2 {
                        key(Image(systemName: "shift"), width: keyWidth * 1.4)
                        Spacer(minLength: 0)
                    }
                    ForEach(Array(row.enumerated()), id: \.offset) { _, letter in
                        key(Text(verbatim: letter).font(.system(size: 23)), width: keyWidth)
                    }
                    if index == 2 {
                        Spacer(minLength: 0)
                        key(Image(systemName: "delete.left"), width: keyWidth * 1.4)
                    }
                }
                .frame(width: width)
            }
            bottomRow(width: width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `KeyboardLayouts.bottomRow` on a Face ID iPhone: 123 (1.5), emoji (1.5), space (5),
    /// return (2), ten units.
    private func bottomRow(width: CGFloat) -> some View {
        let unit = (width - Metrics.keySpacing * 3) / 10
        let language = SupportedLanguage.active
        return HStack(spacing: Metrics.keySpacing) {
            key(Text(verbatim: "123").font(.system(size: 16)), width: unit * 1.5)
            key(Image(systemName: "face.smiling"), width: unit * 1.5)
            key(Text(verbatim: language.spaceName).font(.system(size: 16)), width: unit * 5)
            key(Text(verbatim: language.returnName).font(.system(size: 16)), width: unit * 2)
        }
    }

    private func key(_ label: some View, width: CGFloat) -> some View {
        label
            .font(.system(size: 18))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, height: Metrics.keyHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.keyCornerRadius, style: .continuous)
                    .fill(Self.keyFill)
            )
    }

    /// The vendored theme's keys on iOS 26: white on light, rgb(61, 61, 61) on dark
    /// (`Theme.makeColors`).
    private static let keyFill = Color(light: .white, dark: Color(red: 61 / 255, green: 61 / 255, blue: 61 / 255))
}

// MARK: - System bar

/// iOS's bar under a third-party keyboard: the globe on the left, the system dictation mic
/// on the right. iOS's own UI, so drawn.
private struct SceneSystemBar: View {
    var body: some View {
        HStack {
            Image(systemName: "globe")
            Spacer()
            Image(systemName: "mic")
        }
        .font(.system(size: 24, weight: .regular))
        .foregroundStyle(.primary)
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Finger

/// The drawn finger: a soft grey disc, as screen recordings show touches. Smaller and
/// darker while pressed.
private struct SceneFinger: View {
    let isPressed: Bool

    var body: some View {
        Circle()
            .fill(Color(white: 0.45).opacity(0.45))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            .frame(width: 46, height: 46)
            .scaleEffect(isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
    }
}
