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
            title: Text("Your words, spelled right",
                        comment: "Onboarding vocabulary scene: title (#680)."),
            line: Text("Note a name and the way Dictus gets it wrong. Next time, it will write it your way.",
                       comment: "Onboarding vocabulary scene: the line under the title (#680)."),
            phoneEnd: .top,
            loopSeconds: VocabularySceneScript.loopSeconds,
            stillSeconds: VocabularySceneScript.stillSeconds,
            modelManager: modelManager,
            modelIdentifier: modelIdentifier,
            onNext: onNext
        ) { time in
            VocabularyScene(time: time)
        }
    }
}

/// The scene: the Vocabulary screen as `VocabularyListView` draws it, with its editor
/// sheet (`VocabularyEditorView`) coming up for a new term (`VocabularySceneScript`).
///
/// WHAT IS REAL AND WHAT IS DRAWN (#649 decision 13): the screen is the app's, so it
/// repeats the list's sections, rows, footer and button with their own strings, read from
/// the same catalog keys, and the switches are SwiftUI's own `Toggle`. It is not the view
/// itself: `VocabularyListView` reads and writes the user's real vocabulary, and a scene
/// must not touch the user's data. The navigation bar and the sheet's frame are iOS's.
///
/// Drawn for a 402 pt wide iPhone, then scaled to the card as one picture.
struct VocabularyScene: View {
    /// Seconds into the loop.
    let time: Double

    private typealias Script = VocabularySceneScript
    private typealias Target = VocabularySceneScript.Target

    /// The width the mock-ups are drawn at.
    private static let screenWidth = SmartModesSceneMetrics.screenWidth
    /// The part of the screen the card shows: its top, down to under *Add a term*.
    static let screenHeight: CGFloat = 560

    var body: some View {
        let frame = Script.frame(at: time, term: VocabularySceneText.newTerm, variants: VocabularySceneText.newVariants)
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
        }
        .sceneFinger(frame.finger)
        .animation(.easeOut(duration: 0.35), value: frame.editorIsOpen)
        .animation(.easeInOut(duration: 0.35), value: frame.newTermIsListed)
    }

    /// `VocabularyListView`'s list: the feature's switch, the terms, the footer, *Add a term*.
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// `VocabularyListView.row`: the term, *Replaces: …* under it, its switch.
    private func termRow(_ entry: VocabularySceneText.Entry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.term)
                    .foregroundColor(.primary)
                Text("Replaces: \(entry.variants)")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SceneSwitch()
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 60)
    }

    private func entries(_ frame: Script.Frame) -> [VocabularySceneText.Entry] {
        frame.newTermIsListed ? VocabularySceneText.entries + [VocabularySceneText.newEntry] : VocabularySceneText.entries
    }
}

// MARK: - Text

/// The scene's terms: two already in the list, the one the finger adds.
enum VocabularySceneText {
    struct Entry {
        let term: String
        /// The variants line, as `VocabularyEntry.variantsLine` joins them.
        let variants: String
    }

    /// The two terms of mock-up 07b, proper nouns and jargon: the same in every language.
    static let entries = [
        Entry(term: "Kowalczyk", variants: "Kovalchik, Kovaltchik"),
        Entry(term: "Kubernetes", variants: "cubernetes")
    ]

    /// The term the finger adds.
    static let newTerm = "Dr Nguyen"

    /// What Dictus writes instead of it, in the user's language.
    static var newVariants: String {
        String(localized: "doctor Nguyen",
               comment: "Onboarding vocabulary scene: how the transcription writes the title 'Dr Nguyen' out in full, typed as the variant the term replaces (#680).")
    }

    static var newEntry: Entry { Entry(term: newTerm, variants: newVariants) }
}

// MARK: - Editor

/// `VocabularyEditorView` in its sheet: *Cancel*, *New term*, *Save*, then the two fields
/// with their headers and footers, typed by the finger.
private struct VocabularySceneEditor: View {
    let frame: VocabularySceneScript.Frame
    /// Seconds into the loop, for the cursor's blink.
    let time: Double

    private typealias Target = VocabularySceneScript.Target

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            SceneNavigationBar(title: Text("New term"), leading: .text(Text("Cancel"))) {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundStyle(frame.canSave ? Color.dictusAccent : Color.secondary.opacity(0.6))
                    .sceneTapTarget(Target.save)
            }

            VStack(alignment: .leading, spacing: 0) {
                SceneSectionHeader(text: Text("The correct spelling"))
                field(frame.term, placeholder: Text("Which term?"), isFocused: frame.focusedField == .termField)
                    .sceneTapTarget(Target.termField)
                footer(Text("The spelling Dictus should write."), isWarning: false)

                SceneSectionHeader(text: Text("What Dictus writes instead"))
                    .padding(.top, 12)
                field(frame.variants, placeholder: Text("How does Dictus write it instead?"),
                      isFocused: frame.focusedField == .variantsField)
                    .sceneTapTarget(Target.variantsField)
                // `VocabularyEditorView`'s footer rule: the orange line while a term is typed
                // with nothing it replaces (#536).
                if variantsMissing {
                    footer(Text("Add at least one. A term on its own changes nothing Dictus writes."), isWarning: true)
                } else {
                    footer(Text("Separated by commas. Dictus replaces each of them with your spelling."), isWarning: false)
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                .fill(Color.dictusBackground)
        )
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

    private func footer(_ text: Text, isWarning: Bool) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(isWarning ? Color.orange : Color.secondary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
