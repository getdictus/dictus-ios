// DictusApp/VoiceNotes/VoiceNoteModelCompile.swift
// Compiles the downloaded model a voice note wanted, once nobody is waiting (#1084, PR 2).
import DictusCore
import UIKit

/// The compile a voice note asked for when its downloaded model was cold
/// (`VoiceNoteEngineChoice.Decision.compilesDownloadedModel`).
///
/// That note went to Apple's model. This runs the compile later, only when
/// `VoiceNoteModelCompileGate` allows it: the app in the foreground, no dictation, no
/// keyboard-launched one pending, no note transcribing. Checked when the app becomes active
/// (the moment `warmUpEngineOnForeground` loads a model nobody asked for) and when the
/// queue drains, each time after a short settle, because a keyboard cold start becomes
/// active before its dictation state is written. Once it finishes the model is warm and the
/// next note reads it. A refused or failed compile stays scheduled for the next activation.
///
/// In memory only: a process that dies with a compile scheduled forgets it, and the next
/// cold note schedules it again.
@MainActor
final class VoiceNoteModelCompile {
    static let shared = VoiceNoteModelCompile()

    private var scheduledModel: String?
    private var isCompiling = false
    private var activationObserver: NSObjectProtocol?

    /// How long after an activation (or the queue draining) the gate is read.
    private static let settleNanoseconds: UInt64 = 2_000_000_000

    private init() {}

    func schedule(model: String) {
        if activationObserver == nil {
            activationObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                Task { @MainActor in VoiceNoteModelCompile.shared.runSoon(context: "didBecomeActive") }
            }
        }
        guard scheduledModel != model else { return }
        scheduledModel = model
        log("scheduled", "model=\(model)")
    }

    /// Read the gate after the settle, and compile if it allows.
    func runSoon(context: String) {
        guard scheduledModel != nil else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.settleNanoseconds)
            await runIfAllowed(context: context)
        }
    }

    private func runIfAllowed(context: String) async {
        guard !isCompiling, let model = scheduledModel else { return }
        let coordinator = DictationCoordinator.shared
        if let refusal = VoiceNoteModelCompileGate.refusal(
            scheduled: true,
            appIsActive: UIApplication.shared.applicationState == .active,
            dictationStatus: coordinator.status,
            keyboardDictationPending: coordinator.pendingColdStartDictation,
            voiceNoteRunning: VoiceNoteProcessor.shared.isRunning
        ) {
            log("deferred", "context=\(context) model=\(model) reason=\(refusal.rawValue)")
            return
        }
        isCompiling = true
        defer { isCompiling = false }
        let started = Date()
        log("started", "context=\(context) model=\(model)")
        do {
            try await coordinator.compileDownloadedModelAside(model)
            scheduledModel = nil
            log("finished", "model=\(model) ms=\(Int(Date().timeIntervalSince(started) * 1000)) warm=\(VoiceNoteModelWarmth.isWarm(model))")
        } catch {
            log("failed", "model=\(model) error=\(DictationFailureMessage.diagnostic(for: error))")
        }
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "compile", action: action, details: details))
    }
}

/// `ModelWarmth.isWarm` for this install, read the way the preparation screen reads it.
enum VoiceNoteModelWarmth {
    @MainActor
    static func isWarm(_ model: String) -> Bool {
        ModelWarmth.isWarm(model, identity: ModelWarmth.installIdentity(
            bundlePathComponents: Bundle.main.bundleURL.pathComponents,
            systemVersion: UIDevice.current.systemVersion
        ))
    }
}
