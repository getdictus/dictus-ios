// DictusApp/Onboarding/GlobeKeyTutorialPage.swift
// Onboarding step: the first dictation through the globe key, in three states (#678).
import SwiftUI
import UIKit
import DictusCore

/// The first dictation: the user taps a real text field, switches to the Dictus keyboard
/// with the globe long-press, and dictates. The text landing in the field ends the step.
///
/// THE THREE STATES (#649 decision 1.8, #678), from `FirstDictationStage`:
/// 1. Before the field is tapped: no keyboard. Under the field, a looping drawn card shows a
///    finger long-pressing the globe, the keyboard menu opening and Dictus being chosen.
/// 2. Apple's keyboard is up: a banner just above it, *Long-press the globe, then Dictus*.
/// 3. Dictus's keyboard is up: the banner points at the blue mic.
///
/// WHY EVERY HINT SITS ABOVE THE KEYBOARD: the app cannot draw over a system keyboard. The
/// banner is the last view of the page, and the page ends at the keyboard's top edge (the
/// keyboard safe area), so it can only ever be above it. Nothing is overlaid.
///
/// WHY THE FIELD IS NOT FOCUSED FOR THE USER ANY MORE: before #678 the page raised the
/// keyboard on appear, which skipped what state 1 teaches. Tapping the field is now the
/// first gesture of the lesson.
struct GlobeKeyTutorialPage: View {
    /// Called once the field holds a dictation (or, pre-A14, typed words). `OnboardingView`
    /// resets the dictation coordinator and moves on to the completion step (#675); its
    /// shell's Skip does the same without a dictation.
    let onComplete: () -> Void

    @State private var isFieldFocused = false
    @State private var isDictusKeyboard = false
    @State private var textFieldContent = ""

    /// Latched the first time the Dictus keyboard is up: the completion rule counts text
    /// only from then on (`FirstDictationStage.completes`), as the page did before #678.
    @State private var hasSeenDictusKeyboard = false

    /// Guard against multiple auto-advance triggers.
    @State private var hasAutoAdvanced = false

    /// Set when enough text has landed: drives `successCue` until the page moves on.
    @State private var showSuccessCue = false

    /// The stage shown once the text has landed, so the keyboard closing on the way out
    /// does not bring back state 1's card for the last fraction of a second.
    @State private var frozenStage: FirstDictationStage?

    /// Whether the keyboard can dictate on this device (#635). False on a pre-A14
    /// chip, where the Dictus keyboard draws its mic disabled everywhere, this page's
    /// text field included: the keyboard cannot tell that its host is DictusApp in
    /// the foreground, so it has no safe way to make an exception here. The page then
    /// asks for typing instead, and the same 3-character rule advances it.
    private let keyboardCanDictate = DeviceCapabilities.current().supportsKeyboardDictation

    private var stage: FirstDictationStage {
        frozenStage ?? FirstDictationStage(isFieldFocused: isFieldFocused, isDictusKeyboard: isDictusKeyboard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: Text("Try it now"), subtitle: instruction)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.top, OnboardingMetrics.titleTopPadding)
                .padding(.bottom, 20)

