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
/// State 1: Mockup of the iOS keyboard picker overlaid above the real keyboard,
///          showing where to find "Dictus" in the list.
/// State 2: Once switch detected, mockup disappears → text field + mic hint visible.
///          User dictates → text appears → auto-advance to success.
struct GlobeKeyTutorialPage: View {
    let onComplete: () -> Void

    @State private var dictusKeyboardActive = false
    @State private var textFieldContent = ""
    @State private var showSuccess = false

    /// Guard against multiple auto-advance triggers.
    @State private var hasAutoAdvanced = false

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
                        VStack(spacing: 4) {
                            (Text("Tap and hold ")
                                + Text(Image(systemName: "globe"))
                                + Text(", then"))
                            Text("switch to the Dictus keyboard")
                        }
                    } else {
                        Text("Say anything, tap the mic, and\nsee it appear like magic")
                    }
                }
                .font(.dictusHeading)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .animation(.easeInOut(duration: 0.3), value: dictusKeyboardActive)

                if dictusKeyboardActive {
                    // State 2: Text field + mic hint

                    // Large text field for dictation
                    // WHY KeyboardDetectingTextField instead of SwiftUI TextField:
                    // We need to detect which keyboard is active (Dictus vs system).
                    // SwiftUI's TextField doesn't expose textInputMode. The UIKit
                    // wrapper observes UITextInputMode.currentInputModeDidChangeNotification
                    // and reads the UITextField's textInputMode property directly.
                    KeyboardDetectingTextField(
                        text: $textFieldContent,
                        placeholder: "Say something!",
                        onKeyboardChange: { isDictus in
                            // Already active, no-op
                        }
                    )
                    .frame(minHeight: 160)
                    .dictusGlass(in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .transition(.opacity)

                    Spacer()

                    // Mic hint bar — positioned just above the keyboard
                    HStack {
                        Text("Tap the mic to start speaking")
                            .font(.dictusBody)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundColor(.dictusAccent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // State 1: Keyboard picker mockup + hidden text field for keyboard

                    Spacer()

                    // Fake iOS keyboard picker popup
                    keyboardPickerMockup
                        .padding(.horizontal, 40)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Hidden text field to trigger the keyboard and detect switches.
                    // WHY hidden but present: We need the system keyboard to appear
                    // so the user can long-press the globe key. The text field itself
                    // is invisible (0 height, no border) — only the keyboard matters.
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
            }

            // Success overlay (same pattern as old TestRecordingPage)
            if showSuccess {
                OnboardingSuccessView(onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: dictusKeyboardActive)
        .animation(.easeInOut(duration: 0.3), value: showSuccess)
        .onChange(of: textFieldContent) { newValue in
            // Auto-advance when the user has dictated text
            if dictusKeyboardActive && !newValue.isEmpty && !hasAutoAdvanced {
                hasAutoAdvanced = true
                PersistentLog.log(.onboardingGlobeTutorialTextDetected)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    advanceToSuccess()
                }
            }
        }
    }

    // MARK: - Keyboard Picker Mockup

    /// Fake iOS keyboard picker popup that visually matches the real one.
    ///
    /// WHY a static mockup instead of an animated illustration:
    /// Wispr Flow's onboarding uses this exact pattern — showing the real keyboard
    /// picker appearance helps users recognize it when they long-press the globe.
    /// The "Dictus" row is highlighted to draw attention to the correct choice.
    private var keyboardPickerMockup: some View {
        VStack(spacing: 0) {
            // "Keyboard Settings..." row
            HStack {
                Text("Keyboard Settings...")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.3)

            // Language rows
            ForEach(["French (FR)", "English (US)", "Emoji"], id: \.self) { label in
                HStack {
                    Text(label)
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().opacity(0.3)
            }

            // Dictus row — highlighted to draw attention
            HStack {
                Text("Dictus")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.dictusAccent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.dictusAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dictusAccent.opacity(0.12))
                    .padding(.horizontal, 4)
            )

            // Keyboard type selector icons (mimics the real picker)
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "keyboard")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
    }

    // MARK: - Navigation

    private func advanceToSuccess() {
        withAnimation(.easeOut(duration: 0.3)) {
            showSuccess = true
        }
    }

    private func skipTutorial() {
        PersistentLog.log(.onboardingGlobeTutorialSkipped)
        onComplete()
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
        // Match the app's dark background style
        textField.backgroundColor = .clear

        // Listen for keyboard switches
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.inputModeDidChange(_:)),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )

        // Auto-focus if requested (brings up the keyboard immediately)
        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        /// Weak reference to the UITextField for reading textInputMode on notification.
        weak var textField: UITextField?

        init(_ parent: KeyboardDetectingTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.textField = textField
            // Check immediately in case Dictus is already active
            checkInputMode(for: textField)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            // Update the SwiftUI binding
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

        /// Called by iOS when the user switches keyboards via the globe key.
        @objc func inputModeDidChange(_ notification: Notification) {
            guard let textField = textField else { return }
            checkInputMode(for: textField)
        }

        /// Read the UITextField's textInputMode to determine if Dictus is active.
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
