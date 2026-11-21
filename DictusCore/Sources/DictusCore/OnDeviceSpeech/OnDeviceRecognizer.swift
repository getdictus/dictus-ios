// DictusCore/OnDeviceSpeech/OnDeviceRecognizer.swift
// Moved from DictusKeyboard (#992): the keyboard and the share extension both transcribe
// on the device with it, from one copy.
import AVFAudio
import Foundation
import Speech

/// A finished in-keyboard recording: 16 kHz mono Int16 little-endian PCM.
public struct OnDeviceRecording: Sendable {
    public static let sampleRate: Double = 16_000
    public var pcm16 = Data()

    public init(pcm16: Data = Data()) { self.pcm16 = pcm16 }

    /// From the app's Float32 samples at 16 kHz (`UnifiedAudioEngine`), clipped to
    /// [-1, 1]: the shape the app's own dictation path records in.
    public init(samples: [Float]) {
        var data = Data(count: samples.count * 2)
        data.withUnsafeMutableBytes { raw in
            let out = raw.bindMemory(to: Int16.self)
            for index in samples.indices {
                out[index] = Int16(max(-1, min(1, samples[index])) * 32_767).littleEndian
            }
        }
        self.pcm16 = data
    }

    public var seconds: Double { Double(pcm16.count / 2) / Self.sampleRate }
}

/// The speech-to-text engine behind in-keyboard dictation (spike).
///
/// WHY a protocol: two engines are planned and they live in different places. Apple's
/// `SpeechTranscriber` runs in a system daemon and is what this spike ships. Parakeet
/// running in the same hidden web view (measured on another thread) would take the
/// same 16 kHz PCM and return the same string. The session that records and inserts
/// does not care which one answers.
@MainActor
public protocol OnDeviceRecognizer: AnyObject {
    /// Short name for the log.
    var engineName: String { get }

    /// Whether this engine can transcribe `languageCode` on the device right now, with
    /// nothing to download. Must never trigger a download or reach a server.
    func isReadyOnDevice(languageCode: String) async -> Bool

    /// Whether the model for `languageCode` is on the device, and nothing else: no
    /// reservation, no download. The app's Models screen asks this to draw the Apple
    /// card, where `isReadyOnDevice` would start an install from merely looking.
    func hasModelInstalled(languageCode: String) async -> Bool

    /// Transcribe a finished recording. Throws when nothing usable came back.
    /// `contextualStrings` are the user's Pro vocabulary terms, offered to the engine as
    /// recognition hints (empty when the user has none or is not entitled).
    func transcribe(_ recording: OnDeviceRecording, languageCode: String, contextualStrings: [String]) async throws -> String
}

public enum OnDeviceRecognizerError: LocalizedError {
    case unavailable
    case localeNotInstalled(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "recognizer unavailable on this OS"
        case .localeNotInstalled(let code): return "on-device model not installed for \(code)"
        case .empty: return "no speech recognized"
        }
    }
}

/// Picks the engine for this OS. Nil before iOS 26, where the experiment never runs.
@MainActor
public enum OnDeviceRecognizerFactory {
    public static func make() -> OnDeviceRecognizer? {
        #if DEBUG && targetEnvironment(simulator)
        // No iOS Simulator runtime ships a speech model (measured 2026-11-19 on 26.5 and
        // 27.2: `SpeechTranscriber.isAvailable == false`, no installed locale, and the
        // asset download refused). See `SimulatorHostRecognizer`.
        return SimulatorHostRecognizer()
        #else
        if #available(iOS 26.0, *) { return AppleSpeechRecognizer() }
        return nil
        #endif
    }
}

/// Apple's `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26+).
///
/// On-device only, by construction: the SpeechAnalyzer modules have no server mode
/// (unlike `SFSpeechRecognizer`, which this file deliberately does not use), and the asset
/// check below refuses any locale whose model is not already installed, so nothing is
/// ever downloaded from the keyboard. The model runs in Apple's speech daemon, not in
/// this process, which is why it fits beside the keyboard's ~68 MB ceiling (#555).
///
/// `SpeechTranscriber` is the module asked for. Where it reports itself unavailable
/// (`isAvailable == false`: older hardware, and the iOS Simulator, measured 2026-11-19 on
/// iOS 26.5), the same analyzer runs `DictationTranscriber`, Apple's on-device module for
/// devices without the new model. Same asset rule, same file input.
///
/// The batch shape (record, then transcribe a file) follows anomalyco/hex's
/// `KeyboardSpeech` (MIT License).
@available(iOS 26.0, *)
@MainActor
public final class AppleSpeechRecognizer: OnDeviceRecognizer {
    public init() {}

