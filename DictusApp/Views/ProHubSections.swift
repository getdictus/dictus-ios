// DictusApp/Views/ProHubSections.swift
// The Dictus Pro hub's pieces for users who have Pro: active feature cards, and the membership block (#216).
import SwiftUI
import DictusCore

/// A feature card for someone who has the feature: trial, subscriber, or the DEBUG
/// forced entitlement (#216 decisions 4 and 5).
///
/// Two controls side by side rather than one: the toggle switches the feature, the
/// rest of the card opens its screen. A toggle nested inside a tappable card would
/// fire both on one tap, and VoiceOver would read one element doing two things.
///
/// **Switched off, the card is dimmed and does not navigate**; only the toggle
/// answers. That is the rule Settings applied before this screen took the rows over:
/// a mode list under a switched-off Smart Mode arranges a fan the keyboard will not
/// open, and a term list under a switched-off Vocabulary edits rules nothing applies.
struct ProHubFeatureCard: View {
    let feature: ProFeature

    /// `FeatureGate.isAvailable(feature)`, the single predicate (decision 5). Passed in
    /// rather than read here so the caller decides when it is re-read.
    let isAvailable: Bool

    /// The per-feature switch, bound to `feature.settingsKey`.
    @Binding var isOn: Bool

    /// Pushes the feature's screen onto the hub's stack.
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundColor(iconColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(feature.displayName))
                            .font(.dictusBody.weight(.semibold))
                            .foregroundColor(.primary)
                        Text(LocalizedStringKey(feature.paywallDescription))
                            .font(.dictusCaption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        // Kept on the active card too: a user on a device that cannot
                        // run Smart Modes still owns the switch and the mode list, which
                        // is durable across phones (see `SmartModeListView`), and the
                        // line is what says why nothing happens in the keyboard.
                        if !feature.isSupportedByThisDevice {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Requires Apple Intelligence (iPhone 15 Pro or later, iOS 26)")
                                    .font(.dictusCaption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                // The whole left part is the target, Spacer included.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1 : Self.switchedOffOpacity)
            .accessibilityElement(children: .combine)
            .accessibilityHint(isAvailable ? Text("Opens the settings of this feature") : Text("Switched off"))

            Toggle(isOn: $isOn) {
                Text(LocalizedStringKey(feature.displayName))
            }
            .labelsHidden()
            .tint(.dictusAccent)
        }
        .padding(12)
        .dictusGlass()
    }

    /// How far a switched-off card fades. Lower than the unsupported-device dimming on
    /// the sales cards (0.7), because this one also stops responding.
    private static let switchedOffOpacity = 0.45

    private var iconColor: Color {
        switch feature {
        case .smartMode: return .dictusSmartMode
        case .history, .vocabulary: return .dictusAccentHighlight
        }
    }
}

/// The hub's bottom block for someone who is not being sold anything: what they own,
/// and the way to manage it (#216 decision 2).
///
/// Replaces the "Dictus Pro Active" card #78 left on the subscribed paywall, which
/// was the only thing under the features and said nothing a subscriber could act on.
struct ProHubMembershipCard: View {
    let block: ProHubBottomBlock

    /// Re-reads StoreKit. Called when Apple's sheet closes: turning auto-renew off
    /// there changes the renewal info without producing a transaction, so nothing
    /// else would move "Renews on" to "Ends on".
    let refresh: () async -> Void

    @State private var showsManageSheet = false

    var body: some View {
        Group {
            switch block {
            case .subscription(let subscription):
                card(title: planTitle(subscription.period), detail: dateLine(subscription), managed: true)
            case .lifetime(let alsoSubscribed):
                card(
                    title: Text("Dictus Pro Lifetime"),
                    detail: alsoSubscribed == nil
                        ? Text("One-time purchase")
                        : Text("You also have a subscription that keeps renewing. You can cancel it, your lifetime purchase stays."),
                    managed: alsoSubscribed != nil
                )
            case .paidPlanPending:
                card(title: Text("Dictus Pro Active"), detail: nil, managed: false, loading: true)
            case .paidPlanUnknown:
                card(title: Text("Dictus Pro Active"), detail: nil, managed: true)
            case .entitledWithoutPurchase:
                debugForcedNotice
            case .offers:
                // Never routed here: the offers are the paywall's own block.
                EmptyView()
            }
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSheet)
        .onChange(of: showsManageSheet) { _, isShown in
            if !isShown {
                Task { await refresh() }
            }
        }
    }

    private func card(title: Text, detail: Text?, managed: Bool, loading: Bool = false) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.dictusSuccess)

                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.dictusSubheading)
                    if let detail {
                        detail
                            .font(.dictusCaption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if loading {
                    ProgressView()
                }
            }
            .accessibilityElement(children: .combine)

            if managed {
                Button {
                    showsManageSheet = true
                } label: {
                    Text("Manage subscription")
                        .font(.dictusSubheading)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.dictusAccent)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dictusAccent.opacity(0.12))
                        )
                }
                .buttonStyle(GlassPressStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dictusGlass()
    }

    private func planTitle(_ period: ProPlanPeriod) -> Text {
        switch period {
        case .monthly: return Text("Dictus Pro Monthly")
        case .yearly: return Text("Dictus Pro Yearly")
        case .unlabelled: return Text("Dictus Pro Active")
        }
    }

    /// "Renews on …", "Ends on …" after a cancellation, or a neutral line when the
    /// renewal info could not be read: claiming a renewal that will not happen is the
    /// one wrong answer here.
    private func dateLine(_ subscription: ProActiveSubscription) -> Text? {
        guard let end = subscription.periodEnd else { return nil }
        let date = end.formatted(date: .long, time: .omitted)
        switch subscription.willAutoRenew {
        case true?: return Text("Renews on \(date)")
        case false?: return Text("Ends on \(date)")
        case nil: return Text("Current period ends on \(date)")
        }
    }

    /// What the hub says under the DEBUG forced entitlement (#460, #577): nothing is
    /// sold, and the maintainer is told why. Compiled out of Release, where this state
    /// cannot occur (`ProHub.bottomBlock`).
    @ViewBuilder
    private var debugForcedNotice: some View {
        #if DEBUG
        Text(verbatim: "Pro is forced on by the Developer switch in Settings. Nothing is for sale in this build. Debug builds only.")
            .font(.dictusCaption)
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .dictusGlass()
        #else
        EmptyView()
        #endif
    }
}
