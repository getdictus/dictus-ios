// DictusApp/Onboarding/ChecklistPictureSource.swift
// Hosts the Picture in Picture source layer at the bottom of the page, out of sight
// (#682, #706).
import AVFoundation
import SwiftUI
import UIKit
import DictusCore

/// The sample-buffer layer the Picture in Picture window is started from and stops into,
/// at the bottom of the page, under a patch of the page's own background so nobody sees
/// it: the keyboard step's (#682) and the Apple Intelligence step's (#706). Pages attach it
/// with `checklistPictureSource(_:)`.
///
/// WHY IT IS IN THE PAGE AT ALL: `AVPictureInPictureController` starts from a layer that
/// is in the window and playing; it cannot start from a layer that is not attached.
///
/// WHY COVERED RATHER THAN HIDDEN (decided by Pierre after the device test of 2026-10-10,
/// the page must not show the checklist): a hidden layer, a zero size or a zero opacity are
/// the usual reasons Picture in Picture reports itself impossible. Covering a full-size,
/// fully opaque layer with an opaque view keeps every property Picture in Picture can
/// check intact. The cover is `Color.dictusBackground`, the colour the onboarding shell
/// paints behind every page, so it cannot be told from the background. Whether iOS
/// accepts it is a device question: the player logs `pipPossible`, then `pipStarted` or
/// `fallback reason=…` on the tap.
///
/// WHY AT THE BOTTOM, FULL WIDTH (device test of PR #731, 2026-10-13): stopping Picture in
/// Picture animates the window back onto this layer's frame. The layer used to sit behind
/// the drawn phone, mid-page and 280 pt wide, so on the return to the app the window flew
/// up from the bottom to the middle of the page and shrank there. On the Apple Intelligence
/// step the page also switched to its "getting ready" screen at that moment, taking the
/// layer out of the window mid-animation, and the window collapsed over the title in an
/// odd shape. At the bottom, as wide as the window and with its aspect ratio, the frame is
/// about where iOS shows the window (measured on an iPhone 15 Pro Max: nearly full width,
/// its bottom edge some 55 pt above the home indicator), so the window settles in place.
/// Attached to the page rather than to one of its screens, it stays in the window when a
/// page changes screen.
///
/// It keeps the window's aspect ratio (`SettingsChecklistPictureCard.size`), so the start
/// and stop animations never change the window's shape.
struct ChecklistPictureSource: View {
    let layer: AVSampleBufferDisplayLayer

    /// The window's side margins at its default size.
    private static let horizontalInset: CGFloat = 14
    /// The window's distance from the bottom of the page at its default position.
    private static let bottomInset: CGFloat = 56

    var body: some View {
        let size = SettingsChecklistPictureCard.size
        SampleBufferLayerView(layer: layer)
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .overlay(Color.dictusBackground)
            .padding(.horizontal, Self.horizontalInset)
            .padding(.bottom, Self.bottomInset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Places `player`'s Picture in Picture source behind this page, at its bottom
    /// (`ChecklistPictureSource`). Nothing where the device has no Picture in Picture.
    func checklistPictureSource(_ player: SettingsChecklistPlayer) -> some View {
        background(alignment: .bottom) {
            if player.usesPictureInPicture {
                ChecklistPictureSource(layer: player.displayLayer)
            }
        }
    }
}

/// Hosts an existing `CALayer` in SwiftUI, sized to the view.
///
/// WHY NOT A UIView WITH `layerClass`: the layer belongs to the player, which hands the
/// very same object to Picture in Picture; the view only shows it.
private struct SampleBufferLayerView: UIViewRepresentable {
    let layer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> HostView {
        HostView(hosted: layer)
    }

    func updateUIView(_ view: HostView, context: Context) {}

    final class HostView: UIView {
        private let hosted: CALayer

        init(hosted: CALayer) {
            self.hosted = hosted
            super.init(frame: .zero)
            layer.addSublayer(hosted)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used: the view is built in code only")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // No implicit animation: the layer follows the view's size, it does not slide.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}
