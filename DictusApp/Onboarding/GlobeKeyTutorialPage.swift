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
                    KeyboardDetectingTextField(
                        text: $textFieldContent,
                        placeholder: String(localized: "Say something!"),
                        autoFocus: true,
                        onKeyboardChange: { _ in }
                    )
                    .padding(12)
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

            // Success overlay — keyboard dismissed before appearing
            if showSuccess {
                OnboardingSuccessView(onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: dictusKeyboardActive)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
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
            withAnimation(.easeOut(duration: 0.3)) {
                showSuccess = true
            }
        }
    }

    private func skipTutorial() {
        PersistentLog.log(.onboardingGlobeTutorialSkipped)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    @State private var animationTimer: Timer?

    private let frameDurations: [TimeInterval] = [1.5, 1.5, 1.5, 2.0]

    // AZERTY layout rows
    private let row0 = ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"]
    private let row1 = ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"]
    private let row2 = ["W", "X", "C", "V", "B", "N", "'"]

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
        .onAppear { startAnimation() }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    // MARK: - Fake Keyboard

    /// Realistic AZERTY keyboard using actual SwiftUI text labels.
    /// Non-interactive (allowsHitTesting(false)).
    private func fakeKeyboard(isDictus: Bool) -> some View {
        VStack(spacing: 5) {
            // Row 0: A Z E R T Y U I O P
            HStack(spacing: 4) {
                ForEach(row0, id: \.self) { key in
                    keyCell(key)
                }
            }

            // Row 1: Q S D F G H J K L M
            HStack(spacing: 4) {
                ForEach(row1, id: \.self) { key in
                    keyCell(key)
                }
            }

            // Row 2: shift + W X C V B N ' + delete
            HStack(spacing: 4) {
                // Shift key
                Image(systemName: "shift")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                ForEach(row2, id: \.self) { key in
                    keyCell(key)
                }

                // Delete key
                Image(systemName: "delete.left")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))
            }

            // Row 3: 123 + emoji + space + return
            HStack(spacing: 4) {
                // 123 key
                Text("123")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                // Emoji key
                Text("😊")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                // Space bar
                Text(isDictus ? "Dictus" : "espace")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(keyCapsule(dark: false))

                // Return key
                Image(systemName: "return")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 64, height: 36)
                    .background(keyCapsule(dark: true))
            }

            // Bottom row: globe + mic (outside the key area, like real iOS)
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Spacer()
                if isDictus {
                    // Dictus mic button
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.dictusAccent)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .allowsHitTesting(false)
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
            pickerRow("Français", highlighted: !dictusHighlighted)
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
        scheduleNextFrame()
    }

    private func scheduleNextFrame() {
        let duration = frameDurations[animationFrame]
        animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            animationFrame = (animationFrame + 1) % 4
            scheduleNextFrame()
        }
    }
}

// MARK: - KeyboardDetectingTextField

/// UIKit text field wrapper that detects keyboard input mode changes.
///
/// WHY UIViewRepresentable instead of SwiftUI TextField:
/// SwiftUI's TextField doesn't expose the UITextInputMode of the underlying
/// UITextField. To detect when the user switches to the Dictus keyboard
/// (via long-press globe), we need access to the UITextField's textInputMode
/// property. This wrapper:
/// 1. Observes UITextInputMode.currentInputModeDidChangeNotification
/// 2. Reads the UITextField's textInputMode.identifier
/// 3. Calls onKeyboardChange(isDictus:) when the active keyboard changes
private struct KeyboardDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var autoFocus: Bool = false
    let onKeyboardChange: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textColor = .label
        textField.delegate = context.coordinator
        textField.returnKeyType = .done
        textField.backgroundColor = .clear
        textField.contentVerticalAlignment = .top

        // Listen for keyboard switches
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.inputModeDidChange(_:)),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )

        // Auto-focus immediately to bring up the keyboard without delay.
        // WHY no delay: The previous 0.3s delay caused the keyboard to appear
        // late, leaving the animation floating without a keyboard below it.
        // Immediate focus on the next run loop tick is fast enough.
        if autoFocus {
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
            }
        }

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
    }

    static func dismantleUIView(_ textField: UITextField, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeyboardDetectingTextField
        weak var textField: UITextField?

        init(_ parent: KeyboardDetectingTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.textField = textField
            checkInputMode(for: textField)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""
            if let textRange = Range(range, in: current) {
                parent.text = current.replacingCharacters(in: textRange, with: string)
            }
            return true
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        @objc func inputModeDidChange(_ notification: Notification) {
            guard let textField = textField else { return }
            checkInputMode(for: textField)
        }

        private func checkInputMode(for textField: UITextField) {
            guard let inputMode = textField.textInputMode,
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
