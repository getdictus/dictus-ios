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
    /// Reserve and install the speech model(s) the keyboard will use, so its first cold
    /// tap does not fall back to the app. Called at each launch, when onboarding confirms
    /// the language, and when the setting is turned on. Nothing happens with the setting
    /// off or before iOS 26.
    static func prepareForDictationLanguage(reason: String = "setting") {
        guard #available(iOS 26.0, *) else { return }
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults) else {
            log("skipped", "reason=\(reason) setting=off")
            return
        }
        let locales = InKeyboardDictationRoute.speechLocalesToReserve(
            transcriptionMode: TranscriptionLanguageMode.active,
            keyboardLanguageCode: SupportedLanguage.active.rawValue,
            deviceLocaleIdentifier: Locale.current.identifier
        )
        log("prepare", "reason=\(reason) locales=\(locales)")
        Task.detached(priority: .utility) {
            for locale in locales { await install(languageCode: locale) }
        }
    }

    /// The app's side of `DictationSessionClaim`, for the keyboard's Darwin start post.
    /// False: the keyboard took this session after its 500 ms window, so the app must not
    /// record it too.
    static func appMayStartKeyboardSession() -> Bool {
        let directory = DictationSessionClaim.defaultDirectory
        let mayStart = DictationSessionClaim.appMayStart(defaults: AppGroup.defaults, directory: directory)
        let session = AppGroup.defaults.string(forKey: SharedKeys.dictationSessionRequest) ?? "none"
        log("sessionClaim", "session=\(session) side=app mayStart=\(mayStart)")
        return mayStart
    }

    /// Old session claims, once per launch.
    static func pruneSessionClaims() {
        guard let directory = DictationSessionClaim.defaultDirectory else { return }
        DictationSessionClaim.prune(in: directory)
    }

    /// The same module choice as the keyboard's `AppleSpeechRecognizer`:
    /// `SpeechTranscriber` where available, `DictationTranscriber` otherwise.
    @available(iOS 26.0, *)
    private static func install(languageCode: String) async {
        // Already a regional identifier (`speechLocalesToReserve`), e.g. "fr-FR".
        let requested = Locale(identifier: languageCode)
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
        let installed = await DictationTranscriber.installedLocales.map(\.identifier).sorted()
        log("status", "module=\(name) status=\(before) dictationInstalled=\(installed) reserved=\(await AssetInventory.reservedLocales.map(\.identifier))")
        guard before != .installed else { return }
        do {
            // The app has to hold a reservation on the locale before iOS installs its
            // assets ("not subscribed to assistant.<locale>" otherwise, measured on the
            // simulator).
            let reserved = try await AssetInventory.reserve(locale: locale)
            log("reserve", "locale=\(locale.identifier) reserved=\(reserved) max=\(AssetInventory.maximumReservedLocales)")
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
