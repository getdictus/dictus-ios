// DictusApp/Views/InKeyboardSpeechAssets.swift
import DictusCore
import Foundation
import Speech
import UIKit

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
        guard #available(iOS 26.0, *) else {
            AppGroup.defaults.set(InKeyboardLanguageEligibility.speechTranscriberUnavailable.storedValue,
                                  forKey: SharedKeys.inKeyboardLanguageEligibility)
            return
        }
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
            _ = await refreshLanguageEligibility(reason: reason)
            for locale in locales { await install(languageCode: locale) }
        }
    }

    /// Whether Apple covers the chosen dictation language, read from
    /// `SpeechTranscriber.supportedLocales`, and stored in the App Group for the "How
    /// dictation works" line. Without `SpeechTranscriber` (`isAvailable == false`) nothing
    /// is covered: no fallback to `DictationTranscriber` (Pierre, 2026-11-21).
    /// Activation follows the language the user chose, never the one they speak
    /// (Pierre, 2026-11-21). Called by Settings whenever either language changes.
    @available(iOS 26.0, *)
    static func refreshLanguageEligibility(reason: String) async -> InKeyboardLanguageEligibility {
        let available = SpeechTranscriber.isAvailable
        let locales = available ? await SpeechTranscriber.supportedLocales : []
        let eligibility = InKeyboardLanguageEligibility.evaluate(
            mode: TranscriptionLanguageMode.active,
            keyboardLanguageCode: SupportedLanguage.active.rawValue,
            speechTranscriberAvailable: available,
            supportedLocales: locales.map { $0.identifier(.bcp47) }
        )
        AppGroup.defaults.set(eligibility.storedValue, forKey: SharedKeys.inKeyboardLanguageEligibility)
        log("eligibility", "reason=\(reason) result=\(eligibility) speechTranscriberAvailable=\(available) supportedCount=\(locales.count) "
            + "userChoice=\(InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults))")
        return eligibility
    }

    /// The app's side of `DictationSessionClaim`, for the keyboard's Darwin start post.
    /// False: the app cannot record this start (`answer` declines, and then nothing is
    /// claimed, so the keyboard takes the session), or the keyboard took this session
    /// after its 500 ms window, so the app must not record it too.
    @MainActor
    static func appMayStartKeyboardSession(for coordinator: DictationCoordinator) -> Bool {
        let answer = keyboardStartAnswer(for: coordinator)
        let directory = DictationSessionClaim.defaultDirectory
        let mayStart = DictationSessionClaim.appMayStart(defaults: AppGroup.defaults, directory: directory, answer: answer)
        let session = AppGroup.defaults.string(forKey: SharedKeys.dictationSessionRequest) ?? "none"
        log("sessionClaim", "session=\(session) side=app mayStart=\(mayStart) answer=\(answer.logValue)")
        return mayStart
    }

    /// Answer the keyboard's `inKeyboardPing` while this process runs (#992 round 4):
    /// `inKeyboardPong` when it would record a start now, `inKeyboardPongDeclined` when it
    /// runs but would not (round 2, device 2026-11-23 13:38:56: an app alive with its
    /// engine stopped answered "here", so the keyboard kept its microphone closed, and
    /// then the app did not record). Registered once, at launch.
    static func startAnsweringKeyboardPings(answer: @escaping @MainActor () -> AppKeyboardStartAnswer) {
        DarwinNotificationCenter.addObserver(for: DarwinNotificationName.inKeyboardPing) {
            // Darwin callbacks arrive on the main thread; the hop is only a fallback, and
            // costs a run-loop turn a ping cannot afford in the common case.
            let reply = {
                MainActor.assumeIsolated {
                    let decided = answer()
                    let stamp = DictationStartTable.PingAnswerStamp(answer: decided.willRecord ? .willRecord : .declined,
                                                                    answeredAt: Date())
                    AppGroup.defaults.set(stamp.storedValue, forKey: SharedKeys.inKeyboardPingAnswer)
                    AppGroup.defaults.synchronize()
                    DarwinNotificationCenter.post(decided.willRecord
                        ? DarwinNotificationName.inKeyboardPong
                        : DarwinNotificationName.inKeyboardPongDeclined)
                    if !decided.willRecord { log("pingAnswered", "answer=\(decided.logValue)") }
                }
            }
            if Thread.isMainThread { reply() } else { DispatchQueue.main.async(execute: reply) }
        }
    }

    /// What `coordinator` would do with a keyboard's Darwin start right now: the
    /// questions `startDictation` asks before it records, asked before the session is
    /// claimed and when the keyboard pings (#992 round 2).
    @MainActor
    static func keyboardStartAnswer(for coordinator: DictationCoordinator) -> AppKeyboardStartAnswer {
        let defaults = AppGroup.defaults
        defaults.synchronize()
        let rawLoadState = defaults.string(forKey: SharedKeys.modelLoadState) ?? ""
        return AppKeyboardStartAnswer.decide(.init(
            appIsActive: UIApplication.shared.applicationState == .active,
            engineRunning: coordinator.isAudioEngineRunning,
            dictationStatus: coordinator.status,
            onboardingCompleted: KeyboardOnboardingGate.isOnboardingCompleted(in: defaults),
            isModelDownloaded: defaults.bool(forKey: SharedKeys.modelReady),
            loadState: ModelLoadState(rawValue: rawLoadState) ?? .idle,
            isModelWarm: ModelWarmth.isActiveModelWarm(defaults: defaults, systemVersion: UIDevice.current.systemVersion)
        ))
    }

    /// Old session claims, once per launch.
    static func pruneSessionClaims() {
        guard let directory = DictationSessionClaim.defaultDirectory else { return }
        DictationSessionClaim.prune(in: directory)
    }

    /// The same module as the keyboard's `AppleSpeechRecognizer`: `SpeechTranscriber`
    /// only, and nothing where it is unavailable.
    @available(iOS 26.0, *)
    private static func install(languageCode: String) async {
        // Already a regional identifier (`speechLocalesToReserve`), e.g. "fr-FR".
        let requested = Locale(identifier: languageCode)
        guard SpeechTranscriber.isAvailable else {
            log("unsupported", "lang=\(languageCode) speechTranscriberAvailable=false")
            return
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            log("unsupported", "lang=\(languageCode) speechTranscriberAvailable=true")
            return
        }
        let module = SpeechTranscriber(locale: locale, preset: .transcription)
        let name = "speechtranscriber-\(locale.identifier)"
        let before = await AssetInventory.status(forModules: [module])
        let installed = await SpeechTranscriber.installedLocales.map(\.identifier).sorted()
        log("status", "module=\(name) status=\(before) installedLocales=\(installed) reserved=\(await AssetInventory.reservedLocales.map(\.identifier))")
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
