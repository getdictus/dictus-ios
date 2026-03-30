// DictusKeyboard/KeyboardViewController.swift
import UIKit
import SwiftUI
import Combine
import DictusCore

class KeyboardViewController: UIInputViewController {
    let controllerID = String(UUID().uuidString.prefix(8))

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var dictationStatusCancellable: AnyCancellable?

    /// Central SuggestionState owned by the controller and injected into both
    /// the bridge (for keystroke-driven updates) and the SwiftUI root view (for display).
    /// WHY here: Single ownership avoids duplicate instances and ensures bridge updates
    /// are reflected in the suggestion bar without additional synchronization.
    private let suggestionState = SuggestionState()

    /// The giellakbd-ios UICollectionView keyboard, added as a direct UIKit subview.
    /// WHY not wrapped in UIViewRepresentable: SwiftUI recreates representable views
    /// on state changes, which would destroy/rebuild the UICollectionView and lose
    /// scroll position, active key state, and long-press overlays. Adding as a direct
    /// sibling subview of kbInputView avoids this entirely.
    private var giellaKeyboard: GiellaKeyboardView?

    /// Delegate adapter that translates giellakbd-ios key events into Dictus actions.
    private var bridge: DictusKeyboardBridge?

    /// Explicit height constraint on inputView to prevent layout issues after app switch.
    /// WHY: Without this, iOS may not recalculate the keyboard height correctly when the
    /// extension is brought back to foreground after a URL scheme app switch. The system
    /// keyboard row (globe, mic) bleeds through and the recording overlay gets compressed.
    private var heightConstraint: NSLayoutConstraint?

    /// Height constraint for the SwiftUI hosting view (toolbar + recording overlay).
    /// Changes from toolbarHeight (52pt) to full height when recording overlay is active.
    private var hostingHeightConstraint: NSLayoutConstraint?

    /// Fixed toolbar height matching ToolbarView (52pt: 48pt content + 4pt top padding).
    private let toolbarHeight: CGFloat = 52

