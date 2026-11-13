// DictusApp/Views/FeedbackView.swift
// The "Send feedback" sheet opened from Settings (#565).
import DictusCore
import SwiftUI

/// Bug, idea or other, sent to the Dictus team only when the user taps Send.
///
/// WHY the name sits at the top and every other value sent is listed on screen:
/// Apple lets an app keep "Data Not Collected" for optional, user-initiated
/// submissions only when the form shows the user's name next to everything it
/// submits. Dictus has no accounts, so the form asks for a name.
struct FeedbackView: View {
    @ObservedObject private var composer = FeedbackComposer.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            Group {
                if composer.phase == .sent {
                    sentConfirmation
                } else {
                    form
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.dictusBackground.ignoresSafeArea())
            .navigationTitle("Send feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if composer.phase != .sent {
                    ToolbarItem(placement: .confirmationAction) {
                        if composer.phase == .sending {
                            ProgressView()
                        } else {
                            Button("Send") { Task { await composer.send() } }
                                .disabled(!composer.canSend)
                                .accessibilityIdentifier("feedback.send")
                        }
                    }
                }
            }
        }
        .task { await composer.sheetDidAppear() }
        .onDisappear {
            if composer.phase == .sent { composer.startOver() }
        }
        .sheet(isPresented: $isSharing) {
            ShareSheet(items: composer.shareItems())
        }
    }

    private var form: some View {
        Form {
            if case .failed(let failure) = composer.phase {
                failureSection(failure)
            }

            Section {
                TextField("Your name", text: $composer.draft.name)
                    .textContentType(.name)
                    .accessibilityIdentifier("feedback.name")
                TextField("Email (optional)", text: $composer.draft.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("feedback.email")
            } header: {
                Text("From")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("A name is required. A pseudonym is fine. Give an email only if you want a reply.")
                    if composer.draft.problems.contains(.emailInvalid) {
                        Text("This email address looks incomplete.").foregroundStyle(.red)
                    }
                    if composer.draft.problems.contains(.nameTooLong) {
                        Text("The name is limited to 100 characters.").foregroundStyle(.red)
                    }
                }
            }

            Section {
                Picker("Type", selection: $composer.draft.kind) {
                    Text("Bug").tag(FeedbackKind.bug)
                    Text("Idea").tag(FeedbackKind.idea)
                    Text("Other").tag(FeedbackKind.other)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("feedback.type")

                TextField(messagePrompt, text: $composer.draft.message, axis: .vertical)
                    .lineLimit(6...)
                    .accessibilityIdentifier("feedback.message")
            } footer: {
                if composer.draft.messageOverflow > 0 {
                    Text("Characters over the 4,000 limit: \(composer.draft.messageOverflow)")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Toggle("Attach the debug log", isOn: $composer.draft.attachesLog)
                    .accessibilityIdentifier("feedback.attachLog")
                if composer.draft.attachesLog {
                    NavigationLink {
                        if let snapshot = composer.logSnapshot {
                            DebugLogView(snapshot: snapshot)
                        } else {
                            ProgressView()
                        }
                    } label: {
                        Text("See what will be sent")
                    }
                    .accessibilityIdentifier("feedback.seeLog")
                }
            } footer: {
                logDisclosure
            }

            Section("Also sent") {
                LabeledContent("Dictus", value: "\(composer.device.appVersion) (\(composer.device.build))")
                LabeledContent("iOS", value: composer.device.iosVersion)
                LabeledContent("Device", value: composer.device.deviceModel)
                LabeledContent("Language and region", value: composer.device.locale)
                LabeledContent("Code revision", value: composer.device.gitRevision)
            }
        }
    }

    private var messagePrompt: LocalizedStringKey {
        switch composer.draft.kind {
        case .bug: return "What happened, and what did you expect?"
        case .idea: return "Your idea"
        case .other: return "Your message"
        }
    }

    /// WHY two versions: a TestFlight or Debug build logs the words of the short
    /// passages the Parakeet drift retry replaced (#861, `driftRetrySpanReplaced`),
    /// so only the App Store build can promise the log holds no dictated text.
    private var logDisclosure: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("If you attach the debug log, it covers the last 7 days.")
            if BuildChannel.current == .appStore {
                Text("It contains neither your transcriptions nor what you type.")
            } else {
                Text("It does not contain what you type. In this test version, it can contain short passages of your dictations that Dictus corrected automatically.")
            }
            Text("It contains the iOS and Dictus versions, your device model, and the identifiers of the apps you used the keyboard in. You can read it before sending.")
        }
    }

    private func failureSection(_ failure: FeedbackFailure) -> some View {
        Section {
            Text(failureMessage(failure))
                .foregroundStyle(.red)
                .accessibilityIdentifier("feedback.failure")
            if failure.allowsRetry {
                Button("Retry") { Task { await composer.send() } }
                    .disabled(!composer.canSend)
                    .accessibilityIdentifier("feedback.retry")
            }
            Button("Share instead") { isSharing = true }
                .accessibilityIdentifier("feedback.share")
        }
    }

    private func failureMessage(_ failure: FeedbackFailure) -> LocalizedStringKey {
        switch failure {
        case .unreachable:
            return "Dictus could not reach the server. Your message is kept."
        case .rateLimited(let seconds?) where seconds > 60:
            return "Too many reports came from this network. Try again in \((seconds + 59) / 60) minutes."
        case .rateLimited:
            return "Too many reports came from this network. Try again in a minute."
        case .deliveryFailed:
            return "The server could not deliver your report. Your message is kept."
        case .unavailable:
            return "Feedback is unavailable right now. Your message is kept."
        case .rejected:
            return "The server refused this report. Share it instead."
        }
    }

    private var sentConfirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.dictusSuccess)
            Text("Sent. Thank you.")
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier("feedback.sent")
            Button("Done") { dismiss() }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
