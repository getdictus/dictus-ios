// DictusKeyboard/LegacyCompat.swift
// Temporary compatibility stubs for old SwiftUI keyboard types.
// These provide KeyMetrics, DeviceClass, KeySound, and a placeholder KeyboardView
// that keep the existing KeyboardRootView, KeyboardViewController, and EmojiPickerView
// compiling while the giellakbd-ios UIKit keyboard is being integrated.
// This file will be removed in Phase 18 Plan 02 when the bridge is complete.

import SwiftUI
import UIKit
import DictusCore
import AVFoundation

// MARK: - Device Class (from old KeyButton.swift)

/// Device class for adaptive keyboard layout.
enum DeviceClass {
    case compact    // iPhone SE
    case standard   // iPhone 14/15/16
    case large      // iPhone Plus/Max

    static let current: DeviceClass = {
        let h = UIScreen.main.bounds.height
        if h <= 667 { return .compact }
        else if h <= 852 { return .standard }
        else { return .large }
    }()
}

// MARK: - Key Metrics (from old KeyButton.swift)

/// Shared key dimension constants, computed once per device class.
enum KeyMetrics {
    static let keyHeight: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 40
        case .standard: return 43
        case .large:    return 46
        }
    }()

    static let rowSpacing: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 9
        case .standard: return 11
        case .large:    return 12
        }
    }()

    static let keySpacing: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 5
        case .standard: return 6
        case .large:    return 6
        }
    }()

    static let rowSidePadding: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 3
        case .standard: return 4
        case .large:    return 5
        }
    }()

    static let keyCornerRadius: CGFloat = 8

    static let letterKeyColor = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : .white
    })

    static let pressedKeyColor = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.32, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })
}

// MARK: - Key Sound (from old Views/KeyboardView.swift)

/// 3-category system sounds for key feedback.
/// These sound IDs are the same as giellakbd-ios Audio class and respect silent switch.
enum KeySound {
    static let letter: SystemSoundID = 1104
    static let delete: SystemSoundID = 1155
    static let modifier: SystemSoundID = 1156
}

// MARK: - Key Popup (from old KeyButton.swift, used by EmojiPickerView)

/// Minimal popup view for emoji key labels. Preserves compilation for EmojiPickerView.
struct KeyPopup: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 24))
            .padding(6)
            .background(KeyMetrics.letterKeyColor)
            .cornerRadius(KeyMetrics.keyCornerRadius)
    }
}

// MARK: - Placeholder SwiftUI KeyboardView

/// Placeholder SwiftUI keyboard view that shows during Phase 18 transition.
/// This replaces the old SwiftUI KeyboardView that was removed from compilation.
/// Plan 18-02 will replace this with the giellakbd-ios UIKit keyboard bridge.
struct KeyboardView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool
    @Binding var isEmojiMode: Bool
    @ObservedObject var suggestionState: SuggestionState
    let initialLayer: KeyboardLayerType

    var body: some View {
        // Temporary placeholder -- the vendored UIKit keyboard will replace this
        Text("Keyboard loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
    }
}
