// DictusShare/ShareViewController.swift
// The Dictus entry in the share sheet: takes a voice note and hands it to the app (#620).
import UIKit
import SwiftUI
import UniformTypeIdentifiers
import DictusCore

/// The share extension's principal class.
///
/// ### What it does, and what it deliberately does not
///
/// It copies the shared audio into the App Group inbox and tells DictusApp. A live app
/// takes the note and transcribes it with the user's model, which lives in DictusApp's
/// own containers (#620 spike, finding 2).
///
/// When DictusApp is not alive to take the note (#620's cold path), the extension
/// transcribes it itself with Apple's on-device model when the device can
/// (`ShareOnDeviceTranscription`, #1056: iOS 26+, the language covered, the model
/// installed, 5 minutes at most). Otherwise it opens the app on the note, as before: see
/// `openDictus(on:)` for how, and for the risk that way carries. If opening fails, it
/// says "Open Dictus, your voice note is waiting".
final class ShareViewController: UIViewController {

    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        PersistentLog.source = "SHARE"

        let host = UIHostingController(rootView: ShareStatusView(model: model) { [weak self] in
            self?.finish()
        })
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)

        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        Task { @MainActor in
            await model.receive(providers)
            if model.closesByItself {
                // The warm path: the note is in good hands, and the user goes straight
                // back to the conversation they shared from (#620 decision 2). The
                // haptic says "received"; 1.2 s is long enough to read the line and
                // short enough to feel like the island took it (decision 6). A note
                // transcribed here (#1056) stays 2 s: its sheet carries one more line,
                // the language it was transcribed in.
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let transcribedHere: Bool
                if case .transcribedHere = model.state { transcribedHere = true } else { transcribedHere = false }
                try? await Task.sleep(nanoseconds: transcribedHere ? 2_000_000_000 : 1_200_000_000)
                finish()
            } else if case .waitingForApp(_, let reason) = model.state {
                // The cold path: open Dictus on the note. The "waiting" screen already
                // on display stays as the fallback when opening fails. Over the
                // extension's 5-minute cap (#1056) it stays 2.5 s first, so the reason
                // the app opens can be read.
                if reason == .overExtensionCap {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                }
                if await openDictus(on: model.firstDropID) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    finish()
                }
            }
        }
    }

    // MARK: - Opening DictusApp

    /// Open DictusApp on the voice note link. Returns whether iOS opened it.
    ///
    /// ### Measured on device, 2026-10-01 (iPhone 15 Pro Max, iOS 27.0.1, #620 probe)
    ///
    /// - `NSExtensionContext.open(_:completionHandler:)`, the documented API — the one
    ///   the keyboard uses — returns `false` from a share extension. Apple documents it
    ///   for Today and iMessage extensions only. It is still tried first, so the day
    ///   iOS honours it here this path stops depending on the second one.
    /// - Walking the responder chain from this controller to the `UIApplication`
    ///   instance (8 hops on that device) and calling
    ///   `open(_:options:completionHandler:)` on it returned `true` and Dictus opened.
    ///
    /// ### The risk, stated
    ///
    /// The second call is undocumented: `UIApplication` is unavailable to extensions at
    /// compile time, so it is reached through the Objective-C runtime. That is an App
    /// Review guideline 2.5.1 risk (public APIs only), and Apple DTS calls it
    /// unsupported on the developer forums. MacWhisper and VivaDicta ship the same
    /// behaviour. The maintainer chose it on 2026-10-01 over a notification-permission
    /// prompt. If a review rejects it, deleting this method leaves the extension on the
    /// "Open Dictus" screen, which works on its own.
    private func openDictus(on noteID: UUID?) async -> Bool {
        guard let url = VoiceNoteURL.url(for: noteID) else { return false }

        if let context = extensionContext {
            let opened: Bool = await withCheckedContinuation { continuation in
                context.open(url) { success in continuation.resume(returning: success) }
            }
            if opened {
                log("open", "via=extensionContext result=true")
                return true
            }
        }

        var responder: UIResponder? = self
        while let current = responder, !current.isKind(of: UIApplication.self) {
            responder = current.next
        }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard let application = responder, application.responds(to: selector),
              let method = application.method(for: selector) else {
            log("open", "via=responderChain result=applicationNotFound")
            return false
        }
        typealias OpenFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary,
                                                 (@convention(block) (Bool) -> Void)?) -> Void
        let open = unsafeBitCast(method, to: OpenFunction.self)
        let opened: Bool = await withCheckedContinuation { continuation in
            let completion: @convention(block) (Bool) -> Void = { success in continuation.resume(returning: success) }
            open(application, selector, url as NSURL, NSDictionary(), completion)
        }
        log("open", "via=responderChain result=\(opened)")
        return opened
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNoteShare", instanceID: "extension", action: action, details: details))
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// What the extension is showing.
enum ShareState: Equatable {
    /// Copying, and waiting to hear from the app.
    case sending
    /// DictusApp took the note and transcribes it now. `withActivity` says whether
    /// progress will be on the Live Activity.
    case transcribing(count: Int, withActivity: Bool)
    /// Nobody answered and the extension transcribes the notes itself with Apple's
    /// on-device model (#1056), in `language`.
    case transcribingHere(count: Int, language: ShareTranscriptionLanguage)
    /// The extension transcribed them: the text is in the keyboard (and History).
    case transcribedHere(count: Int, language: ShareTranscriptionLanguage)
    /// Nobody answered: the note waits for the app to open (#620's cold path).
    case waitingForApp(count: Int, reason: ShareWaitingReason)
    /// Refused, with the sentence to show.
    case refused(String)
}

