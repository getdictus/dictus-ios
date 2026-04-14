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

/// Root SwiftUI view for the keyboard extension chrome (toolbar + recording overlay).
///
/// Phase 18 architecture change: The keyboard grid is now a UIKit GiellaKeyboardView
/// added as a direct subview in KeyboardViewController. This SwiftUI view only renders:
/// - ToolbarView (always visible when not recording)
/// - RecordingOverlay (replaces keyboard area during recording)
///
/// WHY SwiftUI for toolbar/overlay but UIKit for keys:
/// The toolbar and recording overlay are simple SwiftUI layouts that don't need
/// zero-latency touch handling. The key grid needs UICollectionView's proven touch
/// pipeline for zero dead zones. Mixing UIKit keys + SwiftUI chrome gives us both.
struct KeyboardRootView: View {
    let controller: UIInputViewController
    let controllerID: String
    @ObservedObject private var state = KeyboardState.shared
    @ObservedObject private var waveformDriver = KeyboardWaveformDriver.shared
    @State private var instanceID = String(UUID().uuidString.prefix(8))
    /// Whether the emoji picker is currently visible.
    /// Toggled via NotificationCenter from KeyboardViewController.toggleEmojiPicker().
    @State private var showingEmoji = false
    /// Observable state for the suggestion bar, owned by KeyboardViewController.
    /// WHY @ObservedObject (not @StateObject): The controller creates and owns SuggestionState,
    /// injecting the same instance into both this view (for display) and the bridge (for updates).
    /// Using @ObservedObject here means we observe without owning -- the controller is the source of truth.
    @ObservedObject var suggestionState: SuggestionState

    /// Reference to the keyboard bridge for prediction tap handling.
    /// WHY needed: When the user taps a prediction, we need to call
    /// bridge.handlePredictionTap() which inserts the word + space and chains
    /// new predictions. The bridge owns textDocumentProxy access and state management.
    var bridge: DictusKeyboardBridge?

    /// Callback when the user cycles language via the toolbar switcher.
    /// The controller uses this to reload the GiellaKeyboardView with the new layout.
    var onLanguageChanged: ((SupportedLanguage) -> Void)?

