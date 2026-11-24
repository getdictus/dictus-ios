// DictusKeyboard/TouchHandling/SwipeTypingController.swift
//
// Ported from Hex (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// ios/HEXShared/FullKeyboard/SwipeTyping.swift, `SwipeTyping`) (#948).
//
// MIT License
//
// Copyright (c) 2026 Christopher Langton
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// What the port changed: touches are `UITouch` objects (Dictus's view is UIKit's
// `touchesBegan/Moved/Ended`, not Hex's touch ids), the engine is `SwipeTypingOutput` (the
// bridge), the keys are `GiellaKeyboardView.spatialKeys()`, and the text rules live in
// DictusCore (`SwipeTypingText`). Left out: Hex's own words and never-suggest words (ADR
// 0004 keeps learned words out of anything typed without a tap; no Hex data is copied), its
// rare-name ranking and `SwipeRetries`.
import DictusCore
import QuartzCore
import UIKit

/// Where a swipe's readings go: the bridge, which owns the document and the bar.
protocol SwipeTypingOutput: AnyObject {
    /// The text before the cursor, for the word before and the spacing.
    func swipeTypingContextBefore() -> String?
    /// A letter touch became a swipe: its key types nothing.
    func swipeTypingDidBegin()
    /// What the swipe under way reads as so far, best first.
    func swipeTypingPreview(_ readings: [String])
    /// The swipe lifted with `readings`, best first; empty when it read as nothing.
    func swipeTypingDidEnd(readings: [String])
    /// The system cancelled the swipe: nothing goes in.
    func swipeTypingDidCancel()
}

/// Swipe typing (#948): slide from a letter through the letters of a word and lift, and the
/// word goes in, as with Apple's QuickPath.
///
/// A touch on a letter key becomes a swipe once it travels more than a key's pitch from
/// where it went down (`SwipeTypingText.isSwipe`): the key no longer types, a light trail
/// follows the finger, and the bar shows what the path reads as so far. Lifting the finger
/// types the best reading and offers the next three in the bar. Taps, holds for accents and
/// slides of a key or less keep working as before, and so do delete, the space bar's
/// trackpad and every key that is not a letter, on which no swipe starts.
///
/// It exists only while swipe typing acts (`SwipeTypingText.availability` is `.on`): with
/// the switch off, the keyboard view holds no controller and none of this runs.
///
/// Main thread only, like the touches that feed it. The preview decodes on a background
/// queue; the decode on lift runs on the main thread, so a key tapped right after the lift
/// cannot reach the document before the swiped word.
final class SwipeTypingController {
    weak var output: SwipeTypingOutput?
    /// The light trail behind the finger; nil when its switch is off.
    let trail: SwipeTrailView?

    /// The letter keys a swipe is read against, where they are drawn; set by the keyboard
    /// view when it takes the controller.
    var keys: () -> SpatialDecoder.Keys? = { nil }
    /// The key under a point of the keyboard view, for a tap that slid.
    var keyAt: (CGPoint) -> KeyDefinition? = { _ in nil }
    /// Whether the focused field takes swipes now; set by the bridge.
    var allowsSwipes: () -> Bool = { false }

    private let decoder: SwipeDecoder
    let language: String

    /// A touch's points so far and when each came (`UITouch.timestamp`): the decoder reads
    /// where the finger paused from the times.
    struct Stroke {
        var key: KeyDefinition
        var points: [CGPoint] = []
        var times: [TimeInterval] = []

        mutating func add(_ point: CGPoint, at time: TimeInterval) {
            points.append(point)
            times.append(time)
        }
    }

    /// Letter touches that may still become swipes: their strokes so far.
    private var pending: [ObjectIdentifier: Stroke] = [:]
    /// The swipe under way, and the keys it is read against (taken at its start).
    private struct ActiveSwipe {
        let touch: ObjectIdentifier
        var stroke: Stroke
        let keys: SpatialDecoder.Keys
    }
    private var active: ActiveSwipe?
    /// Swipes ended early by a second finger whose own finger is still down: its moves and
    /// its lift are swallowed, so it neither drags the new key nor types on lift.
    private var spent: Set<ObjectIdentifier> = []
    /// Bumped by every swipe's start and end, so a reading of an older one is dropped.
    private var generation = 0
    private var previewInFlight = false
    private var lastPreviewAt: TimeInterval = 0
    /// Decodes while the finger moves, for the bar, off the main thread.
    private static let previewQueue = DispatchQueue(label: "com.pivi.dictus.swipe-preview", qos: .userInitiated)
    /// Hex's preview cadence: at most one decode every 70 ms while the finger moves.
    static let previewInterval: TimeInterval = 0.07

