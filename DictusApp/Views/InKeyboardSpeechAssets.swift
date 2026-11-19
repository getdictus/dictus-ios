// DictusApp/Views/InKeyboardSpeechAssets.swift
import DictusCore
import Foundation
import Speech

/// Installs Apple's on-device speech model for in-keyboard dictation (spike).
///
/// WHY the app and not the keyboard: a download is a long, network-bound job the
/// keyboard has no business starting from a mic tap. The keyboard only reads the asset
/// status (`AssetInventory.status`) and falls back to opening the app when the model is
/// missing. This is a model download from Apple; transcription itself never leaves the
/// device.
enum InKeyboardSpeechAssets {
    static func prepareForDictationLanguage() {
        guard #available(iOS 26.0, *) else { return }
        let keyboard = SupportedLanguage.active.rawValue
        let code = TranscriptionLanguageMode.active.resolvedLanguageCode(keyboardLanguageCode: keyboard) ?? keyboard
        Task.detached(priority: .utility) { await install(languageCode: code) }
    }

    /// The same module choice as the keyboard's `AppleSpeechRecognizer`:
    /// `SpeechTranscriber` where available, `DictationTranscriber` otherwise.
    @available(iOS 26.0, *)
    private static func install(languageCode: String) async {
        let requested = Locale(identifier: InKeyboardDictationRoute.speechLocaleIdentifier(
            languageCode: languageCode,
            deviceLocaleIdentifier: Locale.current.identifier
        ))
        let module: any SpeechModule
        let locale: Locale
        let name: String
        if SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
            module = SpeechTranscriber(locale: supported, preset: .transcription)
            locale = supported
            name = "speechtranscriber-\(supported.identifier)"
        } else if let supported = await DictationTranscriber.supportedLocale(equivalentTo: requested) {
            module = DictationTranscriber(locale: supported, preset: .longDictation)
            locale = supported
            name = "dictationtranscriber-\(supported.identifier)"
        } else {
            log("unsupported", "lang=\(languageCode) speechTranscriberAvailable=\(SpeechTranscriber.isAvailable)")
            return
        }
        let before = await AssetInventory.status(forModules: [module])
        log("status", "module=\(name) status=\(before)")
        guard before != .installed else { return }
        do {
            // The app has to hold a reservation on the locale before iOS installs its
            // assets ("not subscribed to assistant.<locale>" otherwise, measured on the
            // simulator).
            _ = try await AssetInventory.reserve(locale: locale)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                try await request.downloadAndInstall()
            }
            let after = await AssetInventory.status(forModules: [module])
            log("installed", "module=\(name) status=\(after)")
        } catch {
            log("installFailed", "module=\(name) error=\(error.localizedDescription)")
        }
    }

    private static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "InKeyboardSpeechAssets",
            instanceID: "app",
            action: action,
            details: details
        ))
    }
}