    public var engineName: String {
        SpeechTranscriber.isAvailable ? "apple-speechtranscriber" : "apple-dictationtranscriber"
    }

    public func isReadyOnDevice(languageCode: String) async -> Bool {
        guard let module = await Self.module(for: languageCode) else {
            OnDeviceSpeechLog.log("assetCheck", "lang=\(languageCode) supported=false speechTranscriberAvailable=\(SpeechTranscriber.isAvailable)")
            return false
        }
        if await Self.isInstalled(module) { return true }
        Self.provisionLocally(module)
        return false
    }

    public func hasModelInstalled(languageCode: String) async -> Bool {
        guard let module = await Self.module(for: languageCode) else { return false }
        return await Self.isInstalled(module)
    }

    /// The keyboard reserves the locale and asks iOS for the model itself, so a keyboard
    /// whose app was never opened since install does not depend on the app having done it.
    ///
    /// This tap still opens the app (the model is not there yet); the next one finds it
    /// once iOS has installed it. Reservations are per bundle, which is the point: the
    /// app's reservation of the same locale does not count for this one. Every step and
    /// its answer goes to the log, because whether an extension may reserve and download
    /// at all is what the device run has to tell.
    private static var provisioning: Set<String> = []

    private static func provisionLocally(_ module: Module) {
        let locale = module.locale
        guard !provisioning.contains(locale.identifier) else {
            OnDeviceSpeechLog.log("reserve", "locale=\(locale.identifier) skipped=already-in-flight")
            return
        }
        provisioning.insert(locale.identifier)
        Task {
            defer { provisioning.remove(locale.identifier) }
            let reservedBefore = await AssetInventory.reservedLocales.map(\.identifier)
            OnDeviceSpeechLog.log(
                "reserve",
                "locale=\(locale.identifier) reservedBefore=\(reservedBefore) max=\(AssetInventory.maximumReservedLocales)"
            )
            do {
                let reserved = try await AssetInventory.reserve(locale: locale)
                OnDeviceSpeechLog.log("reserve", "locale=\(locale.identifier) result=\(reserved)")
            } catch {
                OnDeviceSpeechLog.log("reserve", "locale=\(locale.identifier) error=\(error.localizedDescription)")
            }
            do {
                guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module.speechModule]) else {
                    OnDeviceSpeechLog.log("assetInstall", "locale=\(locale.identifier) request=none")
                    return
                }
                OnDeviceSpeechLog.log("assetInstall", "locale=\(locale.identifier) step=downloading")
                try await request.downloadAndInstall()
                let after = await AssetInventory.status(forModules: [module.speechModule])
                OnDeviceSpeechLog.log("assetInstall", "locale=\(locale.identifier) step=done status=\(after)")
            } catch {
                OnDeviceSpeechLog.log("assetInstall", "locale=\(locale.identifier) error=\(error.localizedDescription)")
            }
        }
    }

    /// Installed per `AssetInventory`, or present in the module's `installedLocales`.
    ///
    /// WHY both: `AssetInventory.status` answers for the calling bundle's reservation, and
    /// the keyboard is a different bundle from the app that reserved the locale. Measured
    /// on macOS 26 (2026-11-19) from a process with no reservation: `status` said
    /// `supported` while `installedLocales` listed `fr_FR`, and `SpeechAnalyzer`
    /// transcribed a French file in 150 ms. Both answers are about models on this device;
    /// neither downloads anything.
    private static func isInstalled(_ module: Module) async -> Bool {
        let status = await AssetInventory.status(forModules: [module.speechModule])
        let installed: [Locale]
        switch module {
        case .speech: installed = await SpeechTranscriber.installedLocales
        case .dictation: installed = await DictationTranscriber.installedLocales
        }
        let listed = installed.contains { $0.identifier(.bcp47) == module.locale.identifier(.bcp47) }
        let reserved = await AssetInventory.reservedLocales.contains { $0.identifier(.bcp47) == module.locale.identifier(.bcp47) }
        OnDeviceSpeechLog.log(
            "assetCheck",
            "module=\(module.name) locale=\(module.locale.identifier) status=\(status) inInstalledLocales=\(listed) reservedByKeyboard=\(reserved)"
        )
        return status == .installed || listed
    }

    public func transcribe(_ recording: OnDeviceRecording, languageCode: String, contextualStrings: [String]) async throws -> String {
        guard let module = await Self.module(for: languageCode) else {
            throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
        }
        // Checked again at the moment of use: the route decision may be a few seconds old.
        guard await Self.isInstalled(module) else {
            throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-keyboard-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.writeWAV(recording, to: url)

        let analyzer = SpeechAnalyzer(
            modules: [module.speechModule],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse)
        )
        let file = try AVAudioFile(forReading: url)
        await Self.offer(contextualStrings, to: analyzer, module: module)
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)

        var transcript = AttributedString()
        switch module {
        case .speech(let transcriber):
            for try await result in transcriber.results where result.isFinal { transcript += result.text }
        case .dictation(let transcriber):
            for try await result in transcriber.results where result.isFinal { transcript += result.text }
        }
        let text = String(transcript.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OnDeviceRecognizerError.empty }
        return text
    }

    /// Study (#80 follow-up): the vocabulary as `AnalysisContext.contextualStrings`.
    /// `setContext` is on `SpeechAnalyzer`, not on the module, so both transcribers get
    /// it. Whether it is *accepted* is logged here; whether it *changes* anything is read
    /// by comparing transcripts. Measured on macOS 26 (2026-11-20) with "Dictus" as the
    /// only string: accepted by both modules, and neither changed "dicttu" / "dictée".
    private static func offer(_ strings: [String], to analyzer: SpeechAnalyzer, module: Module) async {
        guard !strings.isEmpty else {
            OnDeviceSpeechLog.log("contextualStrings", "module=\(module.name) terms=0 offered=false")
            return
        }
        let context = AnalysisContext()
        context.contextualStrings[.general] = strings
        do {
            try await analyzer.setContext(context)
            OnDeviceSpeechLog.log("contextualStrings", "module=\(module.name) terms=\(strings.count) accepted=true")
        } catch {
            OnDeviceSpeechLog.log("contextualStrings", "module=\(module.name) terms=\(strings.count) accepted=false error=\(error.localizedDescription)")
        }
    }

    private enum Module {
        case speech(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var speechModule: any SpeechModule {
            switch self {
            case .speech(let transcriber): return transcriber
            case .dictation(let transcriber): return transcriber
            }
        }

        var locale: Locale {
            switch self {
            case .speech(let transcriber): return transcriber.selectedLocales.first ?? Locale.current
            case .dictation(let transcriber): return transcriber.selectedLocales.first ?? Locale.current
            }
        }

        var name: String {
            switch self {
            case .speech: return "speechtranscriber"
            case .dictation: return "dictationtranscriber"
            }
        }
    }

    private static func module(for languageCode: String) async -> Module? {
        let requested = Locale(identifier: InKeyboardDictationRoute.speechLocaleIdentifier(
            languageCode: languageCode,
            deviceLocaleIdentifier: Locale.current.identifier
        ))
        if SpeechTranscriber.isAvailable {
            guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else { return nil }
            return .speech(SpeechTranscriber(locale: locale, preset: .transcription))
        }
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: requested) else { return nil }
        return .dictation(DictationTranscriber(locale: locale, preset: .longDictation))
    }

    private static func writeWAV(_ recording: OnDeviceRecording, to url: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: OnDeviceRecording.sampleRate,
            channels: 1,
            interleaved: true
        ) else { throw CocoaError(.featureUnsupported) }
        let frames = recording.pcm16.count / 2
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
        else { throw OnDeviceRecognizerError.empty }
        buffer.frameLength = AVAudioFrameCount(frames)
        recording.pcm16.withUnsafeBytes { raw in
            guard let source = raw.baseAddress, let target = buffer.int16ChannelData?[0] else { return }
            memcpy(target, source, frames * 2)
        }
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        try file.write(from: buffer)
    }
}