    /// WHY @Environment here: openURL is the SwiftUI way to open URLs.
    /// Keyboard extensions cannot access UIApplication.shared, but SwiftUI's
    /// openURL environment action works because it goes through the responder
    /// chain. We capture it here and inject it into KeyboardState via .onAppear.
    @Environment(\.openURL) private var openURL

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
        // Show overlay anyway -- only one controller is visible on screen.
        if state.activeControllerID == nil {
            return true
        }

        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsOverlay {
                // Recording overlay fills the full area (toolbar + keyboard space).
                // The UIKit keyboard is hidden by KeyboardViewController when recording.
                RecordingOverlay(
                    dictationStatus: state.dictationStatus,
                    waveformEnergy: state.waveformEnergy,
                    elapsedSeconds: state.recordingElapsed,
                    waveformDriver: waveformDriver,
                    onCancel: { state.requestCancel() },
                    onStop: { state.requestStop() }
                )
            } else if showingEmoji {
                // GeometryReader measures the actual space available to SwiftUI.
                // WHY: In keyboard extensions, the hosting controller may not give the
                // full screen width/height to SwiftUI due to safe area or system insets.
                // Passing measured dimensions to EmojiPickerView guarantees it fits.
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        // Toolbar stays visible during emoji browsing
                        ToolbarView(
                            hasFullAccess: controller.hasFullAccess,
                            dictationStatus: state.dictationStatus,
                            onMicTap: {
                                showingEmoji = false
                                state.startRecording()
                            },
                            statusMessage: state.statusMessage,
                            suggestions: [],
                            suggestionMode: .idle,
                            onSuggestionTap: { _ in },
                            onLanguageChanged: onLanguageChanged
                        )
                        .frame(height: 52)
                        // Emoji picker uses exact measured dimensions
                        EmojiPickerView(
                            onEmojiInsert: { emoji in
                                controller.textDocumentProxy.insertText(emoji)
                                HapticFeedback.keyTapped()
                            },
                            onDelete: {
                                controller.textDocumentProxy.deleteBackward()
                                HapticFeedback.keyTapped()
                            },
                            onDismiss: {
                                // Call toggleEmojiPicker() on the controller which handles:
                                // hiding emoji, showing giellaKeyboard, shrinking hosting,
                                // and posting .dictusToggleEmoji (which .onReceive picks up
                                // to set showingEmoji = false).
                                (controller as? KeyboardViewController)?.toggleEmojiPicker()
                            },
                            availableWidth: geo.size.width,
                            availableHeight: geo.size.height - 52
                        )
                    }
                }
            } else {
                // Toolbar only -- the keyboard grid is UIKit, managed by KeyboardViewController
                ToolbarView(
                    hasFullAccess: controller.hasFullAccess,
                    dictationStatus: state.dictationStatus,
                    onMicTap: { state.startRecording() },
                    statusMessage: state.statusMessage,
                    suggestions: suggestionState.suggestions,
                    suggestionMode: suggestionState.mode,
                    onSuggestionTap: { index in
                        handleSuggestionTap(index: index)
                    },
                    onLanguageChanged: onLanguageChanged
                )
                // No KeyboardView here -- it's UIKit, added directly by KeyboardViewController
                // No bottom spacer -- the UIKit keyboard handles its own height
            }
        }
        .background(Color.clear)
        .onChange(of: showsOverlay) { _, isShowing in
            PersistentLog.log(.diagnosticProbe(
                component: "KeyboardRootView",
                instanceID: instanceID,
                action: "showsOverlayChanged",
                details: "isShowing=\(isShowing) status=\(state.dictationStatus.rawValue) visible=\(state.isKeyboardVisible) owner=\(state.activeControllerID ?? "none") controllerID=\(controllerID)"
            ))
            // Dismiss emoji picker when recording starts
            if isShowing {
                showingEmoji = false
            }
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
            state.controller = controller
            state.openURL = { url in openURL(url) }

            // Pre-allocate haptic generators so the first key tap has zero latency.
            HapticFeedback.warmUp()

            // Refresh cached haptic enabled state from UserDefaults.
            HapticFeedback.refreshEnabledState()

            // Language is set in KeyboardViewController.viewWillAppear, which fires
            // on every keyboard appearance and picks up any App Group preference changes.

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
        .onReceive(NotificationCenter.default.publisher(for: .dictusToggleEmoji)) { _ in
            showingEmoji.toggle()
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
    /// Three modes:
    /// - Completion mode: replace partial word with full completion + space.
    /// - Correction mode: standard mobile behavior:
    ///   - Tap index 0 (original word): keep as-is + space, reject future autocorrect
    ///   - Tap index 1 (bold correction): apply correction + space
    ///   - Tap index 2 (alternative): apply alternative + space
    /// - Accent mode: replace just the vowel without adding a space.
    private func handleSuggestionTap(index: Int) {
        guard index < suggestionState.suggestions.count else { return }
        let suggestion = suggestionState.suggestions[index]
        let proxy = controller.textDocumentProxy

        // Prediction mode: insert word + trailing space, bypass autocorrect, chain predictions.
        if suggestionState.mode == .predictions {
            bridge?.handlePredictionTap(word: suggestion)
            HapticFeedback.keyTapped()
            return
        }

        // Undo mode: tap index 0 = revert autocorrect, tap 1-2 = accept completion/prediction
        if suggestionState.mode == .undoAvailable {
            if index == 0, let undo = suggestionState.pendingUndo {
                performUndo(undo: undo, proxy: proxy)
                suggestionState.pendingUndo = nil
                suggestionState.clear()
            } else {
                suggestionState.pendingUndo = nil
                bridge?.handlePredictionTap(word: suggestion)
            }
            HapticFeedback.keyTapped()
            return
        }

        if suggestionState.mode == .corrections {
            if index == 0 {
                suggestionState.rejectedWords.insert(suggestion.lowercased())
                proxy.insertText(" ")
            } else {
                replaceCurrentWord(
                    proxy: proxy,
                    currentWord: suggestionState.currentWord,
                    replacement: suggestion,
                    addSpace: true
                )
            }
            suggestionState.pendingUndo = nil
            suggestionState.clear()
            HapticFeedback.keyTapped()
            return
        }

        let addSpace = suggestionState.mode == .completions
        replaceCurrentWord(
            proxy: proxy,
            currentWord: suggestionState.currentWord,
            replacement: suggestion,
            addSpace: addSpace
        )

        suggestionState.pendingUndo = nil
        suggestionState.clear()
        HapticFeedback.keyTapped()
    }

    /// Reverts an autocorrection, preserving any characters typed after the correction.
    private func performUndo(undo: AutocorrectState, proxy: UITextDocumentProxy) {
        guard let context = proxy.documentContextBeforeInput else { return }

        // Try to find the corrected word with trailing space first, then without
        // (user may have deleted the space but the word is still intact).
        let correctedWithSpace = undo.correctedWord + " "
        let range: Range<String.Index>
        let matchedWithSpace: Bool

        if undo.insertedSpace, let r = context.range(of: correctedWithSpace, options: .backwards) {
            range = r
            matchedWithSpace = true
        } else if let r = context.range(of: undo.correctedWord, options: .backwards) {
            range = r
            matchedWithSpace = false
        } else {
            return
        }

        let afterCorrection = String(context[range.upperBound...])
        let matchLength = matchedWithSpace ? correctedWithSpace.count : undo.correctedWord.count
        let deleteCount = matchLength + afterCorrection.count

        for _ in 0..<deleteCount {
            proxy.deleteBackward()
        }

        proxy.insertText(undo.originalWord)
        if matchedWithSpace {
            proxy.insertText(" ")
        }
        proxy.insertText(afterCorrection)

        #if DEBUG
        AutocorrectDebugLog.autocorrectUndone(
            original: undo.originalWord, rejected: undo.correctedWord
        )
        #endif

        suggestionState.rejectedWords.insert(undo.originalWord.lowercased())

        if UserDictionary.shared.recordUsage(undo.originalWord) {
            suggestionState.learnWord(undo.originalWord)
        }
    }

    /// Replaces the word currently being typed with a replacement string.
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
