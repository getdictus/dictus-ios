// DictusApp/Views/PaywallView.swift
// The Dictus Pro hub: wordmark, then a layout that follows the subscription state (#216, #913).
import SwiftUI
import StoreKit
import DictusCore

/// The one Dictus Pro screen, for every user (#216).
///
/// It began as the paywall (#78) and kept the name: every entry point already opens
/// it, and a second screen beside it is exactly what #216 decided against. The layout
/// follows `ProHub.bottomBlock`:
///
/// - **Free:** one screen, no scroll on an iPhone SE (#913): wordmark, headline, four
///   checkmark lines, the plan rows, and a pinned CTA with Restore, Redeem a code and
///   the legal links.
/// - **Trial:** the same, with the days left, and the lines open their screens.
/// - **Subscriber:** active cards, the plan, its date, Manage subscription.
/// - **Lifetime:** active cards, "Dictus Pro Lifetime", nothing to manage.
///
/// The end-of-trial presentation (`framing: .trialEnded`) stays a sales page: its
/// lines remain informational whatever the state, because that screen exists to say
/// what was lost, not to hand the features back.
struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var proStatus: ProStatusManager
    @Environment(\.dismiss) private var dismiss

    /// Set when the app opened this paywall because the trial is over (#593), with
    /// how it is framed (#837); nil for every entry point the user chose.
    var trialEnd: ProTrialEndPaywall?

    /// Why this paywall is up. `.trialEnded` only for the end-of-trial framing; a
    /// reinstall over an ended trial gets the ordinary one (#837).
    private var framing: PaywallFraming {
        trialEnd == .trialEnded ? .trialEnded : .standard
    }

    /// Selected plan, tracked by product ID (never by array index: StoreKit's
    /// product order is unspecified). Yearly is preselected per the pricing
    /// decision on #78, true from the first frame with no load-completion hook.
    @State private var selectedProductID = ProProductID.yearly

    /// Set by "See all plans": the monthly row joins the two in view (#724).
    @State private var showsAllPlans = false

    /// The end-of-trial paywall's monthly offer, on screen (#724 decision 2).
    @State private var showsMonthlyOffer = false

    /// Whether this presentation already made that offer. Once: closing the offer
    /// closes everything.
    @State private var monthlyOfferMade = false

    /// Whether the user can still claim the yearly intro offer (7-day trial).
    /// StoreKit grants it once per Apple ID. Defaults to false so the CTA never
    /// over-promises.
    ///
    /// Since #593 the catalogue carries no introductory offer at all (#215), and
    /// this stays false for anyone who ever had the reverse trial even if one
    /// reappears in App Store Connect: a user who has just finished two free weeks
    /// must never be offered "7 more days free".
    @State private var isEligibleForTrial = false

    /// Shows the thank-you screen after a successful purchase or restore.
    @State private var showPurchaseSuccess = false

    /// Drives the staged entrance animation of the thank-you screen elements.
    @State private var successEntrance = false

    /// Presents Apple's offer code sheet (#787).
    @State private var showsOfferCodeRedemption = false

    /// The feature whose screen is pushed onto the hub's stack (#216 decision 4).
    @State private var openedFeature: ProFeature?

    /// The three per-feature switches, observed so the rows' "On" / "Off" values
    /// follow a switch flipped on a pushed screen (#216). The same object that screen
    /// writes through; see `ProFeatureSwitches` for why it is not `@AppStorage`.
    @ObservedObject private var switches = ProFeatureSwitches.shared

    /// Product matching the current selection. Nil disables the CTA.
    ///
    /// WHY no fallback here: it used to degrade to `products.first` when the
    /// selected plan had not loaded, which made the CTA charge a plan that no
    /// row showed as selected — every circle empty while the button read
    /// "S'abonner pour 4,99 €/mois" and charging it did exactly that. With
    /// three plans the gap between the intended and the charged price reaches
    /// 45 €. `reconcileSelection()` moves the selection onto a product that
    /// exists instead, so the checked row, the CTA and the charge never
    /// disagree.
    private var selectedProduct: Product? {
        subscriptionManager.products.first { $0.id == selectedProductID }
    }

    /// Move the selection onto a plan that actually loaded.
    ///
    /// WHY it is needed at all: `selectedProductID` is fixed before the fetch,
    /// so a plan that fails to load leaves it pointing at nothing while the
    /// user sees no checked row.
    ///
    /// WHY the cheapest rather than a preference order: `products` is sorted
    /// ascending by price, so a failed fetch can only ever demote the user to a
    /// cheaper plan. Falling onto the lifetime because the yearly went missing
    /// would put a 79,99 € one-off under a button the user thought said 39,99 €.
    private func reconcileSelection() {
        guard selectedProduct == nil,
              let cheapest = subscriptionManager.products.first else { return }
        selectedProductID = cheapest.id
    }

    var body: some View {
        ScrollView {
            if hubBlock.sellsPlans {
                salesContent
            } else {
                hubContent
            }
        }
        // Scrolls only when the content outgrows the screen: large Dynamic Type, or a
        // device smaller than the iPhone SE the layout is measured on (#913).
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: Bool.self) { $0.size.height < 680 } action: { isCompact = $0 }
        // The purchase area is pinned (#913): the CTA, the price it charges, Restore,
        // Redeem a code and the legal links never need a scroll to find.
        .safeAreaInset(edge: .bottom) {
            if hubBlock.sellsPlans {
                purchaseFooter
            }
        }
        .background(Color.dictusBackground.ignoresSafeArea())
        // Empty bar title: the hero's gradient title is the screen title.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton }
        // Pushed inside this screen's own stack (decision 4), so the back button
        // returns to the hub rather than closing it.
        .navigationDestination(item: $openedFeature) { feature in
            featureScreen(feature)
        }
        .task {
            // Retry the product fetch if the launch-time load came back empty,
            // so a transient failure doesn't leave the CTA stuck on "...".
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
            reconcileSelection()
            // Configuration describes the trial for everyone; eligibility is
            // per Apple ID. Ask StoreKit rather than assuming.
            //
            // Never after a reverse trial (#593): see `isEligibleForTrial`.
            if !proStatus.trialState.hasEverStarted,
               let subscription = subscriptionManager.yearlyProduct?.subscription {
                isEligibleForTrial = await subscription.isEligibleForIntroOffer
            }
        }
        // Products can also land after this view appears: the launch-time fetch
        // started in SubscriptionManager.init and may finish at any point.
        .onChange(of: subscriptionManager.products.map(\.id)) { _, _ in
            reconcileSelection()
        }
        .onChange(of: subscriptionManager.purchaseState) { _, newState in
            // Celebrate instead of silently ejecting the user who just paid:
            // the thank-you screen takes over and Continue dismisses.
            if newState == .success {
                withAnimation(.easeOut(duration: 0.25)) {
                    showPurchaseSuccess = true
                }
                // Bought from the monthly offer: it steps aside for the thank-you
                // screen rather than closing the paywall with it.
                showsMonthlyOffer = false
            }
        }
        .overlay {
            if showPurchaseSuccess {
                purchaseSuccessView
                    .transition(.opacity)
            }
        }
        .alert("Purchase Error", isPresented: showsErrorAlert(fromOffer: false)) {
            Button("OK") { subscriptionManager.resetState() }
        } message: {
            Text(errorMessage)
        }
        // On the screen and not on its button: redeeming can flip `sellsPlans` and
        // remove the button while the sheet is still closing.
        .offerCodeRedemption(isPresented: $showsOfferCodeRedemption) { result in
            subscriptionManager.offerCodeSheetClosed(result)
        }
        // Closing it any way but a purchase closes the paywall too (#724): the user
        // has now declined twice, and a third screen would be the nag the decision
        // rules out. A purchase leaves `showPurchaseSuccess` set, and the thank-you
        // screen underneath takes over.
        .sheet(isPresented: $showsMonthlyOffer, onDismiss: {
            if !showPurchaseSuccess { dismiss() }
        }, content: {
            monthlyOfferSheet
        })
    }

    // MARK: - Hub state (#216)

    /// The subscriber's upgrade (#216 decision 15): the lifetime, bought directly
    /// through the same path as the plan selector. Apple's sheet confirms; on success
    /// the thank-you screen shows, and the next scan lands on plain lifetime, since the
    /// row only buys once the subscription no longer renews.
    ///
    /// The rule is checked again here and not only by which shape the row draws: this
    /// is the one function that can sell the lifetime over a subscription.
    private func buyLifetime() {
        guard ProLifetimeUpgrade.offer(for: hubBlock, paywallVisible: PremiumFlags.paywallVisible)?.isPurchasable == true,
              let lifetime = subscriptionManager.lifetimeProduct else { return }
        Task { await subscriptionManager.purchase(lifetime) }
    }

    /// What sits under the cards. Read from the published caches, so a purchase, a
    /// renewal scan or the trial ending redraws it.
    private var hubBlock: ProHubBottomBlock {
        ProHub.bottomBlock(
            paywallVisible: PremiumFlags.paywallVisible,
            isPaid: proStatus.isPaid,
            isEntitled: proStatus.isProActive,
            trial: proStatus.trialState,
            now: Date(),
            ownership: subscriptionManager.ownership
        )
    }

    /// Whether the cards carry toggles and open their screens (decision 4). Never on
    /// the end-of-trial presentation (decision 3).
    private var cardsAreActive: Bool {
        framing == .standard && hubBlock.cardsAreActive
    }

    /// `FeatureGate.isAvailable`, the one predicate (decision 5). The switch and the
    /// entitlement are read first so SwiftUI redraws when either moves: the gate
    /// itself goes to the App Group, which publishes nothing.
    private func isAvailable(_ feature: ProFeature) -> Bool {
        _ = switches.isOn(feature)
        _ = proStatus.isProActive
        return FeatureGate.isAvailable(feature)
    }

    /// The screens the Settings "Pro Features" rows used to open, now reached here.
    ///
    /// History keeps its home-screen swipe (decision 7); this is a second way in, so
    /// it is pushed rather than presented as the sheet the swipe opens. Its store is
    /// handed over explicitly for the reason `HomeView` gives: this screen is itself a
    /// cover, presented from elsewhere in the tree. `proStatus` likewise, for every
    /// screen: each one observes it to relock when the entitlement changes.
    @ViewBuilder
    private func featureScreen(_ feature: ProFeature) -> some View {
        switch feature {
        case .smartMode:
            SmartModeListView()
                .environmentObject(proStatus)
        case .vocabulary:
            VocabularyListView()
                .environmentObject(proStatus)
        case .voiceNotes:
            VoiceNoteSettingsView()
                .environmentObject(proStatus)
        case .history:
            HistoryView(isPushed: true)
                .environmentObject(TranscriptionHistoryStore.shared)
                .environmentObject(proStatus)
        }
    }

    // MARK: - Close

    /// Dismisses the cover. Absent while the thank-you screen is up, so the
    /// only way forward from it is Continue — a cover has no swipe-back to
    /// serve as the escape hatch a pushed screen had.
    @ToolbarContentBuilder
    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !showPurchaseSuccess {
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Close")
            }
        }
        // The wordmark sits in the bar, level with the cross (#913): on an iPhone SE
        // a row of its own under the bar cost the plans their room.
        ToolbarItem(placement: .principal) {
            PaywallWordmark()
        }
    }

    /// Whether the screen is short enough to need the tighter spacing (#913): the
    /// iPhone SE's 375×667 leaves about 600 pt under the bar, an iPhone 17 about 750.
    ///
    /// WHY read from the container and not from the content: the content's height
    /// depends on this answer, and deciding on it would flip back and forth.
    @State private var isCompact = false

    /// The regular spacing, or the compact one on a short screen.
    private func space(_ regular: CGFloat, compact: CGFloat) -> CGFloat {
        isCompact ? compact : regular
    }

    // MARK: - Sales layout (#913)

    /// Everything above the pinned purchase area, for every state that sells plans:
    /// Free, the running trial, and the end-of-trial screen.
    ///
    /// WHY one screen for the end of the trial, where it used to be a recap and then
    /// the offers: the recap is one line now, so it fits above the same plans, and the
    /// way out sits under the CTA rather than on a step of its own.
    private var salesContent: some View {
        VStack(spacing: 0) {
            Text(framing == .trialEnded ? "Your trial has ended" : "All the power of your voice")
                .font(.dmSans(.semiBold, size: isCompact ? 24 : 26, relativeTo: .title2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, space(16, compact: 4))

            if framing == .trialEnded {
                TrialRecapLine(usage: proStatus.trialUsage)
                    .padding(.top, space(12, compact: 8))
            }

            // The running trial's count, kept to its one line (#913).
            if case .offers(_?, let daysLeft?) = hubBlock {
                Label {
                    Text("\(daysLeft) days left in your free trial")
                } icon: {
                    Image(systemName: "gift.fill")
                }
                .font(.dmSans(.medium, size: 14, relativeTo: .subheadline))
                .foregroundColor(.dictusAccent)
                .padding(.top, space(10, compact: 6))
            }

            PaywallFeatureList(
                showsVoiceNoteDetail: framing == .standard,
                lineSpacing: space(10, compact: 6),
                open: cardsAreActive ? { openedFeature = $0 } : nil
            )
            .padding(.top, space(22, compact: 14))

            planSelector
                .padding(.top, space(22, compact: 14))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, space(12, compact: 4))
    }

    /// The pinned bottom: CTA, what it charges, the way out on the end-of-trial screen,
    /// then Restore · Redeem and Terms · Privacy (guideline 3.1.2).
    private var purchaseFooter: some View {
        VStack(spacing: 0) {
            subscribeCTA

            // Two lines rather than a shrink: the price and its terms are what
            // guideline 3.1.2 asks to be legible, and the German runs long.
            billingLine
                .font(.dmSans(.regular, size: 12, relativeTo: .caption))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            if framing == .trialEnded {
                continueForFreeButton
                    .padding(.top, space(4, compact: 0))
            }

            restoreAndRedeemRow
                .padding(.top, framing == .trialEnded ? 0 : space(12, compact: 6))

            legalLinksRow
                .padding(.top, space(6, compact: 2))
        }
        .padding(.horizontal, 20)
        .padding(.top, space(12, compact: 8))
        .padding(.bottom, 4)
        .background(Color.dictusBackground.ignoresSafeArea())
    }

    /// Subscriber, Lifetime and the in-between states: no sales block, the hub as
    /// before (#216) under the same wordmark.
    private var hubContent: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                ForEach(ProFeature.allCases, id: \.self) { feature in
                    if cardsAreActive {
                        ProHubFeatureCard(
                            feature: feature,
                            isAvailable: isAvailable(feature),
                            open: { openedFeature = feature }
                        )
                    } else {
                        featureCard(feature)
                    }
                }
            }

            ProHubMembershipCard(
                block: hubBlock,
                refresh: { subscriptionManager.recheckAfterManageSheet() },
                upgrade: ProLifetimeUpgrade.offer(
                    for: hubBlock, paywallVisible: PremiumFlags.paywallVisible
                ),
                lifetimePrice: subscriptionManager.lifetimeProduct?.displayPrice,
                isPurchasing: subscriptionManager.purchaseState == .purchasing,
                buyLifetime: buyLifetime
            )

            legalLinksRow
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Feature Card

    /// Feature card with SF Symbol icon, title, and description.
    /// Non-interactive (informational only per UI-SPEC). Compact metrics so
    /// the plan cards stay above the fold on a 6.1-inch screen.
    private func featureCard(_ feature: ProFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(iconColor(for: feature))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(feature.displayName))
                    .font(.dictusBody.weight(.semibold))
                Text(LocalizedStringKey(feature.paywallDescription))
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                if !feature.isSupportedByThisDevice {
                    unsupportedNotice
                }
            }

            Spacer()
        }
        .padding(12)
        .dictusGlass()
        // Dimmed, not hidden, and not disabled: the card is still a truthful part of
        // what Pro contains, and the sentence under it is the point.
        .opacity(feature.isSupportedByThisDevice ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: feature))
    }

    /// The line that makes a paywall honest on a device that cannot run the feature
    /// (#79).
    ///
    /// **This is a review risk before it is a UX one.** Apple Foundation Models needs
    /// an iPhone 15 Pro or later on iOS 26; Dictus supports iOS 17 up, so most of the
    /// installed base is in this state permanently, and #268 closed the only
    /// alternative backend `wontfix`. A reviewer on a device without Apple
    /// Intelligence, facing a paywall that advertises a feature their hardware cannot
    /// deliver, is a rejection for misleading metadata — and the App Review device on
    /// #207 was an iPad Air.
    ///
    /// WHY the card is marked rather than removed, which #79 left open: a paywall
    /// that silently contains different things on different phones is one nobody can
    /// screenshot for review or reason about in a support thread, and a user who
    /// upgrades their iPhone would never learn the feature had been there all along.
    /// Marking says the same true thing to everyone. Pro still sells on History and
    /// Vocabulary, which is exactly what #79 decided.
    private var unsupportedNotice: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))

            Text("Requires Apple Intelligence (iPhone 15 Pro or later, iOS 26)")
                .font(.dictusCaption)
                .lineLimit(2)
        }
        .foregroundColor(.secondary)
        .padding(.top, 2)
    }

    /// Each part goes through the catalog first (#279): `ProFeature`'s strings are
    /// English keys, and `accessibilityLabel(_:)` reads a `String` verbatim, so the
    /// combined label was the one English line on a French paywall.
    private func accessibilityLabel(for feature: ProFeature) -> String {
        let name = String(localized: String.LocalizationValue(feature.displayName))
        let description = String(localized: String.LocalizationValue(feature.paywallDescription))
        guard let notice = feature.unsupportedNotice else {
            return "\(name): \(description)"
        }
        return "\(name): \(description). \(String(localized: String.LocalizationValue(notice)))"
    }

    /// Icon color per feature (Smart Mode = accent, others = accent highlight; #789).
    private func iconColor(for feature: ProFeature) -> Color {
        switch feature {
        case .smartMode: return .dictusAccent
        case .history, .vocabulary, .voiceNotes: return .dictusAccentHighlight
        }
    }

    // MARK: - Plan Selector

    /// Yearly row first, matching its preselection. Each row renders only
    /// if its product loaded, so a partial fetch degrades instead of crashing.
    /// The lifetime comes last, its scope line under it while it is selected.
    ///
    /// The monthly is behind "See all plans" (#724 decision 1): two plans in view,
    /// on every entry point. Which rows draw is `ProPaywallPlans`' answer, which
    /// keeps a selected monthly visible whatever the link says.
    private var planSelector: some View {
        VStack(spacing: space(10, compact: 8)) {
            if let yearly = subscriptionManager.yearlyProduct {
                planRow(
                    product: yearly,
                    title: "Yearly",
                    detail: perMonthEquivalent(for: yearly),
                    badge: discountBadgeText
                )
            }
            if let monthly = subscriptionManager.monthlyProduct,
               ProPaywallPlans.isVisible(monthly.id, showsAllPlans: showsAllPlans, selectedID: selectedProductID) {
                planRow(product: monthly, title: "Monthly", detail: nil, badge: nil)
            }
            if let lifetime = subscriptionManager.lifetimeProduct {
                planRow(
                    product: lifetime,
                    title: "Lifetime",
                    detail: founderOfferLabel ?? Text("one-time payment"),
                    badge: nil
                )
                if selectedProductID == lifetime.id {
                    lifetimeScopeLine
                }
            }
            if ProPaywallPlans.showsSeeAllPlansLink(
                loaded: Set(subscriptionManager.products.map(\.id)),
                showsAllPlans: showsAllPlans,
                selectedID: selectedProductID
            ) {
                seeAllPlansLink
                    .padding(.top, space(4, compact: 0))
            }
        }
    }

    private func planRow(product: Product, title: LocalizedStringKey, detail: Text?, badge: String?) -> some View {
        PaywallPlanRow(
            title: title,
            price: priceString(for: product),
            detail: detail,
            badge: badge,
            minHeight: space(58, compact: 52),
            isSelected: product.id == selectedProductID,
            select: { selectedProductID = product.id }
        )
    }

    /// Reveals the monthly row. A link and not a card: the monthly is there for whoever
    /// looks for it, and the two plans in view are the ones the screen recommends.
    ///
    /// WHY the revealed row is not selected for the user: the link answers "what else
    /// is there", not "I want this one". The yearly stays checked until a row is tapped,
    /// so the CTA never changes price behind a tap that did not mean to buy.
    private var seeAllPlansLink: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showsAllPlans = true
            }
        } label: {
            Text("See all plans")
                .font(.dmSans(.semiBold, size: 14, relativeTo: .subheadline))
                .foregroundColor(.dictusAccent)
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Set by the lifetime scope line: the full sentence in an alert.
    @State private var showsLifetimeTerms = false

    /// What the lifetime purchase covers, shortened to one line for the one screen
    /// (#913), with the full sentence of the #350 decision one tap away.
    ///
    /// WHY it shows while the lifetime is selected, and only then: a promise cannot
    /// be narrowed after someone has bought against it, so the boundary has to be
    /// visible before the sale. Selected is the state the CTA buys it in.
    ///
    /// WHY the boundary is drawn at who pays to run the feature, not at where
    /// it runs: a feature pointed at a server the user provides costs the
    /// project nothing recurring and belongs inside a one-off purchase, while
    /// anything on Dictus infrastructure carries a per-user marginal cost that
    /// a single payment cannot fund. "Local" only approximated that line, so the
    /// short line names Dictus servers, not the device.
    private var lifetimeScopeLine: some View {
        Button {
            showsLifetimeTerms = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Every Pro feature, current and future, except those on Dictus servers.")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "info.circle")
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            .font(.dmSans(.regular, size: 12, relativeTo: .caption))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert("Lifetime", isPresented: $showsLifetimeTerms) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The lifetime purchase covers every current and future Pro feature that runs on your device or on a server you provide. Any feature relying on Dictus infrastructure is a separate offering.")
        }
    }

    /// Founder-window line under the lifetime price, e.g. "Founder offer until
    /// 12 September 2026."
    ///
    /// WHY nil rather than a placeholder while the window is unscheduled: the
    /// end date is only knowable once the first Pro release is scheduled
    /// (#79), and an announcement missing its date is worse than none.
    ///
    /// WHY it goes through `LifetimeFounderWindow` rather than reading the
    /// constant directly: the build outlives the window. The price rises in
    /// App Store Connect on the announced day, but a user who has not updated
    /// keeps running this build, and the line has to retire itself rather than
    /// contradict the price shown right above it.
    ///
    /// WHY it names no later price, although "149,99 € ensuite" was the approved
    /// wording and is the more persuasive line: StoreKit gives us the *current*
    /// price in the buyer's own currency through `displayPrice`, but the future
    /// price is not a product yet, so it could only be written into the string —
    /// and a US buyer would read a dollar amount on the row with "149,99 €
    /// afterwards" underneath, a currency they will never be charged in. The
    /// amount on a non-euro storefront is not ours to state either: App Store
    /// Connect derives it from Apple's price matrix and readjusts it as rates
    /// move. For a window lasting weeks, being correct everywhere beats being
    /// persuasive. The deadline carries the scarcity, and the rise is visible
    /// on the row itself once it happens.
    ///
    /// The alternative considered and deliberately not built, still open: a
    /// second, never-offered StoreKit product holding the future price, so that
    /// `displayPrice` would render it in the right currency everywhere. It
    /// burns a permanent product identifier for a line that shows for weeks.
    ///
    /// Either way this announces a future increase and not a reduction, which
    /// is what keeps it clear of the Omnibus directive (art. L.112-1-1): a
    /// struck-through reference price would have to have actually been charged
    /// in the previous 30 days, and 149,99 € never was.
    private var founderOfferLabel: Text? {
        guard let end = LifetimeFounderWindow.announcedEnd() else { return nil }
        let date = end.formatted(.dateTime.day().month(.wide).year())
        return Text("Founder offer until \(date).")
    }

    /// A plan's price carrying its own period, e.g. "39,99 €/an" — or, for the
    /// lifetime non-consumable, "79,99 €" with no period at all.
    ///
    /// The plan rows and the billing line under the CTA show it as written (#913,
    /// « 39,99 €/an » is the row's largest text); the monthly offer's CTA wraps it.
    ///
    /// WHY derived from `Product.subscription` rather than from an identifier:
    /// the chain this replaces tested for the yearly ID and fell through to
    /// "/month" for everything else, so the one-off lifetime would have been
    /// advertised as a monthly plan (#350). Any period Dictus does not sell —
    /// a weekly plan, or one of App Store Connect's 3- and 6-month durations —
    /// shows the bare price: less informative, never false. `ProPlanPeriod`
    /// owns that rule so it can be tested.
    private func priceString(for product: Product) -> String {
        let period = product.subscription?.subscriptionPeriod
        switch ProPlanPeriod.resolve(
            unit: period.map { Self.planUnit(for: $0.unit) },
            value: period?.value ?? 0
        ) {
        case .yearly: return String(localized: "\(product.displayPrice)/year")
        case .monthly: return String(localized: "\(product.displayPrice)/month")
        case .unlabelled: return product.displayPrice
        }
    }

    private func priceLabel(for product: Product) -> Text {
        Text(verbatim: priceString(for: product))
    }

    /// Maps StoreKit's period unit onto the one DictusCore reasons about.
    ///
    /// WHY the indirection: the keyboard extension links DictusCore and must
    /// not link StoreKit, so the rule deciding the suffix cannot name
    /// StoreKit's types. This mapping is the only place the two meet.
    private static func planUnit(for unit: Product.SubscriptionPeriod.Unit) -> ProSubscriptionUnit {
        switch unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .unknown
        }
    }

    /// Per-month equivalent under the yearly price, e.g. "3,33 € / mois".
    /// WHY priceFormatStyle: it carries the product's own currency and locale,
    /// so the divided price is formatted exactly like displayPrice.
    private func perMonthEquivalent(for yearly: Product) -> Text {
        let perMonth = yearly.priceFormatStyle.format(yearly.price / Decimal(12))
        return Text("\(perMonth) / month", comment: "Paywall yearly row (#913): the yearly price divided by twelve.")
    }

    /// Discount badge, e.g. "-33 %". Computed from live prices so a price
    /// change in App Store Connect can never make the badge lie. Nil (hidden)
    /// when either product is missing or the discount is not positive.
    private var discountBadgeText: String? {
        guard let yearly = subscriptionManager.yearlyProduct,
              let monthly = subscriptionManager.monthlyProduct,
              monthly.price > 0 else { return nil }
        let ratio = 1 - (yearly.price / (monthly.price * 12))
        let percent = (ratio as NSDecimalNumber).doubleValue
        guard percent > 0 else { return nil }
        let formatted = percent.formatted(
            .percent.precision(.fractionLength(0)).sign(strategy: .never)
        )
        return "-" + formatted
    }

    // MARK: - Subscribe CTA

    private var subscribeCTA: some View {
        Button {
            Task {
                if let product = selectedProduct {
                    await subscriptionManager.purchase(product)
                }
            }
        } label: {
            Group {
                if subscriptionManager.purchaseState == .purchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    ctaTitle
                        .font(.dmSans(.semiBold, size: 17, relativeTo: .headline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: space(52, compact: 48))
            // The brand blue in light and dark mode alike (#913).
            .background(Color.dictusAccent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(GlassPressStyle())
        .disabled(selectedProduct == nil || subscriptionManager.purchaseState == .purchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1.0)
        .accessibilityLabel(ctaTitle)
    }

    /// The CTA's words (#913): the brand sentence, and the price on the billing line
    /// right under it rather than in the button.
    ///
    /// WHY the free-trial sentence still wins when it applies: "7 days free, then"
    /// is the one thing about the charge the user must read before tapping, and it
    /// belongs on the button that starts it. Since #593 no plan carries an intro
    /// offer, so this branch is dormant, kept for the day one returns.
    private var ctaTitle: Text {
        if let product = selectedProduct, let trial = freeTrialLabel(for: product) {
            return trial
        }
        return framing == .trialEnded ? Text("Keep Dictus Pro") : Text("Continue with Dictus Pro")
    }

    /// The billed price and its terms, under the CTA (guideline 3.1.2): « 39,99 €/an,
    /// renouvellement auto, sans engagement », or the lifetime's one-off price.
    private var billingLine: Text {
        guard let product = selectedProduct else { return Text(verbatim: "...") }
        let price = priceString(for: product)
        guard product.subscription != nil else {
            return Text("\(price), one-time payment", comment: "Paywall line under the CTA for the lifetime purchase (#913).")
        }
        return Text("\(price), auto-renews, cancel anytime",
                    comment: "Paywall line under the CTA for a subscription (#913): the billed price with its period, e.g. « 39,99 €/an ».")
    }

    /// "7 days free, then 39,99 €/year" when this product's intro offer is a free
    /// trial the user can still claim; nil otherwise.
    private func freeTrialLabel(for product: Product) -> Text? {
        // Ask this product for its offer rather than assuming which plan
        // carries one. Configuration puts the trial on the yearly plan today
        // (#215); the CTA should follow the configuration, not a memory of it.
        guard isEligibleForTrial,
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial,
              let days = trialDays(for: offer) else { return nil }
        return Text("\(days) days free, then \(priceLabel(for: product))")
    }

    /// The CTA sentence for any plan, so the monthly offer (#724) reads exactly like
    /// the paywall's own button would for the same plan.
    private func ctaLabel(for product: Product?) -> Text {
        guard let product else { return Text(verbatim: "...") }
        let price = priceLabel(for: product)

        // No `subscription` means a non-consumable, and "Subscribe" would
        // misdescribe a purchase that never renews.
        guard product.subscription != nil else {
            return Text("Buy for \(price)")
        }

        if let trial = freeTrialLabel(for: product) {
            return trial
        }
        return Text("Subscribe for \(price)")
    }

    /// The line under the monthly offer's CTA (#724 decision 3).
    static let noCommitmentLabel = Text("No commitment, cancel anytime")

    /// Trial length in days. StoreKit expresses the 7-day trial as 1 week;
    /// convert so the CTA reads "7 days free" as designed. Returns nil for
    /// month/year units so the caller falls back to the plain subscribe
    /// label rather than showing awkward copy.
    private func trialDays(for offer: Product.SubscriptionOffer) -> Int? {
        switch offer.period.unit {
        case .day: return offer.period.value
        case .week: return offer.period.value * 7
        default: return nil
        }
    }

    // MARK: - Monthly offer on close (#724)

    /// Every way out of the paywall the user can take: the cross and "Continue for
    /// free". On the paywall the app opened at the trial's end, once the user has seen
    /// the plans, the first one shows the monthly offer instead of closing
    /// (`ProPaywallPlans.offersMonthlyOnClose`); everywhere else, and the second
    /// time, it closes.
    ///
    /// `sawPlans` is always true since #913: the end-of-trial screen no longer opens
    /// on a recap without prices, its plans are on screen from the first frame.
    private func close() {
        guard ProPaywallPlans.offersMonthlyOnClose(
            trialEndPaywall: trialEnd,
            sawPlans: true,
            isPaid: proStatus.isPaid,
            monthlyLoaded: subscriptionManager.monthlyProduct != nil,
            alreadyOffered: monthlyOfferMade
        ) else {
            dismiss()
            return
        }
        monthlyOfferMade = true
        showsMonthlyOffer = true
    }

    /// The offer's content. Its price is the monthly product's `displayPrice`, through
    /// the same CTA sentence as the paywall.
    @ViewBuilder
    private var monthlyOfferSheet: some View {
        if let monthly = subscriptionManager.monthlyProduct {
            MonthlyPlanOfferSheet(
                ctaLabel: ctaLabel(for: monthly),
                isPurchasing: subscriptionManager.purchaseState == .purchasing,
                buy: { Task { await subscriptionManager.purchase(monthly) } },
                decline: { showsMonthlyOffer = false }
            )
            // A swipe mid-purchase would close the paywall under a payment still in
            // flight, and its thank-you screen with it.
            .interactiveDismissDisabled(subscriptionManager.purchaseState == .purchasing)
            .alert("Purchase Error", isPresented: showsErrorAlert(fromOffer: true)) {
                Button("OK") { subscriptionManager.resetState() }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Continue for free

    /// The end-of-trial paywall's way out, as obvious as the way in (#593).
    ///
    /// WHY a full-width button and not only the close cross: this screen was not
    /// asked for. The app opened it, so leaving has to read as a first-class choice
    /// rather than a dismissal hunted for in a corner. The free tier keeps working,
    /// and nothing the user saved is deleted. A text button since #913, for the one
    /// screen to fit an iPhone SE, still full width and in the accent colour.
    private var continueForFreeButton: some View {
        Button {
            close()
        } label: {
            Text("Continue for free")
                .font(.dmSans(.semiBold, size: 16, relativeTo: .callout))
                .foregroundColor(.dictusAccent)
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Distinct from the monthly offer's own "Continue for free" (#793): with the
        // offer up, both share a label, and a tap by label can land on this one.
        .accessibilityIdentifier("paywall.continueForFree")
    }

    // MARK: - Bottom Links

    // Apple requires functional Terms of Use and Privacy Policy links for
    // auto-renewable subscriptions (guideline 3.1.2). Not private: the monthly
    // offer sheet (#724) shows them too. Force unwrap is safe:
    // compile-time constant URLs that cannot be malformed.
    // swiftlint:disable:next force_unwrapping
    static let termsURL = URL(string: "https://getdictus.com/terms")!
    // swiftlint:disable:next force_unwrapping
    static let privacyURL = URL(string: "https://getdictus.com/privacy")!

    /// « Restaurer les achats · Saisir un code », on one line that shrinks rather
    /// than wraps (#913).
    ///
    /// Restore follows the offers (#216): wherever plans are sold, and nowhere else.
    /// Apple requires a restore mechanism to exist (guideline 3.1.1), not to be shown
    /// to subscribers, and during the reverse trial (#593) a returning buyer is
    /// exactly who needs it.
    private var restoreAndRedeemRow: some View {
        HStack(spacing: 6) {
            Button("Restore purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .accessibilityLabel("Restore previous purchases")

            Text(verbatim: "·")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)

            // Apple's own offer code sheet (#787): the codes are made in App Store
            // Connect, so a gifted code grants the same Pro product the plans above
            // sell. Same neutral wording rule as the issue: the label says what
            // the button does, never where a code comes from.
            Button("Redeem a code") {
                showsOfferCodeRedemption = true
            }
            .accessibilityIdentifier("paywall.redeemCode")
        }
        .buttonStyle(.plain)
        .font(.dmSans(.medium, size: 14, relativeTo: .footnote))
        .foregroundColor(.dictusAccent)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(minHeight: 28)
    }

    /// « Conditions d’utilisation · Confidentialité » (guideline 3.1.2).
    private var legalLinksRow: some View {
        HStack(spacing: 6) {
            Link("Terms of Service", destination: Self.termsURL)
            Text(verbatim: "·")
                .accessibilityHidden(true)
            Link("Privacy", destination: Self.privacyURL)
                .accessibilityLabel("Privacy Policy")
        }
        .font(.dmSans(.regular, size: 12, relativeTo: .caption))
        .foregroundColor(.secondary)
        .tint(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // MARK: - Purchase Success

    /// Thank-you screen shown after a successful purchase or restore.
    /// Staged entrance: the checkmark springs in first, then the texts rise
    /// with small delays, then the Continue button. Each element animates on
    /// the same trigger with its own delay, which reads as one choreography.
    private var purchaseSuccessView: some View {
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
                dismiss()
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

    // MARK: - Error Handling

    /// Whether a purchase error is up, on the screen that is in front.
    ///
    /// WHY two bindings over one state: a purchase can fail from the monthly offer
    /// (#724), and an alert asked of a view that is already presenting a sheet is
    /// dropped by UIKit. So the error shows on the offer while it is up, and on the
    /// paywall otherwise.
    private func showsErrorAlert(fromOffer: Bool) -> Binding<Bool> {
        Binding(
            get: {
                if case .failed = subscriptionManager.purchaseState { return showsMonthlyOffer == fromOffer }
                return false
            },
            set: { _ in }
        )
    }

    private var errorMessage: String {
        if case .failed(let msg) = subscriptionManager.purchaseState {
            return msg
        }
        return "An error occurred."
    }
}
