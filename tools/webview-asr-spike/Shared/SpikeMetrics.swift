import Darwin
import Foundation
import os

/// libproc's `proc_pid_rusage` is in the iOS libSystem but not in the iOS SDK
/// headers; declared here for the spike's WebContent footprint probe.
@_silgen_name("proc_pid_rusage")
private func spike_proc_pid_rusage(_ pid: Int32, _ flavor: Int32, _ buffer: UnsafeMutablePointer<rusage_info_t?>) -> Int32

/// Memory and log helpers shared by the app and the keyboard.
enum SpikeMetrics {
    static let appGroup = "group.com.pivi.dictus.spike"

    /// This process's footprint, the figure jetsam compares to its limit.
    static func physFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    /// Bytes this process may still allocate before jetsam (0 on the simulator).
    static func availableMemory() -> UInt64 {
        UInt64(os_proc_available_memory())
    }

    /// Footprint of another process (the WebContent process). Expected to be
    /// refused by the sandbox on a device; the errno is the measurement then.
    static func footprint(ofPID pid: Int32) -> (bytes: UInt64?, errno: Int32) {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                spike_proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? (usage.ri_phys_footprint, 0) : (nil, errno)
    }

    static func megabytes(_ bytes: UInt64) -> Int { Int(bytes / 1_048_576) }
}

/// Append-only JSON-lines log. Written to the spike's App Group when the
/// process can reach it (signing carries the group and, for the keyboard,
/// Full Access is on), otherwise to the process's own Documents folder.
final class SpikeLog: @unchecked Sendable {
    static let shared = SpikeLog()

    let fileURL: URL
    let location: String
    private let queue = DispatchQueue(label: "spike.log")
    private let logger = Logger(subsystem: "com.pivi.dictus.spike", category: "spike")

    private init() {
        let fm = FileManager.default
        let process = Bundle.main.bundleURL.pathExtension == "appex" ? "keyboard" : "app"
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: SpikeMetrics.appGroup),
           (try? fm.createDirectory(at: group.appendingPathComponent("logs"), withIntermediateDirectories: true)) != nil,
           fm.isWritableFile(atPath: group.appendingPathComponent("logs").path) {
            fileURL = group.appendingPathComponent("logs/\(process).jsonl")
            location = "appGroup"
        } else {
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
            fileURL = docs.appendingPathComponent("\(process).jsonl")
            location = "ownContainer"
        }
    }

    func write(_ event: [String: Any]) {
        var entry = event
        entry["ts"] = ISO8601DateFormatter().string(from: Date())
        guard let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]),
              var line = String(data: data, encoding: .utf8) else { return }
        logger.log("\(line, privacy: .public)")
        line += "\n"
        let url = fileURL
        queue.async {
            guard let bytes = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: bytes)
                try? handle.close()
            } else {
                try? bytes.write(to: url)
            }
        }
    }
}