/// The language a note transcribed in the extension was given to Apple's recognizer in,
/// for the sheet to name (#1056: under automatic detection, the default, it is the
/// dictation language, and the sheet says so).
struct ShareTranscriptionLanguage: Equatable {
    let code: String
    /// True under automatic detection: the dictation (keyboard) language stood in.
    let isDictationLanguage: Bool

    /// The language's name in the reader's language, "français" / "French".
    var name: String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

/// Why the note waits for the app.
enum ShareWaitingReason: Equatable {
    /// Today's cold path: the app is closed and the extension does not transcribe this
    /// note (Apple's model not ready, iOS older than 26, language not covered, a failure).
    case appClosed
    /// Longer than the extension's 5-minute cap (#1056).
    case overExtensionCap
}

/// The extension's work, off the view.
@MainActor
final class ShareModel: ObservableObject {

    @Published private(set) var state: ShareState = .sending

    /// The first note this share dropped, which the cold path opens Dictus on.
    private(set) var firstDropID: UUID?

    /// How long the extension waits for a live DictusApp to take the note. A live app
    /// answers in milliseconds — the Darwin post is delivered immediately and the
    /// ingest is a file move — so this only bounds the cold case, where nothing
    /// will ever answer and the user is looking at "Sending…".
    private static let acceptanceTimeout: TimeInterval = 1.5

    /// At most this many voice notes from one share. The queue takes any number; one
    /// share sheet tap dropping fifty files in it is not a voice note.
    private static let maximumAttachments = 10

    var closesByItself: Bool {
        switch state {
        case .transcribing, .transcribedHere: return true
        default: return false
        }
    }

    func receive(_ providers: [NSItemProvider]) async {
        switch VoiceNoteAvailability.shareDecision {
        case .accept:
            break
        case .refuseNeedsPro:
            log("rejected", "reason=notEntitled detected=none type=none")
            state = .refused(String(localized: "Transcribing voice notes is part of Dictus Pro. Open Dictus to find out more.",
                                    comment: "Share extension: the user has no Pro entitlement and the paywall is visible (#620)."))
            return
        case .refuseSwitchedOff:
            log("rejected", "reason=switchedOff detected=none type=none")
            state = .refused(String(localized: "Voice notes are switched off. Turn them back on in Dictus, under Dictus Pro.",
                                    comment: "Share extension: a Pro user switched voice notes off in the Dictus Pro hub (#216)."))
            return
        case .refuseUnavailable:
            log("rejected", "reason=unavailable detected=none type=none")
            state = .refused(String(localized: "Transcribing voice notes is not available in this version of Dictus.",
                                    comment: "Share extension: no entitlement, and the paywall is hidden so no subscription may be named (#620, #236)."))
            return
        }
        guard let storage = VoiceNoteStorage.appGroup else {
            log("rejected", "reason=noAppGroup detected=none type=none")
            state = .refused(Self.couldNotReceive)
            return
        }

        let audioProviders = providers.filter { Self.audioTypeIdentifier(of: $0) != nil }
            .prefix(Self.maximumAttachments)
        var drops: [VoiceNoteDrop] = []
        var refusal: String?
        for provider in audioProviders {
            switch await Self.drop(provider, storage: storage) {
            case .success(let drop): drops.append(drop)
            case .failure(let reason): refusal = refusal ?? reason.message
            }
        }
        guard !drops.isEmpty else {
            if audioProviders.isEmpty {
                let types = providers.flatMap(\.registeredTypeIdentifiers).joined(separator: ",")
                log("rejected", "reason=noAudioAttachment detected=none type=\(types.isEmpty ? "none" : types)")
            }
            state = .refused(refusal ?? Self.couldNotReceive)
            return
        }
        log("dropped", "count=\(drops.count)")
        firstDropID = drops.first?.id

        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteQueued)
        let taken = await waitForApp(drops, storage: storage)
        if taken {
            let withActivity = AppGroup.defaults.bool(forKey: SharedKeys.voiceNoteAcceptedWithActivity)
            state = .transcribing(count: drops.count, withActivity: withActivity)
            log("warm", "count=\(drops.count)")
            return
        }
        await transcribeHereOrWait(drops, storage: storage)
    }

