// DictusKeyboard/Views/KeyButton.swift
import SwiftUI
import AudioToolbox
import DictusCore

/// A standard keyboard key that inserts a character on tap.
/// Shows a popup preview above the key during the press gesture.
/// Long-pressing a key with accented variants (e.g., "e" on AZERTY) shows an AccentPopup
/// where the user can slide their finger to select an accented character.
///
/// WHY DragGesture handles both tap and long-press:
/// SwiftUI's LongPressGesture doesn't provide continuous drag tracking after recognition.
/// By using DragGesture alone with a Task.sleep timer, we get: (1) normal tap when released
/// before 400ms, (2) long-press accent popup when held past 400ms, (3) continuous drag
/// tracking to highlight the accent under the finger. This is how Apple's own keyboard works.
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
    /// The async task that waits 400ms before showing the accent popup.
    /// Stored so it can be cancelled if the user lifts their finger early (normal tap).
    @State private var longPressTimer: Task<Void, Never>? = nil
    /// The initial X position when the drag started, used to calculate which accent
    /// the finger is hovering over relative to the key's center.
    @State private var dragStartX: CGFloat? = nil

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
        // Using a plain gesture to get press/release states
        Text(displayLabel)
            .font(.system(size: keyFontSize, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: KeyMetrics.keyHeight)
            .background(keyBackground)
            .overlay(
                // Popup preview shown above key on press (hidden when accents are showing)
                Group {
                    if isPressed && !showingAccents {
                        KeyPopup(label: displayLabel)
                            .offset(y: -(KeyMetrics.keyHeight + 8))
                    }
                },
                alignment: .top
            )
            .overlay(
                // Accent popup shown on long-press, positioned above the key.
                // Uses .top alignment so offset pushes it above the key.
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressed {
                            // === TOUCH DOWN ===
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

                            // 5. Start long-press timer for accent popup
                            dragStartX = value.location.x
                            startLongPressTimer()
                        }

                        // While accents are showing, track finger position to highlight
                        if showingAccents {
                            updateSelectedAccent(dragLocation: value.location)
                        }
                    }
                    .onEnded { _ in
                        let touchUpState = KeyTapSignposter.beginTouchUp()

                        isPressed = false
                        longPressTimer?.cancel()
                        longPressTimer = nil

                        if showingAccents {
                            // Long-press mode: insert selected accent or dismiss
                            if let index = selectedAccentIndex, index >= 0, index < accentOptions.count {
                                onTap(accentOptions[index])
                                // No additional haptic — already fired on touchDown
                            }
                            // Reset accent state
                            showingAccents = false
                            accentOptions = []
                            selectedAccentIndex = nil
                        } else {
                            // Normal tap: insert character (T3 target: <= 33ms from touchUp)
                            onTap(outputChar)
                            // No haptic/audio — already fired on touchDown
                        }
                        dragStartX = nil

                        KeyTapSignposter.endTouchUp(touchUpState)
                    }
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

    // MARK: - Long-press helpers

    /// Starts a 400ms timer. If the timer completes (user hasn't lifted finger),
    /// check if the key has accented variants and show the popup.
    ///
    /// WHY 400ms:
    /// iOS system keyboard uses ~350-500ms for long-press detection. 400ms balances
    /// responsiveness (not too slow) with avoiding false triggers during fast typing.
    private func startLongPressTimer() {
        longPressTimer?.cancel()
        longPressTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms

            // Check cancellation — user may have lifted finger before 400ms
            guard !Task.isCancelled else { return }

            // Look up accented variants for this key
            if let accents = AccentedCharacters.accents(for: key.label.lowercased()), !accents.isEmpty {
                // Apply shift state: uppercase the accented characters when shifted
                if isShifted {
                    accentOptions = accents.map { $0.uppercased() }
                } else {
                    accentOptions = accents
                }
                showingAccents = true
                selectedAccentIndex = nil
            }
        }
    }

    /// Maps the current drag position to a selected accent index.
    ///
    /// WHY horizontal position mapping:
    /// The accent popup is a horizontal row of cells centered above the key.
    /// As the user slides their finger left/right, we calculate which cell
    /// they're over based on the horizontal distance from center.
    private func updateSelectedAccent(dragLocation: CGPoint) {
        guard !accentOptions.isEmpty else { return }

        // The popup is centered above the key. Calculate the offset from
        // the drag start position to determine which cell the finger is over.
        let totalPopupWidth = CGFloat(accentOptions.count) * accentCellWidth
        let popupStartX = (dragStartX ?? 0) - totalPopupWidth / 2

        // Calculate which cell the finger is over
        let relativeX = dragLocation.x - popupStartX
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
