// DictusKeyboard/Views/KeyButton.swift
import SwiftUI
import AudioToolbox
import DictusCore

/// A standard keyboard key that inserts a character on tap.
/// Shows a popup preview above the key during the press gesture.
/// Long-pressing a key with accented variants (e.g., "e" on AZERTY) shows an AccentPopup
/// where the user can slide their finger to select an accented character.
///
/// WHY UIViewRepresentable instead of DragGesture:
/// SwiftUI DragGesture(minimumDistance: 0) adds gesture resolution overhead (~5-10ms)
/// due to conflict resolution and minimum distance checks. UIKit touchesBegan fires
/// immediately on the UIResponder chain with zero disambiguation delay. This is the
/// single biggest latency reduction for letter key input.
/// Delete, space, and accent adaptive keys keep DragGesture because they need
/// continuous position tracking (repeat, trackpad, accent drag).
struct KeyButton: View {
    let key: KeyDefinition
    let isShifted: Bool
    let onTap: (String) -> Void

    @State private var isPressed = false

    // MARK: - Accent long-press state

    /// Whether the accent popup is currently visible.
    @State private var showingAccents = false
    /// The accented characters available for the current key.
    @State private var accentOptions: [String] = []
    /// Which accent cell the user's finger is hovering over (nil = none selected).
    @State private var selectedAccentIndex: Int? = nil
    /// The initial X position when touch started, used to calculate which accent
    /// the finger is hovering over relative to the key's center.
    @State private var touchStartX: CGFloat = 0

    private var displayLabel: String {
        isShifted ? key.label.uppercased() : key.label.lowercased()
    }

    private var outputChar: String {
        guard let output = key.output else { return "" }
        return isShifted ? output.uppercased() : output
    }

    /// Cell width matching AccentPopup's cellWidth for hit-testing calculations.
    private let accentCellWidth: CGFloat = 36

    /// Fixed font size for key labels — matches native iOS keyboard behavior.
    /// WHY not @ScaledMetric: Native iOS keyboard does NOT scale key labels with
    /// Dynamic Type. Scaling causes layout overflow on larger text sizes.
    private let keyFontSize: CGFloat = 22

    var body: some View {
        Text(displayLabel)
            .font(.system(size: keyFontSize, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: KeyMetrics.keyHeight)
            .background(keyBackground)
            // Popup preview shown above key on press (hidden when accents are showing)
            .overlay(
                Group {
                    if isPressed && !showingAccents {
                        KeyPopup(label: displayLabel)
                            .offset(y: -(KeyMetrics.keyHeight + 8))
                    }
                },
                alignment: .top
            )
            // Accent popup on long-press
            .overlay(
                Group {
                    if showingAccents {
                        AccentPopup(
                            accents: accentOptions,
                            selectedIndex: selectedAccentIndex
                        )
                        .offset(y: -(KeyMetrics.keyHeight + 12))
                    }
                },
                alignment: .top
            )
            // UIKit touch handler overlay (replaces DragGesture for zero-latency)
            .overlay(
                LetterKeyTouchView(
                    onTouchDown: { position in
                        handleTouchDown(position: position)
                    },
                    onTouchUp: {
                        handleTouchUp()
                    },
                    onLongPress: {
                        handleLongPress()
                    },
                    onDragPositionChanged: { position in
                        if showingAccents {
                            updateSelectedAccent(viewPosition: position)
                        }
                    },
                    onTouchCancelled: {
                        handleTouchCancelled()
                    }
                )
            )
    }

    // MARK: - Key Background

    /// Key background: glass on iOS 26, material fallback on older versions.
    ///
    /// WHY conditional glass:
    /// On iOS 26, the native keyboard container already has a glass-like chrome.
    /// Adding individual glass effects to keys might create glass-on-glass artifacts.
    /// We use dictusGlass which applies .glassEffect on iOS 26 and .regularMaterial
    /// on older iOS. If glass-on-glass looks wrong on iOS 26, this can be adjusted
    /// to only apply the fallback material on older versions.
    @ViewBuilder
    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius)
            .fill(KeyMetrics.letterKeyColor)
            .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
            .dictusGlass(in: RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius))
    }

    // MARK: - Touch handlers

    /// touchDown: visual highlight -> audio -> haptic -> prepare for next
    /// Per locked decision: audio AND haptic fire on touchDown (not touchUp)
    private func handleTouchDown(position: CGPoint) {
        let touchDownState = KeyTapSignposter.beginTouchDown()

        // 1. Visual highlight (T1 target: <= 16.67ms from touchDown)
        isPressed = true
        KeyTapSignposter.emitHighlight(touchDownState)

        // 2. Audio on touchDown (matches Apple keyboard: feedback on press)
        AudioServicesPlaySystemSound(KeySound.letter)

        // 3. Haptic on touchDown (matches Apple keyboard: feedback on press)
        HapticFeedback.keyTapped()
        KeyTapSignposter.emitHaptic(touchDownState)

        // 4. Prepare Taptic Engine for NEXT tap (primes hardware)
        HapticFeedback.prepareForNextTap()

        KeyTapSignposter.endTouchDown(touchDownState)

        // 5. Record initial touch position for accent popup position calculation
        touchStartX = position.x
    }

    /// touchUp: insert character or selected accent
    private func handleTouchUp() {
        let touchUpState = KeyTapSignposter.beginTouchUp()

        isPressed = false

        if showingAccents {
            // Long-press mode: insert selected accent or dismiss
            if let index = selectedAccentIndex, index >= 0, index < accentOptions.count {
                onTap(accentOptions[index])
                // No additional haptic -- already fired on touchDown
            }
            // Reset accent state
            showingAccents = false
            accentOptions = []
            selectedAccentIndex = nil
        } else {
            // Normal tap: insert character (T3 target: <= 33ms from touchUp)
            onTap(outputChar)
            // No haptic/audio -- already fired on touchDown
        }

        KeyTapSignposter.endTouchUp(touchUpState)
    }

    /// Long-press fired: show accent popup if key has accented variants
    ///
    /// WHY 400ms: iOS system keyboard uses ~350-500ms for long-press detection.
    /// 400ms balances responsiveness with avoiding false triggers during fast typing.
    /// The timer lives in LetterKeyUIView to keep it close to the touch event source.
    private func handleLongPress() {
        if let accents = AccentedCharacters.accents(for: key.label.lowercased()), !accents.isEmpty {
            if isShifted {
                accentOptions = accents.map { $0.uppercased() }
            } else {
                accentOptions = accents
            }
            showingAccents = true
            selectedAccentIndex = nil
        }
    }

    /// Touch cancelled (e.g., scroll, system interruption)
    private func handleTouchCancelled() {
        isPressed = false
        showingAccents = false
        accentOptions = []
        selectedAccentIndex = nil
    }

    // MARK: - Accent selection

    /// Maps touch position from UIView to accent popup cell index.
    ///
    /// WHY horizontal position mapping:
    /// The accent popup is a horizontal row of cells centered above the key.
    /// As the user slides their finger left/right, we calculate which cell
    /// they're over based on the horizontal distance from the initial touch.
    private func updateSelectedAccent(viewPosition: CGPoint) {
        guard !accentOptions.isEmpty else { return }

        let totalPopupWidth = CGFloat(accentOptions.count) * accentCellWidth
        let popupStartX = touchStartX - totalPopupWidth / 2

        let relativeX = viewPosition.x - popupStartX
        let index = Int(relativeX / accentCellWidth)

        if index >= 0 && index < accentOptions.count {
            selectedAccentIndex = index
        } else {
            selectedAccentIndex = nil
        }
    }
}

