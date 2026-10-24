// DictusApp/Views/HomeSmartModeRing.swift
// The home mic's Smart Mode dial: the half-ring drawn around the mic, its resting hint and
// the line under it (issue #489).
import SwiftUI
import DictusCore

/// The two parts of the dial's presentation that are still under review.
///
/// Both are drawn, and both are one switch away from gone: the dim over the rest of the
/// dashboard while the ring is open, and the line under the mic saying what the release
/// will do. Turning either off removes it and nothing else — the ring, the gesture and
/// VoiceOver's actions do not read them.
enum HomeSmartModeRingStyle {

    /// Dim the cards and the history hint while the ring is open.
    static let dimsDashboard = true

    /// Show "Release to dictate…" under the mic while the ring is open. Also where an
    /// unavailable mode says why, so with this off a greyed sector says nothing more.
    static let showsReleaseHint = true

    /// How far the rest of the dashboard fades.
    static let dimmedOpacity: Double = 0.25
}

extension View {

    /// The dashboard's dim while the ring is open, or nothing when the style turns it off.
    func homeSmartModeRingDim(_ isRingOpen: Bool) -> some View {
        opacity(HomeSmartModeRingStyle.dimsDashboard && isRingOpen ? HomeSmartModeRingStyle.dimmedOpacity : 1)
            .animation(.easeOut(duration: 0.18), value: isRingOpen)
            .allowsHitTesting(!isRingOpen)
    }
}

// MARK: - Resting hint

/// What the mic says at rest about the dial behind it: a chevron on each side for "hold,
/// then slide", and three dots along the top of the halo where the ring will open. No
/// text: the gesture is the accelerator, and VoiceOver has its own way in.
struct HomeSmartModeRestHint: View {

