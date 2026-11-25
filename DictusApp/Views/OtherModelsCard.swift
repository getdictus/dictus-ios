// DictusApp/Views/OtherModelsCard.swift
// Home's "Other transcription models" card, for someone who dictates with Apple's (#1057).
import DictusCore
import SwiftUI

/// Says once that downloadable models exist, what the recommended one costs in space, and
/// leads to the Models tab. When it shows is `OtherModelsCardRule`; this view only draws.
///
/// WHY THE BUTTON DOES NOT CLOSE THE CARD: the user may look at the models and come back
/// without downloading. Only the cross closes it, and a downloaded model becoming active
/// takes it away on its own.
struct OtherModelsCard: View {
    /// The recommended model for this device and language: Parakeet on most iPhones,
    /// Small on a 4 GB iPhone 12. Its name and size come from the catalogue.
    let recommended: ModelInfo
    let onShowModels: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Other transcription models",
                     comment: "Home card title, shown to someone who dictates with Apple's model and has no Dictus model (#1057).")
                    .font(.dictusSubheading)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("home.otherModels.close")
            }

            // swiftlint:disable:next line_length
            Text("You're dictating with Apple's model, already on your \(DeviceNoun.current). Another model, like \(recommended.localizedDisplayName), can be more accurate, but it takes up space (\(recommended.megabytesLabel)).",
                 comment: "Home card body (#1057). First placeholder: the device, iPhone or iPad. Second: the recommended model's name (Parakeet v3, Small). Third: its download size with the unit (483 MB).")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onShowModels) {
                Text("See models", comment: "Home card button: opens the Models tab (#1057).")
                    .font(.dictusCaption.weight(.semibold))
                    .foregroundColor(.dictusAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.otherModels.seeModels")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .dictusGlass()
        // `.contain` so the cross and the button keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.otherModels")
    }
}
