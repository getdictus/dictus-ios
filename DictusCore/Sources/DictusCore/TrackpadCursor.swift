// DictusCore/Sources/DictusCore/TrackpadCursor.swift
// The space-bar trackpad's cursor math (#950).
//
// Ported from Hex (https://github.com/anomalyco/hex, branch dev,
// ios/HEXShared/FullKeyboard/TrackpadCursor.swift as of 50e3464, PRs #2219 and #2233),
// MIT License, Copyright (c) 2026 Christopher Langton. The licence travels with the app
// in Settings > Licences. Changes from Hex's file: public access for the keyboard
// extension, the hold thresholds (`holdDelay`, `holdSlop`, `startsTrackpad`) gathered here
// from Hex's FullKeyboardEngine, no UIKit (the character widths and the line height are
// passed in, so the tests run on the Mac), `Gesture` (Hex's per-move step, out of its
// engine), and one behaviour: `catchUp(keepingX:)`, which keeps the finger's place when the
// host shows the start of a line it had shared from its middle (Safari, #950).
import CoreGraphics
import Foundation

/// The space-bar trackpad as Apple's moves it (Hex's black box, iOS 27.2 simulator, a
/// UITextView logging its selection): the finger drags a point through the text at the
/// text's own scale, in two dimensions, the cursor going to the character boundary nearest
/// it, and the faster the finger the further the point goes (`gain(speed:)`). A keyboard
/// sees only the text around the cursor and moves it by characters, so the text is laid out
/// here as a field would show it: the body font's own widths (an "i" passes quicker than an
/// "m", as on Apple's), lines wrapped at the keyboard's width less margins, and the font's
/// line height for a line.
///
/// WHY a model of the text rather than "N points per character": `adjustTextPosition` is
/// the only lever a keyboard has, and it speaks characters. Apple's trackpad speaks points.
/// Laying the shared context out the way the field most likely shows it turns one into the
/// other, which is what makes a slow drag land on the character under the imagined finger,
/// and what makes up and down possible at all.
public enum TrackpadCursor {

    // MARK: - Starting the trackpad

    /// Holding the space bar this long without sliding starts the trackpad; letting go then
    /// types no space. Apple's space bar turns into the trackpad 330 to 365 ms after
    /// touch-down (Hex, iOS 27.2, the cursor's first move after holds of 250 to 550 ms), and
    /// travel before then doesn't count. Dictus waited UIKit's default 0.5 s before this.
    public static let holdDelay: TimeInterval = 0.35

    /// How far a space-bar touch may slide before its hold and still start the trackpad. A
    /// touch that slides further is a tap: Apple's types a space for taps of 60 to 150 ms
    /// sliding 8 to 24 pt, and for slides of 40 pt in 150 ms (Hex #2233). UIKit's
    /// `UILongPressGestureRecognizer.allowableMovement` default, and Hex's own figure.
    public static let holdSlop: CGFloat = 10

    /// Whether a space-bar touch held `held` seconds after sliding `travel` points becomes the
    /// trackpad. False is a tap: the space goes in on lift, however far the finger drifted.
    public static func startsTrackpad(held: TimeInterval, travel: CGFloat) -> Bool {
        held >= holdDelay && travel <= holdSlop
    }

    // MARK: - Speed

    /// How far the point goes per point of finger travel at `speed` (points a second). Apple's
    /// took 80 pt of finger 1.05 times as far slowly, 1.4 times at 400 pt/s, twice at 1,000 and
    /// 2.6 times at 2,000, whichever way the finger went (a slant at 1,000 went twice as far up
    /// and along), and with no lag to speak of: a quick flick then a slow slide went as far as
    /// each alone. There is no inertia: the cursor stops when the finger does.
    public static func gain(speed: CGFloat) -> CGFloat {
        guard speed > 1000 else { return 1 + max(0, speed - 40) / 960 }
        return min(maxGain, 2 + (speed - 1000) / 1690)
    }

    public static let maxGain: CGFloat = 4

    /// A trackpad finger's position at a moment (`UITouch.timestamp`).
    public struct Sample: Equatable {
        public var time: TimeInterval
        public var point: CGPoint

