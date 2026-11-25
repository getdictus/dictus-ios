// DictusApp/Views/KeyboardSettingsView.swift
// Settings › Keyboard: layout, typing, feedback, learned words, and the test builds' Experiments row.
import SwiftUI
import DictusCore

/// The keyboard's settings page, opened from the one Keyboard row in Settings.
///
/// WHY its own page: the Keyboard section had grown to nine rows of four different
/// kinds (shape of the grid, what typing does, what a key press sounds and feels
/// like, the learned-words dictionary), plus two rows that were about dictation.
/// Grouped here by kind, with the dictation rows back in Transcription.
///
/// The keyboard features that ship behind a switch take their key from `SharedKeys` and
/// their default from `KeyboardFeatureSettings.Defaults`, never from a literal here: that
/// type owns the defaults, so this page and the keyboard cannot disagree about what
/// "never touched" means. `@AppStorage` rather than the type's properties so the toggles
/// redraw on change, which is the split `KeyboardFeatureSettings` documents.
struct KeyboardSettingsView: View {

    // MARK: - Preferences (App Group persisted)

    @AppStorage(SharedKeys.language, store: UserDefaults(suiteName: AppGroup.identifier))
    private var language = "fr"

    @AppStorage(SharedKeys.hapticsEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var hapticsEnabled = true

    /// Persistent digit row above the letter rows (#331). Off by default: it makes the
    /// keyboard a fifth taller, and nobody's keyboard may change shape on update.
    @AppStorage(SharedKeys.numberRowEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var numberRowEnabled = false

    /// WHY default true: most users expect autocorrect to be active by default.
    @AppStorage(SharedKeys.autocorrectEnabled, store: UserDefaults(suiteName: AppGroup.identifier))
    private var autocorrectEnabled = true

    /// Slide left from Delete to erase word by word (#609). On by default (Pierre,
    /// 2026-11-24), a default `KeyboardFeatureSettings` owns.
    @AppStorage(SharedKeys.keyboardDeleteWordSwipe, store: UserDefaults(suiteName: AppGroup.identifier))
    private var deleteWordSwipe = KeyboardFeatureSettings.Defaults.deleteWordSwipe

    /// Bumped whenever the Layout picker writes, to re-evaluate the body. Since #272 the
    /// layout is stored per keyboard language, so there is no single key to observe.
    @State private var layoutRevision = 0

    /// Confirmation dialog for resetting the learned-words dictionary (#222).
    @State private var showResetDictionaryConfirmation = false

    private var keyboardLanguage: SupportedLanguage {
        SupportedLanguage(rawValue: language) ?? .french
    }

    /// The Layout picker's selection: the layout of the keyboard language selected above
    /// it (#272). Changing the language runs neither accessor, which is the point: the
    /// language no longer overwrites the layout.
    private var layoutSelection: Binding<LayoutType> {
        let selectedLanguage = keyboardLanguage
        return Binding(
            get: {
                _ = layoutRevision
                return KeyboardLayoutPreference.layout(for: selectedLanguage)
            },
            set: { newLayout in
                KeyboardLayoutPreference.setLayout(newLayout, for: selectedLanguage)
                layoutRevision += 1
            }
        )
    }

    // MARK: - Body

    var body: some View {
        List {
            layoutSection
            typingSection
            feedbackSection
            learnedWordsSection

            // Test builds only (Debug, TestFlight): `isExperimentsPageVisible` reads the
            // binary's `BuildChannel`, cached at launch. The App Store build has no row and
            // no way into the page.
            if KeyboardFeatureSettings().isExperimentsPageVisible {
                Section {
                    NavigationLink("Experiments") {
                        KeyboardExperimentsView()
                    }
                    .accessibilityIdentifier("settings.keyboard.experiments")
                } footer: {
                    Text("Keyboard features still being tested, off by default. Only in test versions of Dictus.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Keyboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    /// The shape of the key grid: which language's keys, in which order, with or
    /// without digits on top.
    private var layoutSection: some View {
        Section {
            // Drives layout, key labels, and the autocorrect/prediction dictionaries.
            // Since #226 it no longer drives transcription by itself.
            Picker("Keyboard language", selection: $language) {
                ForEach(SupportedLanguage.allCases, id: \.rawValue) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }
            .onChange(of: language) { _, newLang in
                // The layout is NOT touched here (#272). Routing through activate()
                // keeps the legacy mirror in step; @AppStorage already stored the value.
                if let lang = SupportedLanguage(rawValue: newLang) {
                    SupportedLanguage.activate(lang)
                }
            }

            Picker("Layout", selection: layoutSelection) {
                ForEach(LayoutType.allCases, id: \.self) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }

            // Applies to every layout and keyboard language: a number row is a
            // hardware habit, not a language one (#331).
            Toggle("Number row", isOn: $numberRowEnabled)
        } header: {
            Text("Layout")
        } footer: {
            // The keyboard drops the row in landscape (#331) and on iPad (#336); without
            // a word here either one reads as a bug. One sentence true on both, because
            // this target has no device detection: DeviceKit is linked to the keyboard only.
            if numberRowEnabled {
                Text("The number row is shown on iPhone in portrait only.")
            }
        }
    }

    /// What typing does to the text: autocorrect, then the shipped typing features,
    /// each with its own parameters under it.
    private var typingSection: some View {
        Section {
            Toggle("Autocorrect", isOn: $autocorrectEnabled)

            Toggle("Swipe to delete words", isOn: $deleteWordSwipe)
                .accessibilityIdentifier("settings.keyboard.deleteWordSwipe")
        } header: {
            Text("Typing")
        } footer: {
            Text("Slide left from the delete key to erase word by word. Slide back to bring the words back before lifting your finger.")
        }
    }

    /// What a key press feels and sounds like.
    private var feedbackSection: some View {
        Section {
            Toggle("Haptic feedback", isOn: $hapticsEnabled)

            NavigationLink("Sounds") {
                SoundSettingsView()
            }
        } header: {
            Text("Feedback")
        }
    }

    /// The learned-words dictionary (#222). Words learned by the keyboard bypass
    /// autocorrect forever, so the user needs a way to recover from accidental learning.
    private var learnedWordsSection: some View {
        Section {
            Button("Reset learned words", role: .destructive) {
                // Sync from App Group first: words learned by the keyboard process since
                // app launch aren't in this process's cache.
                UserDictionary.shared.reload()
                showResetDictionaryConfirmation = true
            }
            .confirmationDialog(
                "Reset learned words?",
                isPresented: $showResetDictionaryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Forget \(UserDictionary.shared.count) learned words", role: .destructive) {
                    UserDictionary.shared.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Words the keyboard learned from your typing will be forgotten and autocorrect will apply to them again.")
            }
        } header: {
            Text("Learned words")
        }
    }
}