#if DEBUG && targetEnvironment(simulator)
/// Simulator-only test harness, compiled out of every device and Release build.
///
/// The simulator cannot run `SpeechAnalyzer` (no model, no download), so this recognizer
/// hands the finished WAV to a helper on the Mac running the simulator, which transcribes
/// it with the same `SpeechAnalyzer` + `SpeechTranscriber` code on the Mac's own on-device
/// model and answers with the text. It exists to show the rest of the path (capture in the
/// keyboard, the recognizer seam, insertion into the host app) on a machine where the
/// recognizer cannot run; it is not a design for devices, where the connection does not
/// exist. The helper only listens on 127.0.0.1.
@MainActor
public final class SimulatorHostRecognizer: OnDeviceRecognizer {
    public init() {}

    public let engineName = "simulator-host-speechanalyzer"
    private let base = URL(string: "http://127.0.0.1:47811")

    /// Asks the host whether ITS `SpeechTranscriber` supports and has installed the
    /// locale, so a language Apple does not cover falls back here as it would on a device.
    public func isReadyOnDevice(languageCode: String) async -> Bool {
        let locale = InKeyboardDictationRoute.speechLocaleIdentifier(
            languageCode: languageCode, deviceLocaleIdentifier: Locale.current.identifier
        )
        guard var components = base.flatMap({ URLComponents(url: $0.appendingPathComponent("ready"), resolvingAgainstBaseURL: false) })
        else { return false }
        components.queryItems = [URLQueryItem(name: "locale", value: locale)]
        guard let url = components.url else { return false }
        let request = URLRequest(url: url, timeoutInterval: 3)
        let response = try? await URLSession.shared.data(for: request)
        let status = (response?.1 as? HTTPURLResponse)?.statusCode ?? 0
        let detail = response.flatMap { String(bytes: $0.0, encoding: .utf8) } ?? "unreachable"
        OnDeviceSpeechLog.log("assetCheck", "module=simulator-host locale=\(locale) ready=\(status == 200) host=\(detail)")
        return status == 200
    }

