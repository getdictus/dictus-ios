// DictusApp/Audio/AppleSpeechEngine.swift
// "Apple (on-device)" as an engine of the app's own dictation path (Pierre, 2026-11-21).
import DictusCore
import Foundation
import Speech

/// Apple's on-device recognizer, as one of the app's engines.
///
/// WHY AN ADAPTER and not a second implementation: in-keyboard dictation (#992) already
/// transcribes with Apple's `SpeechAnalyzer` + `SpeechTranscriber` behind the
/// `OnDeviceRecognizer` protocol, and the share extension uses the same one. This class
/// only reshapes the app's recording (Float32 samples) into that protocol's 16 kHz PCM,
/// so the three places that use Apple's recognizer run one copy of it. Everything after
/// `transcribe` (vocabulary, polish, Smart Modes, History) is the app's usual pipeline:
/// `TranscriptionService` does not know which engine answered.
///
/// Nothing to prepare and nothing to warm: the model is Apple's, installed by iOS
/// (`AppleEngineAssets`), and runs in Apple's speech daemon, not on Dictus's Core ML
/// cache. That is also why picking it never shows the model preparation screen.
final class AppleSpeechEngine: SpeechModelProtocol {
    let engineName: String
    private let recognizer: OnDeviceRecognizer
    /// The dictation language Apple was found ready for when the engine was chosen.
    let languageCode: String

    @MainActor
    init(recognizer: OnDeviceRecognizer, languageCode: String) {
        self.recognizer = recognizer
        self.languageCode = languageCode
        self.engineName = recognizer.engineName
    }

    var isReady: Bool { true }

    func prepare(modelIdentifier: String) async throws {}

    /// No Neural Engine specialization of Dictus's to pay (#426): Apple's daemon owns it.
    func runWarmInference() async throws {}

    func transcribe(audioSamples: [Float], language: String?) async throws -> SpeechTranscription {
        guard !audioSamples.isEmpty else { throw TranscriptionError.emptyAudio }
        // The policy resolves the chosen language; the engine's own is the fallback for a
        // policy that has none (automatic detection, which makes Apple unavailable anyway).
        let code = language ?? languageCode
        var recording = OnDeviceRecording(samples: audioSamples)
        #if DEBUG && targetEnvironment(simulator)
        if let file = Self.debugTestRecording() { recording = file }
        #endif
        do {
            let text = try await recognizer.transcribe(recording, languageCode: code,
                                                       contextualStrings: Self.vocabularyTerms())
            return SpeechTranscription(text: text, confidence: nil, language: code)
        } catch OnDeviceRecognizerError.empty {
            throw TranscriptionError.noSpeechDetected(context: "empty Apple transcription")
        } catch {
            throw TranscriptionError.transcriptionFailed(LoggedError.domainAndCode(error))
        }
    }

