// DictusApp/VoiceNotes/VoiceNoteSpeechAssets.swift
// Reserves Apple's on-device speech model for shared voice notes, ahead of time (#1056).
import DictusCore
import Foundation
import Speech

/// Reserves and installs Apple's speech model for the voice-note language, at launch and
/// whenever that language changes, so the share extension finds it ready with the app
/// closed (#1056, PR 3).
///
/// WHY the app and not the extension: a download is a long, network-bound job, and a
/// share sheet lasts seconds. The rule is `VoiceNoteSpeechAssetPlan` (DictusCore,
/// tested), the "when" is `VoiceNoteSpeechAssetTrigger`; this reads their inputs on the
/// device and runs the install the Models screen already uses
/// (`AppleEngineAssets.install`, #1036). Always on, no setting (Pierre, 2026-11-25).
/// The model comes from Apple; nothing Dictus records is sent anywhere.
@MainActor
enum VoiceNoteSpeechAssets {

    private static var trigger = VoiceNoteSpeechAssetTrigger()

    /// Run the plan if this is the process's first check or its inputs moved.
    ///
    /// - Parameter context: the call site, for the log (`launch`, `didBecomeActive`,
    ///   `voiceNoteSettings`, `keyboardSettings`). The reason (`launch`,
    ///   `languageChanged`, `entitlementChanged`) comes from the trigger.
    static func refresh(context: String) {
        let voiceNoteLanguage = VoiceNoteSettings.load().language
        let keyboardLanguage = SupportedLanguage.active
        let requested = VoiceNoteSpeechAssetPlan.requestedLanguage(voiceNoteLanguage: voiceNoteLanguage,
                                                                   keyboardLanguage: keyboardLanguage)
        let isEntitled = VoiceNoteAvailability.isEntitled
        guard let reason = trigger.reason(for: .init(languageCode: requested.code, isEntitled: isEntitled)) else {
            return
        }
        Task { @MainActor in
            await prepare(reason: reason, context: context, voiceNoteLanguage: voiceNoteLanguage,
                          keyboardLanguage: keyboardLanguage, isEntitled: isEntitled)
        }
    }

    private static func prepare(reason: VoiceNoteSpeechAssetTrigger.Reason, context: String,
                                voiceNoteLanguage: VoiceNoteLanguage, keyboardLanguage: SupportedLanguage,
                                isEntitled: Bool) async {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        var available = false
        var locales: [String] = []
        if #available(iOS 26.0, *) {
            // `SpeechTranscriber` itself, not `OnDeviceRecognizerFactory`: the factory's
            // simulator harness answers for the Mac's model, and the share extension
            // will need a model on THIS device.
            available = SpeechTranscriber.isAvailable
            if available { locales = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) } }
        }
        let plan = VoiceNoteSpeechAssetPlan.evaluate(voiceNoteLanguage: voiceNoteLanguage,
                                                     keyboardLanguage: keyboardLanguage,
                                                     isEntitled: isEntitled,
                                                     system: .init(majorVersion: major,
                                                                   speechTranscriberAvailable: available,
                                                                   supportedLocales: locales))
        let header = "reason=\(reason.rawValue) trigger=\(context) voiceNoteLanguage=\(voiceNoteLanguage.logValue) "
            + "keyboard=\(keyboardLanguage.rawValue)"
        guard case .reserve(let code, let source) = plan else {
            log("skipped", "\(header) plan=\(plan.logValue) ios=\(major) speechTranscriberAvailable=\(available) "
                + "supportedCount=\(locales.count)")
            return
        }
        guard #available(iOS 26.0, *) else { return }
        let detail = "\(header) language=\(code) source=\(source.rawValue)"
        let installed = await AppleSpeechRecognizer().hasModelInstalled(languageCode: code)
        log("status", "\(detail) installed=\(installed)")
        // Run even when installed: `reserve` keeps this app's reservation, which is what
        // keeps the model on the device, and a model already there costs one
        // `AssetInventory` question (no request, nothing downloaded).
        log("installStart", detail)
        do {
            try await AppleEngineAssets.install(languageCode: code) { _ in }
            log("installDone", detail)
        } catch {
            log("installFailed", "\(detail) error=\(error.localizedDescription)")
        }
    }

    private static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNoteSpeechAssets", instanceID: "app",
                                           action: action, details: details))
    }
}

private extension VoiceNoteLanguage {
    var logValue: String {
        switch self {
        case .autoDetect: return "auto"
        case .fixed(let language): return language.rawValue
        }
    }
}

private extension VoiceNoteSpeechAssetPlan {
    var logValue: String {
        switch self {
        case .reserve(let code, let source): return "reserve(\(code),\(source.rawValue))"
        case .skip(.notEntitled): return "notEntitled"
        case .skip(.systemTooOld): return "systemTooOld"
        case .skip(.speechTranscriberUnavailable): return "speechTranscriberUnavailable"
        case .skip(.languageNotCovered(let code)): return "languageNotCovered(\(code))"
        }
    }
}
