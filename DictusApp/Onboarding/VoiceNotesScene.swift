// DictusApp/Onboarding/VoiceNotesScene.swift
// The voice notes scene: share a voice message to Dictus, insert it from the keyboard (#680).
import SwiftUI
import DictusCore

/// The onboarding step that plays the voice notes scene (#680, mock-up
/// `07a-scene-memos-vocaux`).
struct VoiceNotesScenePage: View {
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void

    /// The layout the keyboard at rest is drawn in: the one the language screen set.
    private let layout = LayoutType.active

    var body: some View {
        OnboardingScenePage(
            title: Text("Your voice notes, transcribed",
                        comment: "Onboarding voice notes scene: title (#680)."),
            line: Text("Share a voice note to Dictus from any app. The text is waiting for you in the keyboard.",
                       comment: "Onboarding voice notes scene: the line under the title (#680)."),
            phoneEnd: .bottom,
            loopSeconds: VoiceNotesSceneScript.loopSeconds,
            stillSeconds: VoiceNotesSceneScript.stillSeconds,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) {
            VoiceNotesPathChips()
        } scene: { time in
            VoiceNotesScene(time: time, layout: layout)
        }
    }
}

// MARK: - Chips

/// "1 Share › 2 Dictus in Favorites › 3 Insert", above the drawn iPhone (mock-up 07a): the
/// everyday path once Dictus is set up. The onboarding's own drawing, not the app's.
private struct VoiceNotesPathChips: View {
    var body: some View {
        // The largest size that fits on one line: the chips are wider in some languages
        // and on narrow iPhones, and a truncated step would say nothing.
        ViewThatFits(in: .horizontal) {
            row(font: .subheadline, spacing: 8)
            row(font: .footnote, spacing: 6)
            row(font: .caption, spacing: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 16)
        // One sentence for VoiceOver; the scene under it is hidden from it.
        .accessibilityElement(children: .combine)
    }

    private func row(font: Font, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            chip(1, Text("Share"))
            chevron
            chip(2, Text("Dictus in Favorites", comment: "Onboarding voice notes scene: second step of the path, Dictus added to the share sheet's favorites so it sits in its row of apps (#680)."))
            chevron
            chip(3, Text("Insert", comment: "Onboarding voice notes scene: third step of the path, inserting the transcript from the keyboard. Same word as the keyboard's button (#680)."))
        }
        .font(font)
        .lineLimit(1)
        .fixedSize()
    }

    private func chip(_ number: Int, _ label: Text) -> some View {
        HStack(spacing: 5) {
            Text(verbatim: "\(number)")
                .fontWeight(.bold)
                .foregroundStyle(Color.dictusAccent)
            label
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.dictusBackground))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Scene

/// The scene: a conversation holding a received voice message, the share sheet and its
/// list of apps, and the Dictus keyboard with its voice note reader
/// (`VoiceNotesSceneScript`).
///
/// WHAT IS REAL AND WHAT IS DRAWN (#649 decision 13): the keyboard's reader repeats
/// `VoiceNoteReaderView` (the keyboard target, which the app cannot import) with its
/// sizes, glass, captions and colours, and the keyboard at rest is the Smart Modes
/// scene's, which repeats the keyboard's own. The conversation, the context menu, the
/// share sheet and its list of apps are iOS's, so they are drawn, in the app's palette
/// like every scene (decision 14).
///
/// Drawn at the keyboard's real size for a 402 pt wide iPhone, then scaled to the card as
/// one picture, like the Smart Modes scene.
struct VoiceNotesScene: View {
    /// Seconds into the loop.
    let time: Double
    /// The layout of the keys at rest.
    let layout: LayoutType

    private typealias Metrics = SmartModesSceneMetrics

    /// The part of the screen the card shows: the keyboard and the last of the
    /// conversation above it, one message tall, as mock-up 07a crops it. Shorter than the
    /// Smart Modes scene's because the card also holds the chips.
    static let screenHeight: CGFloat = 440

