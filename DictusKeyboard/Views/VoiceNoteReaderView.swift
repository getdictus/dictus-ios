// DictusKeyboard/Views/VoiceNoteReaderView.swift
// The full-surface reader for shared voice note transcripts (issues #637, #639).
import SwiftUI
import DictusCore

/// The waiting transcripts, one page each, taking over the whole keyboard surface the
/// way `RecordingOverlay` does: header in the toolbar's 52 pt band, the transcript,
/// and one action row.
///
/// ```
/// [ ✕ ]            1:42  FR             [ ↗ ]
///                   ● ○ ○
///   Salut, je voulais te dire que pour samedi
///   c'est bon de mon côté…              ← swipe
///
///   [================  Insert  ================]
/// ```
///
/// ### The header is the toolbar it replaces (#639, after the device test)
///
/// Three slots, the bar's own: the `✕` in the ☰'s place — the reader opens from a
/// tap on ☰, and the control under the thumb becomes its own way back — `Open in
/// Dictus` in the mic pill's place, at the mic pill's size, and the facts in the
/// centre slot, in the centre slot's quiet register. No title and no logo: the
/// surface says what it is, and a "Voice note" heading over a voice note was the
/// one line on screen carrying nothing. What is left is what helps choose: how long
/// the message was, what language it was read in, and, with several notes, where
/// you are among them.
///
/// Moving `Open in Dictus` up leaves `Insert` alone in the bottom row, full width:
/// one primary action, where a key row was, with nothing beside it to mistap.
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
    /// A page came on screen: a use, which restarts the note's 15 minutes (#639).
    let onPageShown: (UUID) -> Void

    /// The page on screen. Nil until the first layout pass, which reads as page 0.
    @State private var visibleID: UUID?
    @State private var appeared = false

    @Environment(\.colorScheme) private var colorScheme

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
            header
            if pages.isEmpty {
                emptyState
            } else {
                pager
                actionRow
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .background(Color.clear)
        .onAppear {
            visibleID = pages.first?.id
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
        // `Insert` removes the visible page (#637 decision 7). Show the one that took
        // its place — the next, or the previous when it was the last — rather than
        // whatever the scroll view lands on.
        // A note that lands while the reader is open is appended (#637). On the empty
        // state that is the first page, and it is now the one on screen.
        .onChange(of: pages.map(\.id)) { _, newIDs in
            if let visibleID, newIDs.contains(visibleID) { return }
            visibleID = newIDs.first
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
    /// lands exactly on the ☰ and `Open in Dictus` exactly on the mic pill, so nothing
    /// jumps when the reader opens.
    private var header: some View {
        HStack(spacing: 8) {
            closeButton

            pageFacts
                .frame(maxWidth: .infinity)

            if let page = visiblePage {
                openInDictusButton(page.id)
            } else {
                // The empty state has nothing to open; the slot stays, so the facts
                // (none) and the `✕` do not move.
                Color.clear.frame(width: Self.barControlWidth, height: 44)
            }
        }
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

    /// `Open in Dictus`, in the mic pill's place: the same 56 × 36 glass capsule as
    /// the `✕`, so the header is the bar's silhouette and its two ends match.
    private func openInDictusButton(_ id: UUID) -> some View {
        barButton(systemName: "arrow.up.forward.app",
                  label: Text("Open in Dictus", comment: "Accessibility label of the keyboard voice note reader's button that opens the note in the app (#637)."),
                  identifier: "voiceNoteReaderOpen") {
            onOpenInDictus(id)
        }
    }

    /// A header control: 36 pt to the eye, 44 pt to a finger, `ToolbarView.barIcon`'s split.
    private func barButton(systemName: String, label: Text, identifier: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.dictusPillIconSecondary)
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

            Text("Share a voice message to Dictus from WhatsApp or any other app, and its transcript shows up here.",
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
    private func transcriptPage(_ page: VoiceNoteKeyboardDelivery) -> some View {
        ScrollView(.vertical) {
            Text(page.transcript)
                .font(.body)
                .foregroundColor(foregroundColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
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

    /// One key row tall: `Insert`, alone and full width, on the visible page. The
    /// keyboard's job is to write, and the bottom row is where a thumb already is.
    ///
    /// No `Copy` (device feedback on PR #638, 2026-10-03): `Insert` is the keyboard's
    /// job, and the full result screen behind `Open in Dictus` already copies.
    private var actionRow: some View {
        Group {
            if let page = visiblePage {
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
