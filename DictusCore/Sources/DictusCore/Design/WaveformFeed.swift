// DictusCore/Design/WaveformFeed.swift
import Foundation

/// The recording overlay's levels, computed from 16 kHz samples the way DictusApp's audio
/// engine computes them (spike: in-keyboard dictation).
///
/// WHY it exists: the keyboard's waveform driver eases its bars toward whatever array it
/// is given, and the app's array advances at a steady rate because it is cut from the
/// audio itself — each 4096-frame tap buffer (≈ 1365 samples at 16 kHz) becomes six
/// peak+RMS buckets in a 30-bin rolling window, published five times a second. The
/// in-keyboard path first appended one bar per WebView message instead, so the row
/// scrolled at the rate messages arrived, and WebKit delivers them in bursts: the bars
/// sped up, then slowed down.
///
/// Here the bins are cut from fixed blocks of samples, so how the samples arrive no
/// longer matters — a burst of three chunks and three chunks spread over 250 ms produce
/// the same bins — and the caller publishes `snapshot()` on its own 5 Hz clock.
///
/// The arithmetic is a copy of `UnifiedAudioEngine.makeWaveformBuckets`,
/// `resampleWaveform` and `enhanceWaveformContrast`, which this spike does not touch.
public struct WaveformFeed: Sendable {
    /// Bars the overlay draws.
    public static let barCount = 30
    /// One app tap buffer's worth of 16 kHz samples (4096 frames at 48 kHz).
    public static let blockSize = 1365
    /// How often DictusApp publishes a snapshot; the caller's timer uses the same.
    public static let publishInterval: TimeInterval = 0.2

    private var pending: [Float] = []
    private var bins: [Float] = []
    public private(set) var sampleCount = 0

    public init() {}

    /// Feed samples in any chunking. Only whole blocks become bins; the rest waits.
    public mutating func append(_ samples: [Float]) {
        sampleCount += samples.count
        pending.append(contentsOf: samples)
        var start = 0
        while pending.count - start >= Self.blockSize {
            let block = Array(pending[start..<(start + Self.blockSize)])
            bins.append(contentsOf: Self.buckets(from: block))
            start += Self.blockSize
        }
        if start > 0 { pending.removeFirst(start) }
        if bins.count > Self.barCount { bins.removeFirst(bins.count - Self.barCount) }
    }

    /// Convenience for 16-bit little-endian PCM, the WebView's format.
    public mutating func append(pcm16 data: Data) {
        let count = data.count / 2
        guard count > 0 else { return }
        var samples = [Float](repeating: 0, count: count)
        data.withUnsafeBytes { raw in
            let ints = raw.bindMemory(to: Int16.self)
            for index in 0..<count { samples[index] = Float(Int16(littleEndian: ints[index])) / 32_768 }
        }
        append(samples)
    }

    /// The 30 levels to publish, exactly as the app shapes them.
    public func snapshot() -> [Float] {
        Self.enhanceContrast(Self.resample(bins, targetCount: Self.barCount))
    }

    static func buckets(from samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let bucketCount = max(3, min(6, samples.count / 160))
        let bucketSize = max(samples.count / bucketCount, 1)
        var buckets: [Float] = []
        buckets.reserveCapacity(bucketCount)
        var start = 0
        while start < samples.count {
            let end = min(start + bucketSize, samples.count)
            var sumSquares: Float = 0
            var peak: Float = 0
            for sample in samples[start..<end] {
                let magnitude = abs(sample)
                sumSquares += magnitude * magnitude
                peak = max(peak, magnitude)
            }
            let rms = sqrt(sumSquares / Float(max(end - start, 1)))
            buckets.append(min(max((peak * 0.65) + (rms * 6.5), 0), 1))
            start = end
        }
        return buckets
    }

    static func resample(_ source: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 0 else { return [] }
        guard !source.isEmpty else { return Array(repeating: 0, count: targetCount) }
        guard source.count != targetCount else { return source }
        return (0..<targetCount).map { index in
            let position = Float(index) / Float(max(targetCount - 1, 1))
            let arrayIndex = position * Float(source.count - 1)
            let lower = Int(arrayIndex)
            let upper = min(lower + 1, source.count - 1)
            let fraction = arrayIndex - Float(lower)
            return min(max(source[lower] * (1 - fraction) + source[upper] * fraction, 0), 1)
        }
    }

    static func enhanceContrast(_ values: [Float]) -> [Float] {
        guard !values.isEmpty else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let spread = maxValue - minValue
        guard maxValue > 0.06, spread < 0.12 else { return values }
        return values.enumerated().map { index, value in
            let normalizedIndex = Float(index) / Float(max(values.count - 1, 1))
            let centerBias = 1.0 - (abs(normalizedIndex - 0.5) * 0.18)
            let normalized = spread > 0.0001 ? (value - minValue) / spread : 0.5
            let floor = min(maxValue * 0.28, 0.16)
            let stretched = floor + normalized * (1 - floor)
            return min(max(stretched * centerBias, 0), 1)
        }
    }
}
