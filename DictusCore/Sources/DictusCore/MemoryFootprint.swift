// DictusCore/MemoryFootprint.swift
import Foundation
import Darwin

/// Reads the resident memory footprint of the current process via Mach task info.
///
/// Keyboard extensions have a hard ~50 MB budget — iOS terminates the process
/// when it gets close. Logging RSS at lifecycle boundaries lets us see where
/// the spend goes (baseline vs transient peaks during rebuild) so we can
/// target reductions instead of guessing.
public enum MemoryFootprint {
    /// Current resident size (MB, integer). Returns -1 on failure.
    public static func residentMB() -> Int {
        let bytes = physicalFootprintBytes()
        guard bytes >= 0 else { return -1 }
        return Int(bytes / (1024 * 1024))
    }

    /// The same number in KB, for measuring something smaller than a megabyte.
    ///
    /// WHY it exists (issue #483): the question "what does linking CallKit cost the keyboard
    /// against its ~50 MB budget" cannot be answered in whole megabytes — an answer of `0`
    /// and an answer of `900 KB` round to the same integer and mean very different things.
    /// The call-observer probe brackets its own construction with this, so the cost is read
    /// off the log on a real device instead of being asserted.
    public static func residentKB() -> Int {
        let bytes = physicalFootprintBytes()
        guard bytes >= 0 else { return -1 }
        return Int(bytes / 1024)
    }

    /// Bytes held by live malloc allocations, in KB: what the process has allocated and not
    /// freed, across every malloc zone. Returns -1 when the zones report nothing.
    ///
    /// WHY beside `residentKB` (#992): `phys_footprint` also counts pages malloc has freed
    /// but not yet returned to the system, and that part swings by several MB with no
    /// object retained. Measured on the simulator (2026-11-20, keyboard build ee238f03,
    /// eight 9 s in-keyboard dictations): live heap 15.64 → 15.68 MB while the footprint
    /// went 37 → 36 → 43 MB, the jump being freed small-zone pages counted dirty again. A
    /// footprint that climbs over dictations is a leak only if this number climbs with it.
    public static func liveHeapKB() -> Int {
        var stats = malloc_statistics_t()
        malloc_zone_statistics(nil, &stats)
        guard stats.size_in_use > 0 else { return -1 }
        return stats.size_in_use / 1024
    }

    /// `phys_footprint` in bytes, or -1 when the task info read fails.
    ///
    /// phys_footprint is what iOS uses for the jetsam budget — closer to the "real" number
    /// than resident_size, which excludes compressed pages.
    private static func physicalFootprintBytes() -> Int64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return -1 }
        return Int64(info.phys_footprint)
    }
}
