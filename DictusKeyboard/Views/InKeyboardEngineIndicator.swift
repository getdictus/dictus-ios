// DictusKeyboard/Views/InKeyboardEngineIndicator.swift

/// How the dictation banner says that Apple's dictation is transcribing, not the app's
/// model (#992, Pierre 2026-11-21): discreet, inside the existing caption line.
///
/// Two variants were built for Pierre to pick from; the one not picked stays here,
/// one constant away.
enum InKeyboardEngineIndicator {
    enum Style {
        /// "Listening... · Apple" after the caption.
        case label
        /// A small device symbol before the caption.
        case icon
    }

    static let style: Style = .label

    /// The engine's name, shown by `.label` and read by VoiceOver for `.icon`.
    static let label = "Apple"

    /// On-device, not Apple's logo (reserved by Apple's guidelines).
    static let iconName = "iphone"
}