            field
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)

            switch stage {
            case .beforeTap:
                // State 1: no keyboard yet, the drawn loop fills the place it will take.
                GlobeLongPressCard()
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .otherKeyboard, .dictusKeyboard:
                // States 2 and 3: the banner, right above the keyboard.
                FirstDictationBanner(content: bannerContent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.vertical, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .onChange(of: textFieldContent) { newValue in
            // Auto-advance when the user has dictated enough text (`FirstDictationStage`:
            // 3 characters, once the Dictus keyboard has been up).
            guard !hasAutoAdvanced,
                  FirstDictationStage.completes(text: newValue, hasSeenDictusKeyboard: hasSeenDictusKeyboard)
            else { return }
            hasAutoAdvanced = true
            frozenStage = stage
            PersistentLog.log(.onboardingGlobeTutorialTextDetected)
            // WHY 0.6 s AND A CUE (decided 2026-10-09): the fixed 1.5 s wait read as
            // "something is loading" on device. The field now turns green with a check
            // the moment the text lands, and the page leaves about 0.6 s later
            // (0.4 s here, then the 0.2 s keyboard dismissal in `advanceToSuccess`).
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showSuccessCue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                advanceToSuccess()
            }
        }
    }

    // MARK: - Field

    /// The real text field, on a card, outlined in blue while it has the keyboard.
    ///
    /// WHY frame minHeight + maxHeight .infinity: the field takes the height the hint
    /// leaves it, which is everything above the keyboard once one is up. The UITextView
    /// scrolls internally if the dictation is longer than that.
    private var field: some View {
        KeyboardDetectingTextField(
            text: $textFieldContent,
            placeholder: placeholder,
            onFocusChange: { focused in
                guard frozenStage == nil else { return }
                isFieldFocused = focused
            },
            onKeyboardChange: { isDictus in
                guard frozenStage == nil else { return }
                isDictusKeyboard = isDictus
                if isDictus && !hasSeenDictusKeyboard {
                    hasSeenDictusKeyboard = true
                    PersistentLog.log(.onboardingDictusKeyboardActivated)
                }
            }
        )
        .accessibilityIdentifier("onboarding.firstDictation.field")
        .frame(minHeight: 88, maxHeight: .infinity)
        .padding(16)
        .onboardingCard(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFieldFocused ? Color.dictusAccent : Color.primary.opacity(0.08),
                    lineWidth: isFieldFocused ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .overlay { successCue }
        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
    }

    /// The "it worked" cue on the text field, shown between the text landing and the page
    /// moving on: a green outline and a check in its corner, in the app's success colour,
    /// the same check the keyboard and microphone steps use for "detected" and "authorized".
    private var successCue: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.dictusSuccess, lineWidth: 2)
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, Color.dictusSuccess)
                .padding(10)
                .scaleEffect(showSuccessCue ? 1 : 0.4)
        }
        .opacity(showSuccessCue ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Copy

    /// What to do now, under the title. Changes with the stage and, on a pre-A14 chip, asks
    /// for typing instead of dictating (#635).
    private var instruction: Text {
        switch stage {
        case .beforeTap:
            return keyboardCanDictate
                ? Text("Tap the field, switch to the Dictus keyboard, then dictate whatever you like.")
                : Text("Tap the field, switch to the Dictus keyboard, then type a few words.")
        case .otherKeyboard:
            return Text("Long-press the globe, then choose Dictus.")
        case .dictusKeyboard:
            return keyboardCanDictate
                ? Text("Tap the blue mic and speak. The text lands here.")
                : Text("Type a few words to try the keyboard")
        }
    }

    /// The field's placeholder: an invitation to tap it, then what to put in it.
    private var placeholder: String {
        if stage == .beforeTap {
            return String(localized: "Tap here to write")
        }
        return keyboardCanDictate
            ? String(localized: "Say something…")
            : String(localized: "Type something…")
    }

    /// The banner for states 2 and 3.
    private var bannerContent: FirstDictationBanner.Content {
        switch stage {
        case .beforeTap, .otherKeyboard:
            return .init(
                leadingSymbol: "globe",
                text: Text("Long-press the globe, then Dictus"),
                trailingSymbol: "hand.tap"
            )
        case .dictusKeyboard:
            return keyboardCanDictate
                ? .init(leadingSymbol: "mic", text: Text("Tap the blue mic, then speak"), trailingSymbol: "arrow.down.right")
                : .init(leadingSymbol: "keyboard", text: Text("Type a few words"), trailingSymbol: "arrow.down")
        }
    }

    // MARK: - Navigation

    private func advanceToSuccess() {
        // Dismiss the keyboard before the completion step slides in.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onComplete()
        }
    }
}

// MARK: - Banner

/// The coach banner above the keyboard (#678, mock-ups `10b` and `10c`): a capsule in the
/// Dictus blue with white text and symbols, in light and dark alike (decided by Pierre on
/// 2026-10-10 after testing on device: the first version, navy on light and white on dark,
/// read as foreign to the app). Same pairing as the onboarding's primary button: the accent
/// with white on top, and its accent-tinted shadow (a black shadow under blue reads muddy).
private struct FirstDictationBanner: View {
    struct Content {
        let leadingSymbol: String
        let text: Text
        let trailingSymbol: String
    }