        public init(time: TimeInterval, point: CGPoint) {
            self.time = time
            self.point = point
        }
    }

    /// The finger's speed (points a second) along its last moves, `path` oldest first: the
    /// distance over the time since the oldest within `speedWindow` of the newest (at least the
    /// one before it, and at least a 120 Hz frame), so a touch whose times arrive unevenly (the
    /// keyboard's came 1 to 11 ms apart for a steady 120 Hz) still reads steady.
    public static func speed(along path: [Sample]) -> CGFloat {
        guard let last = path.last, path.count > 1 else { return 0 }
        var first = path.count - 2
        while first > 0, last.time - path[first - 1].time <= speedWindow { first -= 1 }
        var distance: CGFloat = 0
        for i in (first + 1)..<path.count {
            let dx = path[i].point.x - path[i - 1].point.x, dy = path[i].point.y - path[i - 1].point.y
            distance += (dx * dx + dy * dy).squareRoot()
        }
        return distance / max(last.time - path[first].time, 1.0 / 120)
    }

    public static let speedWindow: TimeInterval = 0.03

    /// The finger went further up or down than along over its last moves.
    public static func isVertical(_ path: [Sample]) -> Bool {
        guard let first = path.first, let last = path.last else { return false }
        return abs(last.point.y - first.point.y) > abs(last.point.x - first.point.x)
    }

    // MARK: - Layout

    /// A line of the field is about as wide as the keyboard less its margins: a UITextView's
    /// text, 360 pt wide on a 402 pt screen, holds "Line four has some more words in it".
    public static func wrapWidth(forWidth width: CGFloat) -> CGFloat {
        max(120, width - lineMargins)
    }

    public static let lineMargins: CGFloat = 40

    /// One row of laid-out text: a line, or the part of one the field wraps onto a row.
    public struct Row: Equatable {
        /// The row's first character and the one after its last (a line break isn't in it).
        public var start: Int
        public var end: Int
        /// The line goes on in the next row: the field wraps it here.
        public var wraps: Bool
        /// Where the cursor sits before each character from `start` through `end`.
        public var x: [CGFloat]

        public var width: CGFloat { x.last ?? 0 }

        /// The cursor position in this row nearest `point`.
        public func nearest(_ point: CGFloat) -> Int {
            var low = 0, high = x.count - 1
            while low < high {
                let mid = (low + high) / 2
                if x[mid] < point { low = mid + 1 } else { high = mid }
            }
            if low > 0, point - x[low - 1] <= x[low] - point { low -= 1 }
            return start + low
        }
    }

    /// The text around the cursor laid out in rows, built once a gesture (and again only when
    /// the field shows more of its text), so each finger move is a lookup.
    public final class Layout: Equatable {
        public let text: [Character]
        public let rows: [Row]
        public let lineHeight: CGFloat
        public let wrapWidth: CGFloat
        /// The UTF-16 length of the text before each character boundary: the proxy moves the
        /// cursor in UTF-16 units (a 👍🏽 is four), so a move by characters stalled inside one.
        public let utf16: [Int]

        public init(text: [Character], wrapWidth: CGFloat, lineHeight: CGFloat, width: (Character) -> CGFloat) {
            self.text = text
            self.wrapWidth = wrapWidth
            self.lineHeight = lineHeight
            var utf16 = [0]
            utf16.reserveCapacity(text.count + 1)
            for character in text { utf16.append(utf16[utf16.count - 1] + character.utf16.count) }
            self.utf16 = utf16
            var rows: [Row] = []
            var lineStart = 0
            while lineStart <= text.count {
                var lineEnd = lineStart
                while lineEnd < text.count, !text[lineEnd].isNewline { lineEnd += 1 }
                rows += Self.wrap(text, lineStart, lineEnd, wrapWidth, width)
                lineStart = lineEnd + 1
            }
            self.rows = rows
        }

