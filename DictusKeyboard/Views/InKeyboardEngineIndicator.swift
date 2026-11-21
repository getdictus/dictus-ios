// DictusKeyboard/Views/InKeyboardEngineIndicator.swift

/// How the dictation banner says that Apple's dictation is transcribing, not the app's
/// model (#992): "Listening... · Apple", inside the existing caption line. Pierre chose
/// this text variant on 2026-11-21 over a small device icon.
enum InKeyboardEngineIndicator {
    /// The engine's name, appended to the caption. A product name, not translated.
    static let label = "Apple"
}
