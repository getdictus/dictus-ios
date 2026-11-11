// DictusApp/Views/PaywallSalesSections.swift
// The pieces of the one-screen paywall (#913): feature checklist, plan row, trial recap line, thank-you screen.
import SwiftUI
import DictusCore

/// The four Pro features, one line each with a blue checkmark (#913). Informational
/// only: the feature screens belong to the Pro hub, which the paywall is not.
struct PaywallFeatureList: View {
    /// Whether the voice-message line carries its second line, « visible from your
    /// keyboard ». Dropped on the end-of-trial screen, which needs the room.
    var showsVoiceNoteDetail: Bool

    /// The gap between two lines: tighter on an iPhone SE.
    var lineSpacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(ProFeature.allCases, id: \.self) { feature in
                row(feature)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The spacers around it give way first (#913): the lines never truncate.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ feature: ProFeature) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.dictusAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title(feature))
                    .font(.dmSans(.medium, size: 16, relativeTo: .body))
                    .foregroundColor(.primary)

                if let detail = detail(feature) {
                    Text(detail)
                        .font(.dmSans(.regular, size: 13, relativeTo: .footnote))
                        .foregroundColor(.secondary)
                }

                // The review-risk line, kept from the cards it replaces (#79): a
                // device without Apple Intelligence is told before it pays.
                if !feature.isSupportedByThisDevice {
                    Text("Requires Apple Intelligence (iPhone 15 Pro or later, iOS 26)")
                        .font(.dmSans(.regular, size: 12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func title(_ feature: ProFeature) -> LocalizedStringKey {
        switch feature {
        case .smartMode: return "Smart Modes, AI on your iPhone"
        case .history: return "History search"
        case .vocabulary: return "Custom vocabulary"
        case .voiceNotes: return "Transcribed voice messages"
        }
    }

    private func detail(_ feature: ProFeature) -> LocalizedStringKey? {
        guard feature == .voiceNotes, showsVoiceNoteDetail else { return nil }
        return "visible from your keyboard"
    }
}

/// One plan as a row with a radio (#913): the name and an optional badge on the left,
/// the price (largest) over its detail on the right.
struct PaywallPlanRow: View {
    let title: LocalizedStringKey
    /// The amount as StoreKit formats it, with its period where it has one.
    let price: String
    let detail: Text?
    let badge: String?
    /// Tighter on an iPhone SE.
    let minHeight: CGFloat
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                radio

                HStack(spacing: 8) {
                    Text(title)
                        .font(.dmSans(.semiBold, size: 17, relativeTo: .body))
                    if let badge {
                        Text(verbatim: badge)
                            .font(.dmSans(.bold, size: 12, relativeTo: .caption))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.dictusAccent, in: Capsule())
                    }
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(verbatim: price)
                        .font(.dmSans(.bold, size: 19, relativeTo: .title3))
                        .lineLimit(1)
                    if let detail {
                        detail
                            .font(.dmSans(.regular, size: 13, relativeTo: .footnote))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                // The price is what the row exists to compare: it never shrinks
                // away behind a long plan name.
                .layoutPriority(1)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight)
            .background(Color.dictusSurface, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Color.dictusAccent : Color.secondary.opacity(0.25),
                                        lineWidth: isSelected ? 2 : 1)
                // Selecting a plan animates the border and the radio, nothing else.
                .animation(.easeInOut(duration: 0.2), value: isSelected))
            .contentShape(shape)
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.dictusAccent : Color.secondary.opacity(0.5), lineWidth: 2)
            if isSelected {
                Circle()
                    .fill(Color.dictusAccent)
                    .padding(5)
            }
        }
        .frame(width: 22, height: 22)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityHidden(true)
    }
}

/// The end-of-trial recap as one line in a soft card (#913), replacing the tiles:
/// « In 14 days: 6,638 words dictated, 36 min saved ».
///
/// Each value is left out when it is zero, and the whole line when both are, for the
/// reason the tiles had (#593 decision 5): a zero reads as a reproach.
struct TrialRecapLine: View {
    let usage: ProTrialUsage.Snapshot

