// DictusKeyboard/Views/VoiceNoteReaderView.swift
// The full-surface reader for shared voice note transcripts (issues #637, #639).
import SwiftUI
import DictusCore

/// The waiting transcripts, one page each, taking over the whole keyboard surface the
/// way `RecordingOverlay` does: header in the toolbar's 52 pt band, the transcript,
/// and one action row.
///
/// ```
/// [ ✕ ]            1:42  FR             [ 🗑 ]
///                   ● ○ ○
///   Salut, je voulais te dire que pour samedi
///   c'est bon de mon côté…              ← swipe
///
///   (↗)  [=============  Insert  =============]
/// ```
///
/// ### The header is the toolbar it replaces (#639, after the device test)
///
/// Three slots, the bar's own: the `✕` in the ☰'s place — the reader opens from a
/// tap on ☰, and the control under the thumb becomes its own way back — `Delete` in
/// the mic pill's place, at the same capsule size, and the facts in the centre
/// slot, in the centre slot's quiet register. No title and no logo: the surface
/// says what it is. What is left is what helps choose: how long the message was,
/// what language it was read in, and, with several notes, where you are among them.
///
/// The two header controls both *leave* something — the reader, or the note — and
/// the bottom row holds the two that *use* the note: `Open in Dictus` as a round
/// button, and `Insert` taking the rest of the width (second device test of #641).
///
/// With no page — a tap on ☰ when nothing is waiting — it shows an empty state
/// instead, the one place the keyboard teaches the feature (#639).
///
/// ### No card, no panel
///
/// No background fill (`Color.clear`, like `RecordingOverlay`) and no frame around the
/// text: the keyboard *becomes* the transcript for a moment rather than hosting
/// something. The top and bottom lines fade out through a gradient mask instead of
/// meeting a border, which is also what says "this scrolls".
///
/// ### Two scroll axes, one owner each
///
/// Pages move horizontally, the text of one page scrolls vertically. Both are
/// `ScrollView`s, which UIKit resolves by direction lock at the start of a pan: a
/// mostly vertical drag on a long page scrolls it and never turns the page. That is
/// the property #637 asks to be checked on a device with a long transcript on page 2.
///
/// ### Motion
///
/// The mode switch that brings this on screen is not animated — the stacked-branch
/// artefact `KeyboardRootView.togglePanel()` documents applies here too. The short
/// fade and rise live inside this body, where they stack nothing.
struct VoiceNoteReaderView: View {
    let pages: [VoiceNoteKeyboardDelivery]
    let onClose: () -> Void
    let onInsert: (UUID) -> Void
    let onOpenInDictus: (UUID) -> Void
    /// Delete: takes the note out of the keyboard only (#639).
    let onDelete: (UUID) -> Void
    /// A page came on screen: a use, which restarts the note's 15 minutes (#639).
    let onPageShown: (UUID) -> Void

    /// The page on screen. Nil until the first layout pass, which reads as page 0.
    @State private var visibleID: UUID?
    @State private var appeared = false

    @Environment(\.colorScheme) private var colorScheme

    /// The opacity of the reader's invisible fill: the least that still makes every
    /// pixel of the surface take a touch in the keyboard extension. See `body`.
    private static let touchableClear: Double = 0.001

