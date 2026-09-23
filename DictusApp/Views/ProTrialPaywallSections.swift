// DictusApp/Views/ProTrialPaywallSections.swift
// The paywall's reverse-trial pieces: the end-of-trial framing, its recap, the running-trial line (#593).
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

/// The end-of-trial paywall's opening: what ended, and what the user did with it.
///
/// WHY it states the end before it sells anything: a reverse trial converts through
/// loss aversion, which only works if the user knows what they had. And the honest
/// order is the same one: Pro is already off when this shows, and a paywall that
/// opened on a price would read as a trick.
struct TrialEndedHeader: View {
    let usage: ProTrialUsage.Snapshot

    var body: some View {
        VStack(spacing: 12) {
            Text("Your Dictus Pro trial has ended")
                .font(.dictusSubheading)
                .multilineTextAlignment(.center)

            Text("Keep your Smart Modes, History and Vocabulary with Dictus Pro. Everything you saved is still here.")
                .font(.dictusBody)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Decision 5. Absent rather than zero: "0 Smart Mode uses" tells the user
            // they never tried it, which is not a reason to keep it.
            if !usage.isEmpty {
                recap
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Two numbers the user produced, as tiles.
    ///
    /// WHY tiles and not the sentence the issue sketches ("you used Smart Modes 23
    /// times and Vocabulary fixed 11 words"): a sentence holding two counts has to
    /// agree with both in two languages, and a count of zero for one of them turns
    /// half of it into a reproach. A number above a label agrees with nothing.
    private var recap: some View {
        VStack(spacing: 8) {
            Text("During your trial")
                .font(.dictusCaption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                tile(count: usage.smartModeUses, label: Text("Smart Mode dictations"),
                     icon: ProFeature.smartMode.icon, tint: .dictusSmartMode)
                tile(count: usage.vocabularyFixes, label: Text("Words fixed by Vocabulary"),
                     icon: ProFeature.vocabulary.icon, tint: .dictusAccentHighlight)
            }
        }
    }

    private func tile(count: Int, label: Text, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(tint)
            Text(count, format: .number)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
            label
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .dictusGlass()
        .accessibilityElement(children: .combine)
    }
}

/// One line on the paywall while the trial runs: when it ends, and that subscribing
/// now costs nothing of it.
///
/// WHY it exists: without it the paywall, opened mid-trial, sells a subscription to
/// someone who already has every feature and does not know for how long. The line
/// answers the question they would otherwise have to leave to ask.
struct TrialRunningNotice: View {
    let endsAt: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "gift.fill")
                .foregroundColor(.dictusAccent)
            Text("Your free trial ends on \(endsAt.formatted(date: .long, time: .omitted)). Subscribe now and Pro stays on with no interruption.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .dictusGlass()
        .accessibilityElement(children: .combine)
    }
}