    /// The user's Pro vocabulary terms as recognition hints, as the keyboard offers them.
    /// The vocabulary pass on the text runs afterwards either way.
    private static func vocabularyTerms() -> [String] {
        guard VocabularyAvailability.isEntitled else { return [] }
        return VocabularyStore.loadEntries().filter(\.isEnabled).map(\.term)
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Simulator test harness, compiled out of every device and Release build: a 16 kHz
    /// mono Int16 WAV at the App Group root (`app-test-audio.wav`) replaces what the
    /// simulator recorded, whose microphone is the Mac's room. The same idea as the
    /// keyboard's `in-keyboard-test-audio.wav` (#992).
    private static func debugTestRecording() -> OnDeviceRecording? {
        guard let url = AppGroup.containerURL?.appendingPathComponent("app-test-audio.wav"),
              let data = try? Data(contentsOf: url),
              let marker = data.range(of: Data("data".utf8)),
              data.count > marker.upperBound + 4 else { return nil }
        let pcm = data.subdata(in: (marker.upperBound + 4)..<data.count)
        PersistentLog.log(.diagnosticProbe(component: "AppleSpeechEngine", instanceID: "debug",
                                           action: "debugTestAudio", details: "bytes=\(pcm.count)"))
        return OnDeviceRecording(pcm16: pcm)
    }
    #endif
}

/// Where Apple's engine stands for the chosen dictation language, and its install.
///
/// The rule itself is `AppleEngineAvailability` (DictusCore, tested); this reads its three
/// inputs on the device: the iOS version, Apple's `supportedLocales`, and whether the
/// model for the resolved locale is installed.
@MainActor
enum AppleEngineAssets {
    static func availability() async -> AppleEngineAvailability {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let mode = TranscriptionLanguageMode.active
        let keyboard = SupportedLanguage.active.rawValue
        guard #available(iOS 26.0, *) else {
            return AppleEngineAvailability.evaluate(systemMajorVersion: major, mode: mode, keyboardLanguageCode: keyboard,
                                                    supportedLocales: [], assetState: .unknown)
        }
        // The same list as in-keyboard dictation's eligibility (#992): `SpeechTranscriber`'s,
        // or `DictationTranscriber`'s where the former reports itself unavailable (older
        // hardware, and every iOS Simulator), which is the module the recognizer then runs.
        let locales = SpeechTranscriber.isAvailable
            ? await SpeechTranscriber.supportedLocales
            : await DictationTranscriber.supportedLocales
        let identifiers = locales.map { $0.identifier(.bcp47) }
        var asset = AppleEngineAssetState.unknown
        if let code = InKeyboardDictationRoute.dictationLanguageCode(mode: mode, keyboardLanguageCode: keyboard),
           InKeyboardDictationRoute.isLanguageCovered(code, bySupportedLocales: identifiers),
           let recognizer = OnDeviceRecognizerFactory.make() {
            asset = await recognizer.hasModelInstalled(languageCode: code) ? .installed : .notInstalled
        }
        let result = AppleEngineAvailability.evaluate(systemMajorVersion: major, mode: mode, keyboardLanguageCode: keyboard,
                                                      supportedLocales: identifiers, assetState: asset)
        log("availability", "result=\(result) mode=\(mode.telemetryDescription) keyboard=\(keyboard) "
            + "supportedCount=\(identifiers.count) speechTranscriberAvailable=\(SpeechTranscriber.isAvailable)")
        return result
    }

    /// The engine a dictation runs now, from the stored choice and a fresh availability.
    static func effectiveEngine() async -> EffectiveSpeechEngine {
        let choice = SpeechEngineChoice.read(from: AppGroup.defaults)
        guard choice == .apple else { return .downloadedModel }
        let resolved = EffectiveSpeechEngine.resolve(choice: choice, availability: await availability())
        if resolved == .downloadedModel { log("fallback", "choice=apple reason=notReady") }
        return resolved
    }

    /// Ask iOS for Apple's model for `languageCode`: reserve the locale, then download and
    /// install it, reporting `AssetInventory`'s progress. A model download from Apple, the
    /// one Dictus never makes itself; transcription stays on the device.
    static func install(languageCode: String, onProgress: @escaping @MainActor (Double?) -> Void) async throws {
        guard #available(iOS 26.0, *) else { throw OnDeviceRecognizerError.unavailable }
        let requested = Locale(identifier: InKeyboardDictationRoute.speechLocaleIdentifier(
            languageCode: languageCode, deviceLocaleIdentifier: Locale.current.identifier))
        let module: any SpeechModule
        let locale: Locale
        if SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
            module = SpeechTranscriber(locale: supported, preset: .transcription)
            locale = supported
        } else if let supported = await DictationTranscriber.supportedLocale(equivalentTo: requested) {
            module = DictationTranscriber(locale: supported, preset: .longDictation)
            locale = supported
        } else {
            throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
        }
        // iOS installs nothing for a locale the app holds no reservation on ("not
        // subscribed to assistant.<locale>", measured in #992).
        let reserved = try await AssetInventory.reserve(locale: locale)
        log("reserve", "locale=\(locale.identifier) reserved=\(reserved)")
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
            log("install", "locale=\(locale.identifier) request=none (already installed)")
            return
        }
        onProgress(nil)
        let progress = request.progress
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                onProgress(progress.totalUnitCount > 0 ? progress.fractionCompleted : nil)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
        defer { watcher.cancel() }
        log("install", "locale=\(locale.identifier) step=downloading")
        try await request.downloadAndInstall()
        log("install", "locale=\(locale.identifier) step=done status=\(await AssetInventory.status(forModules: [module]))")
    }

    static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "AppleEngine", instanceID: "app", action: action, details: details))
    }
}
