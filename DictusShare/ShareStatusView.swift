// DictusShare/ShareStatusView.swift
// The one screen of the share extension (#620).
import SwiftUI
import DictusCore

/// What the user sees after tapping Dictus in the share sheet.
///
/// Short on purpose: on the warm path it is on screen for under two seconds and
/// closes itself; on the cold path it carries the one instruction that matters,
/// "Open Dictus, your voice note is waiting" (#620, cold path option A).
struct ShareStatusView: View {

    @ObservedObject var model: ShareModel
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            icon
                .font(.system(size: 44, weight: .semibold))
                .frame(height: 56)
            Text(title)
                .font(.dictusSubheading)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.dictusBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            if model.state != .sending {
                Button(action: close) {
                    Text(isWarm ? "OK" : "Close")
                        .font(.dictusBody.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.dictusAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dictusBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.2), value: model.state)
    }

    private var isWarm: Bool { model.closesByItself }

    @ViewBuilder
    private var icon: some View {
        switch model.state {
        case .sending:
            ProgressView().controlSize(.large).tint(.white)
        case .transcribing:
            Image(systemName: "waveform").foregroundColor(.dictusAccentHighlight)
        case .waitingForApp:
            Image(systemName: "tray.and.arrow.down.fill").foregroundColor(.dictusAccentHighlight)
        case .refused:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        }
    }

    private var title: String {
        switch model.state {
        case .sending:
            return String(localized: "Sending to Dictus…", comment: "Share extension: copying the voice note (#620).")
        case .transcribing(let count, _):
            return count > 1
                ? String(localized: "Transcribing your voice notes", comment: "Share extension, warm path, several notes (#620).")
                : String(localized: "Transcribing your voice note", comment: "Share extension, warm path (#620).")
        case .waitingForApp(let count):
            return count > 1
                ? String(localized: "Open Dictus, your voice notes are waiting", comment: "Share extension, cold path, several notes (#620).")
                : String(localized: "Open Dictus, your voice note is waiting", comment: "Share extension, cold path: the app is not running and cannot be opened from here (#620).")
        case .refused:
            return String(localized: "Dictus cannot transcribe this", comment: "Share extension: the note was refused; the reason follows (#620).")
        }
    }

    private var message: String? {
        switch model.state {
        case .sending:
            return nil
        case .transcribing(_, let withActivity):
            return withActivity
                ? String(localized: "Follow it in the Dynamic Island or on the Lock Screen, and tap it when it is done.",
                         comment: "Share extension, warm path with a Live Activity (#620).")
                : String(localized: "Open Dictus when you want to read it.",
                         comment: "Share extension, warm path without a Live Activity (#620).")
        case .waitingForApp:
            return String(localized: "The transcription starts as soon as you open the app.",
                          comment: "Share extension, cold path (#620).")
        case .refused(let reason):
            return reason
        }
    }
}
