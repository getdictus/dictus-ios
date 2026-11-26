// DictusCore/Sources/DictusCore/AdaptiveTouch/AdaptiveTouchModel.swift
//
// Ported from Hex (github.com/anomalyco/hex, branch dev, commit be2f394,
// ios/HEXShared/FullKeyboard/AdaptiveTouch.swift: `AdaptiveTouchGeometry` and
// `AdaptiveTouchModel`), MIT, Copyright (c) 2026 Christopher Langton (#1014).
//
// Kept as Hex has it: the sums per physical key in four rotating bins, the shrinkage toward
// the row and the keyboard, the bound and the step, the promotion schedule, the activation
// gate and the fixed-size file with its checksum. Adapted: the geometry is read off the
// spatial decoder's `Keys` (Dictus's letter cells abut and have no split layout, so a key's
// frame is its pitch and a row is one group).
import CoreGraphics
import Foundation

/// The letter keys of one letter page, as Adaptive touch reads taps on them: their slots,
/// frames, rows and pitch. `key` names the geometry coarsely (the letters on each row and
/// the key size), so another key plane of the same size keeps what was learned: offsets
/// are in keycap widths and heights.
public struct AdaptiveTouchGeometry: Equatable {
    public var key: UInt64
    public var letters: [Character]
    public var frames: [CGRect]
    /// Same row, for sharing evidence between neighbours.
    public var groups: [Int]
    public var pitch: CGSize

    public init?(keys: SpatialDecoder.Keys) {
        guard keys.pitch.width > 0, keys.pitch.height > 0 else { return nil }
        // Rows by height, top first; letters left to right within a row.
        let rowYs = Array(Set(keys.centres.values.map { ($0.y * 4).rounded() })).sorted()
        let sorted = keys.centres.sorted { a, b in
            let ra = (a.value.y * 4).rounded(), rb = (b.value.y * 4).rounded()
            return ra != rb ? ra < rb : a.value.x < b.value.x
        }
        var letters: [Character] = []
        var frames: [CGRect] = []
        var groups: [Int] = []
        var signature = "\(Int((keys.pitch.width * 4).rounded())):\(Int((keys.pitch.height * 4).rounded()))|"
        for (letter, centre) in sorted where letters.count < AdaptiveTouchModel.slotLimit {
            guard let row = rowYs.firstIndex(of: (centre.y * 4).rounded()) else { continue }
            letters.append(letter)
            frames.append(CGRect(x: centre.x - keys.pitch.width / 2, y: centre.y - keys.pitch.height / 2,
                                 width: keys.pitch.width, height: keys.pitch.height))
            groups.append(row)
            signature.append(letter)
            signature += "\(row)"
        }
        guard !letters.isEmpty else { return nil }
        self.letters = letters
        self.frames = frames
        self.groups = groups
        self.pitch = keys.pitch
        key = Self.hash(signature)
    }

    /// FNV-1a, stable across launches (Swift's `Hasher` is seeded per process).
    public static func hash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100_0000_01B3
        }
        return h == 0 ? 1 : h
    }

    /// The key whose cell holds `point`.
    public func slot(at point: CGPoint) -> Int? {
        frames.firstIndex { $0.contains(point) }
    }

    /// The key for `letter`.
    public func slot(for letter: Character) -> Int? {
        letters.firstIndex(of: letter)
    }
}

