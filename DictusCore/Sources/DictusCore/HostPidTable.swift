// DictusCore/Sources/DictusCore/HostPidTable.swift
// What the keyboard has learned about which process is which app (#23).
import Foundation

/// Maps process identifiers to host app bundle identifiers, and refuses to answer when
/// the answer could be wrong.
///
/// ## The one property this type exists to hold
///
/// **It may return nothing. It may never return the wrong thing.**
///
/// A missing answer costs the automatic return, and the user gets the swipe-back overlay
/// they have had since March. A wrong answer opens an app they were not in — and, worse,
/// relaunches one they had deliberately closed. The whole design of #23 is built to trade
/// the second failure for the first, and every rule below is in service of that.
///
/// ## Why a bare `[pid: bundleId]` dictionary is unsafe
///
/// iOS recycles process identifiers, and a keyboard extension can live for hours. Suppose
/// the keyboard learns `44177 → com.apple.mobilenotes`, Notes is killed, and some other
/// app is later assigned pid 44177. Until the arbiter happens to name that pid again, the
/// table cheerfully answers "Notes" for a process that is not Notes, and the app opens the
/// wrong one.
///
/// The protection cannot come from asking the system what a pid is: `proc_pidpath` and
/// `sysctl(KERN_PROC_PID)` both return `EPERM` inside a keyboard extension — measured on
/// device, 7 attempts, 2026-09-11. A sandboxed extension cannot observe another process at
/// all, so the only evidence available is what the keyboard arbiter has said and when.
///
/// ## The rule
///
/// **An entry is only trusted while the appearance that recorded it is still current.**
/// Every time the keyboard appears — which is what happens when the user moves to another
/// app — the generation advances, and entries harvested under an older generation stop
/// being answers. They stay in the table as history, because the count of what has ever
/// been learned is worth having in a log line, but they cannot be returned.
///
/// That is fail-closed by construction: a recycled pid inherited from an earlier
/// appearance is never trusted, and the worst case is a miss. It costs little in practice
/// because the harvest runs on every appearance, every keystroke, every caret move and at
/// the mic tap — a host the arbiter names at all is almost always named within the
/// appearance it is the host of.
///
/// A contradiction is also handled: if the arbiter names a pid with a *different* bundle
/// identifier than the one on file, the new value wins outright. The arbiter's latest word
/// about a pid is better evidence than the table's memory of it.
public struct HostPidTable: Equatable {

    /// One learned pairing, and the appearance it was learned in.
    private struct Entry: Equatable {
        let bundleId: String
        var generation: Int
    }

    /// The most entries kept. Oldest evicted first.
    ///
    /// A keyboard process that outlived 64 distinct host apps has never been observed, and
    /// each entry is a few tens of bytes — but this runs in an extension under a ~50 MB
    /// ceiling, where "it will never get big" is the kind of assumption that turns up in a
    /// jetsam report.
    public static let maxEntries = 64

    private var entries: [Int: Entry] = [:]
    private var insertionOrder: [Int] = []
    private var generation = 0

    public init() {}

    /// How many pairings have ever been learned, trusted or not. For the log line only.
    public var count: Int { entries.count }

    /// How many pairings are currently trusted, i.e. harvested during this appearance.
    public var trustedCount: Int { entries.values.count { $0.generation == generation } }

    /// Advances the generation. Called when the keyboard appears.
    ///
    /// The keyboard appearing is the event that can change the host, so it is the event
    /// that retires the previous appearance's evidence.
    public mutating func noteAppearance() {
        generation &+= 1
    }

    /// Records what the arbiter says about `pid`, as evidence for this appearance.
    ///
    /// Ignores empty identifiers and non-positive pids: both mean the arbiter answered
    /// with nothing useful, and writing them would put a value in the table that can never
    /// be right.
    public mutating func record(bundleId: String, forPid pid: Int) {
        guard !bundleId.isEmpty, pid > 0 else { return }

        if entries[pid] == nil {
            insertionOrder.append(pid)
            if insertionOrder.count > Self.maxEntries {
                let evicted = insertionOrder.removeFirst()
                entries[evicted] = nil
            }
        }
        // A different bundle for a known pid is the pid having been reused. The fresh
        // observation replaces the old one rather than being merged with it.
        entries[pid] = Entry(bundleId: bundleId, generation: generation)
    }

    /// The bundle identifier for `pid`, or nil when there is no answer that can be trusted.
    ///
    /// Nil for a pid never seen **and** for one last confirmed in an earlier appearance.
    /// The caller must treat both the same way: no automatic return, show the overlay.
    public func bundleId(forPid pid: Int) -> String? {
        guard let entry = entries[pid], entry.generation == generation else { return nil }
        return entry.bundleId
    }

    /// Whether `pid` is known at all, regardless of whether it is still trusted. Exists so
    /// a log line can distinguish "never heard of this process" from "heard of it, in an
    /// appearance that has since been retired" — two different stories about a miss.
    public func hasEverSeen(pid: Int) -> Bool {
        entries[pid] != nil
    }
}
