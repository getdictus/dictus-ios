// tools/closing-phrase-bench/main.swift
// Decodes every clip of dictus-test-voices, as is and as a microphone in a room records it,
// through the engines Dictus ships, with the decoding options the app uses (#932).
// One TSV row per decode; score.py turns the rows into the report.
import DictusCore
import FluidAudio
import Foundation
import WhisperKit

struct Clip {
    let file: String
    let language: String
}

/// What the microphone records after the last spoken word. A dictation ends with the
/// user reaching for the stop button while the room keeps playing.
struct Tail {
    let name: String
    let seconds: Double
    /// RMS level of the room noise in dBFS, mixed under the whole recording and not only
    /// the tail, since a room is as loud between words as after them. Nil for digital
    /// silence appended after the clip.
    let roomDBFS: Double?
}

/// Room levels measured on iPhone recordings in dictus-asr-audio: pauses sit
/// between -76 and -44 dBFS (5th percentile of 100 ms windows).
let tails: [Tail] = [
    Tail(name: "clean", seconds: 0, roomDBFS: nil),
    Tail(name: "zero-3s", seconds: 3, roomDBFS: nil),
    Tail(name: "quiet-3s", seconds: 3, roomDBFS: -65),
    Tail(name: "quiet-8s", seconds: 8, roomDBFS: -65),
    Tail(name: "noisy-3s", seconds: 3, roomDBFS: -45),
    Tail(name: "noisy-8s", seconds: 8, roomDBFS: -45)
]

let sampleRate = 16_000

func readManifest(_ corpus: URL) throws -> [Clip] {
    let data = try Data(contentsOf: corpus.appendingPathComponent("manifest.json"))
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let clips = root["clips"] as? [[String: Any]] else {
        throw BenchError.badManifest
    }
    return clips.compactMap { entry in
        guard let file = entry["file"] as? String, let language = entry["language"] as? String else { return nil }
        return Clip(file: file, language: language)
    }
}

/// The corpus format: 44-byte header, PCM s16le, 16 kHz, mono.
func readWAV(_ url: URL) throws -> [Float] {
    let data = try Data(contentsOf: url)
    guard data.count > 44 else { throw BenchError.badAudio(url.path) }
    return data.dropFirst(44).withUnsafeBytes { raw in
        raw.bindMemory(to: Int16.self).map { Float(Int16(littleEndian: $0)) / 32_768 }
    }
}

/// SplitMix64, so every run appends the same noise.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func recording(_ speech: [Float], _ tail: Tail) -> [Float] {
    let padded = speech + [Float](repeating: 0, count: Int(tail.seconds * Double(sampleRate)))
    guard let level = tail.roomDBFS else { return padded }
    let rms = pow(10, level / 20)
    var rng = SeededGenerator(state: 932)
    return padded.map { sample in
        // Box-Muller: Gaussian noise of standard deviation `rms`.
        let u1 = Double.random(in: Double.ulpOfOne..<1, using: &rng)
        let u2 = Double.random(in: 0..<1, using: &rng)
        return sample + Float(rms * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2))
    }
}

enum BenchError: Error {
    case badManifest
    case badAudio(String)
    case usage(String)
}

protocol Engine {
    var name: String { get }
    func transcribe(_ samples: [Float], language: String) async throws -> String
}

/// The options of `WhisperKitEngine.transcribe` in DictusApp, language forced.
struct WhisperEngine: Engine {
    let name: String
    let kit: WhisperKit

    func transcribe(_ samples: [Float], language: String) async throws -> String {
        let options = DecodingOptions(
            task: .transcribe,
            language: language,
            temperature: 0.0,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            chunkingStrategy: .vad
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
    }
}

/// The first pass of `ParakeetEngine.transcribe` in DictusApp. The drift retry (#623)
/// re-decodes drifted spans only and is not run here.
struct ParakeetEngine: Engine {
    let name = "parakeet-v3"
    let manager: AsrManager

    func transcribe(_ samples: [Float], language: String) async throws -> String {
        guard samples.count >= sampleRate else { return "" }
        var state = try TdtDecoderState()
        return try await manager.transcribe(samples, decoderState: &state).text
    }
}

func makeEngine(_ spec: String, models: URL) async throws -> Engine {
    if spec == "parakeet-v3" {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(config: ASRConfig(parallelChunkConcurrency: 1))
        try await manager.loadModels(models)
        return ParakeetEngine(manager: manager)
    }
    let folder = try await WhisperKit.download(variant: spec, downloadBase: models)
    let config = WhisperKitConfig(
        model: spec, modelFolder: folder.path, verbose: false, logLevel: .error,
        prewarm: true, load: true, download: false)
    return WhisperEngine(name: spec, kit: try await WhisperKit(config))
}

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func oneLine(_ text: String) -> String {
    text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespaces)
}

guard let corpusPath = argument("--corpus"), let spec = argument("--engine"), let out = argument("--out") else {
    FileHandle.standardError.write(Data(
        "usage: closing-phrase-bench --corpus <dictus-test-voices> --engine <whisper variant|parakeet-v3> --out <tsv> [--models <dir>] [--trim]\n".utf8))
    exit(2)
}
let corpus = URL(fileURLWithPath: corpusPath)
let models = URL(fileURLWithPath: argument("--models") ?? "build/closing-phrase-bench/models")
let trim = CommandLine.arguments.contains("--trim")

let engine = try await makeEngine(spec, models: models)
let clips = try readManifest(corpus)
var rows = ["engine\tpipeline\tclip\tlanguage\ttail\tsent_seconds\ttext"]
for clip in clips {
    let speech = try readWAV(corpus.appendingPathComponent(clip.file))
    for tail in tails {
        let recorded = recording(speech, tail)
        let sent = trim ? TrailingSilence.trimmed(recorded) : recorded
        let started = Date()
        let raw = try await engine.transcribe(sent, language: clip.language)
        let text = NonSpeechMarkers.spokenText(in: raw)
        let elapsed = Date().timeIntervalSince(started)
        rows.append([engine.name, trim ? "trim" : "shipping", clip.file, clip.language, tail.name,
                     String(format: "%.2f", Double(sent.count) / Double(sampleRate)), oneLine(text)]
            .joined(separator: "\t"))
        FileHandle.standardError.write(Data(String(format: "[%.1fs] %@ %@: %@\n", elapsed, tail.name, clip.file, oneLine(text)).utf8))
    }
}
try (rows.joined(separator: "\n") + "\n").write(toFile: out, atomically: true, encoding: .utf8)
