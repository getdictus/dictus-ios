// DictusKeyboard/Views/SwipeTrailView.swift
//
// Ported from Hex (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// ios/HEXShared/FullKeyboard/SwipeTyping.swift, `SwipeTrailView`) (#948).
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
// What the port changed: the colour is Dictus's (the accent in light mode, white in dark,
// at Hex's opacities) and is read from the view's trait collection instead of Hex's palette.
// The drawing, the tail and the fade are Hex's.
import QuartzCore
import UIKit

/// The light trail behind a swiping finger: the last `tail` seconds of its path, which
/// shortens behind the finger and fades when it lifts. A shape layer, so the keyboard draws
/// no bitmap of its own for it.
///
/// WHY a `CADisplayLink` here when #390 forbids timers that outlive the keyboard: the link
/// runs only while a finger is swiping, `fade`, `clear` and leaving the window all stop it,
/// and its target is this view, which the keyboard view owns and drops with itself.
final class SwipeTrailView: UIView {
    static let tail: TimeInterval = 0.45
    static let width: CGFloat = 6

    private let shape = CAShapeLayer()
    private var points: [(point: CGPoint, at: TimeInterval)] = []
    private var link: CADisplayLink?
    private let clock: () -> TimeInterval = { CACurrentMediaTime() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityIdentifier = "keyboard.swipe.trail"
        shape.fillColor = nil
        shape.lineCap = .round
        shape.lineJoin = .round
        shape.lineWidth = Self.width
        layer.addSublayer(shape)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Hex's colours on Dictus's palette: white at 50% on the dark keyboard, the accent
    /// (#3D7EFF) at 42% on the light one.
    private func strokeColor() -> CGColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(white: 1, alpha: 0.5).cgColor
        }
        return UIColor(red: 0x3D / 255, green: 0x7E / 255, blue: 1, alpha: 0.42).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
    }

    /// Off screen, the display link (which holds this view) stops.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { clear() }
    }

    var isShowing: Bool { shape.path != nil }

    func begin(_ start: [CGPoint]) {
        shape.removeAllAnimations()
        shape.opacity = 1
        shape.strokeColor = strokeColor()
        let now = clock()
        points = start.map { ($0, now) }
        if link == nil, window != nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
        redraw()
    }

    func add(_ point: CGPoint) {
        points.append((point, clock()))
        redraw()
    }

    /// The finger lifted: the trail fades out.
    func fade() {
        stopTicking()
        guard shape.path != nil else { return }
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, self.link == nil else { return }
            self.clear()
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.2
        shape.opacity = 0
        shape.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    func clear() {
        stopTicking()
        points.removeAll()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.removeAllAnimations()
        shape.path = nil
        CATransaction.commit()
    }

    private func stopTicking() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        redraw()
    }

    private func redraw() {
        // Points older than the tail drop off behind the finger, down to its last stretch.
        if let old = points.lastIndex(where: { $0.at < clock() - Self.tail }) {
            let drop = min(old, points.count - 2)
            if drop > 0 { points.removeFirst(drop) }
        }
        let path = CGMutablePath()
        if let first = points.first {
            path.move(to: first.point)
            for p in points.dropFirst() { path.addLine(to: p.point) }
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = points.count >= 2 ? path : nil
        CATransaction.commit()
    }
}
