// DictusApp/Views/ProBannerView.swift
// The Home Pro card: the Pro offer, the trial's last-days reminder, or a subscriber's way into the hub.
import SwiftUI
import DictusCore

/// Compact Pro banner at the bottom of HomeView.
///
/// WHY a separate view:
/// Keeps HomeView clean and makes the banner independently testable.
/// The banner has its own visibility logic and navigation target (the paywall).
///
/// What it shows is `ProStatusManager.homeCardContent`, decided in DictusCore: the
/// ordinary offer for a free user (nothing on a device that can never run Smart
/// Modes), the trial's reminder in its last two days, as #593 settled them. Since #216
/// decision 16, anyone who has Pro otherwise (paid, or a trial before its last days)
/// gets a calm card: Home's visible way into the hub, where the rejected pull-down on
/// the header was not discoverable.
struct ProBannerView: View {
    @EnvironmentObject var proStatus: ProStatusManager

    /// Observed so the subscriber card's count follows a switch flipped in the hub.
    @ObservedObject private var switches = ProFeatureSwitches.shared

    /// Opens the Dictus Pro hub, presented by `HomeView`.
    ///
    /// WHY the banner does not present it itself (#216): a purchase made in the hub
    /// changes what this card shows (and, before decision 16, removed it), and a cover
    /// attached to a view that changes or leaves the hierarchy is dismissed with it,
    /// under the thank-you screen the purchase had just raised. Home stays on screen.
    let open: () -> Void

    private var content: ProHomeCardContent {
        proStatus.homeCardContent(activeFeatures: switches.onCount)
    }

    var body: some View {
        Group {
            switch content {
            case .hidden:
                EmptyView()
            case .upgrade:
                banner(
                    icon: "crown.fill",
                    title: Text("Unlock Dictus Pro"),
                    subtitle: Text("AI reformulation, history & more")
                )
            case .trialEnding(let daysLeft):
                banner(
                    icon: "hourglass",
                    title: Text("Your Pro trial ends in \(daysLeft) days"),
                    subtitle: Text("Subscribe to keep your Smart Modes, with no interruption.")
                )
            case .member(let activeFeatures):
                memberCard(activeFeatures: activeFeatures)
            }
        }
        .animation(.easeOut(duration: 0.3), value: content)
    }

    /// The subscriber's card: same family as Home's model status card (glass, no
    /// gradient, no sales copy, no price), "Dictus Pro" and how many features are on.
    private func memberCard(activeFeatures: Int) -> some View {
        Button {
            open()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundColor(.dictusAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictus Pro")
                        .font(.dictusSubheading)
                        .foregroundColor(.primary)
                    activeFeaturesLine(activeFeatures)
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .dictusGlass()
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .transition(.opacity)
    }

    /// "4 features on", or a sentence of its own for none: "0 features on" reads as
    /// a fault, while every switch off is a choice the user made in the hub.
    private func activeFeaturesLine(_ count: Int) -> Text {
        count == 0 ? Text("All Pro features are off") : Text("\(count) features on")
    }

    private func banner(icon: String, title: Text, subtitle: Text) -> some View {
        Button {
            open()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.dictusAccent)

                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.dictusSubheading)
                        .foregroundColor(.primary)
                    subtitle
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color.dictusAccent.opacity(0.15), Color.dictusAccentHighlight.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .dictusGlass()
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .transition(.opacity.combined(with: .scale))
    }
}

/// The discreet `Pro · N days left` capsule, shown on the home screen and in Settings
/// while the reverse trial runs (#593).
///
/// WHY one view for both places: it is the same statement, and two hand-built copies
/// of a plural sentence are how one of them ends up saying "1 days".
struct ProTrialBadge: View {
    let daysLeft: Int

    var body: some View {
        Text("Pro · \(daysLeft) days left")
            .font(.dictusCaption.weight(.semibold))
            .foregroundColor(.dictusAccentHighlight)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.dictusAccent.opacity(0.15)))
    }
}
