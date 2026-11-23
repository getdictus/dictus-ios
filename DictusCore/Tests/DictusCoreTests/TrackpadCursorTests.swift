import CoreGraphics
import XCTest
@testable import DictusCore

/// The space-bar trackpad's cursor math (#950), ported from Hex (MIT). The first cases are
/// Hex's own (`FullKeyboardEngineTests`, PRs #2219 and #2233), kept as they were so a
/// difference from Hex shows up here; the `Gesture` and hold cases are Dictus's.
///
/// Every layout here uses 10 pt characters and 20 pt lines, so a distance reads directly as
/// characters and lines.
final class TrackpadCursorTests: XCTestCase {

    private let tenPoints: (Character) -> CGFloat = { _ in 10 }

    private func state(_ before: String, _ after: String = "", wrapWidth: CGFloat = 300) -> TrackpadCursor.State {
        TrackpadCursor.State(before: before, after: after, wrapWidth: wrapWidth, lineHeight: 20, width: tenPoints)
    }

    // MARK: - Thresholds: tap or trackpad

    /// Only a still hold starts the trackpad. A quick tap that drifts is a space, as on Apple's
    /// (Hex #2233: taps of 60 to 150 ms sliding 8 to 24 pt, slides of 40 pt in 150 ms).
    func testOnlyAStillHoldStartsTheTrackpad() {
        XCTAssertEqual(TrackpadCursor.holdDelay, 0.35)
        XCTAssertEqual(TrackpadCursor.holdSlop, 10)
        XCTAssertTrue(TrackpadCursor.startsTrackpad(held: 0.35, travel: 0), "held still: the trackpad")
        XCTAssertTrue(TrackpadCursor.startsTrackpad(held: 0.6, travel: 8), "a held finger's jitter is still a hold")
        XCTAssertFalse(TrackpadCursor.startsTrackpad(held: 0.34, travel: 0), "lifted before the hold: a space")
        for (held, travel) in [(0.06, 12.0), (0.1, 16.0), (0.15, 24.0), (0.15, 40.0)] {
            XCTAssertFalse(TrackpadCursor.startsTrackpad(held: held, travel: CGFloat(travel)), "a \(held) s tap sliding \(travel) pt is a space")
        }
        XCTAssertFalse(TrackpadCursor.startsTrackpad(held: 0.6, travel: 20), "slid before the hold: never the trackpad")
    }

    /// Travel before the hold doesn't count: the gesture starts where the finger is.
    func testTravelBeforeTheHoldDoesNotMoveTheCursor() {
        let gesture = TrackpadCursor.Gesture(state: state("hello world"), at: CGPoint(x: 200, y: 30), time: 1)
        XCTAssertEqual(gesture.path, [TrackpadCursor.Sample(time: 1, point: CGPoint(x: 200, y: 30))])
        XCTAssertEqual(gesture.state.cursor, 11)
    }

    // MARK: - Speed and acceleration

    /// Apple's took 80 pt of finger 1.05 times as far slowly, 1.4 times at 400 pt/s, twice at
    /// 1,000 and 2.6 times at 2,000 (iOS 27.2), from the finger's speed in whatever direction.
    func testTheTrackpadGoesFurtherTheFasterTheFinger() {
        XCTAssertEqual(TrackpadCursor.gain(speed: 0), 1)
        XCTAssertEqual(TrackpadCursor.gain(speed: 400), 1.375, accuracy: 0.01)
        XCTAssertEqual(TrackpadCursor.gain(speed: 1000), 2, accuracy: 0.01)
        XCTAssertEqual(TrackpadCursor.gain(speed: 2000), 2.59, accuracy: 0.01)
        XCTAssertEqual(TrackpadCursor.gain(speed: 100_000), TrackpadCursor.maxGain)
        // Moves 7.7 pt apart at a steady 120 Hz, their times arriving 1 to 11 ms apart.
        let times: [TimeInterval] = [0, 0.0001, 0.0089, 0.0149, 0.0254, 0.0322, 0.0381, 0.0488, 0.0554]
        let path = times.enumerated().map { TrackpadCursor.Sample(time: $1, point: CGPoint(x: CGFloat($0) * 7.7, y: 0)) }
        XCTAssertEqual(TrackpadCursor.speed(along: path), 924, accuracy: 120)
        XCTAssertTrue(TrackpadCursor.isVertical([.init(time: 0, point: .zero), .init(time: 0.01, point: CGPoint(x: 3, y: -5))]))
    }

    /// The gain rises with speed and never steps: no speed band jumps the cursor.
    func testTheGainIsContinuousAndRising() {
        var previous = TrackpadCursor.gain(speed: 0)
        for speed in stride(from: CGFloat(5), through: 4000, by: 5) {
            let gain = TrackpadCursor.gain(speed: speed)
            XCTAssertGreaterThanOrEqual(gain, previous, "at \(speed) pt/s")
            XCTAssertLessThan(gain - previous, 0.01, "no jump at \(speed) pt/s")
            previous = gain
        }
    }

