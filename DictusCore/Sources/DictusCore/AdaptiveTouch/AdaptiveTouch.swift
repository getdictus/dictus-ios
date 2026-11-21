// DictusCore/Sources/DictusCore/AdaptiveTouch/AdaptiveTouch.swift
//
// Ported from Hex (github.com/anomalyco/hex, branch dev, commit be2f394,
// ios/HEXShared/FullKeyboard/AdaptiveTouch.swift and AdaptiveTouchLabels.swift:
// `AdaptiveTouch`, `AdaptiveTouchSettings`), MIT, Copyright (c) 2026 Christopher Langton (#1014).
//
// Kept as Hex has it: the label weights, the miss and Huber radii, the fit monitor that
// engages a profile only while it reads recent taps better than the stock centres and drops
// it at once when it reads them worse, the second grip profile, the reset generation, and
// writes in batches off the calling thread.
// Adapted: the averages live in a file in the App Group container (Dictus keeps every
// learned thing there, and the app has to delete it with the learned words), excluded from
// backup and protected until first unlock; the decoder reads `SpatialDecoder.Keys` instead
// of Hex's layout.
import CoreGraphics
import Foundation

/// Where Adaptive touch's averages are, and the reset every keyboard obeys.
public enum AdaptiveTouchStore {
    /// App Group key: when the averages were last reset. A keyboard holding older ones, in
    /// memory or on disk, drops them.
    public static let resetAtKey = "adaptiveTouch.resetAt"
    static let fileName = "adaptive-touch.bin"

