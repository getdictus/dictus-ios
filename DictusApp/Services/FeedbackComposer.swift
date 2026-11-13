// DictusApp/Services/FeedbackComposer.swift
// Holds the feedback form for the app session and sends it (#565).
import DictusCore
import Foundation
import UIKit

/// The feedback form's state, outliving the sheet: closing and reopening it in
/// the same session keeps what the user typed, and a failed send keeps the exact
/// report so Retry and the share sheet send what the user saw.
@MainActor
final class FeedbackComposer: ObservableObject {
    static let shared = FeedbackComposer()

    enum Phase: Equatable {
        case editing, sending, failed(FeedbackFailure), sent
    }

    @Published var draft = FeedbackDraft()
    @Published private(set) var phase: Phase = .editing
    /// The `PersistentLog.exportContent()` text "See what will be sent" shows.
    /// Send attaches this same string, never a fresher read.
    @Published private(set) var logSnapshot: String?
    /// Set while a `429` holds Retry back; cleared when the wait is over, which
    /// re-enables Retry and Send on its own.
    @Published private(set) var retryWindow: FeedbackRetryWindow?
    /// The share sheet's items, prepared once per presentation so its log file
    /// can be deleted when it closes.
    @Published private(set) var shareItems: [Any]?
    private var shareDirectory: URL?

    let device = FeedbackDeviceInfo.current

    /// Reads the log when the sheet opens. A failed report keeps the log it was
    /// sent with, so the retry and the share sheet carry the text already shown.
    /// The old snapshot is dropped first, so Send waits for the new one, and a
    /// read that finishes after Send was tapped is discarded.
    func sheetDidAppear() async {
        guard phase == .editing else { return }
        logSnapshot = nil
        let content = await Task.detached(priority: .userInitiated) { PersistentLog.exportContent() }.value
        guard phase == .editing else { return }
        logSnapshot = content
    }

    /// Send waits for the log read, so a report never leaves without the log
    /// the user chose to attach.
    var canSend: Bool {
        phase != .sending && retryWindow == nil && draft.problems.isEmpty && (!draft.attachesLog || logSnapshot != nil)
    }

    func send() async {
        guard canSend,
              let payload = FeedbackPayload(draft: draft, device: device, log: logSnapshot) else { return }
        phase = .sending
        let outcome = await FeedbackClient(endpoint: Self.endpoint).send(payload)
        switch outcome {
        case .delivered:
            phase = .sent
        case .failed(let failure):
            phase = .failed(failure)
            holdRetry(after: failure)
        }
        PersistentLog.log(.diagnosticProbe(component: "feedback", instanceID: payload.type,
                                           action: outcome == .delivered ? "delivered" : "failed",
                                           details: "failure=\(Self.logName(outcome)) log=\(payload.log != nil)"))
    }

    /// After the confirmation: an empty form, with the name and email kept for
    /// the next report.
    func startOver() {
        let kept = draft
        draft = FeedbackDraft()
        draft.name = kept.name
        draft.email = kept.email
        logSnapshot = nil
        phase = .editing
    }

    /// Keeps Retry and Send disabled until the window opens, then publishes the change.
    private func holdRetry(after failure: FeedbackFailure) {
        guard let window = FeedbackRetryWindow(failure: failure, failedAt: Date()), !window.isOpen(at: Date()) else {
            retryWindow = nil
            return
        }
        retryWindow = window
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(window.opensAt.timeIntervalSinceNow))
            guard let self, self.retryWindow == window else { return }
            self.retryWindow = nil
        }
    }

    /// The report as text, plus the log as a file when it is attached, for the
    /// share sheet offered when sending fails. The file sits in a folder of its
    /// own under the temporary directory, removed by `shareDidEnd()`.
    func prepareShare() {
        shareDidEnd()
        guard let payload = FeedbackPayload(draft: draft, device: device, log: logSnapshot) else {
            shareItems = [draft.message]
            return
        }
        var items: [Any] = [payload.shareText]
        if let log = payload.log {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let url = directory.appendingPathComponent("dictus-logs.txt")
            if (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil,
               (try? log.write(to: url, atomically: true, encoding: .utf8)) != nil {
                items.append(url)
                shareDirectory = directory
            }
        }
        shareItems = items
    }

    /// Deletes the shared log file. Called when the share sheet or the feedback
    /// sheet closes; a second call does nothing.
    func shareDidEnd() {
        if let shareDirectory { try? FileManager.default.removeItem(at: shareDirectory) }
        shareDirectory = nil
        shareItems = nil
    }

    private static func logName(_ outcome: FeedbackOutcome) -> String {
        switch outcome {
        case .delivered: return "none"
        case .failed(.unreachable): return "unreachable"
        case .failed(.rateLimited): return "rateLimited"
        case .failed(.deliveryFailed): return "deliveryFailed"
        case .failed(.unavailable): return "unavailable"
        case .failed(.rejected(let status)): return "rejected-\(status)"
        }
    }

    /// The website route. A Debug build can point it at a local stub or a Vercel
    /// preview with `-DictusFeedbackEndpoint <url>` on the launch command line;
    /// Release has no override.
    private static var endpoint: URL {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "DictusFeedbackEndpoint"),
           let url = URL(string: override) {
            return url
        }
        #endif
        return FeedbackClient.productionEndpoint
    }
}

extension FeedbackDeviceInfo {
    @MainActor static var current: FeedbackDeviceInfo {
        let info = Bundle.main.infoDictionary
        return FeedbackDeviceInfo(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "",
            build: info?["CFBundleVersion"] as? String ?? "",
            gitRevision: PersistentLog.codeRevision,
            iosVersion: UIDevice.current.systemVersion,
            deviceModel: hardwareIdentifier,
            locale: Locale.current.identifier
        )
    }

    /// "iPhone16,1" rather than `UIDevice.model`'s "iPhone". A simulator's own
    /// `uname` answers "arm64", so it reports the device it simulates.
    private static var hardwareIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? ""
        }
    }
}
