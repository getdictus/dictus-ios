// DictusCore/Sources/DictusCore/Design/PrimaryMicAnchor.swift
// The height on screen of the app's primary mic, shared by Home and the recording screen.
import Combine
import CoreGraphics
import SwiftUI

/// Where the app's primary mic is on screen, so the recording screen draws its own big
/// button at exactly the same height and tapping the Home mic shows no jump (#788).
///
/// WHY a measured position and not a shared constant: on Home the mic sits above the
/// history hint and the tab bar, and neither has a height of ours. The tab bar's is the
/// system's (and differs between a phone with a home indicator and one without), the
/// hint's follows Dynamic Type. The recording screen covers both. A constant tuned to
/// make the two centres meet on one iPhone would miss on the next, so Home reports where
/// its mic actually landed and the recording screen lines up on that.
///
/// The value is in window coordinates (`.global`), the one space both screens share:
/// Home lives inside the tab bar's navigation stack, the recording screen is an overlay
/// drawn over all of it.
@MainActor
public final class PrimaryMicAnchor: ObservableObject {
    public static let shared = PrimaryMicAnchor()

    /// The vertical centre of Home's mic in window coordinates, or nil until Home has
    /// drawn it once (no model yet, or a screen shown before Home, such as onboarding).
    @Published public private(set) var centerY: CGFloat?

    public init() {}

    public func report(centerY: CGFloat) {
        // Rounded to the pixel grid's half point so sub-point layout noise does not
        // republish and redraw the recording screen for nothing.
        let rounded = (centerY * 2).rounded() / 2
        guard rounded != self.centerY else { return }
        self.centerY = rounded
    }

    /// The space to leave under a button slot so its centre lands on `anchorY`.
    ///
    /// - Parameters:
    ///   - anchorY: the reported centre, in window coordinates, or nil.
    ///   - containerMaxY: the bottom edge, in window coordinates, of the area the slot is
    ///     stacked in.
    ///   - slotHeight: the height of the slot holding the button, centred in it.
    ///   - fallback: the space to leave when there is nothing to line up on.
    /// - Returns: never negative: a mic reported lower than the slot can go stays as low
    ///   as it can rather than overflowing its container.
    public nonisolated static func bottomSpacing(
        anchorY: CGFloat?,
        containerMaxY: CGFloat,
        slotHeight: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        guard let anchorY else { return fallback }
        return max(0, containerMaxY - anchorY - slotHeight / 2)
    }
}

#if os(iOS)
public extension View {
    /// Reports this view's vertical centre to `PrimaryMicAnchor.shared`. Put it on the one
    /// mic every other primary button lines up on: Home's.
    func reportsPrimaryMicAnchor() -> some View {
        onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).midY
        } action: { centerY in
            PrimaryMicAnchor.shared.report(centerY: centerY)
        }
    }
}
#endif
