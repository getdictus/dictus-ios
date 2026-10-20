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

    /// The numbers the user produced, as tiles.
    ///
    /// WHY tiles and not the sentence the issue sketches ("you used Smart Modes 23
    /// times and Vocabulary fixed 11 words"): a sentence holding two counts has to
    /// agree with both in two languages, and a count of zero for one of them turns
    /// half of it into a reproach. A number above a label agrees with nothing.
    ///
    /// WHY dictation leads (#726): most users mostly dictate, and until then the
    /// recap only knew the Pro counters, so it showed nothing for them. Words and
    /// time saved come first, on their own row; the Pro counters follow, each only
    /// when it is not zero, for the reason the whole recap is absent rather than zero.
    private var recap: some View {
        VStack(spacing: 8) {
            Text("During your trial")
                .font(.dictusCaption)
                .foregroundColor(.secondary)

            if usage.wordsDictated > 0 {
                tileRow {
                    tile(value: Text(usage.wordsDictated, format: .number), label: Text("Words dictated"),
                         icon: "waveform", tint: .dictusAccent)
                    if let saved = usage.timeSaved {
                        tile(value: timeSavedText(saved), label: Text("Time saved over typing"),
                             icon: "clock", tint: .dictusSuccess)
                    }
                }
            }

            if usage.smartModeUses > 0 || usage.vocabularyFixes > 0 {
                tileRow {
                    if usage.smartModeUses > 0 {
                        tile(value: Text(usage.smartModeUses, format: .number), label: Text("Smart Mode dictations"),
                             icon: ProFeature.smartMode.icon, tint: .dictusSmartMode)
                    }
                    if usage.vocabularyFixes > 0 {
                        tile(value: Text(usage.vocabularyFixes, format: .number), label: Text("Words fixed by Vocabulary"),
                             icon: ProFeature.vocabulary.icon, tint: .dictusAccentHighlight)
                    }
                }
            }
        }
    }

    /// One row of tiles sharing the tallest one's height.
    private func tileRow<Content: View>(@ViewBuilder _ tiles: () -> Content) -> some View {
        HStack(spacing: 10, content: tiles)
            // With `maxHeight: .infinity` on each tile, both take the taller one's
            // height instead of each hugging its own label (one or two lines).
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "About 4 h", "About 25 min": an estimate, and worded as one (#726). The
    /// formula and its source are `TimeSavedEstimate`'s.
    private func timeSavedText(_ saved: TimeSavedEstimate.Rounded) -> Text {
        switch saved {
        case .minutes(let minutes):
            return Text("About \(minutes) min",
                        comment: "End-of-trial recap: estimated time dictation saved over typing, under an hour (#726).")
        case .hours(let hours):
            return Text("About \(hours) h",
                        comment: "End-of-trial recap: estimated time dictation saved over typing, rounded down to whole hours (#726).")
        }
    }

    private func tile(value: Text, label: Text, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(tint)
            value
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                // "Environ 45 min" is the longest value, and it shrinks rather than wraps.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            label
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    /// The count the home badge shows, repeated here as the line's headline (#216
    /// decision 2): the hub is where a trial user looks for how long they have left.
    /// Nil only if the trial ended between the state read and this render.
    var daysLeft: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "gift.fill")
                .foregroundColor(.dictusAccent)
            VStack(alignment: .leading, spacing: 2) {
                if let daysLeft {
                    Text("\(daysLeft) days left in your free trial")
                        .font(.dictusBody.weight(.semibold))
                }
                Text("Your free trial ends on \(endsAt.formatted(date: .long, time: .omitted)). Subscribe now and Pro stays on with no interruption.")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .dictusGlass()
        .accessibilityElement(children: .combine)
    }
}
