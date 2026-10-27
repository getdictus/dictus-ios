// DictusApp/Onboarding/VocabularyScene.swift
// The vocabulary scene: a term added to the real Vocabulary list (#680).
import SwiftUI
import DictusCore

/// The onboarding step that plays the vocabulary scene (#680, mock-up
/// `07b-scene-vocabulaire`).
struct VocabularyScenePage: View {
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void

    var body: some View {
        OnboardingScenePage(
            eyebrow: Text("Also in Pro",
                          comment: "Onboarding: small label above the title of the voice notes, vocabulary and history scenes, which come after the Smart Modes and show the other Dictus Pro features (#680)."),
            title: VocabularySceneCard.title,
            line: VocabularySceneCard.line,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) {
            VocabularySceneCard()
        }
    }
}

/// The vocabulary scene in its drawn iPhone: the onboarding page's card and the
/// vocabulary screen's "See the demo" sheet (#686).
struct VocabularySceneCard: View {
    /// The title of the onboarding step, also the title of the feature screen's "See the
    /// demo" sheet (#686): one string for both.
    static var title: Text {
        Text("Your words, spelled right",
             comment: "Onboarding vocabulary scene: title (#680).")
    }

    /// The line under the title, shared the same way. It explains the loop rather than
    /// announcing the feature (#829): keyboard corrections are learned, offered as terms,
    /// then applied to dictations.
    static var line: Text {
        Text("Correct your words in the Dictus keyboard: it learns them. Dictus suggests them for your vocabulary, on your iPhone, and adds nothing without you. After that, your dictations write them your way.",
             comment: "Onboarding vocabulary scene: the line under the title, also shown in What's New and the \"See the demo\" sheet. Explains the loop: corrections typed in the keyboard are learned, suggested as vocabulary terms (never added automatically), then applied to dictations (#680, #829).")
    }

    var body: some View {
        FeatureSceneCard(
            phoneEnd: .top,
            loopSeconds: VocabularySceneScript.loopSeconds,
            stillSeconds: VocabularySceneScript.stillSeconds
        ) { time in
            VocabularyScene(time: time)
        }
    }
}

/// The scene: the Vocabulary screen as `VocabularyListView` draws it, its editor sheet
/// (`VocabularyEditorView`) for a term typed by hand, then its suggestions sheet
/// (`VocabularySuggestionsView`) and the review sheet a suggestion's *Accept* opens
/// (`VocabularyPairReviewView`), in the order `VocabularySceneScript` plays them (#829).
///
/// WHAT IS REAL AND WHAT IS DRAWN (#649 decision 13): the screens are the app's, so they
/// repeat their sections, rows, footers and buttons with their own strings, read from the
/// same catalog keys, and the switches are SwiftUI's own `Toggle`. They are not the views
/// themselves: those read and write the user's real vocabulary and History, and a scene
/// must not touch the user's data. The navigation bars and the sheets' frames are iOS's.
///
/// Drawn for a 402 pt wide iPhone, then scaled to the card as one picture.
struct VocabularyScene: View {
    /// Seconds into the loop.
    let time: Double

    private typealias Script = VocabularySceneScript
    private typealias Target = VocabularySceneScript.Target

    /// The width the mock-ups are drawn at.
    private static let screenWidth = SmartModesSceneMetrics.screenWidth
    /// The part of the screen the card shows: its top, down to under *Analyze my
    /// transcriptions* with both new terms listed.
    static let screenHeight: CGFloat = 700

    var body: some View {
        let frame = Script.frame(at: time, term: VocabularySceneText.manualTerm)
        GeometryReader { geometry in
            screen(frame)
                .frame(width: Self.screenWidth, height: Self.screenHeight, alignment: .top)
                .clipped()
                .scaleEffect(geometry.size.width / Self.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Self.screenWidth / Self.screenHeight, contentMode: .fit)
    }

    private func screen(_ frame: Script.Frame) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                SceneNavigationBar(title: Text("Vocabulary"), leading: .back) {
                    Text("Edit")
                }
                list(frame)
                    // Its natural height: past the bottom it is clipped, never squeezed.
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.dictusBackground)

            if frame.editorIsOpen {
                Color.black.opacity(0.2)
                    .transition(.opacity)
                VocabularySceneEditor(frame: frame, time: time)
                    .padding(.top, 34)
                    .transition(.move(edge: .bottom))
            }