/// Adaptive touch's averages: fixed-size sums per physical key, in four rotating bins of
/// `binTaps` labelled taps for each context (a keyboard geometry and a grip regime), and the
/// frozen centre offsets the decoder reads. No letters, words, times or tap sequences; the
/// whole thing serializes to `byteCount` bytes.
public struct AdaptiveTouchModel: Equatable {
    public static let contextLimit = 8
    public static let slotLimit = 40
    public static let binCount = 4
    /// Labelled taps per bin: the newest 600–800 count once all four are full.
    public static let binTaps = 200
    /// A candidate forms from this many labelled taps in a context, and is promoted every
    /// `promotionEvery` more.
    public static let candidateTaps = 100
    public static let promotionEvery = 25
    /// The decoder reads a context's centres only after this many labelled taps over
    /// `activeSessions` keyboard sessions.
    public static let activeTaps = 400
    public static let activeSessions = 3
    /// Each axis of an offset stays within this many keycaps (about a quarter key pitch), and a
    /// promotion moves it at most `step`.
    public static let bound: Float = 0.3
    public static let step: Float = 0.05
    /// Prior strengths (in weak-label taps) pulling a key to its row, the row to the whole
    /// keyboard, and the keyboard to the stock centre.
    public static let keyPrior: Float = 20
    public static let groupPrior: Float = 50
    public static let allPrior: Float = 40

    static let fieldsPerBin = 4
    static var statCount: Int { contextLimit * slotLimit * binCount * fieldsPerBin }
    static var snapshotCount: Int { contextLimit * slotLimit * 2 }

    public struct Context: Equatable {
        /// `AdaptiveTouchGeometry.key`; 0 for a free slot.
        public var geometry: UInt64 = 0
        public var regime: UInt8 = 0
        public var hasSnapshot = false
        /// The decoder reads this context's snapshot.
        public var inUse = false
        /// Labelled taps go to this regime of its geometry.
        public var learning = false
        var bin: UInt8 = 0
        var binFill: UInt16 = 0
        public var sessions: UInt16 = 0
        var lastUsed: UInt32 = 0
        public var accepted: UInt32 = 0
        var sessionStamp: UInt32 = 0
        var sincePromotion: UInt32 = 0
        public var promotions: UInt32 = 0
        /// Labelled taps by evidence: kept as typed, a picked suggestion, a retype or undo.
        public var weak: UInt32 = 0
        public var picked: UInt32 = 0
        public var strong: UInt32 = 0

    }

    /// The reset generation this model was learned under (`AdaptiveTouchStore.resetAt`).
    public var generation: TimeInterval = 0
    var clock: UInt32 = 0
    public var session: UInt32 = 0
    public var contexts = [Context](repeating: Context(), count: contextLimit)
    /// [context][slot][bin][W, Σw², Σw·x, Σw·y], in keycaps.
    var stats = [Float](repeating: 0, count: statCount)
    /// [context][slot][x, y]: the frozen offsets, in keycaps.
    var snapshot = [Float](repeating: 0, count: snapshotCount)

    public init() {}

    @inline(__always) static func statIndex(_ context: Int, _ slot: Int, _ bin: Int) -> Int {
        ((context * slotLimit + slot) * binCount + bin) * fieldsPerBin
    }

    public func offset(context: Int, slot: Int) -> (x: Float, y: Float) {
        let i = (context * Self.slotLimit + slot) * 2
        return (snapshot[i], snapshot[i + 1])
    }

    public func context(geometry: UInt64, regime: UInt8) -> Int? {
        contexts.firstIndex { $0.geometry == geometry && $0.regime == regime }
    }

    /// The slot for a geometry and regime, taking the least recently used one if it is new.
    mutating func ensureContext(geometry: UInt64, regime: UInt8) -> Int {
        clock &+= 1
        if let found = context(geometry: geometry, regime: regime) {
            contexts[found].lastUsed = clock
            return found
        }
        let free = contexts.firstIndex { $0.geometry == 0 }
            ?? contexts.indices.min { contexts[$0].lastUsed < contexts[$1].lastUsed } ?? 0
        clear(free)
        contexts[free].geometry = geometry
        contexts[free].regime = regime
        contexts[free].lastUsed = clock
        return free
    }

    mutating func clear(_ c: Int) {
        contexts[c] = Context()
        let start = Self.statIndex(c, 0, 0)
        for i in start..<(start + Self.slotLimit * Self.binCount * Self.fieldsPerBin) { stats[i] = 0 }
        for i in (c * Self.slotLimit * 2)..<((c + 1) * Self.slotLimit * 2) { snapshot[i] = 0 }
    }

