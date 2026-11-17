// DictusApp/Onboarding/WhatsNewView.swift
// What's new: the running version's release notes, after an update and from Settings (#974).
import SwiftUI
import DictusCore

/// What's new after an update (#974): the new version's notes, once, in place of the tabs, with
/// a Continue button. No animation, by Pierre's brief. Who sees it, and when, is `WhatsNew` in
/// DictusCore; the words are `ReleaseNotes/<version>/<locale>.txt`, the text App Store Connect
/// gets too.
///
/// WHY MAINTABVIEW SHOWS IT IN PLACE OF THE TABS, NOT AS A COVER (#685): the trial
/// announcement, as a sheet on the tabs, cannot be raised over it, and the tabs' `onAppear`
/// raises it once What's new is done.
struct WhatsNewView: View {
    let notes: ReleaseNotes
    /// Continue was tapped.
    let onFinish: () -> Void

    /// Whether this presentation has recorded What's new as seen.
    @State private var isRecorded = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ReleaseNotesContent(notes: notes)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                OnboardingPrimaryButton(Text("Continue")) {
                    PersistentLog.log(.diagnosticProbe(
                        component: "whatsNew", instanceID: "0", action: "finished", details: ""
                    ))
                    onFinish()
                }
                .accessibilityIdentifier("whatsNew.continue")
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
                // The list scrolls under the button on a small iPhone: it fades out above it
                // instead of being cut by the button's edge.
                .background(alignment: .top) {
                    LinearGradient(colors: [Color.dictusBackground.opacity(0), Color.dictusBackground],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                        .offset(y: -28)
                        .allowsHitTesting(false)
                }
                .background(Color.dictusBackground.ignoresSafeArea())
            }
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
            details: "version=\(WhatsNew.runningVersion) items=\(notes.items.count)"
        ))
    }
}

/// The notes themselves: the app icon, the title, then one row per change. Shared by What's
/// new and the Settings row that reopens it.
///
/// WHY THIS LAYOUT: it is the « What's new » sheet of Apple's own apps (a large centred title,
/// one row per feature with its symbol, a bold title and one sentence), in Dictus's clothes:
/// the app icon tile with the paywall's accent glow (#913), DM Sans, and the brand gradient
/// behind each symbol.
struct ReleaseNotesContent: View {
    let notes: ReleaseNotes

    /// Whether the screen is short (an iPhone SE): smaller icon and title, tighter rows, as
    /// the paywall does (#913).
    @State private var isCompact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DictusIconTile(logoHeight: isCompact ? 24 : 30)
                    .shadow(color: Color.dictusAccent.opacity(0.6), radius: 10)
                    .shadow(color: Color.dictusAccent.opacity(0.3), radius: 22)
                    .accessibilityHidden(true)

                Text(verbatim: notes.title)
                    .font(.dmSans(.bold, size: isCompact ? 27 : 32, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, isCompact ? 12 : 16)

                VStack(alignment: .leading, spacing: isCompact ? 16 : 22) {
                    ForEach(notes.items, id: \.title) { item in
                        ReleaseNoteRow(item: item, isCompact: isCompact)
                    }
                }
                .padding(.top, isCompact ? 20 : 30)
            }
            .padding(.horizontal, isCompact ? 24 : 28)
            .padding(.top, isCompact ? 20 : 32)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            ZStack(alignment: .top) {
                Color.dictusBackground
                // A faint accent light behind the icon, as on the paywall's hero.
                RadialGradient(colors: [Color.dictusAccent.opacity(0.16), .clear],
                               center: .top, startRadius: 0, endRadius: 360)
                    .frame(height: 420)
            }
            .ignoresSafeArea()
        }
        .onGeometryChange(for: Bool.self) { $0.size.height < 700 } action: { isCompact = $0 }
        .accessibilityIdentifier("whatsNew.notes")
    }
}

/// One change: its symbol on a brand-gradient tile, a bold title, one sentence.
private struct ReleaseNoteRow: View {
    let item: ReleaseNotes.Item
    /// The SE's smaller sentence size.
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.dictusGradientStart, .dictusGradientEnd],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: item.title)
                    .font(.dmSans(.semiBold, size: 17, relativeTo: .headline))
                    .foregroundStyle(.primary)
                Text(verbatim: item.text)
                    .font(.dmSans(.regular, size: isCompact ? 14 : 15, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
