// tools/swipe-bench/Sources/swipe-bench/SwipePaths.swift
//
// Ported from Hex (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// android/benchmark/typing/swipe_paths.py: SplitMix64, the noise presets, swipe_timed and
// key_sequence) (#948). Hex's file is itself a port of its iPhone bench's Swift generator.
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
// The random numbers are drawn in Hex's order, so the same seed on the same key centres
// gives the same path. The key centres are Dictus's (`LetterPage`), not Hex's grid.
import Foundation

/// Swift's SplitMix64, with its 64-bit wrapping arithmetic.
struct SplitMix64 {
    private static let golden: UInt64 = 0x9E37_79B9_7F4A_7C15
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ Self.golden }

    mutating func next() -> UInt64 {
        state = state &+ Self.golden
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }

    mutating func uniform(_ a: Double, _ b: Double) -> Double { a + (b - a) * unit() }

    mutating func gaussian() -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
}

/// A finger's habits, in key pitches (Hex's `Noise`).
struct Noise {
    /// Spread of a sentence's sloppiness factor (log-normal), which scales everything below.
    var sloppiness = 0.25
    /// The whole swipe's shift off the keys.
    var offset = 0.08
    /// Spread around a middle key, the first and the last.
    var via = 0.22
    var start = 0.18
    var end = 0.22
    /// How far a corner is rounded.
    var cut = 0.5
    /// Overshoot (positive) or stop short (negative) at the end, drawn in this range.
    var overshoot = (-0.1, 0.35)
    /// A slow wobble across the path.
    var tremor = 0.025
    /// Touches per second.
    var rate = 120.0
    var speed = (0.6, 1.5)
    /// Speed kept through a straight-on key, and the chance of one stop on the way.
    var flow = 0.0
    var hesitate = 0.0

    static let typical = Noise()
    static var sloppy: Noise {
        var n = Noise()
        n.offset = 0.15
        n.via = 0.36
        n.start = 0.3
        n.end = 0.42
        n.cut = 0.8
        n.overshoot = (-0.25, 0.7)
        n.tremor = 0.055
        n.speed = (0.45, 1.2)
        return n
    }
    static var neat: Noise {
        var n = Noise()
        n.offset = 0.04
        n.via = 0.12
        n.start = 0.1
        n.end = 0.12
        n.cut = 0.3
        n.overshoot = (-0.05, 0.15)
        n.tremor = 0.01
        return n
    }
    /// Hex's "none": through the keys' centres, corners unrounded, at an even speed.
    static var clean: Noise {
        var n = Noise()
        n.sloppiness = 0
        n.offset = 0
        n.via = 0
        n.start = 0
        n.end = 0
        n.cut = 0
        n.overshoot = (0, 0)
        n.tremor = 0
        n.speed = (1, 1)
        return n
    }

    static func named(_ name: String) -> Noise? {
        switch name {
        case "clean", "none": return .clean
        case "neat": return .neat
        case "typical": return .typical
        case "sloppy": return .sloppy
        default: return nil
        }
    }
}

enum SwipePaths {
    /// Letters with neither a key nor a base letter's key, swiped as these keys.
    static let spelled: [Character: String] = ["ß": "s", "œ": "oe", "æ": "ae"]

    /// The keys a word's swipe goes through (an accented letter on its base letter's key
    /// unless it has its own), repeats run together; nil for a letter with no key.
    static func keySequence(_ word: String, centres: [Character: (Double, Double)]) -> [Character]? {
        var out: [Character] = []
        for ch in word {
            if ch == "'" { continue }
            let base = String(ch).decomposedStringWithCanonicalMapping.unicodeScalars.first.map(Character.init)
            let keys: String
            if centres[ch] != nil {
                keys = String(ch)
            } else if let base, centres[base] != nil {
                keys = String(base)
            } else if let spelled = spelled[ch] {
                keys = spelled
            } else {
                return nil
            }
            for k in keys {
                guard centres[k] != nil else { return nil }
                if out.last != k { out.append(k) }
            }
        }
        return out
    }

    @inline(__always) private static func length(_ x: Double, _ y: Double) -> Double { (x * x + y * y).squareRoot() }

