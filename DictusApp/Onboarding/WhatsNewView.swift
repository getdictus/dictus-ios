// DictusApp/Onboarding/WhatsNewView.swift
// What's new: the running version's highlights in a sheet after an update, and every change
// from Settings (#974).
import SwiftUI
import DictusCore

/// What's new after an update (#974): a sheet over the tabs, at half height (`.medium`, drag
/// to `.large`), with the Dictus logo, the version's title, its highlights (at most three) and
/// Continue. Who sees it, and when, is `WhatsNew` in DictusCore; the words are
/// `ReleaseNotes/<version>/<locale>.txt`, whose full list App Store Connect gets.
///
/// WHY A SHEET AND THREE LINES (Pierre's device test, validated by Titus on 2026-11-19): a
/// full screen of six rows read as a wall. Half a screen, three short highlights and the app
/// behind it is what an update deserves; the full list stays one tap away in Settings.
struct WhatsNewView: View {
    let notes: ReleaseNotes
    /// Continue was tapped. Dragging the sheet down ends it too, through the presenter.
    let onFinish: () -> Void

    /// Whether this presentation has recorded What's new as seen.
    @State private var isRecorded = false

    /// Whether the sheet is short: the medium detent on an iPhone SE is about 330 pt, where
    /// the logo goes beside the title and the text is a size smaller, so the three highlights
    /// fit above Continue without dragging.
    @State private var isCompact = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ReleaseNotesHeader(title: notes.title, isCompact: isCompact)
                VStack(alignment: .leading, spacing: isCompact ? 10 : 18) {
                    ForEach(notes.highlights, id: \.title) { ReleaseNoteRow(item: $0, isCompact: isCompact) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, isCompact ? 14 : 22)
            }
            .padding(.horizontal, isCompact ? 24 : 28)
            .padding(.top, isCompact ? 22 : 28)
            .padding(.bottom, isCompact ? 8 : 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingPrimaryButton(Text("Continue")) {
                PersistentLog.log(.diagnosticProbe(
                    component: "whatsNew", instanceID: "0", action: "finished", details: ""
                ))
                onFinish()
            }
            .accessibilityIdentifier("whatsNew.continue")
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        .onGeometryChange(for: Bool.self) { $0.size.height < 420 } action: { isCompact = $0 }
        .accessibilityIdentifier("whatsNew.notes")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { recordSeenIfOnScreen() }
        .onChange(of: scenePhase) { _, _ in recordSeenIfOnScreen() }
    }

    /// Records What's new as seen once it is really in front of the user: on screen and the
    /// app active. Then it is shown once even if the app is closed right away.
    ///
    /// WHY NOT ON APPEAR ALONE (CodeRabbit on PR #741): a view appears in a launch the user
    /// does not see yet, and a URL opening the app is handled before it becomes active.
    /// Waiting for `.active` lets that URL withdraw What's new unrecorded
    /// (`MainTabView.onOpenURL`), so it is still due at the next activation.
    private func recordSeenIfOnScreen() {
        guard scenePhase == .active, !isRecorded else { return }
        isRecorded = true
        WhatsNew.recordSeen()
        PersistentLog.log(.diagnosticProbe(
            component: "whatsNew", instanceID: "0", action: "shown",
            details: "version=\(WhatsNew.runningVersion) highlights=\(notes.highlights.count)"
        ))
    }
}

/// Settings › About › What's new: the logo, the title and every change of the running version,
/// the list App Store Connect gets.
struct ReleaseNotesListView: View {
    let notes: ReleaseNotes

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ReleaseNotesHeader(title: notes.title)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(notes.changes, id: \.title) { ReleaseNoteRow(item: $0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("whatsNew.allChanges")
    }
}

/// The Dictus logo over the version's title, centred; beside it in a short sheet.
private struct ReleaseNotesHeader: View {
    let title: String
    var isCompact = false

    var body: some View {
        let layout = isCompact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 14))
        layout {
            DictusLogo(height: isCompact ? 24 : 34)
                .accessibilityHidden(true)
            Text(verbatim: title)
                .font(.dmSans(.bold, size: isCompact ? 22 : 26, relativeTo: .title))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// One change: a bold title, one sentence under it.
private struct ReleaseNoteRow: View {
    let item: ReleaseNotes.Item
    var isCompact = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 1 : 3) {
            Text(verbatim: item.title)
                .font(.dmSans(.semiBold, size: isCompact ? 16 : 17, relativeTo: .headline))
                .foregroundStyle(.primary)
            Text(verbatim: item.text)
                .font(.dmSans(.regular, size: isCompact ? 14 : 15, relativeTo: .subheadline))
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