    /// How long the last swipe's decode on lift took, for the log.
    private(set) var lastDecodeTime: TimeInterval?

    private let clock: () -> TimeInterval = { CACurrentMediaTime() }

    /// - Parameters:
    ///   - model: the keyboard language's swipe model (`en.hextm` or `fr.hextm`).
    ///   - showsTrail: whether the finger's trail draws (`swipeTrail`).
    init(model: SpatialDecoderModel, showsTrail: Bool) {
        var decoder = SwipeDecoder(model: model)
        if model.language == SupportedLanguage.english.rawValue {
            // Google Books splits "don't", so the model barely has contractions: they are
            // read beside it, at Hex's cost of a common contraction. Dictus's own list.
            decoder.extraWords = SwipeDecoder.ExtraWords(
                SwipeExtraWords.englishContractions, cost: { _ in SwipeDecoder.contractionCost },
                model: model, contractions: true
            )
        }
        self.decoder = decoder
        language = model.language
        trail = showsTrail ? SwipeTrailView() : nil
    }

    var isSwiping: Bool { active != nil }

    /// Whether `touch` is the swipe under way, or one a second finger already ended.
    func owns(_ touch: UITouch) -> Bool {
        let id = ObjectIdentifier(touch)
        return active?.touch == id || spent.contains(id)
    }

    // MARK: - Touches (from `GiellaKeyboardView`)

    /// A new finger is going down: the swipe under way types its word first, so it lands
    /// before the new key's letter. Letter touches still pending were committed by the new
    /// finger (the view types the previous key on the next touch-down), so they can no
    /// longer become swipes.
    func touchWillBegin() {
        pending.removeAll()
        guard let swipe = active else { return }
        spent.insert(swipe.touch)
        finish(swipe.stroke, keys: swipe.keys)
    }

    /// A touch went down on `key` at `point`: a letter's may become a swipe.
    func began(_ touch: UITouch, at point: CGPoint, key: KeyDefinition) {
        guard case let .input(character, alternate) = key.type, alternate != "accent",
              character.count == 1, character.first?.isLetter == true, allowsSwipes(), keys() != nil else { return }
        var stroke = Stroke(key: key)
        stroke.add(point, at: touch.timestamp)
        pending[ObjectIdentifier(touch)] = stroke
    }

