// DictusCore/Sources/DictusCore/DeviceCapabilities.swift
// Device capability snapshot used for per-device model gating (Phase 37, issue #104).

import Foundation

/// A snapshot of device characteristics used to decide which speech models
/// can safely run on the current device.
///
/// WHY a struct with public init instead of static helpers:
/// Tests for `ModelInfo.isSupported(on:)` need to inject synthetic capabilities
/// (iPhone 12 / 15 Pro Max / 17 Pro) without running on that hardware. Making
/// every field injectable keeps the gating logic pure and unit-testable.
public struct DeviceCapabilities: Sendable, Equatable {

    /// Total physical RAM in gigabytes (rounded down).
    public let physicalMemoryGB: Int

    /// Remaining jetsam headroom in megabytes at the moment the snapshot was taken.
    /// Measured via `os_proc_available_memory()` — this is the memory the app can
    /// allocate before iOS kills it with a jetsam event.
    public let availableMemoryMB: Int

    /// Hardware model identifier from `sysctl` (e.g. "iPhone16,2" = iPhone 15 Pro Max).
    /// On simulator this is the host-reported value (e.g. "arm64") or the simulated
    /// device via `SIMULATOR_MODEL_IDENTIFIER` env var.
    public let deviceModelIdentifier: String

    /// Current thermal state — throttling under `.serious` or `.critical` will
    /// degrade transcription latency significantly.
    public let thermalState: ProcessInfo.ThermalState

    public init(
        physicalMemoryGB: Int,
        availableMemoryMB: Int,
        deviceModelIdentifier: String,
        thermalState: ProcessInfo.ThermalState
    ) {
        self.physicalMemoryGB = physicalMemoryGB
        self.availableMemoryMB = availableMemoryMB
        self.deviceModelIdentifier = deviceModelIdentifier
        self.thermalState = thermalState
    }