    var body: some View {
        let frame = VoiceNotesSceneScript.frame(at: time)
        GeometryReader { geometry in
            screen(frame)
                .frame(width: Metrics.screenWidth, height: Self.screenHeight)
                .scaleEffect(geometry.size.width / Metrics.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Metrics.screenWidth / Self.screenHeight, contentMode: .fit)
    }

    private func screen(_ frame: VoiceNotesSceneScript.Frame) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VoiceNotesConversation(isLifted: frame.contextMenuIsOpen)
                    .frame(maxHeight: .infinity)
                VoiceNotesInputBar(text: frame.fieldHasTranscript ? VoiceNotesSceneText.transcript : nil)
                if let keyboard = frame.keyboard {
                    VoiceNotesKeyboard(state: keyboard, layout: layout)
                        .transition(.move(edge: .bottom))
                } else {
                    // The home indicator's strip under the input bar, with no keyboard up.
                    Color.clear.frame(height: 34)
                }
            }
            .background(VoiceNotesConversation.background)

            if frame.contextMenuIsOpen {
                VoiceNotesContextMenu()
                    .transition(.opacity)
            }

            if frame.sheet != nil {
                // iOS dims what a sheet covers.
                Color.black.opacity(0.25)
                    .transition(.opacity)
            }
            if let sheet = frame.sheet {
                Group {
                    switch sheet {
                    case .share:
                        VoiceNotesShareSheet(dictusIsFavourite: frame.dictusIsFavourite)
                    case .apps(let isEditing):
                        VoiceNotesAppsList(isEditing: isEditing, dictusIsFavourite: frame.dictusIsFavourite)
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .sceneFinger(frame.finger)
        // The keyboard rising and leaving is animated; the reader giving way to the keys
        // is not, as in the keyboard (`VoiceNoteReaderView`: "never animated").
        .animation(.easeOut(duration: 0.3), value: frame.keyboard != nil)
        .animation(.easeOut(duration: 0.3), value: frame.sheet)
        .animation(.easeOut(duration: 0.2), value: frame.contextMenuIsOpen)
        .animation(.easeOut(duration: 0.2), value: frame.fieldHasTranscript)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: frame.dictusIsFavourite)
    }
}

// MARK: - Text

/// The scene's localized content: what the voice note says, and its language.
enum VoiceNotesSceneText {
    /// The transcript the reader shows and *Insert* writes, the one mock-up 07a draws.
    static var transcript: String {
        String(localized: "Site meeting: the window delivery is pushed back to Monday, the plumber comes on Wednesday morning, and the electrician's quote has to be approved before Friday.",
               comment: "Onboarding voice notes scene: the transcript of a shared voice note, shown in the drawn keyboard's reader and inserted in the message field. A natural spoken work message (#680).")
    }

    /// The transcript's language, as the reader's badge shows it (`languageBadge`): the
    /// language the catalog gave the transcript in.
    static var languageBadge: String {
        (Bundle.main.preferredLocalizations.first ?? "en").prefix(2).uppercased()
    }

    /// The voice note's length, in `VoiceNoteKeyboardDelivery.durationLabel`'s format:
    /// 4 min 12 s, as mock-up 07a draws it.
    static let duration = String(format: "%d:%02d", 252 / 60, 252 % 60)
}

// MARK: - Conversation

/// A conversation ending on a received voice message. iOS's own UI, so drawn.
private struct VoiceNotesConversation: View {
    /// Whether the message is lifted out of the conversation by its context menu.
    let isLifted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                // A recorded voice: bars of fixed, uneven heights.
                HStack(spacing: 2) {
                    ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, height in
                        Capsule()
                            .fill(Color.primary.opacity(0.55))
                            .frame(width: 2.5, height: height)
                    }
                }
                Text(verbatim: VoiceNotesSceneText.duration)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().fill(Self.receivedBubble))
            .scaleEffect(isLifted ? 1.04 : 1, anchor: .leading)
            .shadow(color: .black.opacity(isLifted ? 0.15 : 0), radius: 10, y: 4)
            .sceneTapTarget(VoiceNotesSceneScript.Target.voiceMessage)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let bars: [CGFloat] = [8, 14, 20, 12, 18, 24, 16, 10, 20, 26, 14, 18, 12, 22, 16, 10, 14, 8, 18, 12, 6]