    let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.leadingSymbol)
                .font(.body.weight(.medium))
            content.text
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            Image(systemName: content.trailingSymbol)
                .font(.body.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.dictusAccent))
        .shadow(color: .dictusAccent.opacity(0.3), radius: 12, y: 4)
        // A new banner per state, so the page's stage animation cross-fades them.
        .id(content.leadingSymbol)
        .transition(.opacity)
        // One sentence for VoiceOver; the symbols only decorate it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.text)
        .accessibilityIdentifier("onboarding.firstDictation.banner")
    }
}

// MARK: - GlobeLongPressCard

/// State 1's looping drawn card (#678, mock-up `10a`): a finger long-presses the globe of a
/// drawn iOS keyboard, the keyboard menu opens, the finger slides to Dictus and lets go.
///
/// WHY DRAWN AND WHY BLANK KEYS (#649 decisions 13 and 14): Apple's keyboard and its globe
/// menu are iOS system UI, which the onboarding draws; the keys carry no letters because the
/// globe is the one thing to look at. The card is a picture, so it is one element for
/// VoiceOver, read as its caption.
///
/// WHY A `.task` LOOP AND NOT A TIMER: the loop belongs to the view's lifetime. SwiftUI
/// cancels the task when the card leaves (the field is tapped), so no timer is left firing
/// into a view that is gone. With Reduce Motion on, the card holds the frame that says it
/// all: the menu open, Dictus selected.
private struct GlobeLongPressCard: View {
    /// One moment of the loop, in order.
    private enum Phase: CaseIterable {
        /// The keyboard alone.
        case rest
        /// The finger comes down on the globe.
        case approach
        /// The finger holds the globe.
        case press
        /// The menu is open on the current keyboard.
        case menuOpen
        /// The finger has slid up to Dictus.
        case dictusSelected
        /// The finger has let go: Dictus is chosen, the menu closes.
        case chosen

        var duration: Duration {
            switch self {
            case .rest: return .seconds(0.9)
            case .approach: return .seconds(0.6)
            case .press: return .seconds(0.8)
            case .menuOpen: return .seconds(0.9)
            case .dictusSelected: return .seconds(1.1)
            case .chosen: return .seconds(1.0)
            }
        }
    }