        /// A line broken into rows as a text view breaks it: after the last space that fits,
        /// mid-word only for a word wider than a row, with spaces hanging past the edge.
        private static func wrap(_ text: [Character], _ start: Int, _ end: Int, _ wrapWidth: CGFloat, _ width: (Character) -> CGFloat) -> [Row] {
            var rows: [Row] = []
            var row = Row(start: start, end: start, wraps: false, x: [0])
            var lastBreak: Int?
            for i in start..<end {
                let character = text[i]
                let advance = width(character)
                let isSpace = character.isWhitespace
                if !isSpace, row.width + advance > wrapWidth, i > row.start {
                    let cut = lastBreak.flatMap { $0 > row.start ? $0 : nil } ?? i
                    let kept = cut - row.start
                    rows.append(Row(start: row.start, end: cut, wraps: true, x: Array(row.x[...kept])))
                    let offset = row.x[kept]
                    row = Row(start: cut, end: i, wraps: false, x: row.x[kept...].map { $0 - offset })
                    lastBreak = nil
                }
                row.x.append(row.width + advance)
                row.end = i + 1
                if isSpace { lastBreak = i + 1 }
            }
            rows.append(row)
            return rows
        }

        /// The row a cursor position is in: at a wrap, the row after (where a field shows it).
        public func row(of position: Int) -> Int {
            var low = 0, high = rows.count - 1
            while low < high {
                let mid = (low + high + 1) / 2
                if rows[mid].start <= position { low = mid } else { high = mid - 1 }
            }
            return low
        }

        public static func == (a: Layout, b: Layout) -> Bool { a === b }
    }

    // MARK: - One gesture

    /// One trackpad gesture: the text it found around the cursor, the cursor, and the point the
    /// finger drags. A host shares only the cursor's sentence or line and a little before it
    /// (iOS 27.2's UITextView: "Lin" before and "e two is a bit longer" after, or three lines
    /// before at the end), and ignores a move that would take its cursor past the text's start
    /// or end. So along past the text it knows the cursor goes to its edge, for the host to show
    /// more there (`catchUp`) or nothing, the text's start or a line's end; and up or down past
    /// the known rows the point waits (up to two rows past them) while the cursor steps just
    /// past the known text in one move (`crossing`), which the host makes only if there's text
    /// there, showing it, or ignores at the text's start or end, so no answer in `edgeTimeout`
    /// means the cursor never moved. The host's context lags the moves, so the gesture keeps
    /// this copy and adds what the host shows once it has caught up.
    public struct State: Equatable {
        public private(set) var layout: Layout
        /// The cursor, as a character of `layout.text`.
        public private(set) var cursor: Int
        /// The point, in the layout's points: x along its row, y down from the first row's top.
        public private(set) var point: CGPoint
        /// The known text's start or end is the text's.
        public private(set) var knowsStart: Bool
        public private(set) var knowsEnd = false
        /// The known text ends a line (or the text): the host's context after the cursor stops
        /// at a line break, so it ends in a letter, where at a sentence's end it ends in a space.
        public private(set) var endsLine: Bool
        /// When the cursor stepped just past the known text, up (`crossingUp`) or down, waiting
        /// for the host to show what's there.
        public private(set) var crossing: TimeInterval?
        private var crossingUp = false
        /// The host's context last read as its cursor being where this copy's is.
        public private(set) var hostCaughtUp = true
        /// The finger went up or down past the known rows meaning a line there: the cursor stays
        /// put while it steps past them (`crossing`) for the host to show that line.
        public private(set) var waiting = false

        public init(before: String, after: String, wrapWidth: CGFloat, lineHeight: CGFloat, width: (Character) -> CGFloat) {
            let head = Array(before)
            layout = Layout(text: head + Array(after), wrapWidth: wrapWidth, lineHeight: lineHeight, width: width)
            cursor = head.count
            // Nothing before the cursor: it's at the text's start.
            knowsStart = head.isEmpty
            endsLine = !(after.last?.isWhitespace ?? false)
            point = .zero
            point = caret
        }

        /// The cursor's UTF-16 offset from the known text's start: while crossing, one before it
        /// or one after its end.
        private var position: Int {
            guard crossing != nil else { return layout.utf16[cursor] }
            return crossingUp ? -1 : layout.utf16[layout.text.count] + 1
        }

        /// Where the host's cursor is while crossing, as a character of the known text.
        private var host: Int {
            guard crossing != nil else { return cursor }
            return crossingUp ? -1 : layout.text.count + 1
        }