    var body: some View {
        if let details {
            Text("In \(ProTrial.durationDays) days: \(details)",
                 comment: "End-of-trial recap line (#913). The number is the trial's length; the text lists what the user did, e.g. « 6 638 mots dictés, 36 min gagnées ».")
                .font(.dmSans(.medium, size: 14, relativeTo: .subheadline))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                // Never truncated by the spacers around it (#913): it wraps instead.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.dictusAccent.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// The values joined by a comma, or nil when there is nothing to recap.
    private var details: String? {
        var parts: [String] = []
        // WHY a formatted string and not a plural `%lld`: the count runs into the
        // thousands and must read « 6 638 » in French, which a `%lld` does not group.
        // One word is the only singular, so it gets its own sentence.
        if usage.wordsDictated == 1 {
            parts.append(String(localized: "1 word dictated", comment: "End-of-trial recap value (#913)."))
        } else if usage.wordsDictated > 1 {
            parts.append(String(localized: "\(usage.wordsDictated.formatted()) words dictated",
                                comment: "End-of-trial recap value (#913). The number is already formatted, e.g. « 6 638 »."))
        }
        if let saved = usage.timeSaved {
            parts.append(timeSaved(saved))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private func timeSaved(_ saved: TimeSavedEstimate.Rounded) -> String {
        switch saved {
        case .minutes(let minutes):
            return String(localized: "\(minutes) min saved",
                          comment: "End-of-trial recap value: estimated time dictation saved over typing, under an hour (#913).")
        case .hours(let hours, minutes: 0):
            return String(localized: "\(hours) h saved",
                          comment: "End-of-trial recap value: estimated time saved, a whole number of hours (#913).")
        case .hours(let hours, let minutes):
            return String(localized: "\(hours) h \(minutes) min saved",
                          comment: "End-of-trial recap value: estimated time saved, hours then minutes (#913).")
        }
    }
}

/// Thank-you screen shown after a successful purchase or restore, over the paywall.
/// Moved out of `PaywallView` unchanged (#913), so that type stays under its length
/// limit.
struct PurchaseSuccessView: View {
    /// Continue: closes the paywall.
    let continueAction: () -> Void

    /// Drives the staged entrance animation of the thank-you screen elements.
    @State private var successEntrance = false

    /// Thank-you screen shown after a successful purchase or restore.
    /// Staged entrance: the checkmark springs in first, then the texts rise
    /// with small delays, then the Continue button. Each element animates on
    /// the same trigger with its own delay, which reads as one choreography.
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white, Color.dictusSuccess)
                .shadow(color: Color.dictusSuccess.opacity(0.6), radius: 12)
                .shadow(color: Color.dictusSuccess.opacity(0.3), radius: 28)
                .scaleEffect(successEntrance ? 1 : 0.4)
                .opacity(successEntrance ? 1 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.6), value: successEntrance)

            Text("Welcome to Dictus Pro")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.dictusGradientStart, .dictusGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 28)
                .opacity(successEntrance ? 1 : 0)
                .offset(y: successEntrance ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.2), value: successEntrance)

            Text("All Pro features are now unlocked. Thank you for your support.")
                .font(.dictusBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 24)
                .opacity(successEntrance ? 1 : 0)
                .offset(y: successEntrance ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.3), value: successEntrance)

            Spacer()

            Button {
                continueAction()
            } label: {
                Text("Continue")
                    .font(.dictusSubheading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.dictusAccent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(GlassPressStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .opacity(successEntrance ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.45), value: successEntrance)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dictusBackground.ignoresSafeArea())
        .onAppear {
            successEntrance = true
            // UIKit generator instead of SwiftUI sensoryFeedback: the state
            // change happens while the StoreKit payment sheet still holds
            // scene focus, where sensoryFeedback is silently dropped. The
            // delay lands the haptic as the checkmark spring settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticFeedback.purchaseSucceeded()
            }
        }
    }
}