            if frame.suggestionsAreOpen {
                Color.black.opacity(0.2)
                    .transition(.opacity)
                VocabularySceneSuggestions(frame: frame)
                    .padding(.top, 34)
                    .transition(.move(edge: .bottom))
            }

            if frame.reviewIsOpen {
                Color.black.opacity(0.2)
                    .transition(.opacity)
                VocabularySceneReview()
                    .padding(.top, 150)
                    .transition(.move(edge: .bottom))
            }
        }
        .sceneFinger(frame.finger)
        .animation(.easeOut(duration: 0.35), value: frame.editorIsOpen)
        .animation(.easeOut(duration: 0.35), value: frame.suggestionsAreOpen)
        .animation(.easeOut(duration: 0.35), value: frame.reviewIsOpen)
        .animation(.easeInOut(duration: 0.35), value: frame.suggestionIsListed)
        .animation(.easeInOut(duration: 0.35), value: frame.manualTermIsListed)
        .animation(.easeInOut(duration: 0.35), value: frame.suggestedTermIsListed)
    }

    /// `VocabularyListView`'s list: the feature's switch, the terms, the footer, *Add a
    /// term*, then *Analyze my transcriptions* and its footer.
    private func list(_ frame: Script.Frame) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // `ProFeatureSwitchSection(feature: .vocabulary)`.
            SceneListRow {
                Text("Vocabulary")
                Spacer()
                SceneSwitch()
            }
            .sceneGroup()
            .padding(.bottom, 24)

            SceneSectionHeader(text: Text("Your terms"))
            VStack(spacing: 0) {
                ForEach(Array(entries(frame).enumerated()), id: \.element.term) { index, entry in
                    if index > 0 {
                        Divider().padding(.leading, 20)
                    }
                    termRow(entry)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .sceneGroup()
            Text("When Dictus writes one of these variants, it is replaced by your spelling.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

            SceneListRow {
                Label("Add a term", systemImage: "plus")
                    .foregroundStyle(Color.dictusAccent)
                Spacer()
            }
            .sceneGroup()
            .sceneTapTarget(Target.addTerm)
            .padding(.bottom, 24)

            SceneListRow {
                Label("Analyze my transcriptions", systemImage: "text.magnifyingglass")
                    .foregroundStyle(Color.dictusAccent)
                Spacer()
            }
            .sceneGroup()
            .sceneTapTarget(Target.analyze)
            Text("Words from your History that Dictus may be getting wrong.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// `VocabularyListView.row`: the term, *Replaces: …* under it (or *Waiting for
    /// misspellings* for a term saved without one, #819), its switch.
    private func termRow(_ entry: VocabularySceneText.Entry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.term)
                    .foregroundColor(.primary)
                if entry.variants.isEmpty {
                    Text("Waiting for misspellings")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Replaces: \(entry.variants)")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SceneSwitch()
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 60)
    }

    private func entries(_ frame: Script.Frame) -> [VocabularySceneText.Entry] {
        var entries = VocabularySceneText.entries
        if frame.manualTermIsListed { entries.append(VocabularySceneText.manualEntry) }
        if frame.suggestedTermIsListed { entries.append(VocabularySceneText.newEntry) }
        return entries
    }
}

// MARK: - Text

/// The scene's terms: two already in the list, the one typed by hand, the one the
/// suggestion adds.
enum VocabularySceneText {
    struct Entry {
        let term: String
        /// The variants line, as `VocabularyEntry.variantsLine` joins them; empty for a
        /// term saved without one.
        let variants: String
    }

    /// The two terms of mock-up 07b, proper nouns and jargon: the same in every language.
    static let entries = [
        Entry(term: "Kowalczyk", variants: "Kovalchik, Kovaltchik"),
        Entry(term: "Kubernetes", variants: "cubernetes")
    ]

    /// The term typed by hand in part 1, with no variant: a surname, the same in every
    /// language.
    static let manualTerm = "Okafor"

    static var manualEntry: Entry { Entry(term: manualTerm, variants: "") }

    /// The term the suggestion adds: the spelling typed on the keyboard.
    static let newTerm = "Dr Nguyen"

    /// What Dictus writes instead of it, in the user's language.
    static var newVariants: String {
        String(localized: "doctor Nguyen",
               comment: "Onboarding vocabulary scene: how the transcription writes the title 'Dr Nguyen' out in full, typed as the variant the term replaces (#680).")
    }

    /// In how many dictations the suggestion says Dictus wrote it that way.
    static let dictationCount = 3

    static var newEntry: Entry { Entry(term: newTerm, variants: newVariants) }
}

// MARK: - Sheets

/// A sheet's frame: the grabber, then its content on the background, rounded on top.
private struct VocabularySceneSheet<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Color.dictusBackground)
        )
    }
}

