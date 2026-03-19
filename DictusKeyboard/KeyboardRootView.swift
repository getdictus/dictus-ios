// DictusKeyboard/KeyboardRootView.swift
import SwiftUI
import Combine
import DictusCore

/// Bridge between DictusCore's DefaultKeyboardLayer and DictusKeyboard's KeyboardLayerType.
extension DefaultKeyboardLayer {
    var asLayerType: KeyboardLayerType {
        switch self {
        case .letters: return .letters
        case .numbers: return .numbers
        }
    }
}

/// Root SwiftUI view for the keyboard extension.
/// Phase 3 layout: ToolbarView + (KeyboardView OR RecordingOverlay).
///
/// WHY conditional rendering instead of overlay:
/// When recording, the keyboard letters must be completely replaced by the recording UI
/// to prevent accidental key presses. SwiftUI's conditional rendering (`if/else`) fully
/// removes the inactive view from the hierarchy, freeing its memory and preventing
/// ghost touches. An overlay or ZStack would keep both views alive.
struct KeyboardRootView: View {
    let controller: UIInputViewController
    let controllerID: String
    @ObservedObject private var state = KeyboardState.shared
    @ObservedObject private var waveformDriver = KeyboardWaveformDriver.shared
    @State private var instanceID = String(UUID().uuidString.prefix(8))
    /// Observable state for the suggestion bar: holds current suggestions, mode, and autocorrect undo.
    /// WHY @StateObject: SuggestionState is an ObservableObject that must survive view re-renders.
    /// @StateObject ensures a single instance is created and owned by this view.
    @StateObject private var suggestionState = SuggestionState()
    @State private var isEmojiMode = false
    /// Default keyboard layer read from App Group on each appearance.
    /// Controls which layer (letters or numbers) the keyboard opens on.
    ///
    /// WHY initialized from UserDefaults (not just .letters):
    /// In SwiftUI, child .onAppear fires BEFORE parent .onAppear. If we default
    /// to .letters here and only read UserDefaults in .onAppear, KeyboardView
    /// would always see .letters on first render — even if the user chose 123.
    /// Reading the stored value at @State init time ensures the correct layer
    /// is available when KeyboardView first renders.
    @State private var defaultLayer: KeyboardLayerType = {
        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()
        return DefaultKeyboardLayer.active.asLayerType
    }()

    /// WHY @Environment here: openURL is the SwiftUI way to open URLs.
    /// Keyboard extensions cannot access UIApplication.shared, but SwiftUI's
    /// openURL environment action works because it goes through the responder
    /// chain. We capture it here and inject it into KeyboardState via .onAppear.
    @Environment(\.openURL) private var openURL

    /// Height of just the 4-row keyboard area (without toolbar).
    private var keyboardHeight: CGFloat {
        let rows: CGFloat = 4
        return (rows * KeyMetrics.keyHeight)
            + ((rows - 1) * KeyMetrics.rowSpacing)
            + 8  // vertical padding
    }

    /// Toolbar height — must match ToolbarView's intrinsic height (48pt for mic pill glow room).
    private let toolbarHeight: CGFloat = 48

    /// Total content height (toolbar + keyboard). RecordingOverlay uses this
    /// to cover the full area, preventing layout shift when switching to recording.
    private var totalContentHeight: CGFloat {
        toolbarHeight + keyboardHeight
    }