    /// #1056: nobody took the notes. Transcribe them here when the device can, showing
    /// the "transcribing" sheet with the language; otherwise today's cold path.
    private func transcribeHereOrWait(_ drops: [VoiceNoteDrop], storage: VoiceNoteStorage) async {
        let decision = await ShareOnDeviceTranscription.route(for: drops)
        guard case .shareExtension(let code, let source) = decision.route, let recognizer = decision.recognizer else {
            let reason: ShareWaitingReason
            if case .openApp(.overExtensionCap) = decision.route { reason = .overExtensionCap } else { reason = .appClosed }
            state = .waitingForApp(count: drops.count, reason: reason)
            log("cold", "count=\(drops.count) route=\(decision.route.logName)")
            return
        }
        let language = ShareTranscriptionLanguage(code: code, isDictationLanguage: source == .dictationLanguage)
        state = .transcribingHere(count: drops.count, language: language)
        let started = Date()
        let outcome = await ShareOnDeviceTranscription.run(drops, storage: storage, recognizer: recognizer,
                                                           languageCode: code)
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        switch outcome {
        case .done(let count):
            state = .transcribedHere(count: count, language: language)
            log("onDevice", "count=\(count) elapsedMs=\(elapsed)")
        case .fellBack(let transcribed, let reason):
            // The first note not transcribed is the one Dictus opens on.
            let remaining = Array(drops.dropFirst(transcribed))
            firstDropID = remaining.first?.id
            let waiting: ShareWaitingReason
            if case .overExtensionCap = reason { waiting = .overExtensionCap } else { waiting = .appClosed }
            state = .waitingForApp(count: remaining.count, reason: waiting)
            log("cold", "count=\(remaining.count) transcribedHere=\(transcribed) reason=\(waiting) elapsedMs=\(elapsed)")
        }
    }

