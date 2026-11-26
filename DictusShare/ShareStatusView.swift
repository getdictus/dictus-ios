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
            if let languageLine {
                Text(languageLine)
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            if showsButton {
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

    /// No button while sending, nor while this extension transcribes (#1056): closing the
    /// sheet then would end the process mid-note. It closes itself when done.
    private var showsButton: Bool {
        switch model.state {
        case .sending, .transcribingHere: return false
        default: return true
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch model.state {
        case .sending:
            ProgressView().controlSize(.large).tint(.white)
        case .transcribing, .transcribingHere:
            Image(systemName: "waveform").foregroundColor(.dictusAccentHighlight)
        case .transcribedHere:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.dictusSuccess)
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
        case .transcribing(let count, _), .transcribingHere(let count, _):
            return count > 1
                ? String(localized: "Transcribing your voice notes", comment: "Share extension, warm path, several notes (#620).")
                : String(localized: "Transcribing your voice note", comment: "Share extension, warm path (#620).")
        case .transcribedHere(let count, _):
            return count > 1
                ? String(localized: "Voice notes transcribed", comment: "Share extension: several notes transcribed in the extension with Apple's model, app closed (#1056).")
                : String(localized: "Voice note transcribed", comment: "Share extension: the note was transcribed in the extension with Apple's model, app closed (#1056).")
        case .waitingForApp(let count, _):
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
        case .transcribingHere:
            // Said once, under the title; the language line below names the language.
            return nil
        case .transcribedHere:
            return String(localized: "The text is in the Dictus keyboard.",
                          comment: "Share extension: the note was transcribed with the app closed; the Dictus keyboard offers the text (#1056).")
        case .waitingForApp(_, .appClosed):
            return String(localized: "The transcription starts as soon as you open the app.",
                          comment: "Share extension, cold path (#620).")
        case .waitingForApp(_, .overExtensionCap):
            return String(localized: "Longer than 5 minutes: Dictus transcribes it in the app, as soon as you open it.",
                          comment: "Share extension: the note is over the 5-minute limit of transcription with the app closed, so the app transcribes it (#1056).")
        case .refused(let reason):
            return reason
        }
    }

    /// The language Apple's model was given (#1056). Under automatic detection, the
    /// default, it is the dictation language, and the line says so: Apple's recognizer
    /// does not detect the language.
    private var languageLine: String? {
        switch model.state {
        case .transcribingHere(_, let language):
            let name = language.name
            return language.isDictationLanguage
                ? String(localized: "With Apple's on-device model, in \(name), your dictation language.",
                         comment: "Share extension, app closed: the note is transcribed by Apple's model in the dictation language, standing in for automatic detection (#1056). The argument is a language name.")
                : String(localized: "With Apple's on-device model, in \(name).",
                         comment: "Share extension, app closed: the note is transcribed by Apple's model in the voice-note language the user set (#1056). The argument is a language name.")
        case .transcribedHere(_, let language):
            let name = language.name
            return language.isDictationLanguage
                ? String(localized: "Transcribed in \(name), your dictation language.",
                         comment: "Share extension, app closed: done, in the dictation language, standing in for automatic detection (#1056). The argument is a language name.")
                : String(localized: "Transcribed in \(name).",
                         comment: "Share extension, app closed: done, in the voice-note language the user set (#1056). The argument is a language name.")
        default:
            return nil
        }
    }
}
