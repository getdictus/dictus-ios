// DictusApp/Views/PaywallSalesSections.swift
// The pieces of the one-screen paywall (#913): wordmark, feature checklist, plan row, trial recap line.
import SwiftUI
import DictusCore

/// The official wordmark with the Pro badge: icon glyph, « dictus » in DM Sans 200,
/// a blue "Pro" (#913). In the navigation bar of every state, the hub included.
struct PaywallWordmark: View {
    /// The wordmark's point size. Fixed rather than Dynamic Type: it lives in the
    /// navigation bar, whose height does not grow.
    private let wordSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 8) {
            // logoHeight 19 gives a 36 pt tile (80/42 ratio, `DictusLogoGeometry`),
            // the tallest that sits in the bar beside the close button.
            DictusIconTile(logoHeight: 19)

            Text(verbatim: "dictus")
                .font(.custom(DMSansWeight.extraLight.rawValue, fixedSize: wordSize))
                // The brand kit's -0.03em, in points for this size.
                .tracking(-0.03 * wordSize)
                .foregroundColor(.primary)

            Text(verbatim: "Pro")
                .font(.custom(DMSansWeight.semiBold.rawValue, fixedSize: 13))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.dictusAccent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Dictus Pro"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// The four Pro features, one line each with a blue checkmark (#913).
///
/// WHY the lines open their screens while Pro is on: during the trial this screen is
/// the hub, the only way into each feature's settings (#216 decision 4). The rows keep
/// that job with a chevron, and stay one line so the plans still fit.
struct PaywallFeatureList: View {
    /// Whether the voice-message line carries its second line, « visible from your
    /// keyboard ». Dropped on the end-of-trial screen, which needs the room.
    var showsVoiceNoteDetail: Bool

    /// The gap between two lines: tighter on an iPhone SE.
    var lineSpacing: CGFloat

    /// Set while the user has Pro (the trial): a tap opens the feature's screen.
    var open: ((ProFeature) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(ProFeature.allCases, id: \.self) { feature in
                if let open {
                    Button { open(feature) } label: { row(feature, opens: true) }
                        .buttonStyle(.plain)
                } else {
                    row(feature, opens: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ feature: ProFeature, opens: Bool) -> some View {
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

            if opens {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(opens ? .isButton : [])
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
                                        lineWidth: isSelected ? 2 : 1))
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
