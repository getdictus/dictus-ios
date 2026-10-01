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
/// It copies the shared audio into the App Group inbox and tells DictusApp. That is
/// all. It never decodes or transcribes: the speech models live in DictusApp's own
/// containers (#620 spike, finding 2), and a share extension's memory budget would
/// not hold one anyway.
///
/// When DictusApp is not alive to take the note (#620's cold path), the extension
/// opens it on the note — see `openDictus(on:)` for how, and for the risk that way
/// carries. If opening fails, it says "Open Dictus, your voice note is waiting".
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
                // short enough to feel like the island took it (decision 6).
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                finish()
            } else if case .waitingForApp = model.state {
                // The cold path: open Dictus on the note. The "waiting" screen already
                // on display stays as the fallback when opening fails.
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
    /// Nobody answered: the note waits for the app to open (#620's cold path).
    case waitingForApp(count: Int)
    /// Refused, with the sentence to show.
    case refused(String)
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
        if case .transcribing = state { return true }
        return false
    }

    func receive(_ providers: [NSItemProvider]) async {
        switch VoiceNoteAvailability.shareDecision {
        case .accept:
            break
        case .refuseNeedsPro:
            state = .refused(String(localized: "Transcribing voice notes is part of Dictus Pro. Open Dictus to find out more.",
                                    comment: "Share extension: the user has no Pro entitlement and the paywall is visible (#620)."))
            return
        case .refuseUnavailable:
            state = .refused(String(localized: "Transcribing voice notes is not available in this version of Dictus.",
                                    comment: "Share extension: no entitlement, and the paywall is hidden so no subscription may be named (#620, #236)."))
            return
        }
        guard let storage = VoiceNoteStorage.appGroup else {
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
        } else {
            state = .waitingForApp(count: drops.count)
        }
        log(taken ? "warm" : "cold", "count=\(drops.count)")
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
                                     UTType.mpeg.identifier]

    static func audioTypeIdentifier(of provider: NSItemProvider) -> String? {
        for identifier in provider.registeredTypeIdentifiers {
            guard let type = UTType(identifier) else { continue }
            if audioTypes.contains(identifier) || type.conforms(to: .audio) { return identifier }
        }
        return nil
    }

    private static func drop(_ provider: NSItemProvider, storage: VoiceNoteStorage) async -> Result<VoiceNoteDrop, DropFailure> {
        guard let identifier = audioTypeIdentifier(of: provider) else { return .failure(.notAudio) }
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
        guard let local else { return .failure(.unreadable) }
        defer { try? FileManager.default.removeItem(at: local) }

        // The bytes decide, not the type the sender declared: a `.mpg` film sniffs as
        // nothing (an MPEG program stream), and an MPEG-4 file that turns out to hold
        // a picture is a video, whatever it was shared as.
        guard let format = SharedAudioFormat.sniff(contentsOf: local) else { return .failure(.notAudio) }
        if format == .mpeg4, await SharedAudioDecoder.hasVideoTrack(local) { return .failure(.notAudio) }
        // Refused here when the container states its length, so a forty-minute
        // podcast is never copied into the App Group only to fail in the app.
        let duration = await SharedAudioDecoder.probeDuration(of: local, format: format)
        if let duration, SharedAudioDecoder.exceedsCap(duration) { return .failure(.tooLong) }
        do {
            let drop = try VoiceNoteInbox.drop(copying: local, format: format,
                                               durationSeconds: duration.map { Int($0.rounded()) }, storage: storage)
            return .success(drop)
        } catch {
            return .failure(.unreadable)
        }
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNoteShare", instanceID: "extension", action: action, details: details))
    }
}