/// The popup preview bubble shown above a pressed key.
struct KeyPopup: View {
    let label: String

    /// Fixed popup font size — same rationale as key labels.
    private let popupFontSize: CGFloat = 32

    var body: some View {
        Text(label)
            .font(.system(size: popupFontSize, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: 50, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(KeyMetrics.letterKeyColor)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            )
    }
}

/// Device class for adaptive keyboard layout.
///
/// WHY 3 classes: Apple's keyboard uses different key sizes and spacing
/// across device families. A single set of values looks cramped on large
/// screens and oversized on compact ones.
///
/// WHY static let current: Screen size never changes during a keyboard
/// extension's lifetime. Computing once avoids per-frame UIScreen lookups.
///
/// Breakpoints based on UIScreen.main.bounds.height:
/// - compact: <= 667pt (iPhone SE 3rd gen = 667pt)
/// - standard: <= 852pt (iPhone 14/15/16 = 844-852pt)
/// - large: > 852pt (iPhone Plus/Max = 926-932pt)
///
/// NOTE: Using 667pt as compact boundary matches iPhone SE exactly.
/// iPhone 13 mini (812pt) falls into "standard" -- this is intentional because
/// its screen is physically similar to standard iPhones in width.
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

/// Shared key dimension constants, computed once per device class.
///
/// WHY all static let: These values are read hundreds of times per keyboard
/// render cycle. Static lets compute once at process launch, eliminating
/// per-frame overhead.
///
/// DIMENSION SOURCES:
/// - keyHeight: Measured from Apple keyboard screenshots across devices
///   Reference: KeyboardKit uses 51pt for iOS 26 (standard device)
/// - keySpacing: Apple keyboard inter-key gap ~6pt on standard devices
/// - rowSpacing: Apple keyboard inter-row gap ~10-11pt on standard devices
/// - rowHorizontalPadding: Apple side margins ~= inter-key gap (issue #29 finding)
/// - keyCornerRadius: Apple uses ~5pt on standard devices
enum KeyMetrics {
    /// Key height per device class.
    static let keyHeight: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 42
        case .standard: return 46
        case .large:    return 50
        }
    }()

    /// Vertical spacing between rows.
    static let rowSpacing: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 8
        case .standard: return 10
        case .large:    return 11
        }
    }()

    /// Horizontal spacing between keys within a row.
    static let keySpacing: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 5
        case .standard: return 6
        case .large:    return 6
        }
    }()

    /// Horizontal padding on each side of a row.
    /// CHANGE from old value (3pt for all): Now approximately matches keySpacing.
    /// Per issue #29: Apple keyboard side margins ~= inter-key gap.
    /// Old: 3pt uniform. New: 3pt (compact), 4pt (standard), 5pt (large).
    static let rowHorizontalPadding: CGFloat = {
        switch DeviceClass.current {
        case .compact:  return 3
        case .standard: return 4
        case .large:    return 5
        }
    }()

    /// Corner radius for key backgrounds.
    static let keyCornerRadius: CGFloat = 5

    /// Letter key background — matches native iOS keyboard.
    /// Dark mode: visible gray (not pure black). Light mode: white.
    static let letterKeyColor = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : .white
    })

    /// Pressed key background color for delete/space/return keys.
    /// Per locked decision: "brighter in dark mode, darker in light mode"
    /// Letter keys do NOT use this (they use popup only, no color change).
    static let pressedKeyColor = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.32, alpha: 1)   // brighter than 0.22 base
            : UIColor(white: 0.88, alpha: 1)   // darker than white base
    })
}