    /// The host's answer has no side effect, so it is the same question.
    public func hasModelInstalled(languageCode: String) async -> Bool {
        await isReadyOnDevice(languageCode: languageCode)
    }

    public func transcribe(_ recording: OnDeviceRecording, languageCode: String, contextualStrings: [String]) async throws -> String {
        guard let url = base?.appendingPathComponent("transcribe") else { throw OnDeviceRecognizerError.unavailable }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(languageCode, forHTTPHeaderField: "X-Dictus-Language")
        request.setValue(
            contextualStrings.joined(separator: "|").addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "",
            forHTTPHeaderField: "X-Dictus-Context"
        )
        let (data, response) = try await URLSession.shared.upload(for: request, from: Self.wav(recording))
        let note = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Dictus-Context-Note") ?? "none"
        OnDeviceSpeechLog.log("contextualStrings", "module=simulator-host terms=\(contextualStrings.count) host=\(note)")
        let text = (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OnDeviceRecognizerError.empty }
        return text
    }

    /// A 44-byte RIFF header in front of the 16 kHz mono Int16 samples.
    private static func wav(_ recording: OnDeviceRecording) -> Data {
        func le32(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) } }
        func le16(_ value: Int) -> Data { withUnsafeBytes(of: UInt16(value).littleEndian) { Data($0) } }
        let rate = Int(OnDeviceRecording.sampleRate)
        var data = Data("RIFF".utf8) + le32(36 + recording.pcm16.count) + Data("WAVEfmt ".utf8)
        data += le32(16) + le16(1) + le16(1) + le32(rate) + le32(rate * 2) + le16(2) + le16(16)
        data += Data("data".utf8) + le32(recording.pcm16.count) + recording.pcm16
        return data
    }
}
#endif

/// Where the on-device recognizer's lines go. The component is the process's own name in
/// the log, so the keyboard keeps writing `InKeyboardDictation` lines as before and the
/// share extension writes `VoiceNoteShare` ones.
public enum OnDeviceSpeechLog {
    nonisolated(unsafe) public static var component = "InKeyboardDictation"

    public static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: component, instanceID: "shared", action: action, details: details))
    }
}