    /// One labelled tap, `x` and `y` its offset from the key's centre in keycaps. O(1), but a
    /// full bin rotates (O(keys)).
    mutating func add(context c: Int, slot: Int, x: Float, y: Float, weight w: Float) {
        let bin = Int(contexts[c].bin)
        let i = Self.statIndex(c, slot, bin)
        stats[i] += w
        stats[i + 1] += w * w
        stats[i + 2] += w * x
        stats[i + 3] += w * y
        contexts[c].accepted &+= 1
        contexts[c].sincePromotion &+= 1
        contexts[c].binFill &+= 1
        if contexts[c].binFill >= UInt16(Self.binTaps) {
            let next = (bin + 1) % Self.binCount
            for s in 0..<Self.slotLimit {
                let j = Self.statIndex(c, s, next)
                stats[j] = 0
                stats[j + 1] = 0
                stats[j + 2] = 0
                stats[j + 3] = 0
            }
            contexts[c].bin = UInt8(next)
            contexts[c].binFill = 0
        }
    }

    /// Rebuilds a context's frozen offsets from its bins: each key's mean shrunk toward its
    /// row's (`keyPrior`), the row's toward the keyboard's (`groupPrior`), that toward zero
    /// (`allPrior`); bounded, and at most `step` from the last snapshot.
    mutating func promote(context c: Int, groups: [Int]) {
        let slots = min(groups.count, Self.slotLimit)
        var w = [Float](repeating: 0, count: slots)
        var sx = [Float](repeating: 0, count: slots)
        var sy = [Float](repeating: 0, count: slots)
        var gw: [Int: Float] = [:], gx: [Int: Float] = [:], gy: [Int: Float] = [:]
        var aw: Float = 0, ax: Float = 0, ay: Float = 0
        for s in 0..<slots {
            for b in 0..<Self.binCount {
                let i = Self.statIndex(c, s, b)
                w[s] += stats[i]
                sx[s] += stats[i + 2]
                sy[s] += stats[i + 3]
            }
            gw[groups[s], default: 0] += w[s]
            gx[groups[s], default: 0] += sx[s]
            gy[groups[s], default: 0] += sy[s]
            aw += w[s]
            ax += sx[s]
            ay += sy[s]
        }
        let allX = ax / (aw + Self.allPrior), allY = ay / (aw + Self.allPrior)
        for s in 0..<slots {
            let g = groups[s]
            let rowW = gw[g] ?? 0
            let rowX = ((gx[g] ?? 0) + Self.groupPrior * allX) / (rowW + Self.groupPrior)
            let rowY = ((gy[g] ?? 0) + Self.groupPrior * allY) / (rowW + Self.groupPrior)
            let keyX = (sx[s] + Self.keyPrior * rowX) / (w[s] + Self.keyPrior)
            let keyY = (sy[s] + Self.keyPrior * rowY) / (w[s] + Self.keyPrior)
            let i = (c * Self.slotLimit + s) * 2
            let oldX = snapshot[i], oldY = snapshot[i + 1]
            snapshot[i] = Self.clamp(Self.clamp(keyX, -Self.bound, Self.bound), oldX - Self.step, oldX + Self.step)
            snapshot[i + 1] = Self.clamp(Self.clamp(keyY, -Self.bound, Self.bound), oldY - Self.step, oldY + Self.step)
        }
        contexts[c].hasSnapshot = true
        contexts[c].sincePromotion = 0
        contexts[c].promotions &+= 1
    }

    /// The taps learned on `slot` of context `c`, as a total weight (bench and tests).
    public func weight(context c: Int, slot: Int) -> Float {
        (0..<Self.binCount).reduce(0) { $0 + stats[Self.statIndex(c, slot, $1)] }
    }

