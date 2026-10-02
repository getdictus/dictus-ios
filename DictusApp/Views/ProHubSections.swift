// DictusApp/Views/ProHubSections.swift
// The Dictus Pro hub's pieces for users who have Pro: active feature cards, and the membership block (#216).
import SwiftUI
import DictusCore

/// A feature card for someone who has the feature: trial, subscriber, or the DEBUG
/// forced entitlement (#216 decisions 4 and 5, amended after the first device test).
///
/// **A standard iOS Settings row**: the feature, its state as a value ("On" / "Off",
/// as Settings > Bluetooth writes it), a chevron. No switch here. A chevron and a
/// switch on one row is not an iOS pattern, and the maintainer's verdict on device
/// was "don't reinvent the wheel". The switch lives at the top of the screen the
/// row opens (`ProFeatureSwitchSection`).
///
/// **Always opens**, switched off included: that screen is where the switch is.
struct ProHubFeatureCard: View {
    let feature: ProFeature

    /// `FeatureGate.isAvailable(feature)`, the single predicate (decision 5). Passed in
    /// rather than read here so the caller decides when it is re-read.
    let isAvailable: Bool

    /// Pushes the feature's screen onto the hub's stack.
    let open: () -> Void

    var body: some View {
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

                Spacer(minLength: 8)

                stateValue
                    .font(.dictusBody)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .dictusGlass()
            // The whole card is the target, Spacer included.
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var stateValue: Text {
        isAvailable ? Text("On") : Text("Off")
    }

    private var iconColor: Color {
        switch feature {
        case .smartMode: return .dictusSmartMode
        case .history, .vocabulary, .voiceNotes: return .dictusAccentHighlight
        }
    }
}

/// The feature's switch, as the first section of the screen a hub card opens (#216
/// decision 4, amended). Bound to `feature.settingsKey` in the App Group, so the
/// keyboard reads the same answer (#401).
///
/// WHY `ProFeatureSwitches` and not `@AppStorage`: the screen dims its content from
/// the same value and the hub row shows it, and property wrappers on one key, each
/// on its own `UserDefaults` instance, did not redraw together on the simulator.
/// One owner, observed by all three.
///
/// WHY the footer only speaks when the switch is off: on, the screen below says what
/// the feature does. Off, the content under it is dimmed and locked
/// (`proFeatureContent(isAvailable:)`), and the user is owed why, and that nothing
/// was deleted.
struct ProFeatureSwitchSection: View {
    let feature: ProFeature

    @ObservedObject private var switches = ProFeatureSwitches.shared

    init(feature: ProFeature) {
        self.feature = feature
    }

    private var isOn: Bool {
        switches.isOn(feature)
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { switches.isOn(feature) },
                set: { switches.set(feature, isOn: $0) }
            )) {
                Text(LocalizedStringKey(feature.displayName))
            }
            .tint(.dictusAccent)
        } footer: {
            if !isOn {
                offFooter
            }
        }
    }

    private var offFooter: Text {
        switch feature {
        case .smartMode:
            return Text("Smart Modes are off. Your modes are kept for when you turn them back on.")
        case .vocabulary:
            return Text("Vocabulary is off. Your terms are kept, and replace nothing until you turn it back on.")
        case .history:
            return Text("History is off: new dictations are not saved. Those already saved are kept.")
        case .voiceNotes:
            return Text("Voice notes are off: a voice message shared to Dictus is not transcribed. Your settings are kept.")
        }
    }
}

extension View {
    /// The content under a feature's switch: visible but dimmed and not editable while
    /// the feature is off (#216 decision 5). A list under a switched-off feature
    /// would edit rules nothing applies.
    ///
    /// - Parameter isAvailable: `FeatureGate.isAvailable(feature)`, the one predicate.
    ///
    /// WHY hit-testing as well as `disabled`: a row button drawn with a custom button
    /// style still opened on tap under `disabled` alone (History, on the simulator).
    func proFeatureContent(isAvailable: Bool) -> some View {
        disabled(!isAvailable)
            .allowsHitTesting(isAvailable)
            .opacity(isAvailable ? 1 : ProFeatureDimming.opacity)
    }
}

/// How far the content of a switched-off feature fades.
enum ProFeatureDimming {
    static let opacity = 0.45
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