    /// The conversation: white on light, black on dark, as Messages is.
    static let background = Color(light: .white, dark: .black)
    /// A received bubble's grey.
    private static let receivedBubble = Color(light: Color(hex: 0xE9E9EB), dark: Color(hex: 0x26262A))
}

/// The input bar: +, the field, which holds the transcript once inserted.
private struct VoiceNotesInputBar: View {
    /// The text in the field, nil for the placeholder.
    let text: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Self.field))
                .overlay(Circle().strokeBorder(Self.fieldBorder, lineWidth: 1))

            HStack(alignment: .bottom) {
                if let text {
                    Text(verbatim: text)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
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
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 38)
            .background(RoundedRectangle(cornerRadius: 19, style: .continuous).fill(Self.field))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).strokeBorder(Self.fieldBorder, lineWidth: 1))
            .sceneTapTarget(VoiceNotesSceneScript.Target.messageField)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private static let field = Color(light: .white, dark: Color(hex: 0x181F2B))
    private static let fieldBorder = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x232B3B))
}

/// The voice message's context menu: *Reply* and *Share*, above the lifted message.
private struct VoiceNotesContextMenu: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // iOS blurs and dims what is behind a context menu; a dim is enough at this size.
            Color.black.opacity(0.12)
            VStack(spacing: 0) {
                row(Text("Reply", comment: "Onboarding voice notes scene: an item of the drawn context menu of a received voice message (#680)."),
                    systemImage: "arrowshape.turn.up.left")
                Divider()
                row(Text("Share"),
                    systemImage: "square.and.arrow.up")
                    .sceneTapTarget(VoiceNotesSceneScript.Target.shareAction)
            }
            .frame(width: 230)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            // Above the message, which sits over the input bar and the home strip.
            .padding(.leading, 14)
            .padding(.bottom, 34 + 60 + 60)
        }
    }

    private func row(_ title: Text, systemImage: String) -> some View {
        HStack {
            title
                .font(.system(size: 17))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}

// MARK: - Share sheet

/// An app in the share sheet: its drawn icon and its name.
private enum ShareApp: CaseIterable, Hashable {
    case messages, mail, dictus, notes, reminders

    var name: Text {
        switch self {
        // Apple's app names, the same in every language the app ships.
        case .messages: return Text(verbatim: "Messages")
        case .mail: return Text(verbatim: "Mail")
        case .dictus: return Text(verbatim: "Dictus")
        case .notes: return Text(verbatim: "Notes")
        case .reminders:
            return Text("Reminders", comment: "Onboarding voice notes scene: Apple's Reminders app in the drawn share sheet. Its name as iOS shows it in each language (#680).")
        }
    }

    /// The icon at `side` points: Dictus's own (`DictusIconTile`), a drawn tile for Apple's.
    @ViewBuilder
    func icon(side: CGFloat) -> some View {
        switch self {
        case .dictus:
            DictusIconTile(logoHeight: side * 42 / 80)
        case .messages:
            tile("message.fill", fill: Color(hex: 0x34C759), side: side)
        case .mail:
            tile("envelope.fill", fill: Color(hex: 0x1E88FF), side: side)
        case .notes:
            tile("note.text", fill: Color(hex: 0xFFC83D), side: side)
        case .reminders:
            tile("checklist", fill: Color(hex: 0xFF9500), side: side)
        }
    }

    private func tile(_ symbol: String, fill: Color, side: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.48, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: side * 0.225, style: .continuous).fill(fill))
    }

    /// The favourites before Dictus is added, and the suggestions after them.
    static func favourites(dictusIsFavourite: Bool) -> [ShareApp] {
        dictusIsFavourite ? [.messages, .mail, .dictus] : [.messages, .mail]
    }

    static func suggestions(dictusIsFavourite: Bool) -> [ShareApp] {
        dictusIsFavourite ? [.notes, .reminders] : [.dictus, .notes, .reminders]
    }
}

/// The share sheet: the shared file, the row of apps (favourites first, then *More*), and
/// two actions. iOS's own UI, so drawn.
private struct VoiceNotesShareSheet: View {
    let dictusIsFavourite: Bool

