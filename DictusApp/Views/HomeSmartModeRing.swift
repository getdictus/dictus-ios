// DictusApp/Views/HomeSmartModeRing.swift
// The home mic's Smart Mode dial: the half-ring drawn around the mic, its resting hint and
// the line under it (issue #489).
import SwiftUI
import DictusCore

/// The dial's visual constants, and the two parts of its presentation still under review.
///
/// Only drawing and motion live here. Where a row sits, which row a finger is on and the
/// outline a row is drawn with are `SmartModeRingLayout`'s, in DictusCore, so what is
/// drawn and what is touched cannot disagree.
///
/// Still under review, each one switch away from gone: the blur over the rest of the
/// dashboard while the ring is open, and the line under the mic saying what the release
/// will do. Turning either off removes it and nothing else — the ring, the gesture and
/// VoiceOver's actions do not read them.
enum HomeSmartModeRingStyle {

    /// Blur the cards and the history hint behind the dial while it is open. Replaced the
    /// first version's dim (device feedback, 2026-10-25).
    static let blursBackdrop = true

    /// Show "Release to dictate…" under the mic while the ring is open. Also where an
    /// unavailable mode says why, so with this off a greyed segment says nothing more.
    static let showsReleaseHint = true

    // MARK: Backdrop

    static let backdropBlurRadius: CGFloat = 14

    /// A wash of the screen's own background over the blur, so the segments stand out in
    /// both appearances.
    static let backdropWashOpacity: Double = 0.25

    /// With Reduce Transparency there is no blur: the wash becomes nearly opaque.
    static let reducedTransparencyWashOpacity: Double = 0.9

    // MARK: Segments

    /// The constant gap, in points, drawn between two neighbouring segments, measured
    /// perpendicular to their facing edges (the same at every radius). Drawn only:
    /// the selection has no gap (`SmartModeRingLayout.entryIndex(at:)`).
    static let segmentGap: CGFloat = 4

    /// How round a segment's corners are, as a share of fully round (half the band's
    /// thickness). `SmartModeRingLayout.fittedCornerRadius` turns it into points and
    /// clamps it so narrow segments (four rows on an iPhone SE) stay valid.
    static let segmentRoundness: CGFloat = 0.9

    /// Space kept between a label and its segment's sides.
    static let labelPadding: CGFloat = 6

    static let labelMaximumWidth: CGFloat = 96

    /// The accent hairline around an unlit segment, so a dark segment still reads on the
    /// blurred dark dashboard.
    static let segmentEdgeOpacity: Double = 0.35

    /// The room the band leaves above itself, below whatever is at the top of the Home
    /// screen, when it is sized (`SmartModeRingLayout.radii`).
    static let topClearance: CGFloat = 12

    // MARK: Motion

    /// How much the mic grows while the dial is open. It is a render scale around the
    /// mic's centre, so nothing moves and the recording screen's alignment (#788) holds.
    static let openMicScale: CGFloat = 1.12

    /// The segments' spring as they come out of the mic, and their cascade: each row
    /// starts `segmentStagger` after the one nearer the top, so the band opens from the
    /// centre outward.
    static let segmentSpring = Animation.spring(response: 0.36, dampingFraction: 0.74)
    static let segmentStagger: Double = 0.045
    static let segmentHiddenScale: CGFloat = 0.6

    /// The mic's grow and the dial's close.
    static let micSpring = Animation.spring(response: 0.3, dampingFraction: 0.68)

    /// Reduce Motion: no spring, no scale, a short crossfade.
    static let reducedMotionFade = Animation.easeOut(duration: 0.15)

    // MARK: Resting arrows

    /// The keyboard's discovery hint (`ToolbarView.driftingHint`): its breath, 2 s
    /// `easeInOut` autoreversed, the same curve as the mic's idle glow; its far end of 3;
    /// its arrow reaching 2.2 times that; its opacity rising from 0.62 by 0.13 per point.
    static let arrowBreath = Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)
    static let arrowBreathEnd: CGFloat = 3
    static let arrowReach: CGFloat = 2.2
    static let arrowBaseOpacity: Double = 0.62
    static let arrowOpacityPerPoint: Double = 0.13

    /// The space between each arrow's tip and the mic's halo.
    static let arrowGapToHalo: CGFloat = 14
}

