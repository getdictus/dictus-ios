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

    var body: some View {
        OnboardingScenePage(
            title: SmartModesSceneCard.title,
            line: SmartModesSceneCard.line,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) {
            SmartModesSceneCard()
        }
    }
}

/// The Smart Modes scene in its drawn iPhone: the onboarding page's card and the
/// Smart Modes screen's "See how it works" sheet (#686).
struct SmartModesSceneCard: View {
    /// The title of the onboarding step, also the title of the feature screen's "See how
    /// it works" sheet (#686): one string for both.
    static var title: Text {
        Text("One long press, one Smart Mode",
             comment: "Onboarding Smart Modes scene: title (#679).")
    }

    /// The line under the title, shared the same way.
    static var line: Text {
        Text("Hold the mic, slide to a mode, let go. Dictus writes in that mode.",
             comment: "Onboarding Smart Modes scene: the line under the title, describing the long-press gesture on the keyboard's mic (#679).")
    }

    /// The fan the scene draws, its translation row picked for the language the user said
    /// they speak (`SmartModesSceneScript.entries`). Read once: it was written on the
    /// language screen and does not change while the card is on screen.
    private let entries = SmartModesSceneScript.entries(
        spokenLanguage: AppGroup.defaults.string(forKey: SharedKeys.spokenLanguage)
    )

    /// The layout the keyboard at rest is drawn in: the one the language screen set.
    private let layout = LayoutType.active

    /// The dictated sentence and its translation (`SmartModesSceneSentence`).
    private let sentences = SmartModesSceneSentence.pair(
        spokenLanguage: AppGroup.defaults.string(forKey: SharedKeys.spokenLanguage)
    )

    var body: some View {
        FeatureSceneCard(
            loopSeconds: SmartModesSceneScript.loopSeconds,
            startSeconds: SmartModesSceneScript.openingSeconds,
            stillSeconds: SmartModesSceneScript.stillSeconds
        ) { time in
            SmartModesScene(time: time, entries: entries, layout: layout, sentences: sentences)
        }
    }
}

// MARK: - Sentence

/// The sentence the scene dictates, and the same sentence translated (#679).
///
/// WHY LOOKED UP PER LANGUAGE: the two sentences are in two different languages on the
/// same screen, whatever the interface language. Each is read from that language's own
/// table of the app's catalog; `SmartModesSceneScript.sentenceLanguages` decides which.
enum SmartModesSceneSentence {
    struct Pair: Equatable {
        let original: String
        let translated: String
    }

    static func pair(spokenLanguage: String?) -> Pair {
        let languages = SmartModesSceneScript.sentenceLanguages(
            spokenLanguage: spokenLanguage,
            interfaceLanguage: Bundle.main.preferredLocalizations.first
        )
        return Pair(original: sentence(in: languages.original), translated: sentence(in: languages.translated))
    }

    /// The sentence in `language`, from that language's table.
    private static func sentence(in language: String) -> String {
        let bundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        return String(
            localized: "I'll be there in ten minutes.",
            bundle: bundle,
            comment: "Onboarding Smart Modes scene: the short sentence dictated in the drawn keyboard, shown as dictated, then translated by the → EN or → FR Smart Mode. Natural spoken message (#679)."
        )
    }
}

// MARK: - Keyboard strings

/// Strings the scene shows exactly as the keyboard does, read from the keyboard
/// extension's own catalog: the app's catalog words some of them differently for its own
/// recording screen ("Écoute en cours..." against the keyboard's "En écoute...").
///
/// WHY `localizedString(forKey:)` AND NOT `String(localized:)`: the latter would be
/// extracted into the app's catalog as new or changed keys; these belong to the keyboard.
enum KeyboardStrings {
    private static let bundle: Bundle = Bundle.main.builtInPlugInsURL
        .map { $0.appendingPathComponent("DictusKeyboard.appex") }
        .flatMap(Bundle.init(url:)) ?? .main

