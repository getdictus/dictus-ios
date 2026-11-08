// DictusCore/Sources/DictusCore/DriftRetry/SpeechEnergyProfile.swift
// Where the speech and the pauses are in a dictation, from signal energy alone (#623).
import Foundation

/// The energy levels the retry places its spans with: a speech gate, a silence threshold,
/// and the pauses.
///
/// WHY energy and not the transcript: the retry exists because the transcript is wrong in
/// the places it looks at. A word's timestamp says where the decoder emitted something, not
/// where the speaker stopped, and a gap region is by definition speech the decoder emitted
/// nothing for. Both levels adapt to the recording, from its own percentiles, so a quiet
/// room and a noisy street are judged against themselves.
struct SpeechEnergyProfile {

    /// RMS of each 10 ms frame (160 samples).
    let frameRMS: [Double]

    /// RMS over a centred 110 ms window around each 10 ms frame. Pauses are read on this.
    let smoothedRMS: [Double]

    /// At or below: silence. `max(0.1·p75, 1.5·p10)` of the 80 ms frame RMS, floored.
    let silenceThreshold: Double

    /// At or above: speech, for the gap detector. `clamp(0.3·p75, 0.0005, 0.008)`, the
    /// adaptive threshold FluidAudio's own silence-aligned chunking uses.
    let speechThreshold: Double

    /// Every run of at least `minimumPauseSeconds` at or below the silence threshold, as
    /// half-open ranges of 10 ms frame indices.
    let pauses: [Range<Int>]

    /// Length of the audio profiled. A cut point never lands past it.
    let sampleCount: Int

    /// Samples per 10 ms frame at 16 kHz.
    static let hop = 160

    /// The quietest level that still counts as sound: digital silence and dither sit below it.
    static let audibleFloor = 0.0005

    init(samples: [Float]) {
        let hop = Self.hop
        let frameCount = samples.count / hop
        var meanSquare = [Double](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            var sum = 0.0
            for index in 0..<hop {
                let value = Double(samples[frame * hop + index])
                sum += value * value
            }
            meanSquare[frame] = sum / Double(hop)
        }

        // Centred moving RMS over frames [f - 5, f + 6), from a prefix sum.
        var prefix = [Double](repeating: 0, count: frameCount + 1)
        for frame in 0..<frameCount { prefix[frame + 1] = prefix[frame] + meanSquare[frame] }
        var smoothed = [Double](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            let low = max(0, frame - 5), high = min(frameCount, frame + 6)
            smoothed[frame] = sqrt((prefix[high] - prefix[low]) / Double(high - low))
        }

        // Percentiles over the 80 ms encoder frames that hold any signal at all.
        let encoderFrame = DriftRetryParameters.samplesPerFrame
        var encoderRMS: [Double] = []
        var offset = 0
        while offset + encoderFrame <= samples.count {
            var sum = 0.0
            for index in 0..<encoderFrame {
                let value = Double(samples[offset + index])
                sum += value * value
            }
            if sum > 0 { encoderRMS.append(sqrt(sum / Double(encoderFrame))) }
            offset += encoderFrame
        }
        encoderRMS.sort()
        let audible = encoderRMS.filter { $0 >= Self.audibleFloor }
        let p10 = audible.isEmpty ? Self.audibleFloor : audible[audible.count / 10]
        let p75 = encoderRMS.isEmpty ? 0 : encoderRMS[min(encoderRMS.count - 1, Int(Double(encoderRMS.count) * 0.75))]
        let speechThreshold = min(0.008, max(Self.audibleFloor, 0.3 * p75))
        let silenceThreshold = max(Self.audibleFloor, max(0.1 * p75, 1.5 * p10))

        var pauses: [Range<Int>] = []
        var frame = 0
        while frame < frameCount {
            if smoothed[frame] <= silenceThreshold {
                var end = frame
                while end < frameCount && smoothed[end] <= silenceThreshold { end += 1 }
                if Double(end - frame) * 0.01 >= DriftRetryParameters.minimumPauseSeconds { pauses.append(frame..<end) }
                frame = end
            } else {
                frame += 1
            }
        }

        self.frameRMS = meanSquare.map { sqrt($0) }
        self.smoothedRMS = smoothed
        self.silenceThreshold = silenceThreshold
        self.speechThreshold = speechThreshold
        self.pauses = pauses
        self.sampleCount = samples.count
    }

    /// Number of 10 ms frames in `[startSeconds + margin, endSeconds - margin)` at or above
    /// the speech gate.
    func speechFrameCount(fromSeconds startSeconds: Double, toSeconds endSeconds: Double, margin: Double) -> Int {
        let first = Int((startSeconds + margin) * 100)
        let last = min(frameRMS.count, Int((endSeconds - margin) * 100))
        guard first < last else { return 0 }
        return (first..<last).filter { frameRMS[$0] >= speechThreshold }.count
    }

    /// Where to cut, in samples, on the 80 ms encoder grid.
    ///
    /// The quietest encoder-aligned point of the pause, inside `[low, high]` seconds, whose
    /// position is nearest `preferred`. Without such a pause, the quietest encoder-aligned
    /// point inside `[fallbackLow, fallbackHigh]` seconds.
    func cutPoint(low: Double, high: Double, preferred: Double, fallbackLow: Double, fallbackHigh: Double) -> Int {
        let totalSamples = sampleCount
        // 8 ten-millisecond frames per encoder frame.
        let step = DriftRetryParameters.samplesPerFrame / Self.hop
        var best: (position: Int, distance: Double)?
        for pause in pauses {
            var quietest = -1
            var frame = (pause.lowerBound + step - 1) / step * step
            while frame < pause.upperBound {
                if quietest < 0 || smoothedRMS[frame] < smoothedRMS[quietest] { quietest = frame }
                frame += step
            }
            guard quietest >= 0 else { continue }
            let time = Double(quietest) * 0.01
            guard time >= low && time <= high else { continue }
            let distance = abs(time - preferred)
            if let current = best, distance >= current.distance { continue }
            best = (quietest * Self.hop, distance)
        }
        if let best { return min(totalSamples, max(0, best.position)) }

        let lastFrame = smoothedRMS.count - 1
        let first = max(0, Int(fallbackLow * 100)), last = min(lastFrame, Int(fallbackHigh * 100))
        guard first <= last else {
            return min(totalSamples, max(0, Self.alignedToEncoderFrame(Int(preferred * Double(DriftRetryParameters.sampleRate)))))
        }
        var start = first / step * step
        if start < first { start += step }
        var quietest = start
        var frame = start
        while frame <= last {
            if smoothedRMS[frame] < smoothedRMS[quietest] { quietest = frame }
            frame += step
        }
        return min(totalSamples, max(0, quietest * Self.hop))
    }

    /// `samples` rounded to the nearest encoder-frame boundary.
    static func alignedToEncoderFrame(_ samples: Int) -> Int {
        let frame = DriftRetryParameters.samplesPerFrame
        return Int((Double(samples) / Double(frame)).rounded()) * frame
    }
}
