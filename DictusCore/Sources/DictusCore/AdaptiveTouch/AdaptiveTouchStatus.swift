// DictusCore/Sources/DictusCore/AdaptiveTouch/AdaptiveTouchStatus.swift
//
// What Adaptive touch (#1014) has learned, in one line (#1081): the keyboard logs it at each
// appearance, the Debug app's export writes it beside the file, and the decode tool prints it
// from an exported file. One function for the three, so they never disagree.
import CoreGraphics
import Foundation

/// A summary of an `AdaptiveTouchModel`: counts and offsets, never a letter typed or a tap.
///
/// WHY the learning context: it is the one labelled taps go to, so its counts are what the
/// activation gate (`AdaptiveTouchModel.activeTaps`, `activeSessions`) is waiting on. `active`
/// is read as the decoder reads it (`AdaptiveTouch.personalKeys`): a context of the same
/// geometry in use with a snapshot.
public struct AdaptiveTouchStatus: Equatable, Sendable {
    /// The largest offset of the snapshot's centres, in keycaps (hypotenuse of the two axes).
    public struct Shift: Equatable, Sendable {
        public var keycaps: Float
        public var slot: Int
        /// The letter of `slot`, when the geometry it belongs to is known.
        public var letter: Character?
    }

    /// What the keyboard found in the App Group file while the switch is off.
    public enum Stored: String, Sendable {
        /// The keyboard holds a learner (switch on): nothing read from disk.
        case notRead
        case none
        case yes
        /// Learned before the last reset: the keyboard deletes it once it reads it.
        case stale
        case unreadable
    }

    /// The context summarized, nil when the model holds none.
    public var context: Int?
    /// Labelled taps of the learning context (`Context.accepted`).
    public var labelled: UInt32 = 0
    public var sessions: UInt16 = 0
    /// The learning context has a snapshot (a first promotion happened).
    public var profile = false
    /// Its geometry has a profile the decoder reads.
    public var active = false
    public var promotions: UInt32 = 0
    public var maxShift: Shift?

    /// `geometry` is the keyboard's current letter page when it knows one: its learning
    /// context is summarized. Without one, or when it learned nothing on it, the most
    /// recently used learning context. `letters` names the slots of the geometries it holds.
    /// A model learned before `resetAt` reads as empty: the keyboard drops it at its next
    /// session.
    public init(model: AdaptiveTouchModel, geometry: UInt64? = nil, letters: [UInt64: [Character]] = [:],
                resetAt: TimeInterval = 0) {
        guard model.generation >= resetAt, let c = Self.summarized(model, geometry: geometry) else { return }
        let ctx = model.contexts[c]
        context = c
        labelled = ctx.accepted
        sessions = ctx.sessions
        profile = ctx.hasSnapshot
        active = model.contexts.contains { $0.geometry == ctx.geometry && $0.inUse && $0.hasSnapshot }
        promotions = ctx.promotions
        maxShift = Self.maxShift(model, context: c, letters: letters[ctx.geometry])
    }

    /// `labelled=412 sessions=3 profile=yes active=yes promotions=13 maxShift=0.142@k`.
    public var logFields: String {
        "labelled=\(labelled) sessions=\(sessions) profile=\(profile ? "yes" : "no") active=\(active ? "yes" : "no")"
            + " promotions=\(promotions) maxShift=\(Self.describe(maxShift))"
    }

    /// The summary of a stored file's bytes, as the keyboard would load it: nil data is no file.
    public static func stored(data: Data?, resetAt: TimeInterval) -> (Stored, AdaptiveTouchStatus?) {
        guard let data else { return (.none, nil) }
        guard let model = AdaptiveTouchModel(data: data) else { return (.unreadable, nil) }
        guard model.generation >= resetAt else { return (.stale, nil) }
        return (.yes, AdaptiveTouchStatus(model: model))
    }

    // MARK: - Report

