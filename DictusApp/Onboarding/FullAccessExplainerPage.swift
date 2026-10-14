// DictusApp/Onboarding/FullAccessExplainerPage.swift
// Why the keyboard asks for Full Access: a sheet opened from the keyboard step (#704).
import SwiftUI
import DictusCore

/// Says the truth about Full Access, for the user who wants to know before turning it on.
///
/// WHY THIS PAGE EXISTS (#704): testers declined to set Dictus up because of the alert
/// iOS raises when Full Access is turned on ("the developer of this keyboard can
/// transmit anything you type…"). They read it as something Dictus does. iOS shows the
/// same text for every third-party keyboard that asks for it, and it is one switch, all
/// or nothing. Shown here, drawn, with what Dictus uses it for and what it does not, the
/// alert is no surprise in Settings, and the open source line lets anyone check.
///
/// WHY A SHEET AND NOT A STEP (amended 2026-10-13, after a device test of the step): most
/// users are not worried by the alert, and a whole step made every one of them read about
/// it. The keyboard step warns in one line that the alert is coming, which needs no tap,
/// and its "Why Full Access?" link opens this page for the user who wants the reasons.
///
/// WHY THE ALERT IS DRAWN: only iOS system UI is drawn in the onboarding (#649 decision
/// 13), like the Settings page behind this sheet. A screenshot would not follow the
/// appearance or the language.
///
/// WHAT THE COPY RESTS ON: "your dictations never leave your iPhone" was checked against
/// what the keyboard links before it shipped (written on #704). If that ever changes,
/// the sentence changes.
struct FullAccessExplainerPage: View {
    let onClose: () -> Void

    var body: some View {
        OnboardingPage(
            title: Text("Why Full Access?"),
            subtitle: Text("Apple shows this message for every keyboard that asks for Full Access. It is all or nothing: iOS offers no partial access.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                DrawnFullAccessAlert()
                points
            }
        } bottom: {
            OnboardingPrimaryButton(Text("Close"), action: onClose)
                .accessibilityIdentifier("onboarding.fullAccess.close")
        }
        .background(Color.dictusBackground.ignoresSafeArea())
    }

    // MARK: - The three points

    /// What Dictus uses Full Access for, what it does not, and how to check.
    private var points: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExplainerPoint(
                systemImage: "arrow.up.forward.app",
                lead: Text("Dictus uses it to reach the Dictus app."),
                detail: Text("The app is what listens and transcribes. Without Full Access, the keyboard types but cannot dictate.")
            )
            Divider()
                .padding(.leading, ExplainerPoint.textLeading)
            ExplainerPoint(
                systemImage: "lock.shield",
                lead: Text("The rest, Dictus does not use."),
                detail: Text("No location, no contacts, and your dictations never leave your iPhone: transcription happens on the device.")
            )
            Divider()
                .padding(.leading, ExplainerPoint.textLeading)
            // WHY THE WHOLE ROW IS THE LINK: the brief makes "the GitHub line" the link.
            // A row is a target a thumb finds; a word inside a sentence is not.
            // `Link` hands the URL to the system, which opens it in Safari.
            Link(destination: Self.sourceCodeURL) {
                ExplainerPoint(
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    lead: Text("Anyone can check."),
                    detail: Text("Dictus is open source: anyone can read its code on GitHub."),
                    showsLinkArrow: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding.fullAccess.github")
        }
        .onboardingCard()
    }

    // The public repository. A compile-time constant, so the force unwrap cannot fail.
    // swiftlint:disable:next force_unwrapping
    static let sourceCodeURL = URL(string: "https://github.com/getdictus/dictus-ios")!
}

// MARK: - A point

/// One of the three points: an icon, a bold first sentence, then one line of detail.
private struct ExplainerPoint: View {
    let systemImage: String
    let lead: Text
    let detail: Text
    /// The trailing arrow that says the row opens a page outside the app.
    var showsLinkArrow = false

    /// Icon tile width plus the gap after it, plus the row's leading padding: where the
    /// text starts, which is where the dividers start too, as in a grouped list.
    static let textLeading: CGFloat = 16 + 32 + 14

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.dictusAccent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.dictusAccent.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                lead
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                detail
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsLinkArrow {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.dictusAccent)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Apple's alert, drawn

/// The alert iOS raises when Full Access is turned on for Dictus, drawn over a dimmed
/// card as it sits over the dimmed Settings page.
///
/// WHY APPLE'S OWN WORDS: the point of the page is that this is Apple's text, the same for
/// every keyboard. The strings are iOS's, copied from the alert as iOS 26.5 shows it in
/// French and in English (captured in the simulator for #704), with the keyboard's name
/// where iOS puts it. The layout follows that capture too: title and message aligned
/// left, the message in grey, two grey capsules side by side with neither one preferred.
///
/// WHY SMALLER THAN THE REAL ONE: at full size the alert filled the first screen and
/// pushed the three points, which are what the page is for, below the fold. It is drawn
/// at about 85 % of iOS's sizes, which still reads as the same alert.
private struct DrawnFullAccessAlert: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow Full Access for “Dictus” Keyboards?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Full access allows the developer of this keyboard to transmit anything you type, including things you have previously typed with this keyboard. This could include sensitive information such as your credit card number or street address.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                alertButton(Text("Don’t Allow"))
                alertButton(Text("Allow"))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Self.alertFill)
                .shadow(color: .black.opacity(0.15), radius: 18, y: 6)
        )
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        // The dimmed screen behind the alert.
        .background(
            RoundedRectangle(cornerRadius: OnboardingMetrics.cardCornerRadius, style: .continuous)
                .fill(Self.dimmedScreen)
        )
        .allowsHitTesting(false)
        // A picture, not a control: VoiceOver reads it as one element, its text included.
        .accessibilityElement(children: .combine)
    }

    private func alertButton(_ title: Text) -> some View {
        title
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    /// The alert's own material: the light grey of the capture on light, a raised slate on
    /// dark.
    private static let alertFill = Color(light: Color(hex: 0xEDEDF0), dark: Color(hex: 0x2A3346))

    /// The page behind the alert, dimmed: the light grey darkened as in the capture, the
    /// dark navy darker.
    private static let dimmedScreen = Color(light: Color(hex: 0xC4C4CA), dark: Color(hex: 0x060E1C))
}
