// DictusApp/Onboarding/GlobeKeyTutorialPage.swift
// Step 6 of onboarding: interactive globe key tutorial + dictation test.
import SwiftUI
import UIKit
import DictusCore

/// Interactive tutorial that teaches the user to switch to the Dictus keyboard
/// via the globe key, then test dictation in a real text field.
///
/// WHY this replaces TestRecordingPage:
/// The old test recording validated the mic/model pipeline inside the app, but
/// users still didn't know how to USE Dictus in other apps (via the globe key).
/// This page combines both: the user learns to switch keyboards AND tests
/// dictation in a single step — matching the real-world usage flow.
///
/// UX PATTERN (inspired by Wispr Flow):
/// State 1: Animated keyboard illustration showing the 4-step globe key flow,
///          overlaid above the real keyboard (which is open for interaction).
/// State 2: Once switch detected, animation disappears → text field visible
///          with keyboard still open. User dictates → auto-advance to success.
struct GlobeKeyTutorialPage: View {
    let onComplete: () -> Void

    /// WHY @EnvironmentObject coordinator:
    /// The user may dictate during this tutorial via the Dictus keyboard, which
    /// goes through DictationCoordinator. If we don't reset the coordinator before
    /// completing onboarding, HomeView will show the "last transcription card"
    /// from this test dictation — which is not the desired landing screen.
    @EnvironmentObject var coordinator: DictationCoordinator

    @State private var dictusKeyboardActive = false
    @State private var textFieldContent = ""
    @State private var showSuccess = false

    /// Guard against multiple auto-advance triggers.
    @State private var hasAutoAdvanced = false

    /// Minimum text length to trigger auto-advance.
    /// WHY 3 characters: A single keystroke shouldn't trigger success.
    /// Dictation typically produces multiple words. 3 chars filters accidental
    /// key taps while still allowing short dictation ("oui", "non", "ok").
    private let minTextLength = 3

    var body: some View {
        ZStack {
            Color.dictusBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with Skip button
                HStack {
                    Spacer()
                    Button(action: skipTutorial) {
                        Text("Skip")
                            .font(.dictusBody)
                            .foregroundColor(.dictusAccent)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // Title — changes based on state
                Group {
                    if !dictusKeyboardActive {
                        Text("Hold \(Image(systemName: "globe")) and select Dictus")
                    } else {
                        Text("Tap the mic and start dictating")
                    }
                }
                .font(.dictusHeading)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if dictusKeyboardActive {
                    // State 2: Text field with keyboard open
                    // WHY frame minHeight + maxHeight: The UITextView is multi-line
                    // and needs a bounded frame so SwiftUI can lay it out correctly.
                    // minHeight 140 gives room for ~5 lines of text, and the text view
                    // scrolls internally if the dictation is longer than that.
                    KeyboardDetectingTextField(
                        text: $textFieldContent,
                        placeholder: String(localized: "Say something!"),
                        autoFocus: true,
                        onKeyboardChange: { _ in }
                    )
                    .frame(minHeight: 140, maxHeight: 220)
                    .padding(14)
                    .dictusGlass(in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                } else {
                    // State 1: Animated keyboard switch illustration

                    Spacer()

                    // 4-frame animation showing the globe key flow
                    KeyboardSwitchAnimation()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Hidden text field to bring up the real keyboard immediately.
                    // WHY hidden: The user needs the real system keyboard visible so
                    // they can long-press the globe key. Only the keyboard matters.
                    KeyboardDetectingTextField(
                        text: $textFieldContent,
                        placeholder: "",
                        autoFocus: true,
                        onKeyboardChange: { isDictus in
                            if isDictus {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    dictusKeyboardActive = true
                                }
                                PersistentLog.log(.onboardingDictusKeyboardActivated)
                            }
                        }
                    )
                    .frame(height: 1)
                    .opacity(0)
                }

                Spacer(minLength: 0)
            }
        }
        .fullScreenCover(isPresented: $showSuccess) {
            // WHY fullScreenCover instead of ZStack overlay:
            // When OnboardingSuccessView was overlaid inside this page's ZStack,
            // it inherited the constrained layout from OnboardingView's VStack
            // (which reserves space for the step indicator at the bottom). This
            // made the success button's horizontal padding not render correctly.
            // Using fullScreenCover guarantees a proper full-screen context.
            OnboardingSuccessView(onComplete: finishOnboarding)
        }
        .animation(.easeInOut(duration: 0.3), value: dictusKeyboardActive)
        .onChange(of: textFieldContent) { newValue in
            // Auto-advance when the user has dictated enough text.
            // WHY minTextLength: Prevents a single accidental keystroke from
            // triggering success. Dictation produces multiple characters at once.
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if dictusKeyboardActive && trimmed.count >= minTextLength && !hasAutoAdvanced {
                hasAutoAdvanced = true
                PersistentLog.log(.onboardingGlobeTutorialTextDetected)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    advanceToSuccess()
                }
            }
        }
    }

