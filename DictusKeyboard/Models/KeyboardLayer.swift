// DictusKeyboard/Models/KeyboardLayer.swift
import Foundation

/// Represents a full keyboard layer (letters, numbers, symbols).
enum KeyboardLayerType: Equatable {
    case letters
    case numbers
    case symbols
    case emoji
}

// NOTE: KeyboardLayer struct removed in Phase 18 -- replaced by giellakbd-ios KeyboardPage.
// KeyboardLayerType enum kept for KeyboardRootView compatibility during migration.