    /// 80 pt of finger along a line at a steady speed, sampled at 120 Hz, through `Gesture`
    /// as the keyboard drives it: the characters it moved.
    private func characters(after travel: CGFloat, at speed: CGFloat, dx: CGFloat = -1, dy: CGFloat = 0) -> Int {
        let text = String(repeating: "a", count: 60)
        var gesture = TrackpadCursor.Gesture(state: state(text, wrapWidth: 1000), at: .zero, time: 0)
        let steps = Int((travel / speed * 120).rounded())
        var moved = 0
        for i in 1...steps {
            let along = travel * CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: along * dx, y: along * dy)
            moved += gesture.move(to: point, at: TimeInterval(i) / 120, context: { (text, "") }, width: tenPoints)
        }
        return moved
    }

    /// Hex's black box of Apple's: 80 pt at 150/400/1,000/2,000 pt/s gave 11/13/21/26
    /// characters of a 17 pt body font (about 7.5 pt a character). At 10 pt a character the
    /// same gains give about 9/11/16/21, and Dictus's old constant 12 pt a character gave
    /// 6 or 7 at every speed.
    func testEightyPointsGoFurtherTheFasterTheyAreCovered() {
        let slow = characters(after: 80, at: 150)
        let medium = characters(after: 80, at: 400)
        let fast = characters(after: 80, at: 1000)
        let flick = characters(after: 80, at: 2000)
        XCTAssertEqual(-slow, 9, accuracy: 1)
        XCTAssertEqual(-medium, 11, accuracy: 1)
        XCTAssertEqual(-fast, 16, accuracy: 1)
        XCTAssertEqual(-flick, 21, accuracy: 1)
    }

    /// A slow drag moves the cursor by the text's own widths: one character per character of
    /// finger travel, so the cursor lands where the finger points, an "i" quicker than an "m".
    func testASlowDragFollowsTheTextsOwnWidths() {
        let widths: (Character) -> CGFloat = { $0 == "m" ? 14 : 4 }
        let start = TrackpadCursor.State(before: "mmii", after: "", wrapWidth: 300, lineHeight: 20, width: widths)
        var gesture = TrackpadCursor.Gesture(state: start, at: CGPoint(x: 100, y: 0), time: 0)
        // 10 pt a second, well under the 40 pt/s where the gain starts: the finger's own travel.
        XCTAssertEqual(gesture.move(to: CGPoint(x: 92, y: 0), at: 0.8, context: { ("mmii", "") }, width: widths), -2, "8 pt: both i's")
        XCTAssertEqual(gesture.move(to: CGPoint(x: 78, y: 0), at: 2.2, context: { ("mmii", "") }, width: widths), -1, "14 pt more: one m")
    }

    /// No inertia: the cursor stops when the finger does, and lifting adds nothing.
    func testTheCursorStopsWithTheFinger() {
        var gesture = TrackpadCursor.Gesture(state: state(String(repeating: "a", count: 40)), at: .zero, time: 0)
        XCTAssertLessThan(gesture.move(to: CGPoint(x: -30, y: 0), at: 0.01, context: { ("", "") }, width: tenPoints), 0)
        XCTAssertEqual(gesture.refresh(at: 0.5, context: { ("", "") }, width: tenPoints), 0, "held still")
        XCTAssertEqual(gesture.lift(at: 0.6), 0, "lifted")
    }

    // MARK: - Lines

    /// Up and down by the text's own lines, keeping x across a short line, and stopping at a
    /// line's start, where coming back moves the cursor at once, and past its end, where coming
    /// back takes the travel again (Hex's black box of Apple's).
    func testTheTrackpadMovesThroughLinesAtTheTextsOwnScale() {
        var state = state("one two three\nfour five\nsix seven", " eight nine")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -9), at: 0), 0, "not yet: half a line from the middle")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -2), at: 0), 23 - 33, "up a line, at its end: \"four five\" is shorter")
        XCTAssertEqual(state.move(by: CGVector(dx: -45, dy: 0), at: 0), -5, "along by the text's width: 4.5 characters, the nearer 5")
        XCTAssertEqual(state.move(by: CGVector(dx: -100, dy: 0), at: 0), -4, "and stops at the line's start")
        XCTAssertEqual(state.move(by: CGVector(dx: 10, dy: 0), at: 0), 1, "coming back moves it at once")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -20), at: 0), 1 - 15, "up a line, at its x")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: 40), at: 0), 25 - 1, "down two lines, at its x")
        XCTAssertEqual(state.move(by: CGVector(dx: 200, dy: -20), at: 0), 23 - 25, "up to \"four five\", stopped at its end")
        XCTAssertEqual(state.move(by: CGVector(dx: -100, dy: 0), at: 0), 0, "coming back takes that travel again")
        XCTAssertEqual(state.move(by: CGVector(dx: -30, dy: 0), at: 0), -1)
    }

    /// The finger going up through `Gesture`: one line per line height, the first after half
    /// a line, slowly enough that the gain stays 1.
    func testAGestureUpGoesALineAtATime() {
        let text = "first line\nsecond line\nthird line"
        var gesture = TrackpadCursor.Gesture(state: state(text), at: CGPoint(x: 0, y: 0), time: 0)
        XCTAssertEqual(gesture.move(to: CGPoint(x: 0, y: -8), at: 1, context: { (text, "") }, width: tenPoints), 0, "under half a line")
        XCTAssertEqual(gesture.move(to: CGPoint(x: 0, y: -12), at: 2, context: { (text, "") }, width: tenPoints), -12, "the line above, at its x: before the last \"e\" of \"second line\"")
        XCTAssertEqual(gesture.move(to: CGPoint(x: 0, y: -32), at: 3, context: { (text, "") }, width: tenPoints), -11, "and the one above it, at its end: \"first line\" is as wide as that x")
        XCTAssertEqual(gesture.move(to: CGPoint(x: 0, y: -80), at: 4, context: { (text, "") }, width: tenPoints), 0, "the first line keeps it")
    }

    /// Past the first or last line the host may have more: a host shares only the cursor's
    /// sentence or line, so the cursor steps just past what it showed, in one move the host makes
    /// only if there's text there. Shown it, the cursor goes on to the line there at its x; no
    /// answer means the host never moved, and that line was the text's first.
    func testTheTrackpadStepsPastTheTextItKnowsForTheHostToShowMore() {
        var state = state("Lin", "e two is longer")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -25), at: 0), -4, "just past the start: the end of the line before")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -2), at: 0.01), 0, "waiting for the host")
        XCTAssertTrue(state.catchUp(before: "Line one", after: "", width: tenPoints))
        XCTAssertEqual(state.settle(at: 0.02), 3 - 8, "the line shown, at the x it was at")

        var first = self.state("Lin", "e one")
        XCTAssertEqual(first.move(by: CGVector(dx: 0, dy: -25), at: 0), -4)
        XCTAssertEqual(first.settle(at: 0.5), 0, "unanswered: the host never moved, so neither did the cursor")
        XCTAssertEqual(first.move(by: CGVector(dx: 0, dy: -40), at: 0.6), 0, "the first line keeps it")
        XCTAssertEqual(first.move(by: CGVector(dx: 10, dy: 0), at: 0.7), 1, "and coming back moves it at once")
    }

    /// The same step down, through `Gesture` and its `refresh`, the way the keyboard drives it
    /// a moment after a move (it has no host callback to wait on).
    func testAGestureDownPastTheKnownTextReadsTheNextLineOnRefresh() {
        var shown = (before: "Line one", after: "")
        var gesture = TrackpadCursor.Gesture(state: state(shown.before, shown.after), at: .zero, time: 0)
        let stepped = gesture.move(to: CGPoint(x: 0, y: 25), at: 1, context: { shown }, width: tenPoints)
        XCTAssertEqual(stepped, 1, "one past the end: over the line break, if the host has one")
        XCTAssertNotNil(gesture.state.crossing)
        // The host made the move and now shares the next line.
        shown = (before: "", after: "Line two")
        XCTAssertEqual(gesture.refresh(at: 1.02, context: { shown }, width: tenPoints), 8, "on to the x it was at: the end of \"Line two\", as wide as \"Line one\"")
        XCTAssertNil(gesture.state.crossing)
    }

    /// A host that shares a fixed number of characters before the cursor, cut anywhere (Safari
    /// shared about 60 in the #950 simulator run), and the rest of the cursor's line after it.
    /// It makes each move at once, and ignores one that would leave the text.
    private final class CutContextHost {
        var text: [Character]
        var caret: Int
        let window: Int

        init(_ text: String, caret: Int, window: Int) {
            self.text = Array(text)
            self.caret = caret
            self.window = window
        }

        var context: (before: String, after: String) {
            var end = caret
            while end < text.count, text[end] != "\n" { end += 1 }
            return (String(text[max(0, caret - window)..<caret]), String(text[caret..<end]))
        }

        func move(by offset: Int) {
            if (0...text.count).contains(caret + offset) { caret += offset }
        }

        /// The cursor's line, with "|" at the cursor.
        var line: String {
            var start = caret, end = caret
            while start > 0, text[start - 1] != "\n" { start -= 1 }
            while end < text.count, text[end] != "\n" { end += 1 }
            return String(text[start..<caret]) + "|" + String(text[caret..<end])
        }
    }

    /// Safari, #950: going up onto a line the host shared from its middle. The cursor comes onto
    /// it among guessed widths; once the host shows the line's start, the line wraps, and the
    /// row above "Troisieme ligne." is "premiere.", where Apple's cursor goes (its end, past the
    /// finger's x). Hex's re-anchoring by the cursor put it a row higher, mid-word.
    func testUpOntoALineTheHostSharesFromItsMiddle() {
        let text = "Premiere ligne du texte.\nDeuxieme ligne, un peu plus longue que la premiere.\nTroisieme ligne.\nQuatrieme ligne, la derniere du champ de test."
        let host = CutContextHost(text, caret: text.count - 13, window: 63)
        XCTAssertEqual(host.line, "Quatrieme ligne, la derniere du c|hamp de test.")
        let shown = host.context
        let start = TrackpadCursor.State(before: shown.before, after: shown.after, wrapWidth: 480, lineHeight: 20, width: tenPoints)
        var gesture = TrackpadCursor.Gesture(state: start, at: .zero, time: 0)
        var time: TimeInterval = 0
        for step in 1...32 {
            time += 1.0 / 60
            host.move(by: gesture.move(to: CGPoint(x: 0, y: -CGFloat(step)), at: time, context: { host.context }, width: tenPoints))
            time += 0.01
            host.move(by: gesture.refresh(at: time, context: { host.context }, width: tenPoints))
            if step == 12 { XCTAssertEqual(host.line, "Troisieme ligne.|", "a line up, at its end") }
        }
        XCTAssertEqual(host.line, "Deuxieme ligne, un peu plus longue que la premiere.|", "the row above: \"premiere.\"")
        XCTAssertEqual(gesture.state.point.x, 330, "the finger's x, kept")
    }

    /// Along a line, the point keeps its place beside the cursor when the host shows more, as
    /// Hex does: going left past what the host shared never jumps.
    func testAlongALineMoreTextNeverJumpsTheCursor() {
        let text = String(repeating: "abcdefghij ", count: 20)
        let host = CutContextHost(text, caret: text.count, window: 30)
        let shown = host.context
        let start = TrackpadCursor.State(before: shown.before, after: shown.after, wrapWidth: 5000, lineHeight: 20, width: tenPoints)
        var gesture = TrackpadCursor.Gesture(state: start, at: .zero, time: 0)
        var time: TimeInterval = 0
        for step in 1...60 {
            time += 1
            let moved = gesture.move(to: CGPoint(x: -CGFloat(step) * 10, y: 0), at: time, context: { host.context }, width: tenPoints)
            host.move(by: moved)
            XCTAssertEqual(moved, -1, "a character per 10 pt, step \(step)")
        }
        XCTAssertEqual(host.caret, text.count - 60)
    }

    /// The proxy moves the cursor in UTF-16 units: a 👍🏽 is four of them, so moving by
    /// characters stalled three steps inside one. Each character's own width counts too.
    func testTheTrackpadMovesOverAnEmojiInOneStep() {
        var state = TrackpadCursor.State(before: "ab👍🏽cd", after: "", wrapWidth: 300, lineHeight: 20, width: { $0 == "👍🏽" ? 20 : 10 })
        XCTAssertEqual(state.move(by: CGVector(dx: -25, dy: 0), at: 0), -2, "back over d and c")
        XCTAssertEqual(state.move(by: CGVector(dx: -10, dy: 0), at: 0), -4, "and the emoji at once")
    }

    /// A line the field wraps: along goes on into the next row (the rows are estimates, and a
    /// single-line field never wraps), and up and down go by rows.
    func testTheTrackpadFollowsRowsTheFieldWraps() {
        let long = String(repeating: "word ", count: 12)
        var state = state(long, wrapWidth: 100)
        XCTAssertEqual(state.layout.rows.count, 6, "two words a row, the space after each hanging past the edge")
        XCTAssertEqual(state.move(by: CGVector(dx: 0, dy: -20), at: 0), -10, "up a row")
        XCTAssertEqual(state.move(by: CGVector(dx: -10, dy: 0), at: 0), -1, "along it")
        XCTAssertEqual(state.move(by: CGVector(dx: -100, dy: 0), at: 0), -10, "and on into the row before")
    }

    /// The field is about as wide as the keyboard less its margins, never absurdly narrow.
    func testTheWrapWidthFollowsTheKeyboard() {
        XCTAssertEqual(TrackpadCursor.wrapWidth(forWidth: 402), 362)
        XCTAssertEqual(TrackpadCursor.wrapWidth(forWidth: 100), 120)
    }
}
