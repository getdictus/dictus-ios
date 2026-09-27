// DictusApp/Views/ProBannerView.swift
// Compact gradient banner for HomeView: the Pro offer, or the trial's last-days reminder.
import SwiftUI
import DictusCore

/// Compact Pro banner at the bottom of HomeView.
///
/// WHY a separate view:
/// Keeps HomeView clean and makes the banner independently testable.
/// The banner has its own visibility logic and navigation target (the paywall).
///
/// What it shows is `ProStatusManager.promotionEntry`, decided in DictusCore (#593):
/// nothing for a subscriber, during most of the reverse trial, or on a device that can
/// never run Smart Modes (decision 2); the trial's reminder in its last two days
/// (decision 3); the ordinary offer otherwise.
struct ProBannerView: View {
    @EnvironmentObject var proStatus: ProStatusManager

    @State private var showPaywall = false

    var body: some View {
        Group {
            switch proStatus.promotionEntry {
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
            }
        }
        .animation(.easeOut(duration: 0.3), value: proStatus.promotionEntry)
        .paywallCover(isPresented: $showPaywall)
    }

    private func banner(icon: String, title: Text, subtitle: Text) -> some View {
        Button {
            showPaywall = true
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