    @State private var phase: Phase = .rest
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The current keyboard's row in the menu, in the iPhone's language. The real menu
    /// lists the enabled keyboards by their own names; the language follows the system,
    /// like the keyboard the user will actually see (not `SharedKeys.language`, which is
    /// the transcription language). Each name is a catalog entry, spelled the same in
    /// both locales, like the real menu, which names a keyboard in its own language.
    private let systemKeyboardName: String = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("fr")
            ? String(localized: "Français", comment: "Drawn globe menu row: the French keyboard, named in French (#678).")
            : String(localized: "English", comment: "Drawn globe menu row: the English keyboard, named in English (#678).")
    }()

    // Geometry of the drawn keyboard, in points from its bottom-left corner.
    private let keyHeight: CGFloat = 32
    private let globeSize: CGFloat = 44
    private let globeInset: CGFloat = 14
    private let menuRowHeight: CGFloat = 40
    private let menuWidth: CGFloat = 180
    /// Bottom of the menu, above the globe.
    private var menuBottom: CGFloat { globeInset + globeSize + 12 }

    var body: some View {
        VStack(spacing: 0) {
            Text("Long-press the globe, then Dictus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 14)

            ZStack(alignment: .bottomLeading) {
                keyboard
                globe
                if showsMenu {
                    menu
                        .padding(.leading, globeInset)
                        .padding(.bottom, menuBottom)
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
                }
                finger
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        // Sized so the page fits a 667 pt screen (iPhone SE) with the title and the field.
        .frame(height: 284)
        .onboardingCard()
        .clipShape(RoundedRectangle(cornerRadius: OnboardingMetrics.cardCornerRadius, style: .continuous))
        .animation(.easeInOut(duration: 0.3), value: phase)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Long-press the globe, then Dictus"))
        .task(id: reduceMotion) { await run() }
    }

    // MARK: Loop

    private func run() async {
        if reduceMotion {
            phase = .dictusSelected
            return
        }
        while !Task.isCancelled {
            for next in Phase.allCases {
                phase = next
                do {
                    try await Task.sleep(for: next.duration)
                } catch {
                    return
                }
            }
        }
    }

    private var showsMenu: Bool {
        phase == .menuOpen || phase == .dictusSelected
    }

    // MARK: Drawn keyboard

    /// Blank keys on the keyboard tray, which runs into the card's rounded bottom. The bottom row
    /// leaves room for the globe, drawn on its own so it can light up.
    private var keyboard: some View {
        VStack(spacing: 8) {
            keyRow(count: 10)
            keyRow(count: 10)
            HStack(spacing: 6) {
                functionKey.frame(width: 44)
                keyRow(count: 7)
                functionKey.frame(width: 44)
            }
            HStack(spacing: 6) {
                functionKey.frame(width: 92)
                letterKey
                functionKey.frame(width: 92)
            }
            Color.clear.frame(height: globeSize)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, globeInset)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: OnboardingMetrics.cardCornerRadius,
                topTrailingRadius: OnboardingMetrics.cardCornerRadius,
                style: .continuous
            )
            .fill(Self.trayFill)
        )
    }

    private func keyRow(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { _ in letterKey }
        }
    }

    private var letterKey: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Self.keyFill)
            .frame(height: keyHeight)
            .frame(maxWidth: .infinity)
    }

    private var functionKey: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Self.functionKeyFill)
            .frame(height: keyHeight)
    }

    /// The globe key, ringed in blue while the finger holds it.
    private var globe: some View {
        let lit = phase == .press || showsMenu
        return Image(systemName: "globe")
            .font(.system(size: 22))
            .foregroundStyle(.primary)
            .frame(width: globeSize, height: globeSize)
            .background(Circle().fill(Color.dictusAccent.opacity(lit ? 0.22 : 0)))
            .overlay(Circle().strokeBorder(Color.dictusAccent, lineWidth: 2.5).opacity(lit ? 1 : 0))
            .padding(.leading, globeInset)
            .padding(.bottom, globeInset)
    }

    // MARK: Drawn menu

    /// The globe's keyboard menu: the current keyboard, Dictus, Emoji.
    private var menu: some View {
        VStack(spacing: 0) {
            menuRow(Text(verbatim: systemKeyboardName), selected: phase == .menuOpen)
            menuRow(Text(verbatim: "Dictus"), selected: phase == .dictusSelected)
            menuRow(Text("Emoji"), selected: false)
        }
        .frame(width: menuWidth)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Self.menuFill)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func menuRow(_ label: Text, selected: Bool) -> some View {
        label
            .font(.body.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: menuRowHeight)
            .background(selected ? Color.dictusAccent : Color.clear)
    }

    // MARK: Finger

    /// The fingertip: a translucent disc with a white rim, the way iOS shows touches in
    /// screen recordings. It comes down on the globe, then slides up to the Dictus row.
    private var finger: some View {
        let size: CGFloat = 36
        // Centre of the globe, and of the Dictus row (the menu's middle row), from the
        // keyboard's bottom-left corner.
        let globeCentre = CGPoint(x: globeInset + globeSize / 2, y: globeInset + globeSize / 2)
        let dictusCentre = CGPoint(x: globeInset + menuWidth * 0.75, y: menuBottom + menuRowHeight * 1.5)
        let target: CGPoint
        let visible: Bool
        let pressed: Bool
        switch phase {
        case .rest:
            target = CGPoint(x: globeCentre.x + 50, y: globeCentre.y + 40)
            visible = false
            pressed = false
        case .approach:
            target = globeCentre
            visible = true
            pressed = false
        case .press, .menuOpen:
            target = globeCentre
            visible = true
            pressed = true
        case .dictusSelected:
            target = dictusCentre
            visible = true
            pressed = true
        case .chosen:
            target = dictusCentre
            visible = false
            pressed = false
        }
        return Circle()
            .fill(Color.gray.opacity(0.35))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .frame(width: size, height: size)
            .scaleEffect(pressed ? 0.85 : 1)
            .opacity(visible ? 1 : 0)
            // The ZStack aligns the disc's bottom-left on the keyboard's; move its centre
            // onto the target.
            .offset(x: target.x - size / 2, y: -(target.y - size / 2))
            .allowsHitTesting(false)
    }

    // MARK: Colours

    /// The keyboard tray: iOS's light keyboard grey on light, a lifted navy on dark.
    private static let trayFill = Color(light: Color(hex: 0xD1D4DB), dark: Color(hex: 0x1E2535))
    /// The letter keys: white on light, slate on dark.
    private static let keyFill = Color(light: .white, dark: Color(hex: 0x3A4256))
    /// Shift, delete, 123, return: a step darker than the letters.
    private static let functionKeyFill = Color(light: Color(hex: 0xABB0BA), dark: Color(hex: 0x2A3244))
    /// The menu: a white card on light, the app's surface on dark.
    private static let menuFill = Color(light: .white, dark: Color(hex: 0x161C2C))
}

