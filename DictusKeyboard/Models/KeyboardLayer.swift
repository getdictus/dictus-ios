// DictusKeyboard/Models/KeyboardLayer.swift
import Foundation

/// Represents a full keyboard layer (letters, numbers, symbols).
enum KeyboardLayerType {
    case letters
    case numbers
    case symbols
}

struct KeyboardLayer {
    let type: KeyboardLayerType
    let rows: [[KeyDefinition]]
}
