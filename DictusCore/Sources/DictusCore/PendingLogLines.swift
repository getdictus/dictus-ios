// DictusCore/Sources/DictusCore/PendingLogLines.swift
import Foundation

/// Log text the file refused, kept in memory until it can be written (#868).
///
/// WHY: before the first unlock after a boot the App Group file cannot be opened, and
/// `PersistentLog` used to drop every line silently. A process iOS launched at boot left
/// no `appLaunched` line behind, which is the line every reader splits a log on. Holding
/// the text keeps those lines; they reach the file with the first write that succeeds.
///
/// Bounded, because a device can stay locked for hours with the process alive: past
/// `capacity` chunks the newest ones are counted rather than kept, and the count is
/// written with the held text so a reader knows lines are missing.
struct PendingLogLines {

    /// How many chunks are kept. A chunk is one append: a line, or a line with the
    /// closing `repeated=N` line of the run before it.
    static let capacity = 200

    private(set) var chunks: [String] = []
    private(set) var droppedCount = 0

    var isEmpty: Bool { chunks.isEmpty && droppedCount == 0 }

    /// Keep `text` for later, or count it when the buffer is full.
    mutating func hold(_ text: String) {
        if chunks.count < Self.capacity {
            chunks.append(text)
        } else {
            droppedCount += 1
        }
    }

    /// The held text, followed by one line counting the chunks that did not fit, if any.
    ///
    /// - Parameter timestamp: the time of the counting line, the moment the file became
    ///   writable again.
    func text(timestamp: String) -> String {
        var text = chunks.joined()
        if droppedCount > 0 {
            let event = LogEvent.diagnosticProbe(
                component: "PersistentLog",
                instanceID: "0",
                action: "linesDropped",
                details: "count=\(droppedCount) kept=\(chunks.count) reason=fileUnwritable"
            )
            text += "[\(timestamp)] \(event.payload())\n"
        }
        return text
    }

    mutating func removeAll() {
        chunks.removeAll()
        droppedCount = 0
    }
}