    /// The readable report beside an exported file: the summary line, then each context's
    /// counts and the offset of every key it learned. No letter typed, no tap, no time.
    public static func report(model: AdaptiveTouchModel, letters: [UInt64: [Character]] = [:],
                              resetAt: TimeInterval = 0) -> String {
        let status = AdaptiveTouchStatus(model: model, letters: letters, resetAt: resetAt)
        var lines = ["adaptiveTouchStatus \(status.logFields)"]
        if model.generation < resetAt {
            lines.append("stale: learned before the last reset; the keyboard deletes it at its next session")
        }
        lines.append("file: \(AdaptiveTouchModel.byteCount) bytes, session=\(model.session), "
                     + "generation=\(String(format: "%.3f", model.generation))")
        lines.append("gate: profile from \(AdaptiveTouchModel.candidateTaps) labelled taps, active from "
                     + "\(AdaptiveTouchModel.activeTaps) taps over \(AdaptiveTouchModel.activeSessions) sessions")
        for (c, ctx) in model.contexts.enumerated() where ctx.geometry != 0 {
            let names = letters[ctx.geometry]
            let eligible = ctx.hasSnapshot && ctx.accepted >= UInt32(AdaptiveTouchModel.activeTaps)
                && ctx.sessions >= UInt16(AdaptiveTouchModel.activeSessions)
            lines.append("")
            lines.append("context \(c): geometry=\(String(format: "%016llx", ctx.geometry)) regime=\(ctx.regime)"
                         + " learning=\(yesNo(ctx.learning)) inUse=\(yesNo(ctx.inUse)) snapshot=\(yesNo(ctx.hasSnapshot))"
                         + " eligible=\(yesNo(eligible))\(names == nil ? "" : " keys=named")")
            lines.append("  labelled=\(ctx.accepted) (weak=\(ctx.weak) picked=\(ctx.picked) strong=\(ctx.strong))"
                         + " sessions=\(ctx.sessions) promotions=\(ctx.promotions) sincePromotion=\(ctx.sincePromotion)"
                         + " bin=\(ctx.bin) binFill=\(ctx.binFill)")
            lines.append("  maxShift=\(describe(maxShift(model, context: c, letters: names)))")
            lines.append("  slot\tkey\tweight\tdx\tdy")
            for s in 0..<AdaptiveTouchModel.slotLimit {
                let weight = model.weight(context: c, slot: s)
                let o = model.offset(context: c, slot: s)
                guard weight > 0 || o.x != 0 || o.y != 0 else { continue }
                let key = names.flatMap { s < $0.count ? String($0[s]) : nil } ?? "-"
                lines.append("  \(s)\t\(key)\t\(String(format: "%.1f", weight))\t\(String(format: "%+.3f", o.x))"
                             + "\t\(String(format: "%+.3f", o.y))")
            }
        }
        if !model.contexts.contains(where: { $0.geometry != 0 }) {
            lines.append("")
            lines.append("no context: nothing learned yet")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private

    private static func summarized(_ model: AdaptiveTouchModel, geometry: UInt64?) -> Int? {
        let used = model.contexts.indices.filter { model.contexts[$0].geometry != 0 }
        let onGeometry = used.filter { model.contexts[$0].geometry == geometry }
        let pool = onGeometry.isEmpty ? used : onGeometry
        let learning = pool.filter { model.contexts[$0].learning }
        return (learning.isEmpty ? pool : learning).max { model.contexts[$0].lastUsed < model.contexts[$1].lastUsed }
    }

    private static func maxShift(_ model: AdaptiveTouchModel, context c: Int, letters: [Character]?) -> Shift? {
        guard model.contexts[c].hasSnapshot else { return nil }
        var best: Shift?
        for s in 0..<AdaptiveTouchModel.slotLimit {
            let o = model.offset(context: c, slot: s)
            let length = (o.x * o.x + o.y * o.y).squareRoot()
            guard length > (best?.keycaps ?? 0) else { continue }
            best = Shift(keycaps: length, slot: s, letter: letters.flatMap { s < $0.count ? $0[s] : nil })
        }
        return best ?? Shift(keycaps: 0, slot: 0, letter: nil)
    }

    /// `0.142@k`, `0.142@slot7` when the key is not named, `0` with no snapshot or no offset.
    private static func describe(_ shift: Shift?) -> String {
        guard let shift, shift.keycaps > 0 else { return "0" }
        let key = shift.letter.map(String.init) ?? "slot\(shift.slot)"
        return "\(String(format: "%.3f", shift.keycaps))@\(key)"
    }

    private static func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }
}

// MARK: - Naming an exported file's keys

extension AdaptiveTouchGeometry {
    /// `AdaptiveTouchGeometry.key` for a letter page whose rows hold `rows` (top first, left to
    /// right) and whose key pitch is `width` x `height` quarter points: the signature
    /// `init(keys:)` hashes, rebuilt without a layout.
    public static func key(rows: [[Character]], width: Int, height: Int) -> UInt64 {
        var signature = "\(width):\(height)|"
        var count = 0
        for (r, row) in rows.enumerated() {
            for letter in row where count < AdaptiveTouchModel.slotLimit {
                signature.append(letter)
                signature += "\(r)"
                count += 1
            }
        }
        return hash(signature)
    }

    /// The pitch, in points, at which a letter page holding `rows` has the geometry `key`: the
    /// check that an exported file was learned on those rows, so its slots may be named with
    /// them. Tries every quarter point from 10 to 120 pt on each axis (an iPhone's pitch is
    /// about 40 x 54). Measurement tools only: some 190 000 hashes.
    public static func pitch(of key: UInt64, rows: [[Character]]) -> CGSize? {
        for width in 40...480 {
            for height in 40...480 where Self.key(rows: rows, width: width, height: height) == key {
                return CGSize(width: CGFloat(width) / 4, height: CGFloat(height) / 4)
            }
        }
        return nil
    }
}
