// DictusApp/Onboarding/KeyboardSetupChecklistInline.swift
// The checklist as the keyboard step shows it in the page (#682).
import AVFoundation
import SwiftUI
import UIKit
import DictusCore

/// The checklist card in the page: the sample-buffer layer that feeds Picture in Picture
/// when the device has it, the SwiftUI card otherwise (the fallback). Both draw the same
/// `KeyboardSetupChecklistCard`, so the page looks the same either way.
///
/// WHY THE LAYER IS SHOWN INLINE: Picture in Picture takes over a layer that is already
/// on screen and playing (`AVPictureInPictureController.ContentSource`); it cannot start
/// from a layer that is not in the window.
struct KeyboardSetupChecklistInline: View {
    @ObservedObject var player: KeyboardSetupChecklistPlayer

    private static let cornerRadius: CGFloat = 22

    var body: some View {
        Group {
            if player.usesPictureInPicture {
                SampleBufferLayerView(layer: player.displayLayer)
            } else {
                KeyboardSetupChecklistCard(lines: player.lines, tickProgress: player.tickProgress)
            }
        }
        .frame(width: KeyboardSetupChecklistCard.size.width, height: KeyboardSetupChecklistCard.size.height)
        .background(KeyboardSetupChecklistCard.background)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    /// "Set up Dictus. Tap Keyboards, done. …" read in one go: the layer has no text
    /// VoiceOver could read.
    private var accessibilityText: String {
        let title = String(localized: "Set up Dictus", comment: "Title of the checklist card that floats over iOS Settings during keyboard setup (#682).")
        let done = String(localized: "done", comment: "VoiceOver state of a ticked line of the keyboard setup checklist (#682).")
        let lineTexts = KeyboardSetupChecklistLine.allCases.map { line -> String in
            let isDone = player.lines.indices.contains(line.rawValue) && player.lines[line.rawValue] == .done
            return isDone ? "\(line.spokenTitle), \(done)" : line.spokenTitle
        }
        return ([title] + lineTexts).joined(separator: ". ")
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