        private var caret: CGPoint {
            let row = layout.row(of: cursor)
            return CGPoint(x: layout.rows[row].x[cursor - layout.rows[row].start], y: (CGFloat(row) + 0.5) * layout.lineHeight)
        }

        private var height: CGFloat { CGFloat(layout.rows.count) * layout.lineHeight }

        /// The point is past the known rows, far enough for the line there to be meant.
        private var pastAbove: Bool { !knowsStart && point.y <= -layout.lineHeight / 2 }
        private var pastBelow: Bool { !knowsEnd && point.y >= height + layout.lineHeight / 2 }

        /// Moves the point `delta` (finger travel times `gain(speed:)`) at `time`, and the cursor
        /// to the position nearest it: the UTF-16 offset the cursor moved. Up and down it keeps
        /// its x across short lines; before a line's start, and past the text's first or last
        /// row, it stops, so coming back moves the cursor at once; past a line's end it goes on
        /// to the field's edge, so coming back takes that travel again, all as Apple's does. Along
        /// a row the field wraps it goes on into the next, as the rows are estimates and a
        /// single-line field never wraps. `vertical`: the finger is going more up or down than
        /// along, so a line past the known rows is meant, not a slip off a single line.
        public mutating func move(by delta: CGVector, at time: TimeInterval, vertical: Bool = true) -> Int {
            expire(at: time)
            let start = position
            let lineHeight = layout.lineHeight
            var y = point.y + delta.dy
            if y < 0 {
                y = knowsStart ? 0 : max(y, -2 * lineHeight)
            } else if y >= height {
                y = knowsEnd ? height - 0.001 : min(y, height + 2 * lineHeight)
            }
            point.y = y
            waiting = (pastAbove || pastBelow) && (vertical || waiting)
            if crossing != nil || waiting {
                point.x = min(max(0, point.x + delta.dx), layout.wrapWidth)
                cross(at: time)
                return position - start
            }
            place(dx: delta.dx)
            return position - start
        }

        /// Waiting past the known rows with the host where this copy's cursor is (so no move of
        /// its is still on the way to add up with this one): the cursor steps just past the known
        /// text.
        private mutating func cross(at time: TimeInterval) {
            guard waiting, crossing == nil, hostCaughtUp else { return }
            crossing = time
            crossingUp = pastAbove
        }

        /// Puts the cursor at the position nearest the point, after moving it `dx` along.
        private mutating func place(dx: CGFloat) {
            let rows = layout.rows
            let lineHeight = layout.lineHeight
            let waitingY = point.y
            var y = min(max(0, point.y), height - 0.001)
            var row = Int(y / lineHeight)
            var x = point.x
            if dx > 0, rows[row].wraps {
                x = min(x, rows[row].width) + dx
                while x > rows[row].width, rows[row].wraps, row + 1 < rows.count {
                    x -= rows[row].width
                    row += 1
                    y += lineHeight
                }
            } else if dx < 0, row > 0, rows[row - 1].wraps {
                x = min(x, rows[row].width) + dx
                while x < 0, row > 0, rows[row - 1].wraps {
                    row -= 1
                    x += rows[row].width
                    y -= lineHeight
                }
            } else {
                x += dx
            }
            // Past the known rows the point keeps its travel (not far enough to wait there).
            if waitingY < 0 || waitingY >= height { y = waitingY }
            let width = rows[row].width
            if row == rows.count - 1, !knowsEnd, !endsLine, x > width {
                // Along past the end of what the host showed, mid-line: on at its end, for it to
                // show more.
                point = CGPoint(x: min(x, width + layout.wrapWidth), y: y)
                cursor = rows[row].end
            } else if row == 0, !knowsStart, x < 0 {
                point = CGPoint(x: max(x, -layout.wrapWidth), y: y)
                cursor = rows[row].start
            } else {
                point = CGPoint(x: min(max(0, x), layout.wrapWidth), y: y)
                cursor = rows[row].nearest(point.x)
            }
        }

