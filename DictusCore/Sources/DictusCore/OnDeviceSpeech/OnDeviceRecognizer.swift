// DictusCore/OnDeviceSpeech/OnDeviceRecognizer.swift
// Apple's on-device speech recognizer behind a small protocol, for the app's
// "Apple (on-device)" engine (Models screen), and for the share extension, which
// transcribes a voice note with it when the app is closed (#1056).
import AVFAudio
import Foundation
import Speech

/// A finished recording: 16 kHz mono Int16 little-endian PCM.
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

/// An on-device speech-to-text engine that takes a finished recording and one language.
///
/// WHY a protocol: the device runs Apple's `SpeechTranscriber` (`AppleSpeechRecognizer`),
/// and a Debug simulator build, where no runtime ships Apple's speech model, runs a test
/// harness behind the same seam (`SimulatorHostRecognizer`). The app's engine adapter does
/// not care which one answers.
@MainActor
public protocol OnDeviceRecognizer: AnyObject {
    /// Short name for the log.
    var engineName: String { get }

    /// The locales this engine can transcribe on this device, as BCP 47 identifiers, or
    /// nil when its recognizer is not available here at all.
    func supportedLocaleIdentifiers() async -> [String]?

    /// Whether the model for `languageCode` is on the device, and nothing else: no
    /// reservation, no download. The Models screen asks this to draw the Apple card.
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

/// Picks the engine for this device. Nil before iOS 26 and wherever Apple's
/// `SpeechTranscriber` reports itself unavailable: there is no fallback to another Apple
/// module (Pierre, 2026-11-21), so the Apple card is greyed and the app dictates with the
/// downloaded model.
@MainActor
public enum OnDeviceRecognizerFactory {
    public static func make() -> OnDeviceRecognizer? {
        #if DEBUG && targetEnvironment(simulator)
        // No iOS Simulator runtime ships a speech model (measured 2026-11-19 on 26.5 and
        // 27.2: `SpeechTranscriber.isAvailable == false`, no installed locale, and the
        // asset download refused). See `SimulatorHostRecognizer`.
        return SimulatorHostRecognizer()
        #else
        if #available(iOS 26.0, *) {
            guard SpeechTranscriber.isAvailable else {
                OnDeviceSpeechLog.log("engine", "speechTranscriberAvailable=false recognizer=none")
                return nil
            }
            return AppleSpeechRecognizer()
        }
        return nil
        #endif
    }
}

/// Apple's `SpeechAnalyzer` + `SpeechTranscriber` (iOS 26+).
///
/// On-device only, by construction: the SpeechAnalyzer modules have no server mode
/// (unlike `SFSpeechRecognizer`, which this file deliberately does not use), and the asset
/// check below refuses any locale whose model is not already installed, so transcribing
/// never downloads anything. Installing the model is the Models screen's explicit step
/// (`AssetInventory`, when the user picks the engine). The model runs in Apple's speech
/// daemon, not in this process.
///
/// `SpeechTranscriber` only. Where it reports itself unavailable (`isAvailable == false`:
/// older hardware, and every iOS Simulator, measured 2026-11-19 on iOS 26.5) this class is
/// never made (`OnDeviceRecognizerFactory`): Pierre decided on 2026-11-21 against falling
/// back to `DictationTranscriber`.
@available(iOS 26.0, *)
@MainActor
public final class AppleSpeechRecognizer: OnDeviceRecognizer {
    public init() {}

    public var engineName: String {
        "apple-speechtranscriber"
    }

    public func supportedLocaleIdentifiers() async -> [String]? {
        guard SpeechTranscriber.isAvailable else { return nil }
        return await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
    }

    public func hasModelInstalled(languageCode: String) async -> Bool {
        guard let module = await Self.module(for: languageCode) else { return false }
        return await Self.isInstalled(module)
    }