extension View {

    /// The dashboard behind the open dial: blurred, or under a near-opaque wash with
    /// Reduce Transparency, and untouchable either way.
    func homeSmartModeRingBackdrop(_ isRingOpen: Bool) -> some View {
        modifier(HomeSmartModeRingBackdrop(isRingOpen: isRingOpen))
    }
}

private struct HomeSmartModeRingBackdrop: ViewModifier {

    let isRingOpen: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Style = HomeSmartModeRingStyle

    func body(content: Content) -> some View {
        let isBlurred = isRingOpen && Style.blursBackdrop
        content
            .blur(radius: isBlurred && !reduceTransparency ? Style.backdropBlurRadius : 0)
            .overlay {
                if isBlurred {
                    Color.dictusBackground
                        .opacity(reduceTransparency ? Style.reducedTransparencyWashOpacity : Style.backdropWashOpacity)
                        .allowsHitTesting(false)
                }
            }
            .animation(reduceMotion ? Style.reducedMotionFade : .easeOut(duration: 0.22), value: isRingOpen)
            .allowsHitTesting(!isRingOpen)
    }
}

// MARK: - Resting hint

/// What the mic says at rest about the dial behind it: an arrow on each side pointing at
/// the mic, breathing toward it the way the keyboard's "Hold the mic for Smart Modes" arrow
/// breathes toward the pill. No text: the gesture is the accelerator, and VoiceOver has
/// its own way in. Still with Reduce Motion.
struct HomeSmartModeRestHint: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 at rest, `arrowBreathEnd` at the far end of the breath. One value for the reach
    /// and the opacity, as in the keyboard, so the two cannot drift apart.
    @State private var drift: CGFloat = 0

    private typealias Style = HomeSmartModeRingStyle

    var body: some View {
        // Drawn as shapes, not SF Symbols: inside the mic's background VoiceOver read
        // symbols there as « Retour » and « Suivant », hidden or not (simulator,
        // 2026-10-24). A shape is never an accessibility element.
        HStack(spacing: DictusHalo.size(isPill: false).width + 2 * Style.arrowGapToHalo) {
            RestArrow(pointsRight: true)
                .offset(x: drift * Style.arrowReach)
            RestArrow(pointsRight: false)
                .offset(x: -drift * Style.arrowReach)
        }
        .foregroundStyle(.secondary)
        .opacity(Style.arrowBaseOpacity + Double(drift) * Style.arrowOpacityPerPoint)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: breathe)
        .onChange(of: reduceMotion) { _, _ in breathe() }
    }

    private func breathe() {
        guard !reduceMotion else {
            withAnimation(nil) { drift = 0 }
            return
        }
        withAnimation(Style.arrowBreath) { drift = Style.arrowBreathEnd }
    }
}

/// One resting arrow, the shape of SF Symbols' `arrow.right` / `arrow.left`: a shaft and
/// an open head, 14 × 10 pt.
private struct RestArrow: View {

    let pointsRight: Bool

    var body: some View {
        RestArrowShape(pointsRight: pointsRight)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 14, height: 10)
    }
}

private struct RestArrowShape: Shape {

    let pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        let tipX = pointsRight ? rect.maxX : rect.minX
        let tailX = pointsRight ? rect.minX : rect.maxX
        let headX = pointsRight ? rect.maxX - rect.height / 2 : rect.minX + rect.height / 2
        var path = Path()
        path.move(to: CGPoint(x: tailX, y: rect.midY))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.move(to: CGPoint(x: headX, y: rect.minY))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.addLine(to: CGPoint(x: headX, y: rect.maxY))
        return path
    }
}

// MARK: - The ring