        /// The step past the known text went unanswered: that was the text's start or end, the
        /// host ignored the step, and its cursor is where this copy's is.
        private mutating func expire(at time: TimeInterval) {
            guard let crossing, time - crossing > TrackpadCursor.edgeTimeout else { return }
            self.crossing = nil
            if crossingUp { knowsStart = true } else { knowsEnd = true }
            waiting = false
            point.y = min(max(0, point.y), height - 0.001)
        }

        /// Puts the cursor where the point is once more, as the text known or the host's place
        /// changed (or, `lifting`, as the finger lifts and stops waiting): the UTF-16 offset it
        /// moved.
        public mutating func settle(at time: TimeInterval, lifting: Bool = false) -> Int {
            expire(at: time)
            let start = position
            if lifting {
                crossing = nil
                waiting = false
                point.y = min(max(0, point.y), height - 0.001)
                point.x = min(max(0, point.x), layout.wrapWidth)
            } else if crossing != nil {
                return 0
            } else if waiting, pastAbove || pastBelow {
                cross(at: time)
                return position - start
            } else if waiting {
                // The text's start or end after all: back within the rows.
                waiting = false
                point.y = min(max(0, point.y), height - 0.001)
            }
            place(dx: 0)
            return position - start
        }

        /// Reads the field's context as the host's cursor being where this copy's is: when it
        /// is, what it shows beyond this copy is added and laid out again, the point keeping its
        /// place by the cursor (or among the rows, where it waited past them), and at the known
        /// text's edge an empty context is the text's start or a line's end. True when it learned
        /// anything.
        ///
        /// `keepingX` (Dictus, not Hex): the finger is going up or down, so the point keeps its
        /// own x when the text is laid out again, rather than its place beside the cursor. A
        /// host can share a line from its middle (Safari shares about 60 characters, cut
        /// anywhere): the cursor came onto that line at the finger's x among guessed widths,
        /// and once the line's start shows, the finger's x is still where the person points,
        /// where the cursor's guessed place is not. Along a line the cursor's place is kept, as
        /// Hex does, so a drag never jumps.
        @discardableResult
        public mutating func catchUp(before: String, after: String, width: (Character) -> CGFloat, keepingX: Bool = false) -> Bool {
            let text = layout.text
            var fresh = Array(before) + Array(after)
            let host = self.host
            var low = host - before.count
            var high = low + fresh.count
            // The host's context before its cursor starts just after a line break, and after it
            // stops just before one: a gap of one beside this copy is that line break.
            if crossing != nil, !crossingUp, low == text.count + 1 {
                fresh.insert("\n", at: 0)
                low -= 1
            } else if crossing != nil, crossingUp, high == -1 {
                fresh.append("\n")
                high = 0
            }
            let overlap = (max(low, 0), min(high, text.count))
            hostCaughtUp = false
            guard overlap.0 <= overlap.1 else { return false }
            // Compare near the cursor: a host that hasn't caught up reads as another place.
            var near = (max(overlap.0, host - 48), min(overlap.1, host + 48))
            if near.0 >= near.1 { near = (max(overlap.0, overlap.1 - 48), overlap.1) }
            guard near.0 >= near.1 || fresh[(near.0 - low)..<(near.1 - low)].elementsEqual(text[near.0..<near.1]) else { return false }
            hostCaughtUp = true
            guard low < 0 || high > text.count else {
                var learned = false
                if host == 0, before.isEmpty, !knowsStart {
                    knowsStart = true
                    learned = true
                }
                if host == text.count, after.isEmpty, !endsLine {
                    endsLine = true
                    learned = true
                }
                return learned || waiting
            }
            let shift = max(0, -low)
            let offset = CGVector(dx: point.x - caret.x, dy: point.y - caret.y)
            let row = layout.rows[layout.row(of: cursor)]
            // A row the point only waited by (past the known ones, or a line shown only by its
            // break) is laid out anew: the point keeps its place among the rows.
            let keepsPlace = crossing != nil || waiting || row.start == row.end
            let head = low > 0 ? Array(text[..<low]) : []
            let tail = high < text.count ? Array(text[high...]) : []
            if high > text.count { endsLine = !(after.last?.isWhitespace ?? false) }
            if low < 0, before.isEmpty { knowsStart = true }
            let lastRow = layout.rows.count - 1
            layout = Layout(text: head + fresh + tail, wrapWidth: layout.wrapWidth, lineHeight: layout.lineHeight, width: width)
            cursor = host + shift
            crossing = nil
            if keepsPlace {
                point.y += CGFloat(layout.row(of: shift)) * layout.lineHeight
            } else if keepingX {
                // Going up or down: the point stays where the finger is, its rows counted from
                // the end of the text known before, which is laid out as it was (Dictus).
                point.y += CGFloat(layout.row(of: shift + text.count) - lastRow) * layout.lineHeight
            } else {
                // Elsewhere the point stays beside the cursor, which the host has where it was.
                point = CGPoint(x: caret.x + offset.dx, y: caret.y + offset.dy)
            }
            return true
        }