    // MARK: - Navigation

    private func advanceToSuccess() {
        // Dismiss keyboard before showing success screen
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showSuccess = true
        }
    }

    private func skipTutorial() {
        PersistentLog.log(.onboardingGlobeTutorialSkipped)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        finishOnboarding()
    }

    /// Final cleanup before dismissing onboarding.
    ///
    /// WHY reset the coordinator here:
    /// If the user dictated during the globe key tutorial, the DictationCoordinator
    /// holds the last transcription in `lastResult`. Without clearing it, HomeView
    /// displays a "last transcription card" as soon as the user lands on the main
    /// screen — which is not the expected fresh Home state.
    private func finishOnboarding() {
        coordinator.lastResult = nil
        coordinator.resetStatus()
        onComplete()
    }
}

// MARK: - KeyboardSwitchAnimation

/// Animated 4-frame illustration showing the globe key → keyboard picker → Dictus flow.
///
/// WHY real SwiftUI elements instead of simplified rectangles:
/// The previous version used abstract rectangles for keys which didn't look like iOS.
/// This version uses real text labels for AZERTY keys, proper spacing, and native
/// materials — matching the approach used in KeyboardSetupPage (Animation A) where
/// real Toggle components made the fake Settings card convincing.
///
/// The animation loops through 4 states:
/// Frame 0: Normal AZERTY keyboard
/// Frame 1: Picker appears, "Français" highlighted (current keyboard)
/// Frame 2: Picker, "Dictus" highlighted (user's target)
/// Frame 3: Dictus keyboard visible (with branding on spacebar)
private struct KeyboardSwitchAnimation: View {
    @State private var animationFrame = 0
    @State private var globePressed = false
    @State private var animationTimer: Timer?

    private let frameDurations: [TimeInterval] = [1.5, 1.5, 1.5, 2.0]

    /// Whether the user's language is French (drives AZERTY vs QWERTY layout).
    /// WHY read from AppGroup at init: The language preference is stable during
    /// the animation; no need to observe for changes.
    private let isFrench: Bool

    init() {
        let lang = AppGroup.defaults.string(forKey: SharedKeys.language) ?? "fr"
        self.isFrench = (lang == "fr")
    }

    // Keyboard layout rows — AZERTY for FR, QWERTY for others
    private var row0: [String] {
        isFrench
            ? ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"]
            : ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    }
    private var row1: [String] {
        isFrench
            ? ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"]
            : ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    }
    private var row2: [String] {
        isFrench
            ? ["W", "X", "C", "V", "B", "N", "'"]
            : ["Z", "X", "C", "V", "B", "N", "M"]
    }

    /// Display name for the system keyboard in the picker.
    private var systemKeyboardName: String {
        isFrench ? "Français" : "English (US)"
    }

