// DictusKeyboard/KeyboardViewController.swift
import UIKit
import SwiftUI
import DictusCore

class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        #if DEBUG
        let result = AppGroupDiagnostic.run()
        if #available(iOS 14.0, *) {
            DictusLogger.keyboard.debug(
                "Diagnostic: canWrite=\(result.canWrite) canRead=\(result.canRead)"
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
        // iOS manages the inputView's frame via autoresizing masks — disabling them
        // causes the view to collapse to zero width.

        let rootView = KeyboardRootView(controller: self)
        let hosting = UIHostingController(rootView: rootView)

        // Critical: retain the hosting controller or it gets deallocated
        self.hostingController = hosting

        addChild(hosting)
        // Add hosting view as subview of kbInputView (NOT self.view)
        kbInputView.addSubview(hosting.view)
        hosting.didMove(toParent: self)

        // Remove default background so the keyboard blends with host app
        hosting.view.backgroundColor = .clear

        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: kbInputView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: kbInputView.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: kbInputView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: kbInputView.trailingAnchor)
        ])

        // Assign as the controller's inputView — this activates audio feedback
        self.inputView = kbInputView
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Darwin observers cleaned up by KeyboardState deinit
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // Future: react to cursor position changes, return key type, etc.
    }
}
