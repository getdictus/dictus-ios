// DictusKeyboard/InKeyboardRecognizer.swift
import AVFAudio
import Foundation
import DictusCore
import Speech

/// A finished in-keyboard recording: 16 kHz mono Int16 little-endian PCM.
struct InKeyboardRecording {
    static let sampleRate: Double = 16_000
    var pcm16 = Data()

    var seconds: Double { Double(pcm16.count / 2) / Self.sampleRate }
}

/// The speech-to-text engine behind in-keyboard dictation (spike).
///
/// WHY a protocol: two engines are planned and they live in different places. Apple's
/// `SpeechTranscriber` runs in a system daemon and is what this spike ships. Parakeet
/// running in the same hidden web view (measured on another thread) would take the
/// same 16 kHz PCM and return the same string. The session that records and inserts
/// does not care which one answers.
@MainActor
protocol InKeyboardRecognizer: AnyObject {
    /// Short name for the log.
    var engineName: String { get }

    /// Whether this engine can transcribe `languageCode` on the device right now, with
    /// nothing to download. Must never trigger a download or reach a server.
    func isReadyOnDevice(languageCode: String) async -> Bool

    /// Transcribe a finished recording. Throws when nothing usable came back.
    func transcribe(_ recording: InKeyboardRecording, languageCode: String) async throws -> String
}

enum InKeyboardRecognizerError: LocalizedError {
    case unavailable
    case localeNotInstalled(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable: return "recognizer unavailable on this OS"
        case .localeNotInstalled(let code): return "on-device model not installed for \(code)"
        case .empty: return "no speech recognized"
        }
    }
}

/// Picks the engine for this OS. Nil before iOS 26, where the experiment never runs.
@MainActor
enum InKeyboardRecognizerFactory {
    static func make() -> InKeyboardRecognizer? {
        if #available(iOS 26.0, *) { return AppleSpeechRecognizer() }
        return nil
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
final class AppleSpeechRecognizer: InKeyboardRecognizer {
    var engineName: String {
        SpeechTranscriber.isAvailable ? "apple-speechtranscriber" : "apple-dictationtranscriber"
    }

    func isReadyOnDevice(languageCode: String) async -> Bool {
        guard let module = await Self.module(for: languageCode) else { return false }
        return await AssetInventory.status(forModules: [module.speechModule]) == .installed
    }

    func transcribe(_ recording: InKeyboardRecording, languageCode: String) async throws -> String {
        guard let module = await Self.module(for: languageCode) else {
            throw InKeyboardRecognizerError.localeNotInstalled(languageCode)
        }
        // Checked again at the moment of use: the route decision may be a few seconds old.
        guard await AssetInventory.status(forModules: [module.speechModule]) == .installed else {
            throw InKeyboardRecognizerError.localeNotInstalled(languageCode)
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
        try await analyzer.start(inputAudioFile: file, finishAfterFile: true)

        var transcript = AttributedString()
        switch module {
        case .speech(let transcriber):
            for try await result in transcriber.results where result.isFinal { transcript += result.text }
        case .dictation(let transcriber):
            for try await result in transcriber.results where result.isFinal { transcript += result.text }
        }
        let text = String(transcript.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw InKeyboardRecognizerError.empty }
        return text
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

    private static func writeWAV(_ recording: InKeyboardRecording, to url: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: InKeyboardRecording.sampleRate,
            channels: 1,
            interleaved: true
        ) else { throw CocoaError(.featureUnsupported) }
        let frames = recording.pcm16.count / 2
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))
        else { throw InKeyboardRecognizerError.empty }
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