    static func text(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

/// The scene: a Messages-like host above the Dictus keyboard, and a finger performing the
/// long-press fan and the dictation it starts (`SmartModesSceneScript`): recording,
/// transcription, a Smart Mode's processing, and the sentence landing in the field.
///
/// WHY DRAWN AT THE KEYBOARD'S REAL SIZE, THEN SCALED: the fan has to read as the real one
/// (#649 decision 13: the app's own screens are shown as they are today). Its proportions
/// are the keyboard's own numbers, written in points for a 402 pt wide iPhone, and the
/// whole screen is scaled down to the card as one picture. Nothing is resized piecemeal,
/// so the rows, the pill and the text keep the keyboard's ratios exactly.
///
/// WHAT IS REAL AND WHAT IS DRAWN: the mic pill and its badge are the keyboard's own
/// `AnimatedMicButton`; the rows, the toolbar, the keys and the recording screen repeat
/// `SmartModeFanView`, `ToolbarView` and `RecordingOverlay` / `KeyboardWaveformView`,
/// which live in the keyboard target the app cannot import, with the same fonts, paddings
/// and glass, and the keyboard's own captions (`KeyboardStrings`); which row is lit and what the toolbar's centre shows come
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
    /// The sentence as dictated and translated.
    let sentences: SmartModesSceneSentence.Pair

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
            SceneMessagesHost(text: fieldText(frame.fieldText))
                .frame(height: Metrics.hostHeight)

            VStack(spacing: 0) {
                if frame.keyboard.isOverlay {
                    // `RecordingOverlay` fills the toolbar and the keys together, as in
                    // the keyboard (`KeyboardRootView`, `.recording`).
                    SceneRecordingOverlay(phase: frame.keyboard, armed: armed)
                        .frame(height: Metrics.toolbarHeight + Metrics.fanAreaHeight)
                        .transition(.opacity)
                } else {
                    SceneToolbar(isFanOpen: frame.isFanOpen, offersUndo: frame.offersUndo, armed: armed)
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
                }

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
        .animation(.easeOut(duration: 0.18), value: frame.keyboard.isOverlay)
        .animation(.easeOut(duration: 0.2), value: frame.fieldText)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: frame.armedIndex)
    }

    private func fieldText(_ text: SmartModesSceneScript.FieldText?) -> String? {
        switch text {
        case .original: return sentences.original
        case .translated: return sentences.translated
        case nil: return nil
        }
    }

    /// The finger's centre on the screen: along the toolbar from the mic to the rows'
    /// column, then straight down it (`SmartModesSceneScript.Finger.columnTravel`).
    private func fingerPoint(_ finger: SmartModesSceneScript.Finger) -> CGPoint {
        if finger.place == .undoButton {
            return Metrics.undoCentre
        }
        let startX = Metrics.micCentre.x
        let endX = Metrics.screenWidth * 0.62
        return CGPoint(
            x: startX + (endX - startX) * CGFloat(finger.columnTravel),
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

    /// The centre of the toolbar's Undo capsule, at its leading end. Its width follows its
    /// label; this is the middle of the French and English ones.
    static var undoCentre: CGPoint {
        CGPoint(x: toolbarSidePadding + 48, y: micCentre.y)
    }

    /// The mic pill's centre, which is also the centre of `RecordingOverlay`'s ✓ (trailing
    /// padding 17 plus half of 56, against 12 plus half of the 66 pt halo; top padding 10
    /// plus half of 36, against 4 plus half of 48): the `AnimatedMicButton` halo (`DictusHalo.size`, 66 pt wide)
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
    /// The text in the field, nil for the placeholder.
    let text: String?

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
                    if let text {
                        Text(verbatim: text)
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .transition(.opacity)
                    } else {
                        // The host's own placeholder, the same word in every language iOS
                        // ships, so not localized.
                        Text(verbatim: "iMessage")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                            .transition(.opacity)
                    }
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
    /// Whether the keyboard offers to undo the dictation it just inserted.
    let offersUndo: Bool
    /// The armed mode, nil for none.
    let armed: SmartMode?

    private typealias Metrics = SmartModesSceneMetrics

    var body: some View {
        // What the centre shows is the keyboard's own decision, made in DictusCore. A new
        // user's keyboard has no message and no suggestions; it offers Undo after a
        // dictation, as the real one does for 8 s.
        let slot = ToolbarCentreSlot.resolve(
            isChoosingMode: isFanOpen,
            errorMessage: nil,
            offersDictationUndo: offersUndo,
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
        case .dictationUndo:
            undo
            Spacer()
        default:
            Spacer()
        }
    }

    /// `ToolbarView.dictationUndoButton`'s look.
    private var undo: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 13, weight: .semibold))
            Text(verbatim: KeyboardStrings.text("Undo"))
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.dictusAccent)
        .padding(.horizontal, 14)
        .frame(height: Metrics.pillHeight)
        .background(Capsule().fill(Color.dictusAccent.opacity(0.12)))
        .frame(height: 44)
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

// MARK: - Recording

/// `RecordingOverlay` as the keyboard draws it: the top bar (✕ and ✓ while recording, an
/// empty bar of the same height after), the armed mode's capsule over it, the waveform,
/// and the timer or the stage's caption.
private struct SceneRecordingOverlay: View {
    let phase: SmartModesSceneScript.KeyboardPhase
    let armed: SmartMode?

    @Environment(\.colorScheme) private var colorScheme

