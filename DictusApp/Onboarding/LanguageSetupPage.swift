// DictusApp/Onboarding/LanguageSetupPage.swift
// Onboarding step: the language the user speaks, the keyboard that goes with it, and the
// model that will be downloaded for it (#649).
import SwiftUI
import DictusCore

/// The language screen: spoken language, keyboard language and layout, in one tap for most
/// users.
///
/// WHY THIS SCREEN EXISTS (#649): before it, the keyboard language defaulted to French for
/// everyone, so an English or German user started on a French AZERTY keyboard, and the
/// recommended model depended on the device only, so a Chinese speaker was handed Parakeet,
/// which does not speak Chinese. The language decides both, so it is asked first.
///
/// WHY PREFILLED: the iPhone's own language is the right answer for almost everyone, so
/// the screen opens on it and "Continue" is the whole interaction.
///
/// WHY NO MODEL CHOICE: offered a choice, users take the lightest model instead of the
/// best one (#649 decision 4). The screen names the model and its size, in small type,
/// and says where it can be changed later. Nothing about it blocks.
///
/// WHY THE RULES ARE NOT HERE: which keyboard and layout follow a spoken language, and
/// which transcription mode that implies, live in `LanguageSetup` in DictusCore, where
/// they are unit-tested. This view only binds to it.
///
/// Confirming hands the setup to `OnboardingView`, which writes it and starts the model
/// download before moving on.
struct LanguageSetupPage: View {
    let onConfirm: (LanguageSetup) -> Void

    /// The iPhone's preferred languages, read once: they cannot change while this screen
    /// is up, and the setup's rules take them as an input.
    private let preferredLanguages = Locale.preferredLanguages

    /// The device, read once for the model line. Same reasoning.
    private let capabilities = DeviceCapabilities.current()

    @State private var setup: LanguageSetup

    init(onConfirm: @escaping (LanguageSetup) -> Void) {
        self.onConfirm = onConfirm
        // `KeyboardLayoutPreference.layout(for:)` rather than `defaultLayout`: a user who
        // runs the onboarding again keeps the layout they already chose for a language.
        _setup = State(initialValue: LanguageSetup.prefilled(
            preferredLanguages: Locale.preferredLanguages,
            layoutFor: { KeyboardLayoutPreference.layout(for: $0) }
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 72))
                .foregroundColor(.dictusAccent)
                .padding(.bottom, 24)

            Text("Your language")
                .font(.dictusHeading)
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            Text("Dictus sets up the keyboard and the voice model for the language you speak.")
                .font(.dictusBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            languageCard
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            Text("You can change this later in Settings.")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            modelLine
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            // Same button style as the other onboarding pages (a RoundedRectangle, not
            // `.borderedProminent`, which renders as a capsule on iOS 26 Liquid Glass).
            Button {
                onConfirm(setup)
            } label: {
                Text("Continue")
                    .font(.dictusSubheading)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.dictusAccent)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Language card

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("I speak")
                    .font(.dictusBody)
                Spacer()
                Picker("I speak", selection: spokenLanguageBinding) {
                    // The four languages Dictus has a keyboard for first: they are the
                    // ones most users pick, and the ones where everything works.
                    Section("Dictus keyboards") {
                        ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                            Text(Self.name(of: language.rawValue)).tag(language.rawValue)
                        }
                    }
                    Section("Other languages") {
                        ForEach(otherSpokenLanguages, id: \.self) { code in
                            Text(Self.name(of: code)).tag(code)
                        }
                    }
                }
                .pickerStyle(.menu)
                .tint(.dictusAccent)
            }

            // Only for a spoken language without a Dictus keyboard (Chinese, Italian…):
            // the keyboard then has to be one of the four, and the user picks which.
            if !setup.spokenLanguageHasDictusKeyboard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Keyboard")
                            .font(.dictusBody)
                        Spacer()
                        Picker("Keyboard", selection: keyboardLanguageBinding) {
                            ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.dictusAccent)
                    }
                    Text("Dictus has no keyboard in this language yet. Choose the language you type in.")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)
                        // Without this the card's leading-aligned stack lets the caption
                        // collapse to one truncated line (seen on the simulator).
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Picker("Layout", selection: $setup.layout) {
                ForEach(LayoutType.allCases, id: \.self) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dictusGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    /// Writes go through `LanguageSetup` so the keyboard language and the layout follow
    /// the spoken language instead of being left on the previous one.
    private var spokenLanguageBinding: Binding<String> {
        Binding(
            get: { setup.spokenLanguage },
            set: { code in
                setup.setSpokenLanguage(
                    code,
                    preferredLanguages: preferredLanguages,
                    layoutFor: { KeyboardLayoutPreference.layout(for: $0) }
                )
            }
        )
    }

    private var keyboardLanguageBinding: Binding<SupportedLanguage> {
        Binding(
            get: { setup.keyboardLanguage },
            set: { language in
                setup.setKeyboardLanguage(language, layoutFor: { KeyboardLayoutPreference.layout(for: $0) })
            }
        )
    }

    /// Every other language a model can transcribe, alphabetical in the reader's language.
    private var otherSpokenLanguages: [String] {
        let keyboardCodes = Set(SupportedLanguage.allCases.map(\.rawValue))
        return SpokenLanguage.selectableCodes
            .filter { !keyboardCodes.contains($0) }
            .sorted { Self.name(of: $0).localizedStandardCompare(Self.name(of: $1)) == .orderedAscending }
    }

    /// A language's name in the app's current language ("Chinese" / "chinois"), capitalised
    /// for a list. Falls back to the code for the rare one `Locale` cannot name.
    private static func name(of code: String) -> String {
        guard let name = Locale.current.localizedString(forLanguageCode: code) else { return code }
        return name.capitalized(with: Locale.current)
    }

    // MARK: - Model line

    /// The model that will be downloaded, in small type. Informs; asks nothing.
    private var modelLine: some View {
        let info = ModelInfo.forIdentifier(setup.recommendedModel(on: capabilities))
        return VStack(spacing: 4) {
            if let info {
                // Verbatim: a model name and a size are not words to translate, and an
                // interpolated key would put a meaningless "%@ · %@" in the catalog.
                Label {
                    Text(verbatim: "\(info.displayName) · \(info.sizeLabel)")
                } icon: {
                    Image(systemName: "waveform")
                }
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
            }
            Text("The best voice model for your language and iPhone. It downloads while you finish setting up, and you can change it in Models.")
                .font(.dictusCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
}