    override func viewDidLoad() {
        super.viewDidLoad()
        PersistentLog.source = "KBD"
        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "viewDidLoad",
            details: "controllerClass=\(String(describing: type(of: self)))"
        ))

        #if DEBUG
        let result = AppGroupDiagnostic.run()
        if #available(iOS 14.0, *) {
            DictusLogger.keyboard.debug(
                "Diagnostic: canWrite=\(result.canWrite, privacy: .public) canRead=\(result.canRead, privacy: .public)"
            )
        }
        #endif

        // Create a KeyboardInputView (UIInputView + UIInputViewAudioFeedback)
        // and assign it as the controller's inputView. This is the critical step
        // that makes playInputClick() work: iOS checks that the UIInputViewController's
        // inputView conforms to UIInputViewAudioFeedback and returns true from
        // enableInputClicksWhenVisible. Without this assignment, click sounds are silent.
        let kbInputView = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
        // Do NOT set translatesAutoresizingMaskIntoConstraints = false on the inputView.
        // iOS manages the inputView's frame via autoresizing masks -- disabling them
        // causes the view to collapse to zero width.

        // --- 1. Create the giellakbd-ios UIKit keyboard ---
        let definition = FrenchKeyboardLayouts.current()
        let theme = Theme.current(for: traitCollection)
        let keyboard = GiellaKeyboardView(definition: definition, theme: theme)
        keyboard.translatesAutoresizingMaskIntoConstraints = false

        // --- 2. Create and wire the delegate bridge ---
        let keyBridge = DictusKeyboardBridge()
        keyBridge.controller = self
        keyBridge.keyboardView = keyboard
        keyboard.delegate = keyBridge
        keyBridge.suggestionState = suggestionState
        keyBridge.onEmojiToggle = { [weak self] in
            self?.toggleEmojiPicker()
        }
        self.bridge = keyBridge
        self.giellaKeyboard = keyboard

        // --- 3. Create SwiftUI hosting for toolbar + recording overlay ONLY ---
        let rootView = KeyboardRootView(controller: self, controllerID: controllerID, suggestionState: suggestionState)
        let hosting = UIHostingController(rootView: rootView)
        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "hostingCreated",
            details: "hosting=\(ObjectIdentifier(hosting).debugDescription)"
        ))

        // Critical: retain the hosting controller or it gets deallocated
        self.hostingController = hosting

        // Disable safe area regions so SwiftUI content uses the full hosting bounds.
        // WHY: Keyboard extensions can have unexpected safe area insets from the system.
        // Note: Do NOT set layoutMargins/directionalLayoutMargins to zero — this
        // triggers layout recalculation that causes the keyboard height to shrink
        // when top-row key popups extend above bounds.
        if #available(iOS 16.4, *) {
            hosting.safeAreaRegions = []
        }

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        // --- 4. Add both views to kbInputView ---
        // Order matters: hosting (toolbar) at top, keyboard below
        kbInputView.addSubview(hosting.view)
        kbInputView.addSubview(keyboard)
        hosting.didMove(toParent: self)

        // --- 5. Set up Auto Layout constraints ---
        // Hosting view (toolbar): pinned to top, leading, trailing. Height = toolbarHeight.
        let hostingHeight = hosting.view.heightAnchor.constraint(equalToConstant: toolbarHeight)
        hostingHeight.priority = .defaultHigh
        self.hostingHeightConstraint = hostingHeight

        NSLayoutConstraint.activate([
            // Toolbar (SwiftUI hosting) at top
            hosting.view.topAnchor.constraint(equalTo: kbInputView.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: kbInputView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: kbInputView.trailingAnchor),
            hostingHeight,

            // UIKit keyboard below toolbar
            keyboard.topAnchor.constraint(equalTo: hosting.view.bottomAnchor),
            keyboard.leadingAnchor.constraint(equalTo: kbInputView.leadingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: kbInputView.trailingAnchor),
            keyboard.bottomAnchor.constraint(equalTo: kbInputView.bottomAnchor),
        ])

        // --- 6. Set explicit height constraint on inputView ---
        let height = computeKeyboardHeight()
        let constraint = kbInputView.heightAnchor.constraint(equalToConstant: height)
        constraint.priority = .defaultHigh  // don't fight iOS if it needs to adjust
        constraint.isActive = true
        self.heightConstraint = constraint

        // Attempt to prevent top-row key popup clipping. iOS may re-enforce
        // clipsToBounds -- if so, this is a known limitation of third-party keyboard extensions.
        kbInputView.clipsToBounds = false
        hosting.view.clipsToBounds = false

        // Assign as the controller's inputView -- this activates audio feedback
        self.inputView = kbInputView

        // --- 7. Observe recording state to show/hide keyboard ---
        observeRecordingState()

        // --- 8. Wire post-transcription suggestion refresh ---
        // After dictation inserts text, update the suggestion bar with completions
        // for the last word of the transcription.
        KeyboardState.shared.onTranscriptionInserted = { [weak self] in
            guard let self = self else { return }
            let context = self.textDocumentProxy.documentContextBeforeInput
            self.suggestionState.updateAsync(context: context)
            self.bridge?.updateCapitalization()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // CRITICAL: Disable touch delay on system gesture recognizers.
        // iOS attaches gesture recognizers to the keyboard's UIWindow that have
        // delaysTouchesBegan=true (for system gesture disambiguation at screen edges).
        // This causes edge key touches to be delayed ~100ms, making haptic/popup fire
        // on touchUp instead of touchDown, and long-press accent to fail on outer edges.
        // The original giellakbd-ios uses this exact same technique.
        disableWindowGestureDelay()

        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "viewWillAppear",
            details: "animated=\(animated)"
        ))
        PersistentLog.log(.keyboardDidAppear)
        KeyboardState.shared.registerControllerAppearance(controllerID: controllerID)

        // Force height recalculation when keyboard reappears (e.g., after app switch).
        // Without this, the inputView may retain a stale height from before the switch.
        heightConstraint?.constant = computeKeyboardHeight()
        inputView?.setNeedsLayout()

        // Update theme when keyboard reappears (dark/light mode may have changed)
        if let keyboard = giellaKeyboard {
            keyboard.updateTheme(theme: Theme.current(for: traitCollection))
        }

        // Set initial shift state based on the text field's autocapitalization setting.
        // WHY here and not viewDidLoad: The textDocumentProxy is not fully connected
        // until the view is about to appear. Calling in viewDidLoad would read stale data.
        bridge?.updateCapitalization()

        // Set default opening layer from user preference.
        // WHY here not viewDidLoad: viewWillAppear fires each time the keyboard appears,
        // allowing the user to change settings in the app and see the effect immediately.
        let defaultLayer = DefaultKeyboardLayer.active
        if defaultLayer == .numbers {
            giellaKeyboard?.page = .symbols1
        }

        // Refresh prediction language from App Group on every keyboard appearance.
        // WHY here not viewDidLoad: The user can change language in the app between
        // keyboard appearances. viewWillAppear fires each time, picking up the change.
        let lang = AppGroup.defaults.string(forKey: SharedKeys.language) ?? "fr"
        suggestionState.setLanguage(lang)

        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "registeredAppearance",
            details: ""
        ))

        // Cold start return detection: log for diagnostics.
        // DON'T clear coldStartActive here -- KeyboardState.refreshFromDefaults() reads it
        // to activate the watchdog grace period (15s instead of 5s). The app's .background
        // handler clears it when the transition is complete.
        if AppGroup.defaults.bool(forKey: SharedKeys.coldStartActive) {
            DictusLogger.keyboard.info("Keyboard returned from cold start, recording should be active")
        }

        #if DEBUG
        if #available(iOS 14.0, *) {
            DictusLogger.keyboard.debug("viewWillAppear -- refreshing mode")
        }
        #endif
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Restore system gesture recognizer delay (be a good citizen)
        restoreWindowGestureDelay()

        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "viewDidDisappear",
            details: "animated=\(animated)"
        ))
        PersistentLog.log(.keyboardDidDisappear)
        KeyboardState.shared.registerControllerDisappearance(controllerID: controllerID)
        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "registeredDisappearance",
            details: ""
        ))
        // Darwin observers cleaned up by KeyboardState deinit
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Update keyboard theme when dark/light mode changes while keyboard is visible.
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            giellaKeyboard?.updateTheme(theme: Theme.current(for: traitCollection))
        }
    }

    deinit {
        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardViewController",
            instanceID: controllerID,
            action: "deinit",
            details: ""
        ))
    }

    // MARK: - Keyboard Height

    /// Calculate the total keyboard height using giellakbd-ios KeyboardHeightProvider
    /// for the key grid height, plus toolbar and padding.
    private func computeKeyboardHeight() -> CGFloat {
        let deviceContext = DeviceContext.current
        let keyGridHeight = KeyboardHeightProvider.height(
            for: deviceContext,
            traitCollection: traitCollection
        )
        let bottomPadding: CGFloat = 8
        return keyGridHeight + toolbarHeight + bottomPadding
    }

    // MARK: - Recording State Observation

    /// Observe KeyboardState.dictationStatus to hide/show the UIKit keyboard
    /// when the recording overlay is active. The SwiftUI hosting view handles
    /// showing the overlay itself -- we just need to hide the UIKit keyboard.
    ///
    /// WHY Combine instead of NotificationCenter: KeyboardState uses @Published
    /// for dictationStatus. Subscribing via Combine's $dictationStatus publisher
    /// gives us direct observation without adding manual notification posts.
    private func observeRecordingState() {
        dictationStatusCancellable = KeyboardState.shared.$dictationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleDictationStatusChange(status)
            }
    }

    private func handleDictationStatusChange(_ status: DictationStatus) {
        let isRecording = status == .requested || status == .recording || status == .transcribing

        // Dismiss emoji picker if recording starts
        if isRecording && isShowingEmoji {
            isShowingEmoji = false
        }

        giellaKeyboard?.isHidden = isRecording || isShowingEmoji

        if isRecording {
            // Expand hosting view to fill the full keyboard area for the recording overlay
            let fullHeight = computeKeyboardHeight()
            hostingHeightConstraint?.constant = fullHeight
        } else if !isShowingEmoji {
            // Restore toolbar-only height (unless emoji picker is open)
            hostingHeightConstraint?.constant = toolbarHeight
        }

        inputView?.setNeedsLayout()
    }

    // MARK: - Text Change

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // When text changes externally (paste, cursor move, autocorrect by host app),
        // recheck autocapitalization. This ensures shift state stays correct even when
        // the user moves the cursor to a different position in the text.
        bridge?.updateCapitalization()
    }

    // MARK: - Window Gesture Delay

    /// Hashes of gesture recognizers we disabled, so we can restore them on disappear.
    private var disabledGestureHashes = Set<Int>()

    /// Disable `delaysTouchesBegan` on all UIWindow gesture recognizers.
    ///
    /// WHY: iOS attaches system gesture recognizers to the keyboard's UIWindow with
    /// `delaysTouchesBegan = true`. These recognizers check for system gestures (swipe-back,
    /// Control Center) before delivering touches to the keyboard. This adds ~100ms delay
    /// on edge key touches, causing haptic/popup to fire on touchUp instead of touchDown
    /// and long-press accent popup to fail on outer edge of edge keys.
    ///
    /// This is the same technique used by the original giellakbd-ios keyboard.
    private func disableWindowGestureDelay() {
        guard let window = view.window,
              let recognizers = window.gestureRecognizers else { return }
        for recognizer in recognizers {
            if recognizer.delaysTouchesBegan {
                recognizer.delaysTouchesBegan = false
                disabledGestureHashes.insert(recognizer.hash)
            }
        }
    }

    /// Restore `delaysTouchesBegan` on gesture recognizers we previously disabled.
    private func restoreWindowGestureDelay() {
        guard let window = view.window,
              let recognizers = window.gestureRecognizers else { return }
        for recognizer in recognizers where disabledGestureHashes.contains(recognizer.hash) {
            recognizer.delaysTouchesBegan = true
        }
        disabledGestureHashes.removeAll()
    }

    // MARK: - Emoji Picker

    /// Whether the emoji picker is currently visible.
    private(set) var isShowingEmoji = false

    /// Toggle emoji picker visibility. The emoji picker UI itself is wired in Plan 02.
    ///
    /// WHY toggle here (not in bridge): The bridge handles key events but doesn't
    /// own the view hierarchy. Showing/hiding views is the controller's responsibility.
    /// The bridge calls this via the onEmojiToggle closure.
    func toggleEmojiPicker() {
        isShowingEmoji.toggle()
        giellaKeyboard?.isHidden = isShowingEmoji

        if isShowingEmoji {
            // Expand hosting to cover keyboard area for emoji picker
            hostingHeightConstraint?.constant = computeKeyboardHeight()
        } else {
            hostingHeightConstraint?.constant = toolbarHeight
        }
        inputView?.setNeedsLayout()

        // Notify SwiftUI to show/hide emoji picker
        NotificationCenter.default.post(name: .dictusToggleEmoji, object: nil)
    }
}

// MARK: - Notification names for keyboard internal communication

extension Notification.Name {
    /// Posted by KeyboardViewController when text changes externally (paste, cursor move).
    /// KeyboardView listens for this to recheck autocapitalisation.
    static let dictusTextDidChange = Notification.Name("dictusTextDidChange")

    /// Posted when the emoji picker should toggle visibility.
    static let dictusToggleEmoji = Notification.Name("dictusToggleEmoji")
}
