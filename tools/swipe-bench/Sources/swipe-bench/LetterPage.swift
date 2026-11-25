// tools/swipe-bench/Sources/swipe-bench/LetterPage.swift
// Dictus's letter page, laid out as the keyboard lays it out, for the swipe bench (#948).
import CoreGraphics
import DictusCore

/// The letter page of a language's default layout (`KeyboardLayouts.qwertyNormal` for en,
/// `azertyNormal` for fr, `QWERTZLayout` for de, with its ä ö ü keys: the key widths restated here, since those builders live in the
/// keyboard target and import UIKit) on a `width` x `height` grid laid out by
/// `KeyPlaneGeometry`, as `GiellaKeyboardView.keyPlaneSlots` does. The default grid is an
/// iPhone 17 held upright, as `tools/keyboard-bench` uses.
struct LetterPage {
    /// Where the finger aims: each letter's keycap centre, in points.
    let caps: [Character: CGPoint]
    /// The letter keys' touch targets: a swipe starts on one.
    let letterHits: [CGRect]
    /// What the decoder is given (`KeySource`).
    let keys: SpatialDecoder.Keys
    /// One key unit across and the row pitch down: the generator's unit, as Hex's bench
    /// draws in key pitches.
    let pitch: CGSize
    let width: CGFloat

    /// Each row's keys: a letter, a space bar (" "), or nil for another key (shift, delete,
    /// spacer, the AZERTY accent key, 123, emoji, return), with its width in key units.
    static func rows(_ language: String) -> [[(Character?, CGFloat)]] {
        let bottom: [(Character?, CGFloat)] = [(nil, 1.25), (nil, 1.25), (" ", 5.5), (nil, 2)]
        func letters(_ s: String) -> [(Character?, CGFloat)] { s.map { ($0, 1) } }
        if language == "fr" {
            return [letters("azertyuiop"), letters("qsdfghjklm"),
                    [(nil, 1.5)] + letters("wxcvbn") + [(nil, 1), (nil, 1.5)], bottom]
        }
        if language == "de" {
            let rows = QWERTZLayout.lowercasedLettersRows.map { $0.joined() }
            return [letters(rows[0]), letters(rows[1]), [(nil, 1.5)] + letters(rows[2]) + [(nil, 1.5)], bottom]
        }
        return [letters("qwertyuiop"), [(nil, 0.5)] + letters("asdfghjkl") + [(nil, 0.5)],
                [(nil, 1.5)] + letters("zxcvbnm") + [(nil, 1.5)], bottom]
    }

    /// Which keys the decoder is given.
    enum KeySource: String {
        /// As `tools/keyboard-bench`'s `spatialKeys` reads them (#1011): each letter at its
        /// touch target's centre, one key unit across by the first letter row's target height.
        case targets
        /// As `GiellaKeyboardView.spatialKeys()` reads them: the same, except the unit across
        /// is the first letter's touch target, which on an edge key reaches the screen's side
        /// (43 pt for a 39.5 pt unit on a 402 pt grid).
        case keyboard
        /// As Hex's keyboard gives them: each letter at its keycap's centre, one key unit
        /// across by the row pitch.
        case caps
    }

    init?(_ language: String, width: CGFloat = 402, height: CGFloat = 216, source: KeySource = .targets) {
        let page = Self.rows(language)
        let sizeClass: KeyPlaneSizeClass = width <= 375 ? .small : (width >= 430 ? .large : .standard)
        let geometry = KeyPlaneGeometry.apple(sizeClass, .portrait)
        guard let slots = geometry.layout(rows: page.map { $0.map(\.1) }, width: width, height: height) else { return nil }
        var caps: [Character: CGPoint] = [:]
        var centres: [Character: CGPoint] = [:]
        var hits: [CGRect] = []
        var bottom: CGFloat = 0
        var space: CGRect?
        var keyPitch = CGSize.zero
        var unit: CGFloat = 0
        for (row, rowSlots) in zip(page, slots) {
            let units = row.reduce(0) { $0 + $1.1 }
            let unitWidth = (width - 2 * geometry.sideInset + geometry.keyGap) / units
            for ((key, keyUnits), slot) in zip(row, rowSlots) {
                guard let key else { continue }
                if key == " " {
                    space = slot.hit
                    continue
                }
                caps[key] = CGPoint(x: slot.cap.midX, y: slot.cap.midY)
                centres[key] = source == .caps ? CGPoint(x: slot.cap.midX, y: slot.cap.midY) : CGPoint(x: slot.hit.midX, y: slot.hit.midY)
                hits.append(slot.hit)
                bottom = max(bottom, slot.hit.midY)
                if keyPitch == .zero {
                    unit = unitWidth
                    switch source {
                    case .targets: keyPitch = CGSize(width: unitWidth, height: slot.hit.height)
                    case .keyboard: keyPitch = CGSize(width: slot.hit.width / keyUnits, height: slot.hit.height)
                    case .caps: keyPitch = CGSize(width: unitWidth, height: geometry.rowPitch)
                    }
                }
            }
        }
        self.caps = caps
        self.letterHits = hits
        self.keys = SpatialDecoder.Keys(centres: centres, pitch: keyPitch, bottomRowY: bottom, space: space)
        self.pitch = CGSize(width: unit, height: geometry.rowPitch)
        self.width = width
    }

    /// Whether a point (in key pitches) lands on a letter key.
    func onLetter(_ x: Double, _ y: Double) -> Bool {
        let p = CGPoint(x: x * pitch.width, y: y * pitch.height)
        return letterHits.contains { $0.contains(p) }
    }

    /// The keycap centres in key pitches, as the generator draws.
    var capsInPitches: [Character: (Double, Double)] {
        caps.mapValues { (Double($0.x / pitch.width), Double($0.y / pitch.height)) }
    }
}