/// `VocabularyEditorView` in its sheet: *Cancel*, *New term*, *Save*, then the two fields
/// with their headers and footers. Only the first is typed in: the variant stays empty.
private struct VocabularySceneEditor: View {
    let frame: VocabularySceneScript.Frame
    /// Seconds into the loop, for the cursor's blink.
    let time: Double

    private typealias Target = VocabularySceneScript.Target

    var body: some View {
        VocabularySceneSheet {
            SceneNavigationBar(title: Text("New term"), leading: .text(Text("Cancel"))) {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundStyle(frame.canSave ? Color.dictusAccent : Color.secondary.opacity(0.6))
                    .sceneTapTarget(Target.save)
            }

            VStack(alignment: .leading, spacing: 0) {
                SceneSectionHeader(text: Text("The correct spelling"))
                field(frame.term, placeholder: Text("Which term?"), isFocused: frame.termFieldIsFocused)
                    .sceneTapTarget(Target.termField)
                footer(Text("The spelling Dictus should write."))

                SceneSectionHeader(text: Text("What Dictus writes instead"))
                    .padding(.top, 12)
                field(frame.variants, placeholder: Text("How does Dictus write it instead?"), isFocused: false)
                // `VocabularyEditorView`'s footer rule: the neutral line while a term is typed
                // with nothing it replaces (#819).
                if variantsMissing {
                    footer(Text("Optional. Without a misspelling, this term changes nothing yet. Add one when you spot it."))
                } else {
                    footer(Text("Separated by commas. Dictus replaces each of them with your spelling."))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// `VocabularyEditorView.variantsMissing`: a term the model accepts, with no variant.
    private var variantsMissing: Bool {
        VocabularyEntry(term: frame.term, variants: VocabularyEntry.variants(fromLine: frame.variants))?.hasEffect == false
    }

    private func field(_ text: String, placeholder: Text, isFocused: Bool) -> some View {
        SceneListRow {
            HStack(spacing: 1) {
                if text.isEmpty {
                    if isFocused { cursor }
                    placeholder.foregroundStyle(.tertiary)
                } else {
                    Text(verbatim: text).foregroundStyle(.primary)
                    if isFocused { cursor }
                }
            }
            Spacer(minLength: 0)
        }
        .sceneGroup()
    }

    /// The text cursor, blinking once a second like UIKit's.
    private var cursor: some View {
        Capsule()
            .fill(Color.dictusAccent)
            .frame(width: 2, height: 22)
            .opacity(time.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
    }

    private func footer(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }
}

/// `VocabularySuggestionsView` with one suggestion: a word typed on the keyboard that
/// Dictus writes differently, with *Accept* and *Ignore*. Once accepted, its empty state.
private struct VocabularySceneSuggestions: View {
    let frame: VocabularySceneScript.Frame

    private typealias Target = VocabularySceneScript.Target

    var body: some View {
        VocabularySceneSheet {
            SceneNavigationBar(title: Text("Suggestions from History"), leading: .none) {
                Text("Done")
                    .fontWeight(.semibold)
                    .sceneTapTarget(Target.done)
            }

            VStack(alignment: .leading, spacing: 0) {
                if frame.suggestionIsListed {
                    SceneSectionHeader(text: Text("Your spellings, written differently"))
                    suggestion
                        .sceneGroup()
                    Text("Accept shows the change before adding it, and lets you adjust it. Ignore hides the suggestion for good.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                } else {
                    Text("No suggestions for now. A suggestion appears here when Dictus writes one of your terms differently in at least two dictations, writes differently a word you typed on the keyboard, or when an unknown word comes back in at least two dictations.")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .sceneGroup()
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    /// `VocabularySuggestionsView.row(_: VocabularyPair, rank:)` for a learned word.
    private var suggestion: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: "1")
                .font(.dictusCaption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: VocabularySceneText.newTerm)
                    .foregroundColor(.primary)
                Text("Written as: \(VocabularySceneText.newVariants)")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                Text("In \(VocabularySceneText.dictationCount) dictations")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                Text("Typed on your keyboard, not yet a term")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                HStack(spacing: 20) {
                    Text("Accept")
                        .foregroundStyle(Color.dictusAccent)
                        .sceneTapTarget(Target.accept)
                    Text("Ignore")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 17))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

/// `VocabularyPairReviewView` for the accepted suggestion: what the change is, the term,
/// the new variant, and *Add*.
private struct VocabularySceneReview: View {
    private typealias Target = VocabularySceneScript.Target

    private var term: String { VocabularySceneText.newTerm }
    private var variant: String { VocabularySceneText.newVariants }

    var body: some View {
        VocabularySceneSheet {
            SceneNavigationBar(title: Text("Check the change"), leading: .text(Text("Cancel"))) {
                Text("Add")
                    .fontWeight(.semibold)
                    .sceneTapTarget(Target.add)
            }

            VStack(alignment: .leading, spacing: 0) {
                SceneListRow {
                    Text("New term “\(term)”, with the variant “\(variant)”.")
                        .fontWeight(.semibold)
                        .padding(.vertical, 12)
                    Spacer(minLength: 0)
                }
                .sceneGroup()
                .padding(.bottom, 20)

                SceneSectionHeader(text: Text("The correct spelling"))
                SceneListRow {
                    Text(verbatim: term)
                    Spacer(minLength: 0)
                }
                .sceneGroup()
                .padding(.bottom, 20)

                SceneSectionHeader(text: Text("What Dictus writes instead"))
                SceneListRow {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text(verbatim: variant)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                }
                .sceneGroup()
                Text("From now on, when Dictus writes “\(variant)”, it writes “\(term)” instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Grouped list pieces

// What an inset grouped `List` draws, for the scenes that show one of the app's lists
// (vocabulary) or its navigation bar (vocabulary, history).

/// A row of an inset grouped list: 17 pt text, 20 pt sides, at least 52 pt tall.
struct SceneListRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .font(.system(size: 17))
        .padding(.horizontal, 20)
        .frame(minHeight: 52)
    }
}

/// A section header of an inset grouped list, as iOS 26 draws it: sentence case, bold,
/// secondary.
struct SceneSectionHeader: View {
    let text: Text

    var body: some View {
        text
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
    }
}

/// A switch that is on, in the app's tint: SwiftUI's own, drawn and never touched.
struct SceneSwitch: View {
    var body: some View {
        Toggle("", isOn: .constant(true))
            .labelsHidden()
            .tint(.dictusAccent)
    }
}

extension View {
    /// The card of an inset grouped list section: white on light, the surface on dark.
    func sceneGroup() -> some View {
        background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.dictusSurface))
    }
}

/// An iOS 26 navigation bar: a glass button at each end and the inline title between.
struct SceneNavigationBar<Trailing: View>: View {
    /// What the leading button shows.
    enum Leading {
        /// The back chevron, in a glass circle.
        case back
        /// The close chevron of a sheet, in a glass circle.
        case close
        /// A word, in a glass capsule.
        case text(Text)
        /// Nothing: a sheet whose only button is on the trailing side.
        case none
    }

    let title: Text
    let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        ZStack {
            title
                .font(.system(size: 17, weight: .semibold))
            HStack {
                leadingButton
                Spacer()
                trailingButton
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }

    @ViewBuilder
    private var leadingButton: some View {
        switch leading {
        case .back:
            glassCircle("chevron.left")
        case .close:
            glassCircle("chevron.down")
        case .text(let text):
            text
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .dictusGlass(in: Capsule())
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if Trailing.self != EmptyView.self {
            trailing
                .font(.system(size: 17))
                .foregroundStyle(Color.dictusAccent)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .dictusGlass(in: Capsule())
        }
    }

    private func glassCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .dictusGlass(in: Circle())
    }
}

extension SceneNavigationBar where Trailing == EmptyView {
    init(title: Text, leading: Leading) {
        self.init(title: title, leading: leading) { EmptyView() }
    }
}
