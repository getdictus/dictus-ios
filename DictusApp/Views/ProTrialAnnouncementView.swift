// DictusApp/Views/ProTrialAnnouncementView.swift
// The sheet that discloses the reverse trial and, on dismissal, starts it (#593).
import SwiftUI
import DictusCore

/// "14 days of Dictus Pro, on us": the trial's disclosure, for a new user at the end
/// of onboarding and for an existing user on the first launch of the Pro version.
///
/// ### What it has to say, and why all of it
///
/// App Review guideline 3.1.1's rules for trials, applied even though that paragraph
/// targets non-subscription apps: the **duration**, **what stops working** when it
/// ends, and **what it takes to keep it**. And #593's own reason, which is stronger:
/// a user must never discover later that what they used was paid, and a reverse
/// trial converts through loss aversion, which only works if the user knows what
/// they have and when they lose it. So the end is a date, not a number of days.
///
/// ### What it deliberately does not say
///
/// No price. #494 rules out any price in onboarding, and this sheet is what ends
/// onboarding until #494's screens exist. "It takes a Dictus Pro subscription" names
/// the cost of keeping Pro without turning a gift into a sales screen.
///
/// ### Onboarding's own screens replace the new-user half
///
/// #494 teaches the features and starts the trial through
/// `ProStatusManager.startTrialIfEligible()`. Once it does, the trial is already
/// running when onboarding completes and this sheet no longer comes up for new users.
struct ProTrialAnnouncementView: View {
    let announcement: ProTrialCoordinator.Announcement

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(spacing: 10) {
                    ForEach(ProFeature.allCases, id: \.self) { feature in
                        featureRow(feature)
                    }
                }

                disclosure

                Button {
                    dismiss()
                } label: {
                    Text("Start my free trial")
                        .font(.dictusSubheading)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.dictusAccent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(GlassPressStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color.dictusBackground.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.dictusGradientStart, .dictusGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityHidden(true)

            // Existing users are told what changed before they are told what they get:
            // they never saw a Pro screen, and "on us" means nothing without it.
            if announcement.kind == .existingUser {
                Text("Dictus Pro is here")
                    .font(.dictusCaption.weight(.semibold))
                    .foregroundColor(.dictusAccentHighlight)
            }

            Text("\(ProTrial.durationDays) days of Dictus Pro, on us")
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Everything in Pro is unlocked, free, starting today.")
                .font(.dictusBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Features

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title3)
                .foregroundColor(feature == .smartMode ? .dictusSmartMode : .dictusAccentHighlight)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(feature.displayName))
                    .font(.dictusBody.weight(.semibold))
                Text(LocalizedStringKey(feature.paywallDescription))
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)

                // A capable iPhone with Apple Intelligence switched off gets the trial
                // too (decision 2), and the clock runs anyway. Saying so here is the
                // difference between two weeks of Smart Modes and two weeks of a
                // feature that silently did nothing.
                if feature == .smartMode && PolishAvailability.state == .appleIntelligenceNotEnabled {
                    Text("Turn on Apple Intelligence in iOS Settings to use Smart Modes.")
                        .font(.dictusCaption)
                        .foregroundColor(.dictusAccentHighlight)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .dictusGlass()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Disclosure

    /// The terms, in plain words: when it ends, what it costs now, what happens after.
    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            disclosureLine(
                icon: "calendar",
                text: Text("Your trial ends on \(announcement.endsAt.formatted(date: .long, time: .omitted)).")
            )
            disclosureLine(
                icon: "creditcard",
                text: Text("No payment, nothing to cancel: nothing renews on its own.")
            )
            disclosureLine(
                icon: "arrow.uturn.backward",
                text: Text("When it ends, Dictus goes back to the free version by itself. Your history and your vocabulary are kept.")
            )
            disclosureLine(
                icon: "crown",
                text: Text("To keep Smart Modes, History and Vocabulary afterwards, you will need a Dictus Pro subscription.")
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func disclosureLine(icon: String, text: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            text
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