    var body: some View {
        VStack(spacing: 18) {
            header
            appRow
            VStack(spacing: 0) {
                action(Text("Copy"), systemImage: "doc.on.doc")
                Divider().padding(.leading, 16)
                action(Text("Save to Files", comment: "Onboarding voice notes scene: an action of the drawn share sheet, as iOS words it (#680)."),
                       systemImage: "folder")
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dictusSurface))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .background(VoiceNotesSheetShape().fill(Color.dictusBackground))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.dictusAccent)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.dictusSurface))
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice note")
                    .font(.system(size: 15, weight: .semibold))
                Text(verbatim: "Audio · \(VoiceNotesSceneText.duration)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(0.08)))
        }
    }

    /// Four apps and *More*: what the row shows without scrolling.
    private var appRow: some View {
        let apps = Array((ShareApp.favourites(dictusIsFavourite: dictusIsFavourite)
                          + ShareApp.suggestions(dictusIsFavourite: dictusIsFavourite)).prefix(4))
        return HStack(alignment: .top, spacing: 0) {
            ForEach(apps, id: \.self) { app in
                appCell(icon: app.icon(side: 60), name: app.name)
                    .frame(maxWidth: .infinity)
            }
            appCell(
                icon: Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.primary.opacity(0.08))),
                name: Text("More", comment: "Onboarding voice notes scene: the drawn share sheet's last item, which opens the list of every app. As iOS words it (#680).")
            )
            .sceneTapTarget(VoiceNotesSceneScript.Target.moreApps)
            .frame(maxWidth: .infinity)
        }
    }

    private func appCell(icon: some View, name: Text) -> some View {
        VStack(spacing: 6) {
            icon
            name
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private func action(_ title: Text, systemImage: String) -> some View {
        HStack {
            title.font(.system(size: 17))
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 17))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 46)
    }
}

/// The list behind *More*: favourites, then suggestions; in edit mode, a red − beside each
/// favourite and a green + beside each suggestion. iOS's own UI, so drawn.
private struct VoiceNotesAppsList: View {
    let isEditing: Bool
    let dictusIsFavourite: Bool

    private typealias Target = VoiceNotesSceneScript.Target

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            navigationRow
                .padding(.bottom, 6)
            sectionHeader(Text("Favorites", comment: "Onboarding voice notes scene: header of the drawn list of favorite apps behind the share sheet's More. As iOS words it (#680)."))
            group(ShareApp.favourites(dictusIsFavourite: dictusIsFavourite), areFavourites: true)
            sectionHeader(Text("Suggestions", comment: "Onboarding voice notes scene: header of the drawn list of suggested apps behind the share sheet's More. As iOS words it (#680)."))
                .padding(.top, 8)
            group(ShareApp.suggestions(dictusIsFavourite: dictusIsFavourite), areFavourites: false)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .frame(height: 420)
        .frame(maxWidth: .infinity)
        .background(VoiceNotesSheetShape().fill(Color.dictusBackground))
    }

    private var navigationRow: some View {
        ZStack {
            Text("Apps", comment: "Onboarding voice notes scene: title of the drawn list of apps behind the share sheet's More. As iOS words it (#680).")
                .font(.system(size: 17, weight: .semibold))
            HStack {
                Spacer()
                Group {
                    if isEditing {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold))
                            .sceneTapTarget(Target.doneEditing)
                    } else {
                        Text("Edit")
                            .font(.system(size: 17))
                            .sceneTapTarget(Target.editApps)
                    }
                }
                .foregroundStyle(Self.systemBlue)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Color.dictusSurface))
            }
        }
        .frame(height: 40)
    }

    private func sectionHeader(_ title: Text) -> some View {
        title
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 16)
    }

    private func group(_ apps: [ShareApp], areFavourites: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element) { index, app in
                if index > 0 {
                    Divider().padding(.leading, isEditing ? 98 : 62)
                }
                row(app, isFavourite: areFavourites)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.dictusSurface))
    }

    private func row(_ app: ShareApp, isFavourite: Bool) -> some View {
        HStack(spacing: 12) {
            if isEditing {
                Image(systemName: isFavourite ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, isFavourite ? Color(hex: 0xFF3B30) : Color(hex: 0x34C759))
                    .modifier(AddDictusTarget(isTarget: !isFavourite && app == .dictus))
                    .transition(.scale.combined(with: .opacity))
            }
            app.icon(side: 30)
            app.name
                .font(.system(size: 17))
            Spacer()
            if isEditing && isFavourite {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .modifier(DictusRowTarget(isTarget: !isEditing && app == .dictus))
    }

    /// iOS's tint for its own buttons, which a share sheet keeps whatever the app's accent.
    private static let systemBlue = Color(light: Color(hex: 0x007AFF), dark: Color(hex: 0x0A84FF))
}

/// Marks Dictus's green + as the tap target, and nothing else.
private struct AddDictusTarget: ViewModifier {
    let isTarget: Bool

    func body(content: Content) -> some View {
        if isTarget {
            content.sceneTapTarget(VoiceNotesSceneScript.Target.addDictus)
        } else {
            content
        }
    }
}

/// Marks Dictus's row, outside edit mode, as the tap target that shares to it.
private struct DictusRowTarget: ViewModifier {
    let isTarget: Bool

    func body(content: Content) -> some View {
        if isTarget {
            content.sceneTapTarget(VoiceNotesSceneScript.Target.dictusInList)
        } else {
            content
        }
    }
}

/// A sheet's shape: rounded at the top, as iOS 26 draws it.
private struct VoiceNotesSheetShape: Shape {
    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous).path(in: rect)
    }
}