    /// The App Group file, or nil without the App Group (no Full Access).
    public static var defaultURL: URL? {
        AppGroup.containerURL?
            .appendingPathComponent("AdaptiveTouch", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func resetAt(_ defaults: UserDefaults?) -> TimeInterval {
        defaults?.double(forKey: resetAtKey) ?? 0
    }

    /// Forgets what every keyboard learned: deletes the file and bumps the generation, so a
    /// keyboard running now drops its copy at its next tap or session.
    public static func requestReset(
        defaults: UserDefaults? = AppGroup.defaults, url: URL? = defaultURL,
        now: TimeInterval = Date().timeIntervalSince1970
    ) {
        defaults?.set(max(now, resetAt(defaults) + 0.001), forKey: resetAtKey)
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}

/// Adaptive touch for one keyboard process: the model, the labels it admits
/// (`AdaptiveTouchSpans`), which grip regime fits, and the personal centres the decoder
/// reads. Not thread-safe: the keyboard calls it on the main thread, as it types.
public final class AdaptiveTouch {
    public enum Storage: Equatable {
        case file(URL)
        case memory
    }

    /// For replays: `.frozen` reads the centres and learns nothing; `.monitor` also watches
    /// how they fit (and falls back) without adding to the averages.
    public enum Mode {
        case learn
        case monitor
        case frozen
    }

    /// Grip regimes: the profile in use falls back to the stock centres once it fits recent
    /// taps worse than they do (mean log-likelihood gain per tap and axis, nats, over the last
    /// `monitorWindow` labels). Labels then teach the other regime, and a profile is taken
    /// back once it fits better again on both axes.
    static let monitorWindow = 32
    static let monitorMinimum = 16
    static let disengageAxis: Float = -0.06
    static let disengageGain: Float = -0.1
    static let switchAxis: Float = -0.08
    static let switchGain: Float = -0.12
    static let engageAxis: Float = -0.02
    /// Label weights: a word kept as typed, a picked suggestion, a retype or an undone fix.
    public static let weakQuality: Float = 1
    public static let pickedQuality: Float = 2
    public static let strongQuality: Float = 3
    /// Residuals past this many key pitches are misses, not aims; past `huberPitches` they count less.
    static let missPitches: CGFloat = 1.5
    static let huberPitches: CGFloat = 0.6
    /// How far an erased tap may be from the key of the letter that replaced it: a neighbour,
    /// diagonals included.
    static let neighbourPitches: CGFloat = 1.25
    /// At most this many weak labels per word, as Hex.
    static let weakPerWord = 12
    static let saveEvery = 400

    public let storage: Storage
    private let defaults: UserDefaults?
    public private(set) var model: AdaptiveTouchModel
    public var mode: Mode = .learn
    /// Hex's activation gate: labelled taps and keyboard sessions before a profile may be
    /// used. The bench changes them to measure the gate; the keyboard keeps Hex's.
    public var activeTaps = AdaptiveTouchModel.activeTaps
    public var activeSessions = AdaptiveTouchModel.activeSessions
    /// Seconds, for the labels' timeout. The bench replaces it with the run's own clock.
    public var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    /// Bumped whenever the centres the decoder should read change (a promotion, a fallback).
    public private(set) var version = 0
    public private(set) var geometry: AdaptiveTouchGeometry?
    public private(set) var spans = AdaptiveTouchSpans()
    /// [context][window][x, y]: each recent label's log-likelihood gain of the context's
    /// centres over the stock ones, per axis. Memory only.
    private var gains = [Float](repeating: 0, count: AdaptiveTouchModel.contextLimit * AdaptiveTouch.monitorWindow * 2)
    private var gainCount = [Int](repeating: 0, count: AdaptiveTouchModel.contextLimit)
    private var gainHead = [Int](repeating: 0, count: AdaptiveTouchModel.contextLimit)
    private var unsaved = 0
    /// The personal centres last handed out, for the stock keys and model version they came from.
    private struct KeysCache {
        var stock: SpatialDecoder.Keys
        var version: Int
        var personal: SpatialDecoder.Keys?
    }
    private var keysCache: KeysCache?
    private static let writer = DispatchQueue(label: "solutions.pivi.dictus.adaptive-touch.writer", qos: .utility)

    /// `defaults` holds the reset generation (the App Group's in the keyboard; nil in the
    /// bench, which no reset reaches).
    public init(storage: Storage, defaults: UserDefaults?) {
        self.storage = storage
        self.defaults = defaults
        var model = AdaptiveTouchModel()
        let resetAt = AdaptiveTouchStore.resetAt(defaults)
        if case .file(let url) = storage {
            if let data = try? Data(contentsOf: url), let loaded = AdaptiveTouchModel(data: data), loaded.generation >= resetAt {
                model = loaded
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
        model.generation = max(model.generation, resetAt)
        self.model = model
    }

    /// A model to start from, for the bench (a profile learned on another session).
    public init(model: AdaptiveTouchModel) {
        storage = .memory
        defaults = nil
        self.model = model
    }

    // MARK: - Decoder

    /// The centres the decoder should read the taps with, for the stock `keys`: moved by
    /// the personal offsets, or nil when this geometry has no profile in use (thin evidence,
    /// a new size, or a grip the profile doesn't fit). Also keeps the geometry labels are
    /// read against.
    public func personalKeys(for keys: SpatialDecoder.Keys) -> SpatialDecoder.Keys? {
        sync(keys)
        if let cache = keysCache, cache.version == version, cache.stock == keys { return cache.personal }
        var personal: SpatialDecoder.Keys?
        if let geometry,
           let c = model.contexts.firstIndex(where: { $0.geometry == geometry.key && $0.inUse && $0.hasSnapshot }) {
            var moved = keys
            var changed = false
            for s in geometry.letters.indices {
                let o = model.offset(context: c, slot: s)
                guard o.x != 0 || o.y != 0, let centre = keys.centres[geometry.letters[s]] else { continue }
                moved.centres[geometry.letters[s]] = CGPoint(
                    x: centre.x + CGFloat(o.x) * geometry.frames[s].width,
                    y: centre.y + CGFloat(o.y) * geometry.frames[s].height
                )
                changed = true
            }
            personal = changed ? moved : nil
        }
        keysCache = KeysCache(stock: keys, version: version, personal: personal)
        return personal
    }

    /// A new letter page: keeps its geometry, and forgets taps typed on another.
    private func sync(_ keys: SpatialDecoder.Keys) {
        if let cache = keysCache, cache.stock == keys, geometry != nil { return }
        let next = AdaptiveTouchGeometry(keys: keys)
        guard next != geometry else { return }
        if next?.key != geometry?.key || next?.frames != geometry?.frames { spans.forget() }
        geometry = next
        keysCache = nil
    }

    /// Whether personal centres are in use for the current geometry.
    public var isActive: Bool {
        guard let geometry else { return false }
        return model.contexts.contains { $0.geometry == geometry.key && $0.inUse }
    }

    // MARK: - Sessions and reset

    /// A keyboard session began (the keyboard appeared, or a new field).
    public func beginSession() {
        spans.forget()
        model.session &+= 1
        applyResetIfNeeded()
    }

    /// Drops everything when a reset ran since this was learned.
    public func applyResetIfNeeded() {
        let resetAt = AdaptiveTouchStore.resetAt(defaults)
        guard resetAt > model.generation else { return }
        let hadProfile = model.contexts.contains(where: \.inUse)
        model = AdaptiveTouchModel()
        model.generation = resetAt
        spans.forget()
        for i in gainCount.indices {
            gainCount[i] = 0
            gainHead[i] = 0
        }
        unsaved = 0
        if case .file(let url) = storage { try? FileManager.default.removeItem(at: url) }
        if hadProfile { changed() }
    }

    /// Writes the averages off the calling thread, never over a newer reset.
    public func save() {
        applyResetIfNeeded()
        guard case .file(let url) = storage, unsaved > 0 else { return }
        unsaved = 0
        let data = model.serialized()
        let generation = model.generation
        let defaults = defaults
        Self.writer.async {
            guard AdaptiveTouchStore.resetAt(defaults) <= generation else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            Self.write(data, to: url)
        }
    }

    /// Blocks until queued writes finished (tests).
    public static func waitForWrites() {
        writer.sync {}
    }

    private static func write(_ data: Data, to url: URL) {
        let folder = url.deletingLastPathComponent()
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        #if os(iOS)
        let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        let options: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        let protection: [FileAttributeKey: Any] = [:]
        let options: Data.WritingOptions = [.atomic]
        #endif
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: protection)
        var folderURL = folder
        try? folderURL.setResourceValues(excluded)
        guard (try? data.write(to: url, options: options)) != nil else { return }
        var fileURL = url
        try? fileURL.setResourceValues(excluded)
    }

    // MARK: - What the keyboard tells it

    /// A letter key typed `letter` on a tap at `point` (nil: a popup or swiped key, or a
    /// point the keyboard did not keep). `slid`: the finger slid onto the key.
    public func typed(_ letter: String, at point: CGPoint?, slid: Bool, keys: SpatialDecoder.Keys?) {
        guard mode != .frozen else { return }
        guard let keys, let point, let first = AdaptiveTouchSpans.letters(letter).first, letter.count == 1 else {
            return spans.untracked()
        }
        sync(keys)
        guard let geometry else { return spans.untracked() }
        spans.typed(AdaptiveTouchTap(x: Float(point.x), y: Float(point.y), letter: first, usable: !slid),
                    geometry: geometry.key, now: clock())
    }

    /// Backspace is about to delete the last character of `before`.
    public func willDelete(before: String?) {
        spans.willDelete(before: before)
    }

    /// Undo put `original` back over the autocorrection.
    public func undone(original: String) {
        spans.undone(original: original)
    }

    public func forget() {
        spans.forget()
    }

    /// The host changed the text or the cursor moved; `before` is the text before the cursor.
    public func hostChanged(before: String?) {
        guard !spans.isEmpty else { return }
        spans.hostChanged(before: before, token: SpatialTouchBuffer.token(before: before))
    }

    /// The word being typed ended (space, return, a mark); `corrected` when autocorrect
    /// replaced it, `previousRevised` when it is changing the word before too. `before` is
    /// the text before the cursor, still ending in the word. Words before it that stood
    /// teach now; this one waits for the next.
    public func finish(corrected: String? = nil, previousRevised: Bool = false, before: String?) {
        let token = SpatialTouchBuffer.token(before: before)
        admit(spans.finish(token: token, corrected: corrected, previousRevised: previousRevised, before: before, now: clock()))
    }

    /// A suggestion is about to replace the word being typed (`before` ends in it).
    public func picked(replacement: String, overCorrection: Bool, before: String?) {
        let token = SpatialTouchBuffer.token(before: before)
        admit(spans.finish(token: token, picked: replacement, overCorrection: overCorrection, before: before, now: clock()))
    }

    private func admit(_ stood: [AdaptiveTouchSpans.Span]) {
        guard let geometry else { return }
        for span in stood where span.geometry == geometry.key && span.outcome != .corrected {
            var weak = 0
            for (i, tap) in span.taps.enumerated() where i < span.labels.count {
                let label = span.labels[i]
                if span.retyped, let erased = tap.erasedLetter, erased != tap.letter {
                    // The erased tap meant the letter that replaced it: a neighbour, not a miss.
                    let at = tap.erasedPoint
                    if let slot = geometry.slot(for: label), geometry.slot(at: at) != slot,
                       Self.pitches(at, geometry.frames[slot], geometry) <= Self.neighbourPitches {
                        admit(slot: slot, point: at, quality: Self.strongQuality)
                    }
                }
                guard tap.usable, let slot = geometry.slot(for: label) else { continue }
                switch span.outcome {
                case .typed:
                    // Only what the key under the finger typed.
                    guard geometry.slot(at: tap.point) == slot, weak < Self.weakPerWord else { continue }
                    weak += 1
                    admit(slot: slot, point: tap.point, quality: Self.weakQuality)
                case .kept:
                    admit(slot: slot, point: tap.point, quality: Self.strongQuality)
                case .picked:
                    admit(slot: slot, point: tap.point, quality: Self.pickedQuality)
                case .corrected:
                    break
                }
            }
        }
    }

    private static func pitches(_ point: CGPoint, _ frame: CGRect, _ geometry: AdaptiveTouchGeometry) -> CGFloat {
        let x = (point.x - frame.midX) / geometry.pitch.width
        let y = (point.y - frame.midY) / geometry.pitch.height
        return (x * x + y * y).squareRoot()
    }

    /// One tap with evidence of the letter it meant: `quality` is a label weight, `point`
    /// where the finger was. O(1): sums, a bin and the fit monitor; a promotion every
    /// `promotionEvery` taps.
    func admit(slot: Int, point: CGPoint, quality: Float) {
        applyResetIfNeeded()
        guard mode != .frozen, let geometry, geometry.letters.indices.contains(slot) else { return }
        let frame = geometry.frames[slot]
        guard frame.width > 0, frame.height > 0 else { return }
        let x = (point.x - frame.midX) / frame.width
        let y = (point.y - frame.midY) / frame.height
        let px = (point.x - frame.midX) / geometry.pitch.width
        let py = (point.y - frame.midY) / geometry.pitch.height
        let distance = (px * px + py * py).squareRoot()
        guard x.isFinite, y.isFinite, distance <= Self.missPitches else { return }
        let shrink = Float(min(1, Self.huberPitches / max(0.000_1, distance)))

        // How each profile of this geometry fits the tap, before the tap teaches anything.
        let parameters = SpatialDecoder.Parameters()
        let sx = Float(parameters.sigmaX * Double(geometry.pitch.width / frame.width))
        let sy = Float(parameters.sigmaY * Double(geometry.pitch.height / frame.height))
        let rx = Float(x) * shrink, ry = Float(y) * shrink
        for c in model.contexts.indices where model.contexts[c].geometry == geometry.key && model.contexts[c].hasSnapshot {
            let o = model.offset(context: c, slot: slot)
            pushGain(x: (rx * o.x - 0.5 * o.x * o.x) / (sx * sx), y: (ry * o.y - 0.5 * o.y * o.y) / (sy * sy), context: c)
        }

        if mode == .learn {
            let learning = learningContext(for: geometry.key)
            if model.contexts[learning].sessionStamp != model.session {
                model.contexts[learning].sessionStamp = model.session
                model.contexts[learning].sessions &+= 1
            }
            model.add(context: learning, slot: slot, x: Float(x), y: Float(y), weight: quality * shrink)
            if quality >= Self.strongQuality {
                model.contexts[learning].strong &+= 1
            } else if quality >= Self.pickedQuality {
                model.contexts[learning].picked &+= 1
            } else {
                model.contexts[learning].weak &+= 1
            }
            let ctx = model.contexts[learning]
            if ctx.accepted >= UInt32(AdaptiveTouchModel.candidateTaps),
               ctx.sincePromotion >= UInt32(AdaptiveTouchModel.promotionEvery) {
                model.promote(context: learning, groups: geometry.groups)
                if model.contexts[learning].inUse { changed() }
            }
            unsaved += 1
            if unsaved >= Self.saveEvery { save() }
        }
        decideRegime(geometry: geometry.key)
    }

    /// The regime of `geometry` labels go to, making its first one.
    private func learningContext(for geometry: UInt64) -> Int {
        if let c = model.contexts.firstIndex(where: { $0.geometry == geometry && $0.learning }) {
            model.clock &+= 1
            model.contexts[c].lastUsed = model.clock
            return c
        }
        let c = model.ensureContext(geometry: geometry, regime: 0)
        model.contexts[c].learning = true
        return c
    }

    /// Falls back to the stock centres when the profile in use fits recent taps worse than
    /// they do; lets labels teach the other regime when the learning one stopped fitting (a
    /// new grip); takes a profile into use once it has the evidence and fits.
    private func decideRegime(geometry: UInt64) {
        let regimes = model.contexts.indices.filter { model.contexts[$0].geometry == geometry }
        var didChange = false
        for c in regimes where model.contexts[c].inUse && gainCount[c] >= Self.monitorMinimum
            && misfits(c, axis: Self.disengageAxis, total: Self.disengageGain) {
            model.contexts[c].inUse = false
            didChange = true
        }
        // The window and its newest quarter agree the learning profile, which had the evidence
        // to be used, stopped fitting. (Before that, a new grip only mixes into what is learned
        // and nothing is in use.)
        if mode == .learn, let learning = regimes.first(where: { model.contexts[$0].learning }),
           isEligible(learning), gainCount[learning] >= Self.monitorMinimum + 8,
           misfits(learning, axis: Self.switchAxis, total: Self.switchGain), recentGain(learning) < 0 {
            let regime: UInt8 = model.contexts[learning].regime == 0 ? 1 : 0
            let next: Int
            if let other = model.context(geometry: geometry, regime: regime) {
                // The other profile fits the newest taps: that grip is back. One that doesn't is
                // a third grip's to learn from scratch.
                if model.contexts[other].hasSnapshot, !(gainCount[other] > 0 && recentGain(other) > 0) {
                    model.clear(other)
                    model.contexts[other].geometry = geometry
                    model.contexts[other].regime = regime
                    resetGains(other)
                }
                next = other
            } else {
                next = model.ensureContext(geometry: geometry, regime: regime)
                resetGains(next)
            }
            model.contexts[learning].learning = false
            model.contexts[next].learning = true
        }
        if !model.contexts.indices.contains(where: { model.contexts[$0].geometry == geometry && model.contexts[$0].inUse }) {
            let ready = model.contexts.indices.filter {
                guard model.contexts[$0].geometry == geometry, isEligible($0),
                      gainCount[$0] >= Self.monitorMinimum else { return false }
                let g = meanGain($0)
                return g.x + g.y > 0 && min(g.x, g.y) > Self.engageAxis && recentGain($0) > 0
            }
            if let best = ready.max(by: { meanGain($0).x + meanGain($0).y < meanGain($1).x + meanGain($1).y }) {
                model.contexts[best].inUse = true
                if mode == .learn {
                    for c in model.contexts.indices where model.contexts[c].geometry == geometry {
                        model.contexts[c].learning = c == best
                    }
                }
                didChange = true
            }
        }
        if didChange { changed() }
    }

    /// A profile with the evidence to be used: a snapshot, `activeTaps` labels, `activeSessions` sessions.
    private func isEligible(_ c: Int) -> Bool {
        let ctx = model.contexts[c]
        return ctx.hasSnapshot && ctx.accepted >= UInt32(activeTaps) && ctx.sessions >= UInt16(activeSessions)
    }

    private func pushGain(x: Float, y: Float, context c: Int) {
        let i = (c * Self.monitorWindow + gainHead[c]) * 2
        gains[i] = x
        gains[i + 1] = y
        gainHead[c] = (gainHead[c] + 1) % Self.monitorWindow
        gainCount[c] = min(Self.monitorWindow, gainCount[c] + 1)
    }

    /// The profile fits worse than the stock centres along one axis, or overall.
    private func misfits(_ c: Int, axis: Float, total: Float) -> Bool {
        let g = meanGain(c)
        return min(g.x, g.y) < axis || g.x + g.y < total
    }

    private func resetGains(_ c: Int) {
        gainCount[c] = 0
        gainHead[c] = 0
    }

    private func meanGain(_ c: Int) -> (x: Float, y: Float) {
        guard gainCount[c] > 0 else { return (0, 0) }
        var x: Float = 0, y: Float = 0
        for k in 0..<gainCount[c] {
            x += gains[(c * Self.monitorWindow + k) * 2]
            y += gains[(c * Self.monitorWindow + k) * 2 + 1]
        }
        return (x / Float(gainCount[c]), y / Float(gainCount[c]))
    }

    /// The newest quarter of the window, both axes: a second, later window that must agree.
    private func recentGain(_ c: Int) -> Float {
        let n = min(gainCount[c], Self.monitorWindow / 4)
        guard n > 0 else { return 0 }
        var sum: Float = 0
        for k in 1...n {
            let i = (c * Self.monitorWindow + (gainHead[c] - k + Self.monitorWindow) % Self.monitorWindow) * 2
            sum += gains[i] + gains[i + 1]
        }
        return sum / Float(n)
    }

    private func changed() {
        version += 1
    }
}