    /// `RecordingOverlay.timerFontSize`'s base size.
    private let timerFontSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                topBar
                if let armed {
                    // `RecordingOverlay.armedModeBadge`.
                    HStack(spacing: 5) {
                        Image(systemName: armed.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(verbatim: armed.localizedDisplayName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.dictusAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Color.dictusAccent.opacity(0.14)))
                    .offset(y: 2)
                }
            }

            VStack(spacing: 8) {
                Spacer(minLength: 0)
                SceneWaveform(phase: phase, maxHeight: 120)
                    .padding(.horizontal, 2)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    @ViewBuilder
    private var topBar: some View {
        if case .recording = phase {
            HStack {
                pill("xmark", color: .dictusPillIconSecondary)
                Spacer()
                pill("checkmark", color: .dictusSuccess)
            }
            .padding(.leading, 12)
            .padding(.trailing, 17)
            .padding(.top, 10)
            .padding(.bottom, 6)
        } else {
            Color.clear
                .frame(height: 36)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .recording(let elapsed):
            Text(verbatim: String(format: "%02d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                .font(.system(size: timerFontSize, weight: .medium, design: .monospaced))
                .foregroundColor(colorScheme == .dark ? .white : Color(white: 0.15))
                .padding(.bottom, 4)
            caption("Listening...")
        case .transcribing:
            Color.clear.frame(height: timerFontSize).padding(.bottom, 4)
            caption("Transcribing...")
        case .processing:
            Color.clear.frame(height: timerFontSize).padding(.bottom, 4)
            caption("Processing...")
        case .keys, .fan:
            EmptyView()
        }
    }

    /// `.dictusCaption` in `dictusPillIconSecondary`, in the keyboard's own words.
    private func caption(_ key: String) -> some View {
        Text(verbatim: KeyboardStrings.text(key))
            .font(.system(.caption))
            .foregroundColor(.dictusPillIconSecondary)
            .padding(.bottom, 8)
    }

    /// `RecordingOverlay.PillButton`'s look.
    private func pill(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 56, height: 36)
            .dictusGlass(in: Capsule())
    }
}

/// `KeyboardWaveformView`: 30 capsules, 2 pt apart, the middle ones in the brand blue.
/// The levels are the scene's (`SmartModesSceneScript.recordingLevels`) while recording,
/// and the keyboard's own motion after: `KeyboardWaveformDriver.processingEnergy`'s sweep
/// for the transcription, `ProcessingWaveform`'s travelling peak for a Smart Mode.
private struct SceneWaveform: View {
    let phase: SmartModesSceneScript.KeyboardPhase
    let maxHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private let barCount = ProcessingWaveform.barCount

    var body: some View {
        let levels = recordingLevels
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(color(at: index))
                    .frame(height: height(at: index, recording: levels))
            }
        }
        .frame(height: maxHeight)
    }

    private var recordingLevels: [Float] {
        if case .recording(let elapsed) = phase {
            return SmartModesSceneScript.recordingLevels(elapsed: elapsed)
        }
        return []
    }

    /// `KeyboardWaveformView.barHeight`.
    private func height(at index: Int, recording: [Float]) -> CGFloat {
        let energy: Float
        let minHeight: CGFloat
        switch phase {
        case .transcribing(let elapsed):
            // The phase starts centred and advances at the driver's rate.
            let phase = ProcessingWaveform.centredPhase + elapsed * ProcessingWaveform.sweepPhaseRate
            let normalized = Double(index) / Double(max(barCount - 1, 1))
            energy = Float(0.2 + 0.25 * (sin(2 * .pi * (normalized + phase)) + 1))
            minHeight = 4
        case .processing(let elapsed):
            let phase = ProcessingWaveform.centredPhase + elapsed * ProcessingWaveform.phaseRate
            energy = ProcessingWaveform.level(at: index, peakPosition: ProcessingWaveform.peakPosition(phase: phase))
            minHeight = 4
        case .recording, .keys, .fan:
            energy = index < recording.count ? recording[index] : 0
            minHeight = 2
        }
        return max(minHeight + CGFloat(energy) * (maxHeight - minHeight), minHeight)
    }

    /// `KeyboardWaveformView.resolvedBarColor`.
    private func color(at index: Int) -> Color {
        let center = Float(barCount - 1) / 2
        let distance = abs(Float(index) - center) / center
        if distance < 0.4 {
            return .dictusGradientStart
        }
        let opacity = Double(1 - distance) * 0.9 + 0.15
        return (colorScheme == .dark ? Color.white : Color.gray).opacity(opacity)
    }
}

// MARK: - System bar

/// iOS's bar under a third-party keyboard: the globe on the left, the system dictation mic
/// on the right. iOS's own UI, so drawn.
struct SceneSystemBar: View {
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
/// darker while pressed. Shared by every drawn scene (#679, #680, #681).
struct SceneFinger: View {
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