    /// Hex's swipeTimed: via points around each key, corners rounded with quadratic Béziers,
    /// an overshoot or a trim at the end, a slow wobble, then sampled in time on a quintic
    /// (minimum-jerk) profile between keys, with an optional hesitation. In key pitches and
    /// seconds.
    static func swipeTimed(
        _ centres: [(Double, Double)], noise: Noise, sloppiness s: Double, rng: inout SplitMix64,
        onLetter: (Double, Double) -> Bool
    ) -> (points: [(Double, Double)], times: [Double]) {
        let m = centres.count
        let ox = rng.gaussian() * noise.offset * s
        let oy = rng.gaussian() * noise.offset * s
        var via: [(Double, Double)] = []
        for (j, (cx, cy)) in centres.enumerated() {
            let sd = (j == 0 ? noise.start : j == m - 1 ? noise.end : noise.via) * s
            var gx = rng.gaussian() * sd
            var vx = (cx + ox) + gx
            var vy = (cy + oy) + rng.gaussian() * sd
            // A swipe starts on a letter key.
            var tries = 0
            while j == 0, !onLetter(vx, vy), tries < 50 {
                gx = rng.gaussian() * sd
                vx = (cx + ox * 0.5) + gx
                vy = (cy + oy * 0.5) + rng.gaussian() * sd
                tries += 1
            }
            if j == 0, !onLetter(vx, vy) { (vx, vy) = (cx, cy) }
            via.append((vx, vy))
        }

        // Dense path with rounded corners; anchors are the path indices of each key's moment.
        var path = [via[0]]
        var anchors = [0]
        func lineTo(_ p: (Double, Double)) {
            let (ax, ay) = path[path.count - 1]
            let steps = max(1, Int(length(p.0 - ax, p.1 - ay) / 0.05))
            for k in 1...steps {
                let t = Double(k) / Double(steps)
                path.append((ax + (p.0 - ax) * t, ay + (p.1 - ay) * t))
            }
        }
        if m > 2 {
            for j in 1..<(m - 1) {
                let (ax, ay) = via[j - 1], (bx, by) = via[j], (cx, cy) = via[j + 1]
                let lin = length(bx - ax, by - ay), lout = length(cx - bx, cy - by)
                guard lin > 1e-6, lout > 1e-6 else {
                    lineTo((bx, by))
                    anchors.append(path.count - 1)
                    continue
                }
                // Fingers round a corner by a few tenths of a key, however long the strokes around it.
                let d = min(0.45 * min(lin, lout), noise.cut * min(s, 1.8) * rng.uniform(0.4, 1.4) * 0.6)
                let pin = (bx - (bx - ax) * (d / lin), by - (by - ay) * (d / lin))
                let pout = (bx + (cx - bx) * (d / lout), by + (cy - by) * (d / lout))
                lineTo(pin)
                for k in 1...12 {
                    let t = Double(k) / 12
                    let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
                    path.append((pin.0 * a + bx * b + pout.0 * c, pin.1 * a + by * b + pout.1 * c))
                    if k == 6 { anchors.append(path.count - 1) }
                }
            }
        }
        lineTo(via[m - 1])

        // Overshoot along the last direction, or stop short (keeping half the last stretch).
        let e = rng.uniform(noise.overshoot.0, noise.overshoot.1) * s
        if path.count >= 2 {
            let (tx, ty) = path[max(0, path.count - 6)]
            let (lx, ly) = path[path.count - 1]
            let dx = lx - tx, dy = ly - ty
            let dl = length(dx, dy)
            if dl > 1e-6 {
                if e > 0 {
                    lineTo((lx + dx * (e / dl), ly + dy * (e / dl)))
                } else {
                    var trimmed = 0.0
                    let last = anchors[anchors.count - 1]
                    let keep = last + (path.count - 1 - last) / 2
                    while path.count - 1 > keep, trimmed < -e {
                        let a = path[path.count - 1], b = path[path.count - 2]
                        trimmed += length(a.0 - b.0, a.1 - b.1)
                        path.removeLast()
                    }
                }
            }
        }
        anchors.append(path.count - 1)

        // Arc lengths, and a slow wobble across the path fading in and out at its ends.
        var arc = [0.0]
        for i in 1..<path.count {
            arc.append(arc[i - 1] + length(path[i].0 - path[i - 1].0, path[i].1 - path[i - 1].1))
        }
        let total = arc[arc.count - 1]
        if noise.tremor > 0, total > 0 {
            let amp = noise.tremor * s
            let l1 = rng.uniform(1.2, 3.0)
            let l2 = rng.uniform(0.5, 1.2)
            let p1 = rng.uniform(0, 2 * Double.pi)
            let p2 = rng.uniform(0, 2 * Double.pi)
            var wobbled = path
            if path.count > 2 {
                for i in 1..<(path.count - 1) {
                    let dx = path[i + 1].0 - path[i - 1].0, dy = path[i + 1].1 - path[i - 1].1
                    let dl = length(dx, dy)
                    guard dl > 1e-9 else { continue }
                    let fade = min(1, arc[i] / 0.3, (total - arc[i]) / 0.3)
                    let w = amp * fade * (sin(2 * Double.pi * arc[i] / l1 + p1) + 0.5 * sin(2 * Double.pi * arc[i] / l2 + p2))
                    wobbled[i] = (path[i].0 + (-dy / dl) * w, path[i].1 + (dx / dl) * w)
                }
            }
            path = wobbled
        }

        // Time: each stretch between key moments takes (0.08 + 0.05 * its length) * speed.
        let speed = rng.uniform(noise.speed.0, noise.speed.1)
        var times = [0.0]
        for k in 1..<anchors.count {
            times.append(times[k - 1] + (0.08 + 0.05 * (arc[anchors[k]] - arc[anchors[k - 1]])) * speed)
        }
        func position(_ u: Double) -> (Double, Double) {
            var lo = 0, hi = arc.count - 1
            while lo < hi - 1 {
                let mid = (lo + hi) / 2
                if arc[mid] <= u { lo = mid } else { hi = mid }
            }
            let span = arc[hi] - arc[lo]
            let t = span > 0 ? min(1, max(0, (u - arc[lo]) / span)) : 0
            return (path[lo].0 + (path[hi].0 - path[lo].0) * t, path[lo].1 + (path[hi].1 - path[lo].1) * t)
        }

        // Speed kept through each key: flow of the slower neighbouring stretch's peak, by cos²(turn/2).
        var through = [Double](repeating: 0, count: anchors.count)
        if noise.flow > 0, anchors.count == m, m > 2 {
            for j in 1..<(m - 1) {
                let ax = via[j].0 - via[j - 1].0, ay = via[j].1 - via[j - 1].1
                let bx = via[j + 1].0 - via[j].0, by = via[j + 1].1 - via[j].1
                let la = length(ax, ay), lb = length(bx, by)
                guard la > 1e-6, lb > 1e-6 else { continue }
                let cosTurn = max(-1, min(1, (ax * bx + ay * by) / (la * lb)))
                let keep = noise.flow * (1 + cosTurn) / 2
                let before = (arc[anchors[j]] - arc[anchors[j - 1]]) / max(1e-9, times[j] - times[j - 1])
                let after = (arc[anchors[j + 1]] - arc[anchors[j]]) / max(1e-9, times[j + 1] - times[j])
                through[j] = keep * 1.5 * min(before, after)
            }
        }

        // A sample every 1/rate s, each stretch walked on a quintic Hermite (minimum jerk from rest).
        var out: [(Double, Double)] = []
        var stamps: [Double] = []
        let end = times[times.count - 1]
        var t = 0.0
        var k = 1
        while t < end {
            while k < times.count - 1, t > times[k] { k += 1 }
            let span = max(1e-9, times[k] - times[k - 1])
            let tau = (t - times[k - 1]) / span
            let stretch = arc[anchors[k]] - arc[anchors[k - 1]]
            let t2 = tau * tau, t3 = t2 * tau, t4 = t3 * tau, t5 = t4 * tau
            let h5 = 10 * t3 - 15 * t4 + 6 * t5
            let h1 = tau - 6 * t3 + 8 * t4 - 3 * t5
            let h4 = -4 * t3 + 7 * t4 - 3 * t5
            let walked = stretch * h5 + through[k - 1] * span * h1 + through[k] * span * h4
            out.append(position(arc[anchors[k - 1]] + max(0, min(stretch, walked))))
            stamps.append(t)
            t += 1 / noise.rate
        }
        out.append(path[path.count - 1])
        stamps.append(end)
        // Sometimes the finger stops once along the way, for 0.08 to 0.25 s.
        if noise.hesitate > 0, rng.unit() < noise.hesitate, out.count > 8 {
            let at = Int(Double(out.count) * rng.uniform(0.15, 0.85))
            let wait = rng.uniform(0.08, 0.25)
            for i in at..<stamps.count { stamps[i] += wait }
        }
        return (out, stamps)
    }
}
