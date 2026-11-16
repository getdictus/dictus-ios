// DictusCore/Sources/DictusCore/DeviceCapabilities+Parakeet.swift
// How Parakeet v3 runs on this device: compute units and the drift retry (issue #963).
import Foundation

public extension DeviceCapabilities {

    /// Which Core ML compute units Parakeet v3 is loaded with.
    ///
    /// WHY this enum carries no Core ML type: same split as `AudioEncoderComputePolicy`.
    /// DictusCore decides and `swift test` covers the decision; DictusApp, which links
    /// FluidAudio, translates it into an `MLModelConfiguration` at the one load site.
    enum ParakeetComputePolicy: Equatable, Sendable {
        /// Pass no configuration and let FluidAudio choose: preprocessor on the CPU,
        /// encoder, decoder and joint on the CPU and the Neural Engine. Never the GPU.
        case fluidAudioDefault
        /// Every component on the CPU only.
        case cpuOnly
    }

    /// The compute policy Parakeet needs on this device.
    ///
    /// WHY THE CPU ON EVERY PRE-A14 CHIP (#963): on an A12X iPad Pro (`iPad8,1`, 4 GB) the
    /// default load was jetsammed twice inside `AsrModels.load`, with DictusApp at about
    /// 2.7 GB resident (`JetsamEvent-2026-11-15-183201`, `vm-pageshortage` then
    /// `proc-thrashing`). The same models with every component on `.cpuOnly` loaded in
    /// about 10 s with a 440-510 MB footprint, returned correct text, and transcribed
    /// 4/4 keyboard dictations from a backgrounded DictusApp in 4.6-6.2 s. The CPU, like
    /// the Neural Engine, is a unit iOS lets a background app use; the GPU is not (#635).
    ///
    /// WHY THE WHOLE FLOOR AND NOT `iPad8,*`: one rule for every device below A14, iPhone
    /// and iPad (Pierre, 2026-11-16). Only the A12X was measured. The A12/A13 iPhones and
    /// iPads, some with 3 GB, follow by decision, not by measurement.
    ///
    /// A14 and later keep FluidAudio's default, which every Parakeet measurement since
    /// #552 was taken with.
    var parakeetComputePolicy: ParakeetComputePolicy {
        isPreA14 ? .cpuOnly : .fluidAudioDefault
    }

    /// Whether Parakeet re-decodes the spans of a dictation that look drifted (#623).
    ///
    /// WHY NOT BEFORE A14 (#963): on the CPU the retry costs as much as the first pass, or
    /// more. Measured on `iPad8,1`: the first pass of a keyboard dictation finished in
    /// about 6 s, then the retry ran 27.9 s, the 30 s keyboard watchdog reset at
    /// 20:59:57Z, and the result was dropped as stale. The retry goes; the watchdog was
    /// only scaled later, for long dictations (`transcriptionWatchdogTimeout`). These
    /// devices get the first pass, which is what every Parakeet dictation returned
    /// before #623.
    var runsParakeetDriftRetry: Bool {
        !isPreA14
    }

    /// The base delay of DictusApp's transcription stage watchdog, before A14 and after.
    static let transcriptionWatchdogBaseSeconds: TimeInterval = 30

    /// Seconds of watchdog added per second of audio before A14.
    static let preA14TranscriptionWatchdogSecondsPerAudioSecond: TimeInterval = 0.5

    /// How long DictusApp's transcription stage may run before its watchdog cancels it,
    /// for a recording of `audioSeconds`.
    ///
    /// WHY IT SCALES BEFORE A14 (#963): on the CPU a long dictation outlasts a fixed 30 s.
    /// Measured on `iPad8,1` (build `21739bdb`, no drift retry): 2.3 s of audio in 6.4 s,
    /// 4.1 s in 6.2 s, 17.1 s in 11.6 s, 64.4 s in 19.3 s; a ~71 s dictation was cancelled
    /// by the watchdog at 30 s and nothing was inserted. 30 s + 0.5 x the audio gives that
    /// one 65.5 s (Pierre, 2026-11-16).
    ///
    /// A14 and later keep the fixed 30 s.
    func transcriptionWatchdogTimeout(audioSeconds: TimeInterval) -> TimeInterval {
        let base = Self.transcriptionWatchdogBaseSeconds
        guard isPreA14 else { return base }
        return base + Self.preA14TranscriptionWatchdogSecondsPerAudioSecond * max(0, audioSeconds)
    }
}
