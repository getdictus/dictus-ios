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
                    // State 2: Text field with keyboard open, no mic hint bar
                    // The text field auto-focuses to keep the Dictus keyboard visible.
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
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                    // Hidden text field to bring up the real keyboard for interaction.
                    // WHY hidden but present: The user needs the real system keyboard
                    // visible so they can long-press the globe key. The text field is
                    // invisible — only the keyboard matters at this stage.
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

            // Success overlay — dismisses keyboard before appearing
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
/// WHY an animated illustration instead of a static mockup:
/// Wispr Flow uses this exact pattern — a looping animation that shows:
/// 1. Normal iOS keyboard
/// 2. Globe pressed → picker appears with system keyboard selected
/// 3. Picker → Dictus selected (highlighted)
/// 4. Dictus keyboard active
///
/// The animation loops so the user sees the complete flow before doing it themselves
/// on the real keyboard below.
private struct KeyboardSwitchAnimation: View {
    /// Current frame of the 4-step animation (0-3).
    @State private var animationFrame = 0
    @State private var animationTimer: Timer?

    /// Animation timing:
    /// Frame 0: 1.5s — Normal keyboard visible
    /// Frame 1: 1.5s — Picker appears, system keyboard highlighted
    /// Frame 2: 1.5s — Picker, Dictus highlighted
    /// Frame 3: 2.0s — Dictus keyboard visible
    /// Total: ~6.5s per cycle
    private let frameDurations: [TimeInterval] = [1.5, 1.5, 1.5, 2.0]

    var body: some View {
        ZStack {
            // Base: simplified keyboard illustration
            miniKeyboardBase(isDictus: animationFrame == 3)

            // Picker overlay for frames 1-2
            if animationFrame == 1 || animationFrame == 2 {
                miniKeyboardPicker(dictusHighlighted: animationFrame == 2)
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

    /// Simplified iOS keyboard illustration — just enough to be recognizable.
    ///
    /// WHY simplified and not pixel-perfect: We're showing a miniature illustration
    /// (not a real keyboard). The goal is recognition, not replication. Users see
    /// the real keyboard below this illustration.
    private func miniKeyboardBase(isDictus: Bool) -> some View {
        VStack(spacing: 6) {
            // 4 rows of key placeholders
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 4) {
                    let keyCount = row == 0 ? 10 : (row == 1 ? 9 : (row == 2 ? 7 : 3))
                    ForEach(0..<keyCount, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 28)
                    }
                }
            }

            // Bottom row: globe + space + return
            HStack(spacing: 4) {
                // Globe key
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                    )

                // Space bar — shows "Dictus" branding in frame 3
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 28)
                    .overlay {
                        if isDictus {
                            Text("Dictus")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                // Return key
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 28)
                    .overlay {
                        Image(systemName: "return")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    /// Mini keyboard picker popup — matches the iOS picker style.
    private func miniKeyboardPicker(dictusHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerRow(text: "Keyboard Settings...", dimmed: true, highlighted: false)
            Divider().opacity(0.2)
            pickerRow(text: "Français", dimmed: false, highlighted: !dictusHighlighted)
            Divider().opacity(0.2)
            pickerRow(text: "Emoji", dimmed: false, highlighted: false)
            Divider().opacity(0.2)
            pickerRow(text: "Dictus", dimmed: false, highlighted: dictusHighlighted, accent: dictusHighlighted)
        }
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        )
        // Position: bottom-left of the keyboard illustration (near the globe key)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 12)
        .padding(.bottom, 48)
    }

    private func pickerRow(text: String, dimmed: Bool, highlighted: Bool, accent: Bool = false) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(accent ? .dictusAccent : (dimmed ? .secondary : .primary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                highlighted
                    ? Color.primary.opacity(0.08)
                    : (accent ? Color.dictusAccent.opacity(0.1) : Color.clear)
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
        // Placeholder top-left alignment (default for UITextField)
        textField.contentVerticalAlignment = .top

        // Listen for keyboard switches
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.inputModeDidChange(_:)),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )

        // Auto-focus to bring up the keyboard immediately
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