/// The half-circle band of modes, centred on the mic and drawn behind it: one band split
/// into a segment per row.
///
/// It is a background of the mic and owns no layout: the mic stays exactly where #788
/// put it, which is where the recording screen draws its own button. It takes no touches
/// either — the finger that opened it is still the mic's gesture, which feeds the session
/// the positions; this only draws what the session says, from the layout's own outlines.
struct HomeSmartModeRing: View {

    let session: SmartModeRingSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// False on the first frame, so the segments spring out of the mic.
    @State private var appeared = false

    private typealias Style = HomeSmartModeRingStyle

    private var diameter: CGFloat { session.layout.outerRadius * 2 }

    var body: some View {
        ZStack {
            ForEach(Array(session.entries.enumerated()), id: \.element.id) { index, entry in
                segment(index: index, entry: entry)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("home.smartModeRing")
        .onAppear { appeared = true }
    }

    private func segment(index: Int, entry: SmartModeFanEntry) -> some View {
        let isLit = session.highlightedIndex == index
        let isSelectable = session.isSelectable(index)
        let outline = session.layout.segmentOutline(
            ofEntry: index,
            gap: Style.segmentGap,
            cornerRadius: session.layout.fittedCornerRadius(gap: Style.segmentGap, roundness: Style.segmentRoundness)
        )
        let fill = isLit ? Color.dictusAccent : Color.dictusSurface.opacity(isSelectable ? 1 : 0.7)
        let center = session.layout.labelCenter(ofEntry: index)
        // Rows nearer the top come out first: index order is nearness order.
        let entrance = reduceMotion
            ? Style.reducedMotionFade
            : Style.segmentSpring.delay(Double(index) * Style.segmentStagger)
        return ZStack {
            SegmentShape(outline: outline)
                .fill(fill)
                .overlay(
                    SegmentShape(outline: outline)
                        .stroke(Color.dictusAccent.opacity(isLit ? 0 : Style.segmentEdgeOpacity), lineWidth: 1)
                )
                .shadow(color: isLit ? .dictusAccent.opacity(0.45) : .black.opacity(0.16), radius: isLit ? 12 : 8)

            label(entry, isLit: isLit, isSelectable: isSelectable)
                .frame(width: session.layout.labelWidth(
                    gap: Style.segmentGap, padding: Style.labelPadding, maximum: Style.labelMaximumWidth
                ))
                .offset(x: center.x, y: center.y)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : Style.segmentHiddenScale)
        .opacity(appeared ? 1 : 0)
        .animation(entrance, value: appeared)
        .animation(.easeOut(duration: 0.12), value: isLit)
    }

    /// An icon and the fan's short name, with the fan's `PRO` / `Off` tag under it, on one
    /// line each.
    private func label(_ entry: SmartModeFanEntry, isLit: Bool, isSelectable: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: entry.icon)
                .font(.system(size: 18, weight: .medium))
            Text(HomeSmartModeCopy.shortName(of: entry))
                .font(.system(size: 14, weight: isLit ? .bold : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let tag = HomeSmartModeCopy.tagLabel(session.picker.tag(for: entry)) {
                Text(tag)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .opacity(0.8)
            }
        }
        .foregroundColor(isLit ? .white : .primary)
        .opacity(isSelectable ? 1 : 0.35)
        // The ring's labels stay at one size: the band already spans most of the screen's
        // width and cannot grow with Dynamic Type. VoiceOver's actions, which follow the
        // user's text size, carry the same choices.
        .dynamicTypeSize(.large)
    }
}

/// A closed outline from `SmartModeRingLayout.segmentOutline`, placed on the ring's
/// centre: a band segment with rounded corners, filled as is.
private struct SegmentShape: Shape {

    let outline: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = outline.first else { return path }
        let origin = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: origin.x + first.x, y: origin.y + first.y))
        outline.dropFirst().forEach { path.addLine(to: CGPoint(x: origin.x + $0.x, y: origin.y + $0.y)) }
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