// MARK: - KeyboardDetectingTextField

/// UIKit text view wrapper that reports its focus and which keyboard is up.
///
/// WHY UITextView (not UITextField):
/// UITextField is single-line only — long dictated text overflows horizontally
/// and gets clipped. UITextView supports multi-line editing with automatic
/// wrapping, which matches user expectations for dictation output.
///
/// WHY UIViewRepresentable instead of SwiftUI TextEditor:
/// We need access to the UITextView's `textInputMode` property to detect when
/// the user switches to the Dictus keyboard (via long-press globe). SwiftUI's
/// TextEditor doesn't expose this. This wrapper:
/// 1. Reports focus from `textViewDidBeginEditing` / `textViewDidEndEditing`: a focused
///    field is a keyboard on screen (#678 state 1 versus states 2 and 3)
/// 2. Observes UITextInputMode.currentInputModeDidChangeNotification
/// 3. Reads the UITextView's textInputMode.identifier
/// 4. Calls onKeyboardChange(isDictus:) when the active keyboard changes
private struct KeyboardDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onFocusChange: (Bool) -> Void
    let onKeyboardChange: (Bool) -> Void

    func makeUIView(context: Context) -> PlaceholderTextView {
        let textView = PlaceholderTextView()
        textView.placeholder = placeholder
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = UIColor(Color.dictusAccent)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        // Remove default inner padding so text aligns to the top-left
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences

        // Listen for keyboard switches
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.inputModeDidChange(_:)),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )

        return textView
    }

    func updateUIView(_ textView: PlaceholderTextView, context: Context) {
        context.coordinator.parent = self
        if textView.text != text {
            textView.text = text
            textView.refreshPlaceholder()
        }
        if textView.placeholder != placeholder {
            textView.placeholder = placeholder
        }
    }

    static func dismantleUIView(_ textView: PlaceholderTextView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardDetectingTextField
        weak var textView: PlaceholderTextView?

        init(_ parent: KeyboardDetectingTextField) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView as? PlaceholderTextView
            DispatchQueue.main.async {
                self.parent.onFocusChange(true)
            }
            checkInputMode(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.onFocusChange(false)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
        }

        @objc func inputModeDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            checkInputMode(for: textView)
        }

        /// WHY KVC ON "identifier": `UITextInputMode` exposes no public identifier, and the
        /// KVC key is the one `KeyboardSetupPage` already reads to detect the installed
        /// keyboard. Guarded, so an unreadable key reads as "not Dictus" rather than
        /// crashing (`FirstDictationStage.isDictusInputMode`).
        private func checkInputMode(for textView: UITextView) {
            guard let inputMode = textView.textInputMode else { return }
            let identifier = inputMode.value(forKey: "identifier") as? String
            let isDictus = FirstDictationStage.isDictusInputMode(identifier: identifier)
            DispatchQueue.main.async {
                self.parent.onKeyboardChange(isDictus)
            }
        }
    }
}

/// UITextView subclass that shows a placeholder when empty.
///
/// WHY a subclass: UITextView has no built-in placeholder (unlike UITextField).
/// We overlay a UILabel that shows/hides based on whether the text view is empty.
private class PlaceholderTextView: UITextView {
    var placeholder: String = "" {
        didSet { placeholderLabel.text = placeholder; refreshPlaceholder() }
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .placeholderText
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }

    private func setupPlaceholder() {
        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func refreshPlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }
}
