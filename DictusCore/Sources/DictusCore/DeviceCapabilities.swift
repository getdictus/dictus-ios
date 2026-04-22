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

    // MARK: - Private readers

    private static func readPhysicalMemoryGB() -> Int {
        // Round to nearest GB. An 8 GB iPhone typically reports ~7.8-7.95 GB of
        // physical memory because the kernel and secure enclave reserve some —
        // integer truncation would misclassify it as a 7 GB device and gate Turbo
        // off. Rounding reflects the marketed hardware tier instead of kernel
        // accounting noise.
        let bytes = Double(ProcessInfo.processInfo.physicalMemory)
        return Int((bytes / 1_073_741_824.0).rounded())
    }

    private static func readAvailableMemoryMB() -> Int {
        // `os_proc_available_memory()` is iOS 13+. Returns jetsam headroom in bytes.
        // Returns 0 if the process has no jetsam limit (rare, mostly simulator).
        let bytes = os_proc_available_memory()
        return Int(bytes / 1_048_576)
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