// MARK: - Keyboard

/// The Dictus keyboard: the voice note reader, or the keys once *Insert* closed it.
private struct VoiceNotesKeyboard: View {
    let state: VoiceNotesSceneScript.Keyboard
    let layout: LayoutType

    private typealias Metrics = SmartModesSceneMetrics

    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .reader:
                VoiceNotesReader()
                    .frame(height: Metrics.toolbarHeight + Metrics.fanAreaHeight)
            case .keys:
                // The note stays in the keyboard after an insert (#640), so the ☰ keeps
                // its ring.
                SceneToolbar(isFanOpen: false, offersUndo: false, armed: nil, ringsMenu: true)
                    .frame(height: Metrics.toolbarHeight)
                SceneKeys(layout: layout)
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
            .fill(SmartModesScene.backdrop)
        )
    }
}

/// `VoiceNoteReaderView` as the keyboard draws it with one note: the header in the
/// toolbar's band (✕, the duration and language, the red Delete), the transcript fading at
/// its edges, then *Open in Dictus* and *Insert*.
private struct VoiceNotesReader: View {
    @Environment(\.colorScheme) private var colorScheme

    /// `RecordingOverlay`'s adaptive foreground, which the reader shares.
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.15)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Text(verbatim: VoiceNotesSceneText.transcript)
                .font(.body)
                .foregroundColor(foregroundColor)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask(edgeFade)
            actionRow
        }
    }

    /// `VoiceNoteReaderView.header`: 52 pt, 12 pt sides, 4 pt top.
    private var header: some View {
        HStack(spacing: 0) {
            barButton("xmark", tint: .dictusPillIconSecondary)
            Spacer(minLength: 0)
            barButton("trash", tint: .red)
        }
        .overlay {
            HStack(spacing: 6) {
                Text(verbatim: VoiceNotesSceneText.duration)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(verbatim: VoiceNotesSceneText.languageBadge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(foregroundColor.opacity(0.1)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(height: 52)
    }

    /// `VoiceNoteReaderView.barButton`'s look: a 56 × 36 glass capsule.
    private func barButton(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(tint)
            .frame(width: 56, height: 36)
            .dictusGlass(in: Capsule())
            .frame(width: 56, height: 44)
    }

    /// `VoiceNoteReaderView.edgeFade`.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
                .init(color: .black, location: 0.9),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// `VoiceNoteReaderView.actionRow`: the round *Open in Dictus*, then *Insert*.
    private var actionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.dictusPillIconSecondary)
                .frame(width: 44, height: 44)
                .dictusGlass(in: Circle())

            Text(verbatim: KeyboardStrings.text("Insert"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Capsule().fill(Color.dictusAccent))
                .sceneTapTarget(VoiceNotesSceneScript.Target.insert)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