    /// The warm detection (#620 open question 3): a live DictusApp moves the drop
    /// out of the inbox as soon as the post arrives. See `VoiceNoteInbox`.
    private func waitForApp(_ drops: [VoiceNoteDrop], storage: VoiceNoteStorage) async -> Bool {
        let deadline = Date().addingTimeInterval(Self.acceptanceTimeout)
        while Date() < deadline {
            if drops.allSatisfy({ !VoiceNoteInbox.isPending($0, storage: storage) }) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return drops.allSatisfy { !VoiceNoteInbox.isPending($0, storage: storage) }
    }

    // MARK: - One attachment

    private enum DropFailure: Error {
        case unreadable, notAudio, tooLong

        var message: String {
            switch self {
            case .unreadable:
                return ShareModel.couldNotReceive
            case .notAudio:
                return String(localized: "This file is not an audio format Dictus can read.",
                              comment: "Share extension: the shared file is not a recognised audio container (#620).")
            case .tooLong:
                return String(localized: "This voice note is longer than 10 minutes, the longest Dictus transcribes.",
                              comment: "Share extension: over the 10-minute cap (#620).")
            }
        }
    }

    nonisolated private static var couldNotReceive: String {
        String(localized: "Dictus could not receive this file.",
               comment: "Share extension: the file could not be read or copied (#620).")
    }

    /// The identifiers that mark an attachment as audio. Ogg is named on its own:
    /// iOS 26 maps `.opus` and `.ogg` to `org.xiph.ogg-audio` (#620 spike), and on
    /// iOS 17/18 the declaration DictusApp imports makes it conform to `public.audio`.
    ///
    /// `public.mpeg` is a video type, and it is here anyway: Signal hands a received
    /// voice note over as MP3 frames in a `.mpg` file, which iOS types that way
    /// (measured on device, 2026-10-01). Such a candidate is only a candidate — `drop`
    /// takes it only when its bytes are audio and it carries no video track.
    private static let audioTypes = ["org.xiph.ogg-audio", "org.xiph.opus", UTType.audio.identifier,
                                     UTType.mpeg.identifier, UTType.mpeg4Movie.identifier,
                                     "org.webmproject.webm", "org.matroska.mkv"]

    static func audioTypeIdentifier(of provider: NSItemProvider) -> String? {
        for identifier in provider.registeredTypeIdentifiers {
            guard let type = UTType(identifier) else { continue }
            if audioTypes.contains(identifier) || type.conforms(to: .audio) { return identifier }
        }
        return nil
    }

    private static func drop(_ provider: NSItemProvider, storage: VoiceNoteStorage) async -> Result<VoiceNoteDrop, DropFailure> {
        guard let identifier = audioTypeIdentifier(of: provider) else {
            return reject(.notAudio, reason: "noAudioType", detected: nil, type: provider.registeredTypeIdentifiers.first)
        }
        // The URL handed to the callback is valid only inside it, so the copy to a
        // file of our own happens there.
        let local: URL? = await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
                guard let url else { return continuation.resume(returning: nil) }
                let copy = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        guard let local else { return reject(.unreadable, reason: "loadFailed", detected: nil, type: identifier) }
        defer { try? FileManager.default.removeItem(at: local) }

        // The bytes decide, not the type or the name the sender gave (#620 format
        // audit): Radar names raw ADTS AAC `.m4a`, Signal puts MP3 in `.mpg`, a
        // `.mpg` film sniffs as nothing (an MPEG program stream), and a container that
        // turns out to hold a picture is a video, whatever it was shared as.
        guard let format = SharedAudioFormat.sniff(contentsOf: local) else {
            return reject(.notAudio, reason: "unrecognisedContainer", detected: nil, type: identifier)
        }
        guard format.isSupported else {
            return reject(.notAudio, reason: "unsupportedCodec", detected: format, type: identifier)
        }
        if format == .mpeg4, await SharedAudioDecoder.hasVideoTrack(local) {
            return reject(.notAudio, reason: "video", detected: format, type: identifier)
        }
        if format == .matroska,
           let data = try? Data(contentsOf: local, options: .mappedIfSafe),
           MatroskaOpusDemuxer.hasVideoTrack(data) {
            return reject(.notAudio, reason: "video", detected: format, type: identifier)
        }
        // Refused here when the container states its length, so a forty-minute
        // podcast is never copied into the App Group only to fail in the app.
        let duration = await SharedAudioDecoder.probeDuration(of: local, format: format)
        if let duration, SharedAudioDecoder.exceedsCap(duration) {
            return reject(.tooLong, reason: "tooLong", detected: format, type: identifier)
        }
        do {
            let drop = try VoiceNoteInbox.drop(copying: local, format: format,
                                               durationSeconds: duration.map { Int($0.rounded()) }, storage: storage)
            return .success(drop)
        } catch {
            return reject(.unreadable, reason: "copyFailed", detected: format, type: identifier)
        }
    }

    /// Every refusal leaves one line in the debug log, so a note that "does not work"
    /// can be told apart from one Dictus was never offered (#620 format audit). The
    /// line names the reason, what the bytes were and what the sender called them —
    /// never anything of the file's content.
    private static func reject(_ failure: DropFailure, reason: String, detected: SharedAudioFormat?,
                               type: String?) -> Result<VoiceNoteDrop, DropFailure> {
        PersistentLog.log(.diagnosticProbe(
            component: "VoiceNoteShare", instanceID: "extension", action: "rejected",
            details: "reason=\(reason) detected=\(detected?.rawValue ?? "none") type=\(type ?? "none")"
        ))
        return .failure(failure)
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNoteShare", instanceID: "extension", action: action, details: details))
    }
}
