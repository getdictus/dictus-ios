// Headless probe for #550: is ASRResult.tokenTimings populated at runtime for
// Parakeet v3, on the same batch `transcribe([Float])` call DictusApp makes — and
// is a pause visible in it?
import AVFoundation
import Foundation
import FluidAudio

func samples(of url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                        frameCapacity: AVAudioFrameCount(file.length)) else {
        fatalError("cannot allocate buffer")
    }
    try file.read(into: buffer)
    guard let channel = buffer.floatChannelData?[0] else { fatalError("no float channel") }
    return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
}

let models = try await AsrModels.downloadAndLoad(version: .v3)
let manager = AsrManager(config: .default)
try await manager.initialize(models: models)

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let audio = try samples(of: url)
    let seconds = Double(audio.count) / 16000
    print("\n══ \(url.lastPathComponent) — \(audio.count) samples, \(String(format: "%.1f", seconds)) s, "
          + "path=\(audio.count <= 240_000 ? "short (single window)" : "ChunkProcessor"))")
    let result = try await manager.transcribe(audio)
    print("text: \(result.text)")
    print("tokenTimings nil: \(result.tokenTimings == nil)   count: \(result.tokenTimings?.count ?? -1)")
    guard let timings = result.tokenTimings, !timings.isEmpty else { continue }
    let gaps = zip(timings, timings.dropFirst()).map { $1.startTime - $0.endTime }
    let spans = timings.map { $0.endTime - $0.startTime }
    print(String(format: "coverage: %.2f s → %.2f s   max inter-token gap: %.3f s   max token span: %.3f s",
                 timings.first!.startTime, timings.last!.endTime, gaps.max() ?? 0, spans.max() ?? 0))
    print("every inter-token gap of 0.15 s or more:")
    for (index, gap) in gaps.enumerated() where gap >= 0.15 {
        print(String(format: "  %.3f s at %.2f s — after '%@' (…%@ | %@…)",
                     gap,
                     timings[index].endTime,
                     timings[index].token,
                     timings[max(0, index - 4)...index].map(\.token).joined(),
                     timings[(index + 1)...min(timings.count - 1, index + 4)].map(\.token).joined()))
    }
    _ = spans
}