    /// The touches moved. Returns the ones this does not own, which the view handles as
    /// before (a slide to another key). `onBegin` runs once, when a touch becomes a swipe.
    func moved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView, onBegin: () -> Void) -> Set<UITouch> {
        var rest = touches
        for touch in touches where moved(touch, with: event, in: view, onBegin: onBegin) {
            rest.remove(touch)
        }
        return rest
    }

    private func moved(_ touch: UITouch, with event: UIEvent?, in view: UIView, onBegin: () -> Void) -> Bool {
        let id = ObjectIdentifier(touch)
        if spent.contains(id) { return true }
        // Every sample the screen took since the last call (120 Hz on ProMotion), so the
        // path and its pauses are as fine as the hardware reports them.
        let samples = (event?.coalescedTouches(for: touch) ?? [touch]).map { ($0.location(in: view), $0.timestamp) }
        if var swipe = active, swipe.touch == id {
            for (point, time) in samples {
                swipe.stroke.add(point, at: time)
                trail?.add(point)
            }
            active = swipe
            schedulePreview()
            return true
        }
        guard var stroke = pending[id] else { return false }
        for (point, time) in samples { stroke.add(point, at: time) }
        pending[id] = stroke
        guard let first = stroke.points.first, let last = stroke.points.last, let keys = keys(),
              SwipeTypingText.isSwipe(from: first, to: last, pitch: keys.pitch.width) else { return false }
        pending[id] = nil
        active = ActiveSwipe(touch: id, stroke: stroke, keys: keys)
        generation += 1
        lastPreviewAt = 0
        onBegin()
        output?.swipeTypingDidBegin()
        trail?.begin(stroke.points)
        schedulePreview()
        return true
    }

    /// The swipe's finger lifted: its word goes in. Returns the key to type as a tap when
    /// the swipe was a tap that slid, with the point it went down at.
    func ended(_ touch: UITouch, in view: UIView) -> (key: KeyDefinition, point: CGPoint)? {
        if spent.remove(ObjectIdentifier(touch)) != nil { return nil }
        guard var swipe = active, swipe.touch == ObjectIdentifier(touch) else { return nil }
        swipe.stroke.add(touch.location(in: view), at: touch.timestamp)
        return finish(swipe.stroke, keys: swipe.keys)
    }

    /// Touches that never became swipes ended, or were taken by a long press.
    func forget(_ touches: Set<UITouch>) {
        for touch in touches { pending[ObjectIdentifier(touch)] = nil }
    }

    /// The system cancelled the touches, or the keyboard is going away: nothing goes in.
    func cancelAll() {
        pending.removeAll()
        spent.removeAll()
        guard let swipe = active else { return }
        active = nil
        generation += 1
        trail?.clear()
        PersistentLog.log(.swipeEnded(points: swipe.stroke.points.count, decodeMs: 0, readings: 0, outcome: "cancelled"))
        output?.swipeTypingDidCancel()
    }

    @discardableResult
    private func finish(_ stroke: Stroke, keys: SpatialDecoder.Keys) -> (key: KeyDefinition, point: CGPoint)? {
        active = nil
        generation += 1
        trail?.fade()
        let started = clock()
        let candidates = decoder.decode(
            stroke.points, times: stroke.times, keys: keys,
            previous: SwipeTypingText.previousWord(before: output?.swipeTypingContextBefore()), limit: 8
        )
        let readings = SwipeTypingText.unique(candidates.map(\.text))
        let elapsed = clock() - started
        lastDecodeTime = elapsed
        let decodeMs = elapsed * 1000
        if let tap = slidTap(stroke, keys: keys, best: readings.first) {
            PersistentLog.log(.swipeEnded(points: stroke.points.count, decodeMs: decodeMs, readings: readings.count, outcome: "slidTap"))
            output?.swipeTypingDidEnd(readings: [])
            return tap
        }
        PersistentLog.log(.swipeEnded(
            points: stroke.points.count, decodeMs: decodeMs, readings: readings.count,
            outcome: readings.isEmpty ? "none" : "word"
        ))
        output?.swipeTypingDidEnd(readings: readings)
        return nil
    }

    /// A swipe that came back to the key it went down on without going more than
    /// `slidTapReach` pitches from it ("a" dragged a little too far and back): the decoder
    /// reads no word of one letter, so it would read "as". Its key goes in as a tap's would,
    /// unless the best reading starts and ends on that key ("pop").
    private func slidTap(_ stroke: Stroke, keys: SpatialDecoder.Keys, best: String?) -> (key: KeyDefinition, point: CGPoint)? {
        guard let first = stroke.points.first, let last = stroke.points.last,
              SwipeTypingText.staysNearStart(stroke.points, pitch: keys.pitch.width),
              keyAt(last)?.type == stroke.key.type,
              case let .input(letter, _) = stroke.key.type else { return nil }
        if let best, SwipeTypingText.word(best, startsAndEndsWith: letter) { return nil }
        return (stroke.key, first)
    }

    // MARK: - The word so far

    /// Reads the path so far off the main thread, at most every `previewInterval`, and shows
    /// its best words in the bar while the swipe is still the same one.
    private func schedulePreview() {
        guard let swipe = active, !previewInFlight, swipe.stroke.points.count >= 3 else { return }
        let now = clock()
        guard now - lastPreviewAt >= Self.previewInterval else { return }
        previewInFlight = true
        lastPreviewAt = now
        let decoder = decoder, keys = swipe.keys, generation = generation
        let points = swipe.stroke.points, times = swipe.stroke.times
        let previous = SwipeTypingText.previousWord(before: output?.swipeTypingContextBefore())
        Self.previewQueue.async { [weak self] in
            let candidates = decoder.decode(points, times: times, keys: keys, previous: previous, limit: 3)
            DispatchQueue.main.async {
                guard let self else { return }
                self.previewInFlight = false
                guard self.generation == generation, self.active != nil else { return }
                self.output?.swipeTypingPreview(SwipeTypingText.unique(candidates.map(\.text)))
            }
        }
    }
}
