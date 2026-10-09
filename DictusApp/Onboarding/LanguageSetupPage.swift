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
        OnboardingPage(
            title: Text("Your language"),
            subtitle: Text("Your iPhone's language, already selected. You can change it later in Settings.")
        ) {
            VStack(alignment: .leading, spacing: 0) {
                languageCard
                    .padding(.bottom, 28)

                OnboardingSectionLabel(text: Text("Keyboard layout"))
                    .padding(.leading, 4)
                    .padding(.bottom, 8)

                Picker("Layout", selection: $setup.layout) {
                    ForEach(LayoutType.allCases, id: \.self) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 12)

                LayoutPreview(layout: setup.layout)
                    .padding(.bottom, 24)

                modelLine
            }
        } bottom: {
            OnboardingPrimaryButton(Text("Continue")) {
                onConfirm(setup)
            }
            .accessibilityIdentifier("onboarding.primary")
        }
    }

    // MARK: - Language card

    /// The language the user speaks, with the keyboard that goes with it, in one white card
    /// (#675 mock-up `02-langue-et-clavier`). "Change" opens the same pickers the screen
    /// had before the shell (#649 PR A), as menus.
    private var languageCard: some View {
        VStack(spacing: 0) {
            languageRow(
                code: setup.spokenLanguage,
                name: Self.name(of: setup.spokenLanguage),
                role: setup.spokenLanguageHasDictusKeyboard
                    ? Text("Dictation and keyboard")
                    : Text("Dictation")
            ) {
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
            }

            // Only for a spoken language without a Dictus keyboard (Chinese, Italian…):
            // the keyboard then has to be one of the four, and the user picks which.
            if !setup.spokenLanguageHasDictusKeyboard {
                Divider()
                    .padding(.leading, 76)
                languageRow(
                    code: setup.keyboardLanguage.rawValue,
                    name: setup.keyboardLanguage.displayName,
                    role: Text("Keyboard")
                ) {
                    Picker("Keyboard", selection: keyboardLanguageBinding) {
                        ForEach(SupportedLanguage.allCases, id: \.rawValue) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }
                Text("Dictus has no keyboard in this language yet. Choose the language you type in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    // Without this the caption can collapse to one truncated line (seen
                    // on the simulator before the shell).
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .onboardingCard()
    }

    /// One row of the language card: a round code badge, the language and what it is used
    /// for, and "Change", a menu holding `picker`.
    private func languageRow<Choices: View>(
        code: String,
        name: String,
        role: Text,
        @ViewBuilder picker: () -> Choices
    ) -> some View {
        HStack(spacing: 16) {
            Text(verbatim: code.uppercased())
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.dictusAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.dictusAccent.opacity(0.12)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                role
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Menu {
                picker()
            } label: {
                Text("Change")
                    .font(.body)
                    .foregroundStyle(Color.dictusAccent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
    ///
    /// WHY "your language" and not the language's name: French needs an article that
    /// changes with the language ("le français", "l'anglais"), which a format string cannot
    /// choose.
    private var modelLine: some View {
        let info = ModelInfo.forIdentifier(setup.recommendedModel(on: capabilities))
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cpu")
                .font(.body)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Group {
                if let info {
                    // Both arguments arrive already localized (name qualifier #665, size
                    // unit #661).
                    Text("\(info.localizedDisplayName) model, the best for your language on this iPhone. \(info.sizeLabel), downloaded as soon as you continue. You can change it in Models.")
                } else {
                    Text("The best voice model for your language and iPhone. It downloads while you finish setting up, and you can change it in Models.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Layout preview

/// The top of the keyboard in the chosen layout, cropped like the mock-up's: enough rows to
/// tell AZERTY from QWERTY from QWERTZ at a glance, without drawing a whole keyboard.
///
/// WHY THE ROWS ARE WRITTEN HERE FOR AZERTY ONLY: QWERTY and QWERTZ come from DictusCore,
/// where the keyboard reads them too. AZERTY's rows live in the keyboard extension
/// (`KeyboardLayouts`), which the app cannot import; the first two and a half rows are
/// all this preview shows, and they are the French layout's fixed letters.
private struct LayoutPreview: View {
    let layout: LayoutType

    /// Height of the visible crop: two rows and the top of the third.
    private let visibleHeight: CGFloat = 126

    private var rows: [[String]] {
        switch layout {
        case .azerty:
            return [
                ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
                ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
                ["w", "x", "c", "v", "b", "n"]
            ]
        case .qwerty:
            return QWERTYLayout.lettersRows.prefix(3).map { row in row.map { $0.lowercased() } }
        case .qwertz:
            return QWERTZLayout.lowercasedLettersRows
        }
    }

    var body: some View {
        GeometryReader { geometry in
            // Every key is as wide as one key of the longest row, and shorter rows are
            // centred, as on the real keyboard.
            let spacing: CGFloat = 5
            let longest = CGFloat(rows.map(\.count).max() ?? 10)
            let keyWidth = (geometry.size.width - 12 - spacing * (longest - 1)) / longest
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, letter in
                            Text(verbatim: letter)
                                .font(.system(size: 18))
                                .foregroundStyle(.primary)
                                .frame(width: keyWidth, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Self.keyFill)
                                        .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                                )
                        }
                    }
                }
            }
            .frame(width: geometry.size.width)
            .padding(.top, 12)
        }
        .frame(height: visibleHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Self.trayFill)
        // Cropped at the bottom: rounded on top only, cut straight across below.
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: layout)
        .accessibilityHidden(true)
    }

    /// The tray behind the keys: the card colour, like the mock-up.
    private static let trayFill = Color.dictusSurface

    /// The keys: a light grey on the white tray, a lifted navy on the dark one.
    private static let keyFill = Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x0A1628))
}