    /// Reads the current device's capabilities at call time. Not cached — calling
    /// it twice produces fresh readings (available memory + thermal state drift).
    public static func current() -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: readPhysicalMemoryGB(),
            availableMemoryMB: readAvailableMemoryMB(),
            deviceModelIdentifier: readDeviceModelIdentifier(),
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }

    /// Whether this device's chip predates the A14: an iPhone or iPad whose hardware
    /// family number is below 13 (iPhone XS/XR through iPhone 11 and SE 2nd gen; iPad
    /// Pro 2017-2020, iPad mini 5, iPad Air 3, iPad 6th-9th gen).
    ///
    /// WHY a hardware-family test and not a RAM test:
    /// These devices ship 3-6 GB, overlapping the A14 tier, so RAM alone cannot tell
    /// them apart. Argmax's WhisperKit Core ML support matrix draws the line on the
    /// chip, not the memory: A12/A13 list only Tiny and Base, while A14 adds Small.
    /// Recommending or offering Small here traps the app in Core ML optimization
    /// during onboarding and can jetsam it (issue #362).
    ///
    /// WHY a floor and not a list of families (issue #612):
    /// the matrix names only some pre-A14 devices. The A12X/A12Z iPad Pros (`iPad8,*`),
    /// the A12 iPads (`iPad11,*`) and the A10 iPads (`iPad7,*`) are absent from it
    /// entirely, and the first version of this test matched `iPhone11,`/`iPhone12,`
    /// only, so every iPad fell through to the RAM rule and was handed Small or
    /// Parakeet. Argmax adds Small from A14 onward, and A14 is family 13 on both
    /// product lines (`iPhone13,*`, `iPad13,1`), so everything below it gets the
    /// Tiny/Base tier. Families below the current iOS 17 floor (`iPhone10,*`) also
    /// match; they cannot install Dictus, so that costs nothing.
    ///
    /// WHY it lives on DeviceCapabilities rather than ModelInfo:
    /// This type states facts about the hardware; ModelInfo decides what those facts
    /// mean for the catalog. Keeping the rule here gives the recommendation, the
    /// per-device gate and the compute policy one shared definition.
    ///
    /// Source of truth: https://huggingface.co/argmaxinc/whisperkit-coreml/raw/main/config.json
    public var isPreA14: Bool {
        guard let family = hardwareFamily(after: "iPhone") ?? hardwareFamily(after: "iPad") else {
            // Not an iPhone or iPad identifier (a Mac, "arm64" on some simulators, a
            // test placeholder): no chip-tier restriction applies.
            return false
        }
        return family < 13
    }

    /// The family number of an identifier such as "iPad8,1" (→ 8), or nil when the
    /// identifier does not start with `prefix` followed by digits and a comma.
    ///
    /// WHY parse the number instead of comparing prefixes: a floor needs an ordering,
    /// and the comma bound keeps "iPhone1" from being read out of "iPhone13,2".
    private func hardwareFamily(after prefix: String) -> Int? {
        guard deviceModelIdentifier.hasPrefix(prefix) else { return nil }
        let rest = deviceModelIdentifier.dropFirst(prefix.count)
        guard let comma = rest.firstIndex(of: ","), comma > rest.startIndex else { return nil }
        let digits = rest[rest.startIndex..<comma]
        guard digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }

    /// Which Core ML compute units the Whisper audio encoder should be compiled for
    /// on this device (issue #370).
    ///
    /// WHY this enum carries no WhisperKit type:
    /// `ModelComputeOptions` lives in WhisperKit, which DictusCore deliberately does
    /// not link — pulling it in here would drag the dependency into the keyboard
    /// extension's link graph, and that extension runs under a ~50 MB ceiling nobody
    /// has measured this against. Keeping the decision as a plain enum lets it be
    /// unit tested by `swift test` (the repo's only suite, DictusCore-only) while
    /// DictusApp does the one-line translation at the initialisation sites.
    public enum AudioEncoderComputePolicy: Equatable, Sendable {
        /// Pass no compute options and let WhisperKit choose. On iOS 17+ that means
        /// the Neural Engine for the audio encoder.
        case whisperKitDefault
        /// Force the audio encoder onto CPU + GPU.
        case cpuAndGPU
    }

    /// The compute policy this device needs.
    ///
    /// WHY only pre-A14 chips deviate:
    /// Argmax documents Tiny/Base on the A12/A13 tier as requiring `.cpuAndGPU`; with no
    /// options supplied WhisperKit picks the Neural Engine on iOS 17+, which is the
    /// suspected reason Base can still stall in Core ML optimization there even after
    /// issue #362 stops those devices being handed Small. Every other device keeps
    /// today's configuration: forcing CPU+GPU across the install base would move the
    /// transcription hot path for everyone at an unmeasured latency cost, to fix a
    /// problem two hardware generations old.
    ///
    /// WHY pre-A14 iPads keep the default even though they share the model gate
    /// (issue #612): measured on an A12X iPad Pro (`iPad8,1`, 4 GB, iPadOS 26.0) on
    /// 2026-09-29, the CPU+GPU encoder brought nothing measurable and roughly tripled
    /// peak memory during transcription (~2.4 GB against ~0.8 GB), while the default
    /// Neural Engine path prepared Base in ~22 s without stalling. So the iPads get
    /// the #612 model gate (Base only) but not this compute override, and the policy
    /// stays exactly what #370 shipped: pre-A14 iPhones only.
    ///
    /// NOTE: Argmax's requirement is documentation. It has not been measured on an
    /// iPhone 11 by anyone here, and only the reporter's device can confirm it.
    public var audioEncoderComputePolicy: AudioEncoderComputePolicy {
        isPreA14 && isIPhone ? .cpuAndGPU : .whisperKitDefault
    }

    /// Whether the identifier is a parsable iPhone one ("iPhone12,1"). Scopes the
    /// compute policy above, which differs between iPhones and iPads of one tier.
    private var isIPhone: Bool {
        hardwareFamily(after: "iPhone") != nil
    }

    /// Number of concurrent decoding workers WhisperKit should use for parallel
    /// chunk processing. Scales with physical RAM tier and de-rates under thermal
    /// pressure. Tiers match Apple's marketed iPhone RAM lineup (6/8/12 GB).
    ///
    /// Used as `DecodingOptions.concurrentWorkerCount` — higher = more parallelism
    /// but more peak memory + heat. Conservative on low-RAM devices and when the
    /// SoC is already throttling.
    public var recommendedConcurrentWorkerCount: Int {
        let base: Int
        switch physicalMemoryGB {
        case 12...:
            base = 8   // iPhone 17 Pro / 18 Pro and beyond
        case 8...:
            base = 6   // iPhone 15 Pro / 16 Pro / Pro Max class
        default:
            base = 4   // 6 GB devices (turbo gating floor) and older
        }
        switch thermalState {
        case .serious, .critical:
            return max(2, base / 2)
        default:
            return base
        }
    }

    // MARK: - Private readers

    private static func readPhysicalMemoryGB() -> Int {
        // Use ceiling, not nearest-rounding, to report the marketed RAM tier.
        //
        // Real-device observation on iPhone 15 Pro Max (8 GB marketed):
        // ProcessInfo.physicalMemory returns ~7.47 GB because the kernel and
        // secure enclave reserve ~530 MB. Nearest-rounding gives 7, floor
        // gives 7, only ceiling produces the 8 that Turbo gating relies on.
        //
        // Safe across the iPhone lineup because Apple's RAM tiers are spaced
        // by whole GB (4/6/8/12) — ceiling can only push a reading up to the
        // next integer, never past the next marketed tier:
        //   - 3.8 GB (iPhone 12 mini, 4 GB marketed) → ceil = 4 ✓
        //   - 5.9 GB (iPhone 13 Pro, 6 GB marketed) → ceil = 6 ✓
        //   - 7.47 GB (iPhone 15 Pro Max, 8 GB marketed) → ceil = 8 ✓
        //   - 11.3 GB (iPhone 17 Pro, 12 GB marketed) → ceil = 12 ✓
        let bytes = Double(ProcessInfo.processInfo.physicalMemory)
        return Int((bytes / 1_073_741_824.0).rounded(.up))
    }

    private static func readAvailableMemoryMB() -> Int {
        // `os_proc_available_memory()` is iOS 13+. Returns jetsam headroom in bytes.
        // Returns 0 if the process has no jetsam limit (rare, mostly simulator).
        // macOS has no jetsam equivalent and this path only matters on-device;
        // the macOS build exists solely for the polish eval harness.
        #if os(iOS)
        let bytes = os_proc_available_memory()
        return Int(bytes / 1_048_576)
        #else
        return 0
        #endif
    }

    private static func readDeviceModelIdentifier() -> String {
        // Simulator reports host arch via sysctl; prefer SIMULATOR_MODEL_IDENTIFIER
        // when present so we see the simulated device.
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulated.isEmpty {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
}

// MARK: - Thermal state log formatting

public extension ProcessInfo.ThermalState {
    /// Human-readable label used in log output.
    var logLabel: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
