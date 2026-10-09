// DictusApp/Onboarding/SmartModePickPage.swift
// Onboarding step: pick the three Smart Modes the keyboard's long-press fan holds (#677).
import SwiftUI
import DictusCore

/// The pick of three Smart Modes (#649 decision 16, mock-up `06-vos-3-smart-modes`).
///
/// WHY A STEP AT ALL: the fan holds three modes and the catalogue has eight (Structured,
/// List, Message, Summary and four translation targets). Without a choice, every user
/// gets the seed (`defaultPinnedIdentifiers`) and never learns the other modes exist.
///
/// One large card per structure or register mode, then a Translate group whose chips are
/// the targets minus the language the user speaks. The counter beside the title shows
/// how many of the three are picked. Continue writes the pick to the pinned list, in the
/// order it was made; the shell's Skip writes nothing, so the seed stays
/// (`OnboardingView.skip`). The rules (offer, cap, write) are `SmartModePick`, in
/// DictusCore, where they are tested.
///
/// WHY BLUE: Smart Modes are the app's accent here, never the purple `dictusSmartMode`
/// token (#649 mock-ups).
struct SmartModePickPage: View {
    /// The flow's model manager, read for the download pill at the bottom.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onContinue: () -> Void

    @State private var pick = SmartModePick()

    /// The language the user said they speak on the language screen, which removes its
    /// own translation target. Read once: it was written two steps ago and does not change
    /// while this page is on screen.
    private let spokenLanguage = AppGroup.defaults.string(forKey: SharedKeys.spokenLanguage)

    var body: some View {
        OnboardingPage(
            title: Text("Your 3 Smart Modes"),
            subtitle: Text("Pick three. They will be waiting for you when you hold down the microphone.")
        ) {
            counter
        } content: {
            VStack(spacing: 12) {
                ForEach(SmartModePick.cardModes) { mode in
                    card(for: mode)
                }
                translateGroup
                    .padding(.top, 8)
            }
        } bottom: {
            downloadPill
            OnboardingPrimaryButton(Text("Continue"), isEnabled: pick.canContinue, action: commit)
                .accessibilityIdentifier("onboarding.primary")
        }
    }

    // MARK: - Counter

    /// The "n / 3" capsule beside the title. Digits and a slash read the same in every
    /// locale, so the visible text is not localized; VoiceOver gets a sentence.
    private var counter: some View {
        Text(verbatim: "\(pick.selected.count) / \(SmartModePick.maximum)")
            .font(.headline.monospacedDigit())
            .foregroundStyle(Color.dictusAccent)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.dictusAccent.opacity(0.14)))
            .accessibilityLabel(Text("\(pick.selected.count) of \(SmartModePick.maximum) selected"))
            .accessibilityIdentifier("onboarding.smartModePick.counter")
    }

    // MARK: - Cards

    private func card(for mode: SmartMode) -> some View {
        let isSelected = pick.isSelected(mode.id)
        let isEnabled = pick.canToggle(mode.id)
        return Button {
            toggle(mode.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.dictusAccent)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? Color.dictusAccent : Color.dictusBackground)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.localizedDisplayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Self.explanation(for: mode)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SelectionMark(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(selectionBackground(isSelected: isSelected, cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.smartModePick.\(mode.id)")
    }

    /// The card's one line. Keyed on the identifier, like `localizedDisplayName`, because
    /// DictusCore ships no string catalog.
    private static func explanation(for mode: SmartMode) -> Text {
        switch mode.id {
        case SmartModeCatalogue.structuredIdentifier:
            return Text("A long dictation, put in order.",
                        comment: "Onboarding Smart Mode pick: one-line explanation of the Structured mode (#677).")
        case SmartModeCatalogue.notesIdentifier:
            return Text("Your ideas as bullet points.",
                        comment: "Onboarding Smart Mode pick: one-line explanation of the List mode (#677).")
        case SmartModeCatalogue.messageIdentifier:
            return Text("A clear message, ready to send.",
                        comment: "Onboarding Smart Mode pick: one-line explanation of the Message mode (#677).")
        case SmartModeCatalogue.summaryIdentifier:
            return Text("The gist in a few sentences.",
                        comment: "Onboarding Smart Mode pick: one-line explanation of the Summary mode (#677).")
        default:
            // A mode added to `builtIns` later shows its name alone until it gets a line.
            return Text(verbatim: "")
        }
    }

    // MARK: - Translate

    private var translateGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.dictusAccent)
                Text("Translate")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            translateLine
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(SmartModePick.translateTargets(spokenLanguage: spokenLanguage), id: \.self) { target in
                    chip(for: SmartModeCatalogue.translate(to: target))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard(cornerRadius: 20)
    }

    /// "Dictate in French, get the translation", naming the language the user speaks in
    /// the interface's language.
    private var translateLine: Text {
        if let spokenLanguage,
           let name = Locale.current.localizedString(forLanguageCode: spokenLanguage) {
            return Text("Dictate in \(name), get the translation",
                        comment: "Onboarding Smart Mode pick, Translate group. The placeholder is the spoken language's name, lowercase in French (#677).")
        }
        return Text("Dictate, get the translation",
                    comment: "Onboarding Smart Mode pick, Translate group, when the spoken language is unknown (#677).")
    }

    /// One translation target. Its label is the catalogue's "→ EN", the name the fan and
    /// the mic pill's badge show, so the chip is recognisable in the keyboard later.
    private func chip(for mode: SmartMode) -> some View {
        let isSelected = pick.isSelected(mode.id)
        let isEnabled = pick.canToggle(mode.id)
        return Button {
            toggle(mode.id)
        } label: {
            Text(verbatim: mode.displayName)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule().fill(isSelected ? Color.dictusAccent : Color.dictusBackground)
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(Text(SmartModeListView.listName(for: mode)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.smartModePick.\(mode.id)")
    }

    // MARK: - Download pill

    /// "Parakeet v3 · 34 %" while the model downloads, as the mock-up draws it: this step
    /// falls within the download (decision 16), and the pill says it is still moving.
    /// Nothing once the download is over or before it starts.
    @ViewBuilder
    private var downloadPill: some View {
        if modelManager.modelStates[modelIdentifier] == .downloading,
           let model = ModelInfo.forIdentifier(modelIdentifier) {
            let fraction = Double(modelManager.downloadProgress[modelIdentifier] ?? 0)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: max(0.02, fraction))
                        .stroke(Color.dictusAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
                .animation(.easeInOut(duration: 0.3), value: fraction)

                (Text(verbatim: "\(model.displayName) · ")
                    + Text(fraction, format: .percent.precision(.fractionLength(0))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.dictusSurface))
            .accessibilityElement(children: .combine)
            .transition(.opacity)
        }
    }

    // MARK: - Actions

    private func toggle(_ identifier: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            pick.toggle(identifier)
        }
    }

    private func commit() {
        guard pick.canContinue else { return }
        pick.commit()
        PersistentLog.log(.onboardingSmartModesPicked(identifiers: pick.selected.joined(separator: ",")))
        onContinue()
    }

    // MARK: - Styling

    /// A card's background: the shell's white (or dark) card, washed with the accent and
    /// outlined in it when picked.
    private func selectionBackground(isSelected: Bool, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return shape
            .fill(Color.dictusSurface)
            .overlay(shape.fill(Color.dictusAccent.opacity(isSelected ? 0.08 : 0)))
            .overlay(shape.strokeBorder(Color.dictusAccent.opacity(isSelected ? 1 : 0), lineWidth: 2))
    }
}

/// The round mark at a card's trailing edge: an empty ring, or a blue disc with a check.
private struct SelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.dictusAccent)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}
