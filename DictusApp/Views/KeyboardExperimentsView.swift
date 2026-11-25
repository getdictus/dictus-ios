// DictusApp/Views/KeyboardExperimentsView.swift
// Settings › Keyboard › Experiments: keyboard features under test, off by default, test builds only.
import SwiftUI
import DictusCore

/// The switches for keyboard features still being measured.
///
/// Reached only from `KeyboardSettingsView`, and only when
/// `KeyboardFeatureSettings.isExperimentsPageVisible` is true (Debug, TestFlight). Each
/// switch takes its key from `SharedKeys` and its default from
/// `KeyboardFeatureSettings.Defaults`; the one rule between them, adaptive touch acting
/// only on top of spatial autocorrect, is the type's `isAdaptiveTouchEffective`.
struct KeyboardExperimentsView: View {

    @AppStorage(SharedKeys.language, store: UserDefaults(suiteName: AppGroup.identifier))
    private var language = "fr"

    @AppStorage(SharedKeys.keyboardSpatialAutocorrect, store: UserDefaults(suiteName: AppGroup.identifier))
    private var spatialAutocorrect = KeyboardFeatureSettings.Defaults.spatialAutocorrect

    @AppStorage(SharedKeys.keyboardAdaptiveTouch, store: UserDefaults(suiteName: AppGroup.identifier))
    private var adaptiveTouch = KeyboardFeatureSettings.Defaults.adaptiveTouch

    @AppStorage(SharedKeys.keyboardBilingualAutocorrect, store: UserDefaults(suiteName: AppGroup.identifier))
    private var bilingualAutocorrect = KeyboardFeatureSettings.Defaults.bilingualAutocorrect

    @AppStorage(SharedKeys.keyboardSwipeTyping, store: UserDefaults(suiteName: AppGroup.identifier))
    private var swipeTyping = KeyboardFeatureSettings.Defaults.swipeTyping

    @AppStorage(SharedKeys.keyboardSwipeTrail, store: UserDefaults(suiteName: AppGroup.identifier))
    private var swipeTrail = KeyboardFeatureSettings.Defaults.swipeTrail

    /// Bumped when the partner picker writes. The partner is read through
    /// `KeyboardFeatureSettings.partnerLanguage(for:)`, which resolves a missing or
    /// colliding value to a default, so it is not an `@AppStorage` and redraws nothing by
    /// itself; same pattern as `layoutRevision` on the Keyboard page.
    @State private var partnerRevision = 0

    private var keyboardLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: language) ?? .french
    }

    /// The bilingual partner, among the languages other than the keyboard's own. The type
    /// already reads a stored partner equal to the keyboard language as the default one.
    private var partnerLanguage: Binding<SupportedLanguage> {
        let primary = keyboardLanguage
        return Binding(
            get: {
                _ = partnerRevision
                return KeyboardFeatureSettings().partnerLanguage(for: primary)
            },
            set: { newValue in
                KeyboardFeatureSettings().setPartnerLanguage(newValue)
                partnerRevision += 1
            }
        )
    }

    private var partnerChoices: [SupportedLanguage] {
        SupportedLanguage.allCases.filter { $0 != keyboardLanguage }
    }

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Toggle("Spatial autocorrect", isOn: $spatialAutocorrect)
                    .accessibilityIdentifier("settings.keyboard.experiments.spatialAutocorrect")
            } header: {
                Text("Off by default. These features can change or disappear.")
                    .textCase(nil)
            } footer: {
                Text("Corrects a word from where your fingers landed on the keys, not only from the letters typed. French, English and Spanish only.")
            }

            adaptiveTouchSection
            bilingualSection
            swipeTypingSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Experiments")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    /// Greyed while spatial autocorrect is off: adaptive touch moves the key centres the
    /// spatial decoder reads, and without the decoder it acts on nothing. The switch keeps
    /// the user's choice either way; the line under it says when that choice is idle.
    private var adaptiveTouchSection: some View {
        Section {
            Toggle("Adaptive touch", isOn: $adaptiveTouch)
                .disabled(!spatialAutocorrect)
                .accessibilityIdentifier("settings.keyboard.experiments.adaptiveTouch")

            // TODO(adaptive touch): a learning status line ("N taps learned" / "in use")
            // and a "Reset touch learning" button belong here. DictusCore on develop has no
            // API for either: the learner, its file and its reset (`AdaptiveTouchStore`,
            // the `adaptiveTouch.resetAt` stamp) arrive with #1018, not merged. Wire both
            // here once it lands.
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if adaptiveTouch && !KeyboardFeatureSettings.isAdaptiveTouchEffective(
                    adaptiveTouch: adaptiveTouch, spatialAutocorrect: spatialAutocorrect
                ) {
                    Text("Inactive: turn on spatial autocorrect for adaptive touch to work.")
                } else if !spatialAutocorrect {
                    Text("Turn on spatial autocorrect first.")
                }
                Text("Learns where you actually tap each key, and reads your taps with those positions. Stays on this \(DeviceNoun.current).")
            }
        }
    }

    private var bilingualSection: some View {
        Section {
            Toggle("Bilingual autocorrect", isOn: $bilingualAutocorrect)
                .accessibilityIdentifier("settings.keyboard.experiments.bilingualAutocorrect")

            Picker("Second language", selection: partnerLanguage) {
                ForEach(partnerChoices, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .disabled(!bilingualAutocorrect)
            .accessibilityIdentifier("settings.keyboard.experiments.partnerLanguage")
        } footer: {
            Text("Corrects and suggests in your keyboard language and a second one at the same time, without switching keyboards. French and English only for now.")
        }
    }

    private var swipeTypingSection: some View {
        Section {
            Toggle("Swipe typing", isOn: $swipeTyping)
                .accessibilityIdentifier("settings.keyboard.experiments.swipeTyping")

            // On by default, but the trail only ever draws while swipe typing is on.
            Toggle("Show swipe trail", isOn: $swipeTrail)
                .disabled(!swipeTyping)
                .accessibilityIdentifier("settings.keyboard.experiments.swipeTrail")
        } footer: {
            Text("Slide your finger from letter to letter to type a word, then lift it. The trail draws the path under your finger.")
        }
    }
}
