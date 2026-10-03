// DictusKeyboard/Views/VoiceNoteReaderView.swift
// The full-surface reader for shared voice note transcripts (issue #637).
import SwiftUI
import DictusCore

/// The waiting transcripts, one page each, taking over the whole keyboard surface the
/// way `RecordingOverlay` does: header in the toolbar's 52 pt band, the transcript,
/// and one action row.
///
/// ```
/// ▍▌▍ Voice note · 1:42 · FR       ● ○ ○    ✕
///
///   Salut, je voulais te dire que pour samedi
///   c'est bon de mon côté…              ← swipe
///
///   [↗]   [============  Insert  ============]
/// ```
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
            pager
            actionRow
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
        .onChange(of: pages.map(\.id)) { oldIDs, newIDs in
            guard let visibleID, !newIDs.contains(visibleID) else { return }
            let removedAt = oldIDs.firstIndex(of: visibleID) ?? 0
            self.visibleID = newIDs.isEmpty ? nil : newIDs[min(removedAt, newIDs.count - 1)]
        }
    }

    // MARK: - Header

    /// 52 pt, the toolbar's band: the same 4 pt top inset `ToolbarView` uses, so the
    /// controls sit where the bar's did and nothing jumps when the reader opens.
    private var header: some View {
        HStack(spacing: 8) {
            // The logo, drawn by the same view as the app's Home: its sizes derive
            // from the height, so it holds its shape at chip size too (#636).
            DictusLogo(height: 16)
                .accessibilityHidden(true)

            Text("Voice note", comment: "Header of the keyboard's voice note reader, and the toolbar chip when one note is waiting (#637).")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(foregroundColor)
                .lineLimit(1)

            metadata
                .layoutPriority(-1)

            Spacer(minLength: 4)

            if pages.count > 1 {
                pageDots
            }

            closeButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 4)
        .frame(height: 52)
    }

    /// `· 1:42 · FR`.
    @ViewBuilder
    private var metadata: some View {
        if let page = visiblePage {
            Text(([page.durationLabel, page.languageBadge].compactMap { $0 }).map { "· \($0)" }.joined(separator: " "))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
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

    /// `✕`: closes the reader, the notes stay waiting (#637 decision 4).
    private var closeButton: some View {
        Button {
            HapticFeedback.keyTapped()
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.dictusPillIconSecondary)
                .frame(width: 36, height: 36)
                .dictusGlass(in: Circle())
                // Same split as `ToolbarView.barIcon`: 36 pt to the eye, 44 pt to a finger.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(Text("Close", comment: "Accessibility label of the keyboard voice note reader's close button (#637)."))
        .accessibilityIdentifier("voiceNoteReaderClose")
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

    /// One key row tall. `Insert` is the primary and takes the width; `Open in Dictus`
    /// is icon-only on its leading side. Both act on the visible page.
    ///
    /// No `Copy` (device feedback on PR #638, 2026-10-03): `Insert` is the keyboard's
    /// job, and the full result screen behind `Open in Dictus` already copies.
    private var actionRow: some View {
        HStack(spacing: 10) {
            if let page = visiblePage {
                secondaryButton(
                    systemName: "arrow.up.forward.app",
                    tint: .dictusPillIconSecondary,
                    label: Text("Open in Dictus", comment: "Accessibility label of the keyboard voice note reader's button that opens the note in the app (#637)."),
                    identifier: "voiceNoteReaderOpen"
                ) { onOpenInDictus(page.id) }

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

    private func secondaryButton(systemName: String, tint: Color, label: Text, identifier: String,
                                 action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .dictusGlass(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(GlassPressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
