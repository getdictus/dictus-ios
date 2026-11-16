// DictusCore/Sources/DictusCore/ProcessMemory.swift
// The process's memory footprint and its peak, as the kernel accounts them (issue #963).
import Darwin

/// The current process's physical footprint and the highest it has been since launch.
///
/// WHY THIS AND NOT `DeviceCapabilities.availableMemoryMB`: that is
/// `os_proc_available_memory()`, the headroom left before jetsam, which `transcriptionPerformance`
/// logs under the name `peakMemoryMB`. It says how close the app is to being killed, not how
/// much a model took. `phys_footprint` is the figure jetsam itself compares against the
/// limit, and `ledger_phys_footprint_peak` is its high-water mark, so a spike during a
/// Core ML load or an inference is caught even when the reading is taken afterwards.
public enum ProcessMemory {

    /// Footprint readings in megabytes.
    public struct Footprint: Equatable, Sendable {
        public let currentMB: Int
        public let peakMB: Int
    }

    /// Reads `TASK_VM_INFO` for this task, or `nil` if the kernel refuses.
    public static func footprint() -> Footprint? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return Footprint(
            currentMB: Int(info.phys_footprint / 1_048_576),
            peakMB: Int(info.ledger_phys_footprint_peak / 1_048_576)
        )
    }

    /// `footprintMB=… peakFootprintMB=…` for a log line, or `footprint=unavailable`.
    public static func logFields() -> String {
        guard let footprint = footprint() else { return "footprint=unavailable" }
        return "footprintMB=\(footprint.currentMB) peakFootprintMB=\(footprint.peakMB)"
    }
}