    /// Installed per `AssetInventory`, or present in `SpeechTranscriber.installedLocales`.
    ///
    /// WHY both: `AssetInventory.status` answers for the calling bundle's reservation, and
    /// another bundle may have reserved and installed the same locale. Measured on macOS 26
    /// (2026-11-19) from a process with no reservation: `status` said `supported` while
    /// `installedLocales` listed `fr_FR`, and `SpeechAnalyzer` transcribed a French file in
    /// 150 ms. Both answers are about models on this device; neither downloads anything.
    private static func isInstalled(_ module: Module) async -> Bool {
        let status = await AssetInventory.status(forModules: [module.transcriber])
        let installed = await SpeechTranscriber.installedLocales
        let listed = installed.contains { $0.identifier(.bcp47) == module.locale.identifier(.bcp47) }
        // Whether THIS bundle holds a reservation (#992, #1056): the share extension's and
        // the app's are separate, which is what a device log has to show when the model
        // reads missing from the extension.
        let reserved = await AssetInventory.reservedLocales.contains { $0.identifier(.bcp47) == module.locale.identifier(.bcp47) }
        OnDeviceSpeechLog.log(
            "assetCheck",
            "locale=\(module.locale.identifier) status=\(status) inInstalledLocales=\(listed) reservedByThisBundle=\(reserved)"
        )
        return status == .installed || listed
    }

    public func transcribe(_ recording: OnDeviceRecording, languageCode: String, contextualStrings: [String]) async throws -> String {
        guard let module = await Self.module(for: languageCode) else {
            throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
        }
        // Checked again at the moment of use: the availability reading may be stale.
        guard await Self.isInstalled(module) else {
            throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-speech-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.writeWAV(recording, to: url)

        let analyzer = SpeechAnalyzer(
            modules: [module.transcriber],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .whileInUse)
        )
        let file = try AVAudioFile(forReading: url)
        await Self.offer(contextualStrings, to: analyzer)
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)

