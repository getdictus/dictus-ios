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
        ZStack {
            Color.dictusBackground
                .ignoresSafeArea()

            ReleaseNotesContent(notes: notes)
                .safeAreaInset(edge: .bottom) {
                    OnboardingPrimaryButton(Text("Continue")) {
                        PersistentLog.log(.diagnosticProbe(
                            component: "whatsNew", instanceID: "0", action: "finished", details: ""
                        ))
                        onFinish()
                    }
                    .accessibilityIdentifier("whatsNew.continue")
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
                }
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
            details: "version=\(WhatsNew.runningVersion) lines=\(notes.lines.count)"
        ))
    }
}

/// The notes themselves: the title, then one bulleted line per change. Shared by What's new
/// and the Settings row that reopens it.
struct ReleaseNotesContent: View {
    let notes: ReleaseNotes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(verbatim: notes.title)
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                ForEach(notes.lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(verbatim: "•")
                            .font(.body.bold())
                            .foregroundStyle(Color.dictusAccent)
                            .accessibilityHidden(true)
                        Text(verbatim: line)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.vertical, OnboardingMetrics.titleTopPadding)
        }
        .accessibilityIdentifier("whatsNew.notes")
    }
}