    /// Display name for the space bar in non-Dictus frames.
    private var spaceLabel: String {
        isFrench ? "espace" : "space"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Base keyboard illustration
            fakeKeyboard(isDictus: animationFrame == 3)

            // Picker overlay for frames 1-2
            if animationFrame == 1 || animationFrame == 2 {
                fakeKeyboardPicker(dictusHighlighted: animationFrame == 2)
                    .padding(.leading, 8)
                    .padding(.bottom, 44)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: animationFrame)
        .animation(.easeInOut(duration: 0.15), value: globePressed)
        .onAppear { startAnimation() }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    // MARK: - Fake Keyboard

    /// Realistic keyboard using actual SwiftUI text labels.
    /// Non-interactive (allowsHitTesting(false)).
    /// WHY isDictus branches the layout:
    /// - isDictus == false: native iOS keyboard with standard globe/mic at bottom
    /// - isDictus == true: Dictus keyboard with toolbar (FR/EN label + blue mic pill)
    ///   replicating the real Dictus keyboard design
    private func fakeKeyboard(isDictus: Bool) -> some View {
        VStack(spacing: 5) {
            // Dictus keyboard has a toolbar at the top (FR label + blue mic pill)
            if isDictus {
                dictusToolbar
                    .padding(.bottom, 2)
            }

            // Row 0: A Z E R T Y U I O P (or Q W E R T Y U I O P)
            HStack(spacing: 4) {
                ForEach(row0, id: \.self) { key in
                    keyCell(key)
                }
            }

            // Row 1
            HStack(spacing: 4) {
                ForEach(row1, id: \.self) { key in
                    keyCell(key)
                }
            }

            // Row 2: shift + letters + delete
            HStack(spacing: 4) {
                Image(systemName: "shift")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                ForEach(row2, id: \.self) { key in
                    keyCell(key)
                }

                Image(systemName: "delete.left")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))
            }

            // Row 3: 123 + emoji + space + return
            HStack(spacing: 4) {
                Text("123")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                Text("😊")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                // Space bar
                Text(spaceLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(keyCapsule(dark: false))

                Image(systemName: "return")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 64, height: 36)
                    .background(keyCapsule(dark: true))
            }

            // Bottom row: globe + mic (only shown on the native keyboard, not on Dictus)
            // WHY hidden on Dictus: Dictus has its own toolbar at the top with the mic pill.
            if !isDictus {
                HStack {
                    // Globe icon — highlighted when "pressed" during the animation transition
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(globePressed ? Color.primary : Color.secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(globePressed ? 0.18 : 0))
                        )

                    Spacer()

                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .allowsHitTesting(false)
    }

    /// Dictus keyboard toolbar: language indicator on the left + blue mic pill on the right.
    /// Matches the real Dictus keyboard design.
    private var dictusToolbar: some View {
        HStack {
            // Language label (FR/EN)
            Text(isFrench ? "FR" : "EN")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            // Blue mic pill — matches real Dictus mic button
            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.dictusAccent)
                )
        }
        .padding(.horizontal, 8)
    }

    /// A single keyboard key cell.
    private func keyCell(_ letter: String) -> some View {
        Text(letter)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(keyCapsule(dark: false))
    }

    /// Key background capsule — light for letter keys, darker for function keys.
    private func keyCapsule(dark: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.primary.opacity(dark ? 0.08 : 0.05))
            .shadow(color: .black.opacity(0.08), radius: 0.5, y: 1)
    }

    // MARK: - Fake Keyboard Picker

    /// Keyboard picker popup matching iOS style.
    private func fakeKeyboardPicker(dictusHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerRow("Keyboard Settings...", dimmed: true)
            Divider().opacity(0.2)
            pickerRow(systemKeyboardName, highlighted: !dictusHighlighted)
            Divider().opacity(0.2)
            pickerRow("Emoji")
            Divider().opacity(0.2)
            pickerRow("Dictus", highlighted: dictusHighlighted, accent: dictusHighlighted)

            // Keyboard type icons (dock/split/full)
            HStack(spacing: 12) {
                ForEach(["keyboard.onehanded.left", "keyboard", "keyboard.onehanded.right"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 2)
        )
    }

    private func pickerRow(_ text: String, dimmed: Bool = false, highlighted: Bool = false, accent: Bool = false) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(accent ? .dictusAccent : (dimmed ? .secondary : .primary))
            .fontWeight(highlighted || accent ? .medium : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(highlighted ? Color.primary.opacity(0.1) : (accent ? Color.dictusAccent.opacity(0.12) : Color.clear))
                    .padding(.horizontal, 4)
            )
    }

    // MARK: - Animation Timer

    private func startAnimation() {
        animationFrame = 0
        globePressed = false
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        let duration = frameDurations[animationFrame]

        // WHY globe press timing:
        // During frame 0 (normal keyboard), press the globe ~0.3s before
        // the picker appears, so the user sees the "click" happening before
        // the picker opens. The globe stays pressed while the picker is shown
        // (frames 1-2) and releases when we return to frame 3 (Dictus active).
        if animationFrame == 0 {
            // Schedule globe press ~0.3s before picker appears
            DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.3) {
                globePressed = true
            }
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            animationFrame = (animationFrame + 1) % 4
            // Release globe press when we transition to frame 3 (Dictus keyboard)
            // and also ensure it's false when we loop back to frame 0
            if animationFrame == 3 || animationFrame == 0 {
                globePressed = false
            }
            scheduleNextFrame()
        }
    }
}

// MARK: - KeyboardDetectingTextField

/// UIKit text view wrapper that detects keyboard input mode changes.
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
/// 1. Observes UITextInputMode.currentInputModeDidChangeNotification
/// 2. Reads the UITextView's textInputMode.identifier
/// 3. Calls onKeyboardChange(isDictus:) when the active keyboard changes
private struct KeyboardDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var autoFocus: Bool = false
    let onKeyboardChange: (Bool) -> Void

    func makeUIView(context: Context) -> PlaceholderTextView {
        let textView = PlaceholderTextView()
        textView.placeholder = placeholder
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = .label
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

        // Auto-focus immediately to bring up the keyboard without delay.
        if autoFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }

        return textView
    }

    func updateUIView(_ textView: PlaceholderTextView, context: Context) {
        if textView.text != text {
            textView.text = text
            textView.refreshPlaceholder()
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
            checkInputMode(for: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
        }

        @objc func inputModeDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            checkInputMode(for: textView)
        }

        private func checkInputMode(for textView: UITextView) {
            guard let inputMode = textView.textInputMode,
                  let identifier = inputMode.value(forKey: "identifier") as? String else {
                return
            }

            let isDictus = identifier.contains("com.pivi.dictus")
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