        /// The cursor is on the first or last row this copy knows, or the one beside it, or
        /// waiting past them: the field may show more by now.
        public var nearsEdge: Bool {
            let row = layout.row(of: cursor)
            return crossing != nil || row <= 1 || row >= layout.rows.count - 2 || point.y < 0 || point.y >= height
        }
    }

    /// How long the step over a line break past the known text waits for the host to show the
    /// next line before it's taken as the text's end (the simulator's UITextView answered in
    /// about 10 ms).
    public static let edgeTimeout: TimeInterval = 0.1

    // MARK: - The finger

    /// One finger on the trackpad: the `State` it moves, and its last few moves, for its speed.
    /// Hex's `FullKeyboardEngine.trackpadStep` without the engine, so the keyboard only reads
    /// the host and moves its cursor.
    public struct Gesture: Equatable {
        public private(set) var state: State
        public private(set) var path: [Sample]

        /// The trackpad starts with the finger at `point`: travel before the hold doesn't count.
        public init(state: State, at point: CGPoint, time: TimeInterval) {
            self.state = state
            path = [Sample(time: time, point: point)]
        }

        /// The finger moved to `point` at `time`: the UTF-16 offset to move the cursor by. The
        /// finger's speed sets how far the point goes (`gain(speed:)`); with no time between
        /// moves (a test's clock) it goes as far as the finger. Near the edge of the text it
        /// knows, `context` is read for what the host shows by now.
        public mutating func move(
            to point: CGPoint,
            at time: TimeInterval,
            context: () -> (before: String, after: String),
            width: (Character) -> CGFloat
        ) -> Int {
            let last = path.last ?? Sample(time: time, point: point)
            let sample = Sample(time: time, point: point)
            path = time > last.time ? path.suffix(7) + [sample] : [sample]
            let gain = TrackpadCursor.gain(speed: TrackpadCursor.speed(along: path))
            let dx = point.x - last.point.x, dy = point.y - last.point.y
            let vertical = path.count > 1 ? TrackpadCursor.isVertical(path) : abs(dy) > abs(dx)
            var offset = state.move(by: CGVector(dx: dx * gain, dy: dy * gain), at: time, vertical: vertical)
            if state.nearsEdge {
                let shown = context()
                if state.catchUp(before: shown.before, after: shown.after, width: width, keepingX: vertical) {
                    offset += state.settle(at: time)
                }
            }
            return offset
        }

        /// The field may have changed (the host following the moves): it may show more of the
        /// text, or that the cursor is at the text's start or a line's end, so the cursor goes
        /// where the point is once more. Hex runs this on the host's text/selection callbacks;
        /// Dictus runs it a moment after each move, which needs no hook in the view controller.
        public mutating func refresh(
            at time: TimeInterval,
            context: () -> (before: String, after: String),
            width: (Character) -> CGFloat
        ) -> Int {
            if state.nearsEdge {
                let shown = context()
                let vertical = path.count > 1 && TrackpadCursor.isVertical(path)
                state.catchUp(before: shown.before, after: shown.after, width: width, keepingX: vertical)
            }
            return state.settle(at: time)
        }

        /// The finger lifts: the cursor goes where the point is, among the rows known.
        public mutating func lift(at time: TimeInterval) -> Int {
            state.settle(at: time, lifting: true)
        }
    }
}