    private static func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(hi, max(lo, v)) }

    // MARK: - File

    static let magic: UInt32 = 0x5441_5844 // "DXAT"
    static let version: UInt32 = 1
    static let headerBytes = 32
    static let contextBytes = 64
    /// The serialized size: always this, whatever was learned.
    public static var byteCount: Int { headerBytes + contextLimit * contextBytes + 4 * (statCount + snapshotCount) + 4 }

    public func serialized() -> Data {
        var out = Data(capacity: Self.byteCount)
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) } }
        put(Self.magic)
        put(Self.version)
        put(generation.bitPattern)
        put(clock)
        put(session)
        put(UInt32(Self.contextLimit))
        put(UInt32(Self.slotLimit))
        for c in contexts {
            let start = out.count
            put(c.geometry)
            put(c.regime)
            put(UInt8((c.hasSnapshot ? 1 : 0) | (c.inUse ? 2 : 0) | (c.learning ? 4 : 0)))
            put(c.bin)
            put(UInt8(0))
            put(c.binFill)
            put(c.sessions)
            for v in [c.lastUsed, c.accepted, c.sessionStamp, c.sincePromotion, c.promotions, c.weak, c.picked, c.strong] {
                put(v)
            }
            out.append(contentsOf: [UInt8](repeating: 0, count: Self.contextBytes - (out.count - start)))
        }
        for v in stats { put(v.bitPattern) }
        for v in snapshot { put(v.bitPattern) }
        put(Self.checksum(out))
        return out
    }

    /// Nil for anything but a whole, unchanged file of this version.
    public init?(data: Data) {
        guard data.count == Self.byteCount else { return nil }
        let bytes = [UInt8](data)
        guard Self.checksum(Data(bytes[0..<(bytes.count - 4)])) == Self.read(UInt32.self, bytes, bytes.count - 4)
        else { return nil }
        var at = 0
        func get<T: FixedWidthInteger>(_: T.Type) -> T {
            let v = Self.read(T.self, bytes, at)
            at += MemoryLayout<T>.size
            return v
        }
        guard get(UInt32.self) == Self.magic, get(UInt32.self) == Self.version else { return nil }
        generation = TimeInterval(bitPattern: get(UInt64.self))
        clock = get(UInt32.self)
        session = get(UInt32.self)
        guard get(UInt32.self) == UInt32(Self.contextLimit), get(UInt32.self) == UInt32(Self.slotLimit) else { return nil }
        for i in 0..<Self.contextLimit {
            let start = at
            var c = Context()
            c.geometry = get(UInt64.self)
            c.regime = get(UInt8.self)
            let flags = get(UInt8.self)
            c.hasSnapshot = flags & 1 != 0
            c.inUse = flags & 2 != 0
            c.learning = flags & 4 != 0
            c.bin = min(get(UInt8.self), UInt8(Self.binCount - 1))
            _ = get(UInt8.self)
            c.binFill = get(UInt16.self)
            c.sessions = get(UInt16.self)
            c.lastUsed = get(UInt32.self)
            c.accepted = get(UInt32.self)
            c.sessionStamp = get(UInt32.self)
            c.sincePromotion = get(UInt32.self)
            c.promotions = get(UInt32.self)
            c.weak = get(UInt32.self)
            c.picked = get(UInt32.self)
            c.strong = get(UInt32.self)
            at = start + Self.contextBytes
            contexts[i] = c
        }
        for i in 0..<Self.statCount { stats[i] = Float(bitPattern: get(UInt32.self)) }
        for i in 0..<Self.snapshotCount { snapshot[i] = Float(bitPattern: get(UInt32.self)) }
        guard stats.allSatisfy(\.isFinite), snapshot.allSatisfy({ $0.isFinite && abs($0) <= Self.bound }) else { return nil }
    }

    private static func read<T: FixedWidthInteger>(_: T.Type, _ bytes: [UInt8], _ at: Int) -> T {
        var v = T.zero
        withUnsafeMutableBytes(of: &v) { raw in
            for k in 0..<MemoryLayout<T>.size { raw[k] = bytes[at + k] }
        }
        return T(littleEndian: v)
    }

    private static func checksum(_ data: Data) -> UInt32 {
        var h: UInt32 = 0x811C_9DC5
        for byte in data { h = (h ^ UInt32(byte)) &* 0x0100_0193 }
        return h
    }
}
