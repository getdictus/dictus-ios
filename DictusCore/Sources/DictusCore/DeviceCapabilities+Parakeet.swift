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
    /// 20:59:57Z, and the result was dropped as stale. The watchdog stays as it is; the
    /// retry goes. These devices get the first pass, which is what every Parakeet
    /// dictation returned before #623.
    var runsParakeetDriftRetry: Bool {
        !isPreA14
    }
}