    /// Whether the recording overlay should be visible.
    /// Extracted as a computed property for clear animation binding.
    private var showsOverlay: Bool {
        let isActiveStatus = state.dictationStatus == .requested
            || state.dictationStatus == .recording
            || state.dictationStatus == .transcribing
        guard isActiveStatus else { return false }

        // Normal path: this controller is the registered active one
        if state.activeControllerID == controllerID && state.isKeyboardVisible {
            return true
        }

        // Fallback: active recording but no controller registered yet.
        // During cold start app transitions, iOS can rapidly create/destroy
        // keyboard controllers. viewWillAppear may not have fired on the
        // current controller, leaving activeControllerID == nil.
        // Show overlay anyway — only one controller is visible on screen.
        if state.activeControllerID == nil {
            return true
        }

        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Conditional: recording overlay (full area) OR toolbar + keyboard
            if showsOverlay {
                RecordingOverlay(
                    dictationStatus: state.dictationStatus,
                    waveformEnergy: state.waveformEnergy,
                    elapsedSeconds: state.recordingElapsed,
                    waveformDriver: waveformDriver,
                    onCancel: { state.requestCancel() },
                    onStop: { state.requestStop() }
                )
                .frame(height: totalContentHeight)
            } else {
                // Single keyboard layout — no more mode switching.
                // The only variable is which layer opens first (letters vs numbers),
                // controlled by the user's DefaultKeyboardLayer preference.

                // Hide toolbar in emoji mode to give full height to emoji picker
                if !isEmojiMode {
                    ToolbarView(
                        hasFullAccess: controller.hasFullAccess,
                        dictationStatus: state.dictationStatus,
                        onMicTap: { state.startRecording() },
                        suggestions: suggestionState.suggestions,
                        suggestionMode: suggestionState.mode,
                        onSuggestionTap: { index in
                            handleSuggestionTap(index: index)
                        }
                    )
                }

                KeyboardView(
                    controller: controller,
                    hasFullAccess: controller.hasFullAccess,
                    isEmojiMode: $isEmojiMode,
                    suggestionState: suggestionState,
                    initialLayer: defaultLayer
                )

                if !isEmojiMode {
                    Spacer().frame(height: 8)
                }
            }
        }
        // WHY .clear: The native iOS keyboard container already provides a
        // blurred background. Using secondarySystemBackground created visible
        // gray bands at the top and bottom that didn't match the native chrome.
        // Transparent background lets the native keyboard styling show through.
        .background(Color.clear)
        .onChange(of: showsOverlay) { _, isShowing in
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardRootView",
                instanceID: instanceID,
                action: "showsOverlayChanged",
                details: "isShowing=\(isShowing) status=\(state.dictationStatus.rawValue) visible=\(state.isKeyboardVisible) owner=\(state.activeControllerID ?? "none") controllerID=\(controllerID)"
            ))
            syncWaveformDriver()
        }
        .onChange(of: state.dictationStatus) { _, newStatus in
            let showsOverlay = newStatus == .requested || newStatus == .recording || newStatus == .transcribing
            if showsOverlay {
                PersistentLog.log(.overlayShown(status: newStatus.rawValue))
            } else {
                PersistentLog.log(.overlayHidden(status: newStatus.rawValue))
            }
            syncWaveformDriver()
        }
        .onChange(of: state.waveformEnergy) { _, _ in
            syncWaveformDriver()
        }
        .onChange(of: state.activeControllerID) { _, newOwner in
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardRootView",
                instanceID: instanceID,
                action: "activeControllerChanged",
                details: "newOwner=\(newOwner ?? "none") controllerID=\(controllerID)"
            ))
            if newOwner == controllerID {
                defaultLayer = DefaultKeyboardLayer.active.asLayerType
            }
            syncWaveformDriver()
        }
        .onChange(of: state.isKeyboardVisible) { _, _ in
            syncWaveformDriver()
        }
        .onAppear {
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardRootView",
                instanceID: instanceID,
                action: "onAppear",
                details: "status=\(state.dictationStatus.rawValue) visible=\(state.isKeyboardVisible) owner=\(state.activeControllerID ?? "none") controllerID=\(controllerID)"
            ))
            // Provide controller reference to KeyboardState for auto-insert.
            // WHY here and not in init: KeyboardState is created by @StateObject
            // before the view body runs. The controller is only available as a
            // View property, so we pass it on first appearance.
            state.controller = controller
            state.openURL = { url in openURL(url) }

            // Re-read default layer in case user changed settings since extension loaded.
            defaultLayer = DefaultKeyboardLayer.active.asLayerType

            // Pre-allocate haptic generators so the first key tap has zero latency.
            // Without this, the Taptic Engine needs ~2-5ms to spin up on first use.
            HapticFeedback.warmUp()

            // Set prediction engine language from App Group shared preference.
            let lang = AppGroup.defaults.string(forKey: SharedKeys.language) ?? "fr"
            suggestionState.setLanguage(lang)

            syncWaveformDriver()
        }
        .onDisappear {
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardRootView",
                instanceID: instanceID,
                action: "onDisappear",
                details: "status=\(state.dictationStatus.rawValue) controllerID=\(controllerID)"
            ))
            syncWaveformDriver(forceHidden: true)
        }
    }

    private func syncWaveformDriver(forceHidden: Bool = false) {
        waveformDriver.sync(
            presenterID: controllerID,
            status: state.dictationStatus,
            energyLevels: state.waveformEnergy,
            isVisible: !forceHidden && showsOverlay
        )
    }

    // MARK: - Suggestion Handling

    /// Handles a tap on one of the suggestion bar slots.
    ///
    /// WHY two modes:
    /// - Completion mode: the user is typing a word and taps a completion.
    ///   We replace the partial word with the full suggestion and add a space
    ///   so the user can continue typing the next word immediately.
    /// - Accent mode: the user typed a single vowel and wants an accent variant.
    ///   We replace just the vowel character without adding a space, because
    ///   the user may continue typing the same word.
    private func handleSuggestionTap(index: Int) {
        guard index < suggestionState.suggestions.count else { return }
        let suggestion = suggestionState.suggestions[index]
        let proxy = controller.textDocumentProxy

        let addSpace = suggestionState.mode == .completions
        replaceCurrentWord(
            proxy: proxy,
            currentWord: suggestionState.currentWord,
            replacement: suggestion,
            addSpace: addSpace
        )

        suggestionState.lastAutocorrect = nil
        suggestionState.clear()
        HapticFeedback.keyTapped()
    }

    /// Replaces the word currently being typed with a replacement string.
    ///
    /// WHY deleteBackward loop:
    /// UITextDocumentProxy doesn't support selecting or replacing text directly.
    /// The only way to "replace" is to delete the current word character by character
    /// and then insert the replacement. This is the standard pattern used by all
    /// third-party iOS keyboards.
    private func replaceCurrentWord(
        proxy: UITextDocumentProxy,
        currentWord: String,
        replacement: String,
        addSpace: Bool
    ) {
        for _ in 0..<currentWord.count {
            proxy.deleteBackward()
        }
        proxy.insertText(replacement)
        if addSpace {
            proxy.insertText(" ")
        }
    }
}
