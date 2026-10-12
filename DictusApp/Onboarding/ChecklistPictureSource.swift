// DictusApp/Onboarding/ChecklistPictureSource.swift
// Hosts the Picture in Picture source layer in the page, out of sight (#682).
import AVFoundation
import SwiftUI
import UIKit

/// The sample-buffer layer the Picture in Picture window is started from, placed behind the
/// drawn Settings phone so nobody sees it.
///
/// WHY IT IS IN THE PAGE AT ALL: `AVPictureInPictureController` starts from a layer that
/// is in the window and playing; it cannot start from a layer that is not attached.
///
/// WHY COVERED RATHER THAN HIDDEN (decided by Pierre after the device test of 2026-10-10,
/// the page must not show the checklist): a hidden layer, a zero size or a zero opacity are
/// the usual reasons Picture in Picture reports itself impossible. Covering a full-size,
/// fully opaque layer with the opaque drawn phone keeps every property Picture in Picture
/// can check intact. Whether iOS accepts it is a device question: the player logs
/// `pipPossible`, then `pipStarted` or `fallback reason=…` on the tap.
///
/// It keeps the window's aspect ratio (`KeyboardSetupChecklistPictureCard.size`), so the
/// start animation grows from a frame of the right shape.
struct ChecklistPictureSource: View {
    let layer: AVSampleBufferDisplayLayer

    /// Narrower than the drawn phone, so its whole frame sits under it.
    private static let width: CGFloat = 280

    var body: some View {
        let size = KeyboardSetupChecklistPictureCard.size
        SampleBufferLayerView(layer: layer)
            .frame(width: Self.width, height: Self.width * size.height / size.width)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
