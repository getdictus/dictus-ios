// DictusApp/Views/ProTrialPaywallSections.swift
// The paywall's reverse-trial pieces: the end-of-trial framing and its monthly offer (#593, #724).
import SwiftUI
import DictusCore

/// Why the paywall is on screen, which decides how it opens.
enum PaywallFraming: Equatable {
    /// Every entry point the user chose: Settings, the home banner, a locked row, the
    /// keyboard pill.
    case standard

    /// Opened by the app, once, on the first launch after the reverse trial ended
    /// (#593). Framed as the end of something the user had rather than as an offer,
    /// with the recap and an obvious way to continue for free.
    case trialEnded
}

/// The sheet the end-of-trial paywall shows when it is closed without buying (#724
/// decision 2): the monthly plan, at its existing price.
///
/// WHY only there: that paywall was not asked for, and a user who closes it may only
/// be turned away by the yearly commitment. Every other entry point is one the user
/// opened, and closing it must never nag (`ProPaywallPlans.offersMonthlyOnClose`).
///
/// WHY an existing price and never a discount: a lower price shown only to those who
/// refuse teaches users to refuse, and it would undercut the yearly that the paywall
/// just recommended.
///
/// It sells and nothing else. The paywall underneath owns the outcome: a purchase
/// closes this sheet onto its thank-you screen, and any other way out closes both.
struct MonthlyPlanOfferSheet: View {
    /// The CTA's label, the paywall's own sentence ("Subscribe for 4,99 €/month") so
    /// the two read the same.
    let ctaLabel: Text
    let isPurchasing: Bool
    let buy: () -> Void
    let decline: () -> Void

    /// The content's own height, which the sheet takes as its only detent.
    ///
    /// WHY not `.medium`: a detent taller than the content leaves the rest of the
    /// sheet to iOS 26's translucent material, which showed the paywall blurred above
    /// and below the offer (device test of #724). Sized to its content, the sheet has
    /// no empty band to fill.
    @State private var contentHeight: CGFloat = 360

    var body: some View {
        // Scrolls only when the content outgrows the screen (large Dynamic Type), where
        // iOS clamps the detent and would otherwise cut off the way out and the terms.
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(contentHeight)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.dictusBackground)
    }

    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Not ready for a year?")
                    .font(.dictusSubheading)
                    .multilineTextAlignment(.center)
                Text("There is also a monthly plan.")
                    .font(.dictusBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)

            VStack(spacing: 8) {
                Button(action: buy) {
                    Group {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            ctaLabel
                                .font(.dictusSubheading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.dictusAccent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(GlassPressStyle())
                .disabled(isPurchasing)
                .accessibilityLabel(ctaLabel)

                PaywallView.noCommitmentLabel
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
            }

            // The same words as the paywall's own way out: declining here is that
            // choice, made a second time.
            Button(action: decline) {
                Text("Continue for free")
                    .font(.dictusSubheading)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.dictusAccent)
                    .dictusGlass()
            }
            .buttonStyle(GlassPressStyle())
            .disabled(isPurchasing)
            // Distinct from the paywall's own button under this sheet (#793).
            .accessibilityIdentifier("monthlyOffer.continueForFree")

            // Guideline 3.1.2: the terms travel with every screen that sells a
            // subscription, and this one sells it on its own.
            HStack(spacing: 16) {
                Link("Terms of Service", destination: PaywallView.termsURL)
                Link("Privacy Policy", destination: PaywallView.privacyURL)
            }
            .font(.dictusCaption)
            .foregroundColor(.secondary)
            // Same gap as the paywall's links (#793): a tap just under the way out
            // must not open Safari.
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }
}