        var transcript = AttributedString()
        for try await result in module.transcriber.results where result.isFinal { transcript += result.text }
        let text = String(transcript.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw OnDeviceRecognizerError.empty }
        return text
    }

    /// The vocabulary as `AnalysisContext.contextualStrings`. Whether it is *accepted* is
    /// logged here; whether it *changes* anything is read by comparing transcripts.
    /// Measured on macOS 26 (2026-11-20) with "Dictus" as the only string: accepted, and
    /// it did not change "dicttu" / "dictée".
    private static func offer(_ strings: [String], to analyzer: SpeechAnalyzer) async {
        guard !strings.isEmpty else { return }
        let context = AnalysisContext()
        context.contextualStrings[.general] = strings
        do {
            try await analyzer.setContext(context)
            OnDeviceSpeechLog.log("contextualStrings", "terms=\(strings.count) accepted=true")
        } catch {
            OnDeviceSpeechLog.log("contextualStrings", "terms=\(strings.count) accepted=false error=\(error.localizedDescription)")
        }
    }

    /// The transcriber for one locale.
    private struct Module {
        let transcriber: SpeechTranscriber
        let locale: Locale
    }

    private static func module(for languageCode: String) async -> Module? {
        let requested = Locale(identifier: AppleSpeechLanguage.localeIdentifier(
            languageCode: languageCode,
            deviceLocaleIdentifier: Locale.current.identifier
        ))
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else { return nil }
        return Module(transcriber: SpeechTranscriber(locale: locale, preset: .transcription), locale: locale)
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
/// asks a helper on the Mac running the simulator, which answers with the same
/// `SpeechAnalyzer` + `SpeechTranscriber` code on the Mac's own on-device model. It exists
/// to show the rest of the path (the Models screen card, the engine seam, the app's
/// pipeline after it) on a machine where the recognizer cannot run; it is not a design
/// for devices, where the connection does not exist. The helper only listens on 127.0.0.1;
/// with no helper running, the card reads as an iPhone without `SpeechTranscriber`.
@MainActor
public final class SimulatorHostRecognizer: OnDeviceRecognizer {
    public init() {}

    public let engineName = "simulator-host-speechanalyzer"
    /// 47811 unless the App Group says otherwise (`dictus.debugSimulatorHostPort`, #1056):
    /// two agents on one Mac each run their own helper, and every simulator shares the
    /// Mac's loopback. Read per call, so the share extension sees a value set after launch.
    private var base: URL? {
        let port = AppGroup.defaults.integer(forKey: "dictus.debugSimulatorHostPort")
        return URL(string: "http://127.0.0.1:\(port > 0 ? port : 47811)")
    }

    /// The host's `SpeechTranscriber.supportedLocales`, one per line. Nil when no helper
    /// answers, which greys the card as `SpeechTranscriber.isAvailable == false` would.
    public func supportedLocaleIdentifiers() async -> [String]? {
        guard let url = base?.appendingPathComponent("locales") else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 3)),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            OnDeviceSpeechLog.log("hostLocales", "host=unreachable")
            return nil
        }
        let lines = (String(bytes: data, encoding: .utf8) ?? "").split(separator: "\n").map(String.init)
        OnDeviceSpeechLog.log("hostLocales", "count=\(lines.count)")
        return lines
    }

    /// Asks the host whether ITS `SpeechTranscriber` has installed the locale.
    public func hasModelInstalled(languageCode: String) async -> Bool {
        let locale = AppleSpeechLanguage.localeIdentifier(
            languageCode: languageCode, deviceLocaleIdentifier: Locale.current.identifier
        )
        guard var components = base.flatMap({ URLComponents(url: $0.appendingPathComponent("ready"), resolvingAgainstBaseURL: false) })
        else { return false }
        components.queryItems = [URLQueryItem(name: "locale", value: locale)]
        guard let url = components.url else { return false }
        let response = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 3))
        let status = (response?.1 as? HTTPURLResponse)?.statusCode ?? 0
        OnDeviceSpeechLog.log("assetCheck", "module=simulator-host locale=\(locale) ready=\(status == 200)")
        return status == 200
    }

    /// Stands in for `AssetInventory`'s install of Apple's model (#1057): asks the host to
    /// start installing the locale, then polls it for a fraction until it answers `done`
    /// or `failed`. The host decides how long it takes and whether it fails, so a run can
    /// show the onboarding's progress and its fallback to the download.
    public func install(languageCode: String, onProgress: @escaping @MainActor (Double?) -> Void) async throws {
        let locale = AppleSpeechLanguage.localeIdentifier(
            languageCode: languageCode, deviceLocaleIdentifier: Locale.current.identifier
        )
        guard var components = base.flatMap({ URLComponents(url: $0.appendingPathComponent("install"), resolvingAgainstBaseURL: false) })
        else { throw OnDeviceRecognizerError.unavailable }
        components.queryItems = [URLQueryItem(name: "locale", value: locale)]
        guard let url = components.url else { throw OnDeviceRecognizerError.unavailable }
        var start = URLRequest(url: url, timeoutInterval: 3)
        start.httpMethod = "POST"
        guard let (_, response) = try? await URLSession.shared.data(for: start),
              let status = (response as? HTTPURLResponse)?.statusCode, status == 200 || status == 202 else {
            OnDeviceSpeechLog.log("hostInstall", "locale=\(locale) step=refused")
            throw OnDeviceRecognizerError.unavailable
        }
        onProgress(nil)
        while true {
            try await Task.sleep(nanoseconds: 250_000_000)
            guard let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 3)) else {
                throw OnDeviceRecognizerError.unavailable
            }
            let answer = (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if answer == "done" {
                OnDeviceSpeechLog.log("hostInstall", "locale=\(locale) step=done")
                return
            }
            guard let fraction = Double(answer) else {
                OnDeviceSpeechLog.log("hostInstall", "locale=\(locale) step=failed answer=\(answer)")
                throw OnDeviceRecognizerError.localeNotInstalled(languageCode)
            }
            onProgress(fraction)
        }
    }

    public func transcribe(_ recording: OnDeviceRecording, languageCode: String, contextualStrings: [String]) async throws -> String {
        guard let url = base?.appendingPathComponent("transcribe") else { throw OnDeviceRecognizerError.unavailable }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(languageCode, forHTTPHeaderField: "X-Dictus-Language")
        let (data, _) = try await URLSession.shared.upload(for: request, from: Self.wav(recording))
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

/// Where the on-device recognizer's lines go.
public enum OnDeviceSpeechLog {
    /// The process's own name in the log (#992, #1056): the app writes
    /// `AppleSpeechRecognizer` lines, the share extension `VoiceNoteShare` ones. Set once,
    /// before the first line.
    nonisolated(unsafe) public static var component = "AppleSpeechRecognizer"
    nonisolated(unsafe) public static var instanceID = "app"

    public static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: component, instanceID: instanceID, action: action, details: details))
    }
}