    /// `RecordingOverlay`'s adaptive foreground, so the two full-surface modes read as
    /// one system.
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : Color(white: 0.15)
    }

    /// The page the header and the action row describe.
    private var visiblePage: VoiceNoteKeyboardDelivery? {
        pages.first { $0.id == visibleID } ?? pages.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Never animated (seventh round of #641): the `✕` takes the ☰'s place the
            // way the panel's does — the bar swaps in place, in one frame, at the same
            // 56 × 36 frame (`togglePanel()` in `KeyboardRootView` explains why the
            // swap itself is not a transition). The first version faded and lifted the
            // whole reader, header included, so the ☰ seemed to vanish and a `✕` to
            // rise from below. Closing is the same swap back: the toolbar branch
            // returns with the ☰ where the `✕` was.
            header
            // Only what is below the bar comes in: the short fade and rise live here,
            // like the panel's content.
            Group {
                if pages.isEmpty {
                    emptyState
                } else {
                    pager
                    actionRow
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
        }
        // Not `Color.clear`: in a keyboard extension a touch on a pixel with no alpha
        // at all is not delivered to the extension, so the empty page under a short
        // transcript took no swipe — only a finger starting on the glyphs or a filled
        // button worked (device test of e9095f5d). The vendored keys solve the same
        // problem the same way (`KeyView`, `UIColor(white: 0.001, alpha: 0.001)`).
        // Invisible, and the reader stays `RecordingOverlay`'s "no fill" surface.
        .background(Color.black.opacity(Self.touchableClear))
        .onAppear {
            visibleID = pages.first?.id
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
        // Delete removes the visible page (#639). Show the one that took its place —
        // the next, or the previous when it was the last — rather than whatever the
        // scroll view lands on. A note that lands while the reader is open is
        // appended (#637); on the empty state it becomes the page on screen.
        .onChange(of: pages.map(\.id)) { oldIDs, newIDs in
            if let visibleID, newIDs.contains(visibleID) { return }
            guard !newIDs.isEmpty else {
                visibleID = nil
                return
            }
            let removedAt = visibleID.flatMap { oldIDs.firstIndex(of: $0) } ?? 0
            visibleID = newIDs[min(removedAt, newIDs.count - 1)]
        }
        // A swipe to another page is a use of that note (#639). The first page's use is
        // recorded by the state when the reader opens.
        .onChange(of: visibleID) { oldID, newID in
            guard let newID, oldID != nil, newID != oldID else { return }
            onPageShown(newID)
        }
    }

    // MARK: - Header

    /// 52 pt, the toolbar's band, with its 12 pt sides and 4 pt top inset: the `✕`
    /// lands exactly on the ☰ and `Delete` exactly on the mic pill, so nothing jumps
    /// when the reader opens.
    ///
    /// One layout for both states, built so the side controls cannot drift: the two
    /// capsules sit at the ends of a full-width row held apart by a `Spacer`, and the
    /// facts are laid *over* that row, centred, rather than between them. The first
    /// version put the facts between the capsules as a `@ViewBuilder` that produced
    /// `EmptyView` on the empty state — its `.frame(maxWidth: .infinity)` vanished
    /// with it, and the lone `✕` was centred (second device test of #641).
    private var header: some View {
        HStack(spacing: 0) {
            closeButton
            Spacer(minLength: 0)
            if let page = visiblePage {
                deleteButton(page.id)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay { pageFacts }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(height: 52)
    }

    /// The centre slot: duration and language on one line, the page dots under them
    /// when there is more than one note.
    ///
    /// The duration in the secondary grey of the toolbar's hints, with tabular digits
    /// so `0:59` → `1:02` does not shimmy between pages. The language as a small tinted
    /// capsule rather than a `· FR` suffix: it is a different kind of fact — a code,
    /// not a quantity — and a joined string of facts reads like a log line.
    @ViewBuilder
    private var pageFacts: some View {
        if let page = visiblePage {
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    if let duration = page.durationLabel {
                        Text(verbatim: duration)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let language = page.languageBadge {
                        Text(verbatim: language)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(foregroundColor.opacity(0.1)))
                    }
                }
                .lineLimit(1)

                if pages.count > 1 {
                    pageDots
                }
            }
        }
    }

    /// One dot per page, the visible one filled. Only with more than one page.
    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(pages) { page in
                Circle()
                    .fill(page.id == visiblePage?.id ? Color.dictusAccent : foregroundColor.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    /// The width of the bar's two side controls, ☰ and the mic pill (both 56 pt).
    private static let barControlWidth: CGFloat = 56

    /// `✕`: closes the reader, the notes stay waiting (#637 decision 4).
    ///
    /// The ☰'s exact object (#639) — `ToolbarView.panelToggleButton`'s 56 × 36 glass
    /// capsule and 17 pt glyph — so the morph happens in place, the way the panel's
    /// does.
    private var closeButton: some View {
        barButton(systemName: "xmark",
                  label: Text("Close", comment: "Accessibility label of the keyboard voice note reader's close button (#637)."),
                  identifier: "voiceNoteReaderClose") {
            HapticFeedback.keyTapped()
            onClose()
        }
    }

    /// `Delete`, in the mic pill's place (#639): the same 56 × 36 glass capsule as the
    /// `✕`, the glyph in red because it removes something. From the keyboard only —
    /// the note stays in Dictus — so no confirmation.
    private func deleteButton(_ id: UUID) -> some View {
        barButton(systemName: "trash", tint: .red,
                  label: Text("Delete voice note", comment: "Accessibility label of the keyboard voice note reader's button that removes the note from the keyboard; it stays in the app (#639)."),
                  identifier: "voiceNoteReaderDelete") {
            onDelete(id)
        }
    }

    /// A header control: 36 pt to the eye, 44 pt to a finger, `ToolbarView.barIcon`'s split.
    private func barButton(systemName: String, tint: Color = .dictusPillIconSecondary,
                           label: Text, identifier: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(tint)
                .frame(width: Self.barControlWidth, height: 36)
                .dictusGlass(in: Capsule())
                .frame(width: Self.barControlWidth, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Empty state

    /// A long press on ☰ with nothing waiting (#639): what the feature is and how to
    /// feed it, since this is the only place the keyboard says so.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No recent voice note", comment: "Keyboard voice note reader, opened by a long press on the menu button when no shared voice note is waiting (#639).")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(foregroundColor)

            Text("Share a voice message to Dictus from a messaging app, and its transcript will show up here.",
                 comment: "Keyboard voice note reader's empty state: how a voice note gets here (#639).")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Lifted a little off the centre, where the action row would otherwise sit.
        .padding(.bottom, 24)
        .accessibilityIdentifier("voiceNoteReaderEmpty")
    }

    // MARK: - Pages

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages) { page in
                    transcriptPage(page)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleID)
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
    }

    /// Plain text, left-aligned, body size. Scrolls on its own; a long transcript
    /// never grows the keyboard, whose height is not this view's to change (#166).
    ///
    /// The text's frame is at least the page's height, with a full rectangle as its
    /// hit shape, so SwiftUI treats the whole page as the page — below a two-line note
    /// included. Necessary and, on device, not sufficient: the pixels there must also
    /// not be fully transparent, which is the reader's invisible fill (see `body`).
    /// Measured in a plain app on iOS 26.5 and 27 (sixth round of #641): with both, a
    /// swipe below a short text turns the page. The buttons are outside the pager, so
    /// nothing is taken from them; a long text is still taller than the minimum and
    /// scrolls.
    private func transcriptPage(_ page: VoiceNoteKeyboardDelivery) -> some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                Text(page.transcript)
                    .font(.body)
                    .foregroundColor(foregroundColor)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                    .contentShape(Rectangle())
            }
            .scrollIndicators(.hidden)
        }
        .contentShape(Rectangle())
        .mask(edgeFade)
    }

    /// Fades the first and last lines instead of a border.
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

    // MARK: - Actions

    /// One key row tall, on the visible page: `Open in Dictus` as a round glass button
    /// on the leading side, `Insert` taking the rest of the width (#637's row,
    /// restored after the second device test of #641).
    ///
    /// No `Copy` (device feedback on PR #638, 2026-10-03): `Insert` is the keyboard's
    /// job, and the full result screen behind `Open in Dictus` already copies.
    private var actionRow: some View {
        HStack(spacing: 10) {
            if let page = visiblePage {
                Button {
                    onOpenInDictus(page.id)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.dictusPillIconSecondary)
                        .frame(width: 44, height: 44)
                        .dictusGlass(in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityLabel(Text("Open in Dictus", comment: "Accessibility label of the keyboard voice note reader's button that opens the note in the app (#637)."))
                .accessibilityIdentifier("voiceNoteReaderOpen")

                Button {
                    onInsert(page.id)
                } label: {
                    Text("Insert", comment: "Primary button of the keyboard's voice note reader: writes the transcript into the text field (#637).")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(Color.dictusAccent))
                        .contentShape(Capsule())
                }
                .buttonStyle(GlassPressStyle())
                .accessibilityIdentifier("voiceNoteReaderInsert")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}