    var body: some View {
        ZStack {
            // Drawn as shapes, not SF Symbols: inside the mic's background VoiceOver
            // read the two symbols as « Retour » and « Suivant », hidden or not
            // (simulator, 2026-10-24). A shape is never an accessibility element.
            HStack(spacing: 92 + 20) {
                RestChevron(pointsLeft: true)
                RestChevron(pointsLeft: false)
            }
            .foregroundColor(.dictusAccent.opacity(0.55))

            ForEach([-28.0, 0.0, 28.0], id: \.self) { degrees in
                Circle()
                    .fill(Color.dictusAccent.opacity(degrees == 0 ? 0.7 : 0.4))
                    .frame(width: 4, height: 4)
                    .offset(HomeSmartModeRing.offset(angle: 90 + degrees, radius: 56))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One of the resting hint's chevrons, 7 × 12 pt.
private struct RestChevron: View {

    let pointsLeft: Bool

    var body: some View {
        ChevronShape(pointsLeft: pointsLeft)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 7, height: 12)
    }
}

private struct ChevronShape: Shape {

    let pointsLeft: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipX = pointsLeft ? rect.minX : rect.maxX
        let backX = pointsLeft ? rect.maxX : rect.minX
        path.move(to: CGPoint(x: backX, y: rect.minY))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.addLine(to: CGPoint(x: backX, y: rect.maxY))
        return path
    }
}

// MARK: - The ring

/// The half-ring of modes, centred on the mic and drawn over it.
///
/// It is an overlay on the mic and owns no layout: the mic stays exactly where #788 put
/// it, which is where the recording screen draws its own button. It takes no touches
/// either — the finger that opened it is still the mic's gesture, which feeds the
/// session the positions; this only draws what the session says.
struct HomeSmartModeRing: View {

    let session: SmartModeRingSession

    private typealias Layout = SmartModeRingLayout

    private static var diameter: CGFloat { Layout.outerRadius * 2 }

    var body: some View {
        ZStack {
            // The track: the whole upper half, so an empty slot reads as part of the
            // dial rather than as a missing piece.
            RingSectorShape(
                range: 0...Layout.sweep,
                innerRadius: Layout.innerRadius,
                outerRadius: Layout.outerRadius
            )
            .fill(Color.dictusSurface.opacity(0.96))
            .overlay(
                RingSectorShape(
                    range: 0...Layout.sweep,
                    innerRadius: Layout.innerRadius,
                    outerRadius: Layout.outerRadius
                )
                .stroke(Color.dictusAccent.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .dictusAccent.opacity(0.3), radius: 16)

            ForEach(Array(session.entries.enumerated()), id: \.element.id) { index, entry in
                sector(index: index, entry: entry)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("home.smartModeRing")
    }

    private func sector(index: Int, entry: SmartModeFanEntry) -> some View {
        let range = session.layout.angleRange(ofEntry: index)
        let isLit = session.highlightedIndex == index
        let isSelectable = session.isSelectable(index)
        let mid = (Layout.innerRadius + Layout.outerRadius) / 2 + 4
        return ZStack {
            RingSectorShape(
                range: (range.lowerBound + 1.5)...(range.upperBound - 1.5),
                innerRadius: Layout.innerRadius + 3,
                outerRadius: Layout.outerRadius - 3
            )
            .fill(isLit ? Color.dictusAccent : Color.clear)

            label(entry, isLit: isLit, isSelectable: isSelectable)
                .frame(width: sectorLabelWidth)
                .offset(Self.offset(angle: session.layout.centerAngle(ofEntry: index), radius: mid))
        }
        .animation(.easeOut(duration: 0.12), value: isLit)
    }

    /// An icon and the fan's short name, with the fan's `PRO` / `Off` tag under it.
    private func label(_ entry: SmartModeFanEntry, isLit: Bool, isSelectable: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: entry.icon)
                .font(.system(size: 15, weight: .medium))
            Text(HomeSmartModeCopy.shortName(of: entry))
                .font(.system(size: 12, weight: isLit ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let tag = HomeSmartModeCopy.tagLabel(session.picker.tag(for: entry)) {
                Text(tag)
                    .font(.system(size: 8, weight: .bold))
                    .textCase(.uppercase)
                    .opacity(0.8)
            }
        }
        .foregroundColor(isLit ? .white : .primary)
        .opacity(isSelectable ? 1 : 0.35)
        // The ring's labels stay at one size: the dial is a 240 pt object around a 92 pt
        // mic and cannot grow with Dynamic Type without covering the cards. VoiceOver's
        // actions, which follow the user's text size, carry the same choices.
        .dynamicTypeSize(.large)
    }

    /// The width a label may take: the chord of a slot at the label's radius.
    private var sectorLabelWidth: CGFloat {
        let radians = session.layout.slotWidth * .pi / 180
        return min(72, 2 * 86 * CGFloat(sin(radians / 2)))
    }

    /// The offset from the ring's centre of the point at `angle` (0 right, 90 up) and
    /// `radius`.
    static func offset(angle: Double, radius: CGFloat) -> CGSize {
        let radians = angle * .pi / 180
        return CGSize(width: CGFloat(cos(radians)) * radius, height: -CGFloat(sin(radians)) * radius)
    }
}

/// An annular sector, angles in `SmartModeRingLayout`'s convention.
private struct RingSectorShape: Shape {

    let range: ClosedRange<Double>
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Sampled rather than `addArc`, whose `clockwise` flag reads inverted in a
        // y-down space: one degree per point is smooth at these radii and cannot be
        // drawn the wrong way round.
        func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
            let radians = degrees * .pi / 180
            return CGPoint(x: center.x + CGFloat(cos(radians)) * radius,
                           y: center.y - CGFloat(sin(radians)) * radius)
        }
        let steps = max(2, Int((range.upperBound - range.lowerBound).rounded()))
        let angles = (0...steps).map {
            range.lowerBound + (range.upperBound - range.lowerBound) * Double($0) / Double(steps)
        }
        var path = Path()
        path.move(to: point(angles[0], outerRadius))
        angles.dropFirst().forEach { path.addLine(to: point($0, outerRadius)) }
        angles.reversed().forEach { path.addLine(to: point($0, innerRadius)) }
        path.closeSubpath()
        return path
    }
}

// MARK: - The line under the mic

/// "Release to dictate: → EN", and how to back out. Shown only while the ring is open,
/// and only when `HomeSmartModeRingStyle.showsReleaseHint` is on.
struct HomeSmartModeRingHint: View {

    let hint: SmartModeRingHint

    var body: some View {
        VStack(spacing: 4) {
            Text(primary)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.dictusAccent)
            if let secondary {
                Text(secondary)
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        // Capped: it is drawn over the history hint, between the mic and the tab bar,
        // and at accessibility sizes its second line ran into the tab bar (iPhone SE,
        // 2026-10-24). VoiceOver does not read it; the mic's value and actions do.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .frame(width: 300)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var primary: String {
        switch hint {
        case .slide:
            return String(localized: "Slide onto a mode to dictate",
                          comment: "Line under the Home mic while the Smart Mode dial is open and the finger points at nothing yet.")
        case .nothingPinned:
            return String(localized: "No modes pinned. The keyboard will offer only Normal.")
        case .unavailable(let reason):
            return reason.map(HomeSmartModeCopy.reasonText)
                ?? String(localized: "Available with Dictus Pro",
                          comment: "Line under the Home mic's Smart Mode dial when the finger is on a mode that needs a subscription.")
        case .release(.pro, _):
            return String(localized: "Release to see Dictus Pro",
                          comment: "Line under the Home mic's Smart Mode dial when the finger is on the Dictus Pro sector.")
        case .release(let entry, _):
            return String(localized: "Release to dictate: \(HomeSmartModeCopy.spokenName(of: entry.smartMode))",
                          comment: "Line under the Home mic's Smart Mode dial: lifting the finger starts a dictation in this mode. The placeholder is the mode's name.")
        }
    }

    private var secondary: String? {
        guard case .release(_, let start) = hint else { return nil }
        return String(localized: "Slide back to \(HomeSmartModeCopy.spokenName(of: start.smartMode)) to cancel",
                      comment: "Second line under the Home mic's Smart Mode dial. The placeholder is the mode the mic started on, usually Normal.")
    }
}

// MARK: - Copy

/// The words the dial, the mic's VoiceOver value and its actions share.
enum HomeSmartModeCopy {

    /// A mode's short name, the fan's: "→ EN", "List", or "Normal".
    static func name(of mode: SmartMode?) -> String {
        mode?.localizedDisplayName
            ?? String(
                localized: "Normal",
                comment: "The Smart Mode fan row that clears the armed mode and returns to the free polish."
            )
    }

    /// A ring sector's name, the Dictus Pro row included.
    static func shortName(of entry: SmartModeFanEntry) -> String {
        if case .pro = entry { return "Dictus Pro" }
        return name(of: entry.smartMode)
    }

    /// The name VoiceOver reads: the mode list's, where a translation is "Translate → EN"
    /// rather than an arrow and two letters.
    static func spokenName(of mode: SmartMode?) -> String {
        mode.map(SmartModeListView.listName(for:)) ?? name(of: nil)
    }

    /// The word a fan tag says. Nil for the effective row and for no tag.
    static func tagLabel(_ tag: SmartModeFanRowTag?) -> String? {
        switch tag {
        case .inactive:
            return String(
                localized: "Off",
                comment: "Marker on the Smart Mode fan row the user armed, when that mode will not run and the dictation goes in as Normal."
            )
        case .pro:
            return String(
                localized: "PRO",
                comment: "Tag on a Smart Mode fan row that is behind the Dictus Pro subscription. Identical in French today, and in the catalog so a future locale can change it."
            )
        case .effective, nil:
            return nil
        }
    }

    /// The resting face the Home mic takes for `entry`: the mode's glyph in the deep
    /// blue, a translation's target code under it. Nil for Normal, the plain mic.
    static func micFace(for entry: SmartModeFanEntry) -> AnimatedMicButton.MicFace? {
        guard SmartModeMicTint.tint(for: entry) == .deep, let mode = entry.smartMode else { return nil }
        let caption: String?
        if case .text(let code) = mode.badge { caption = code } else { caption = nil }
        return AnimatedMicButton.MicFace(symbol: mode.icon, caption: caption, fill: .dictusGradientEnd)
    }

    /// Why no mode may be armed, in the app's words.
    ///
    /// The keyboard's `localizedReason` is the model and cannot be called from here: it
    /// lives in the other target, whose string catalog is its own. Where the app already
    /// has a sentence for the reason it is reused; the rest are the keyboard's sentences.
    /// `.notSubscribed` never reaches here with a sentence to say — the Dictus Pro sector
    /// is the message, and with nothing on sale the dial does not exist.
    static func reasonText(_ reason: SmartModeUnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return String(localized: "Turn on Apple Intelligence in iOS Settings to use Smart Modes.")
        case .modelNotReady:
            return String(
                localized: "Apple Intelligence is still downloading. Smart Modes will work once it finishes.",
                comment: "Shown in the Smart Mode fan while the on-device model is downloading."
            )
        case .deviceNotEligible:
            return String(localized: "Smart Modes need Apple Intelligence, which this iPhone does not support. Your choices are saved for a device that does.")
        case .osTooOld:
            return String(
                localized: "Smart Modes need iOS 26 or later.",
                comment: "Shown in the Smart Mode fan when the OS predates Apple Foundation Models."
            )
        case .sdkMissing:
            return String(
                localized: "Smart Modes are not available in this build.",
                comment: "Shown in the Smart Mode fan when the build has no FoundationModels SDK."
            )
        case .engineRefusing:
            return String(
                localized: "Apple Intelligence is busy right now. Smart Modes will come back shortly.",
                comment: "Shown in the Smart Mode fan while the process is rate-limited."
            )
        case .switchedOff:
            return String(localized: "Smart Modes are off. Your modes are kept for when you turn them back on.")
        case .notSubscribed, .other:
            return String(
                localized: "Smart Modes are unavailable right now.",
                comment: "Shown in the Smart Mode fan for an unavailability reason this build does not recognise."
            )
        }
    }
}
