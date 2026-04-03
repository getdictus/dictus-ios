// DictusCore/Sources/DictusCore/UserDictionary.swift
// Persistent user-learned words dictionary stored in App Group.
import Foundation

/// Stores words the user has taught the keyboard through usage patterns.
///
/// HOW WORDS ARE LEARNED:
/// 1. Rejection learning: user types "helo" → autocorrected to "hello" → user
///    presses backspace to undo → "helo" is immediately learned (strong signal).
/// 2. Repetition learning: user types an unknown word multiple times → after
///    `repetitionThreshold` occurrences, the word is learned.
///
/// WHY App Group UserDefaults:
/// The dictionary must be shared between DictusApp and DictusKeyboard extension.
/// UserDefaults via App Group is the simplest cross-process storage on iOS.
/// For a typical user dictionary (hundreds to low thousands of words), the
/// serialization overhead is negligible.
///
/// WHY a separate class in DictusCore:
/// Both the keyboard extension (for learning + lookup) and the main app
/// (for a future "manage learned words" UI) need access to the same data.
public final class UserDictionary {

    /// Singleton shared instance. Uses App Group storage.
    public static let shared = UserDictionary()

    /// Key in App Group UserDefaults for the learned words dictionary.
    /// Stored as [String: Int] where key = lowercase word, value = usage count.
    private static let storageKey = "dictus.userDictionary"

    /// Key for the repetition counter (words being "observed" before learning).
    /// Stored as [String: Int] where key = lowercase word, value = times typed.
    private static let pendingKey = "dictus.userDictionary.pending"

    /// Number of times an unknown word must be typed before it's learned.
    /// 2 is the sweet spot: first time could be a typo, second time is intentional.
    public static let repetitionThreshold = 2

    /// In-memory cache of learned words. Synced to UserDefaults on mutation.
    private var learnedWords: [String: Int] = [:]

    /// Temporary counter for words being observed (not yet learned).
    private var pendingWords: [String: Int] = [:]

    private init() {
        loadFromDefaults()
    }

    // MARK: - Public API

    /// Whether a word has been learned by the user.
    public func isLearned(_ word: String) -> Bool {
        learnedWords[word.lowercased()] != nil
    }

    /// All learned words with their usage counts.
    /// Useful for a future "manage dictionary" UI in the app.
    public var allLearnedWords: [String: Int] {
        learnedWords
    }

    /// Number of learned words.
    public var count: Int { learnedWords.count }

    /// Learn a word immediately (e.g., after user rejects autocorrection).
    /// The word is stored lowercase. If already learned, increments usage count.
    public func learn(_ word: String) {
        let key = word.lowercased()
        guard !key.isEmpty, key.count > 1 else { return }
        learnedWords[key, default: 0] += 1
        // Remove from pending if it was being tracked
        pendingWords.removeValue(forKey: key)
        saveToDefaults()
    }

    /// Record that an unknown word was typed. If it reaches the repetition
    /// threshold, it's automatically learned. Returns true if the word was
    /// just learned (crossed the threshold this call).
    @discardableResult
    public func recordUsage(_ word: String) -> Bool {
        let key = word.lowercased()
        guard !key.isEmpty, key.count > 1 else { return false }

        // Already learned — just bump usage count
        if learnedWords[key] != nil {
            learnedWords[key]! += 1
            saveToDefaults()
            return false
        }

        // Increment pending counter
        pendingWords[key, default: 0] += 1

        if pendingWords[key]! >= Self.repetitionThreshold {
            // Threshold reached — promote to learned
            learnedWords[key] = pendingWords[key]!
            pendingWords.removeValue(forKey: key)
            saveToDefaults()
            print("[UserDictionary] Learned '\(key)' after \(Self.repetitionThreshold) uses")
            return true
        }

        savePendingToDefaults()
        return false
    }

    /// Remove a learned word (e.g., user removes it from dictionary management UI).
    public func forget(_ word: String) {
        let key = word.lowercased()
        learnedWords.removeValue(forKey: key)
        pendingWords.removeValue(forKey: key)
        saveToDefaults()
    }

    /// Reload from App Group (useful if the other process updated the dictionary).
    public func reload() {
        loadFromDefaults()
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        let defaults = AppGroup.defaults
        learnedWords = defaults.dictionary(forKey: Self.storageKey) as? [String: Int] ?? [:]
        pendingWords = defaults.dictionary(forKey: Self.pendingKey) as? [String: Int] ?? [:]
    }

    private func saveToDefaults() {
        let defaults = AppGroup.defaults
        defaults.set(learnedWords, forKey: Self.storageKey)
        defaults.set(pendingWords, forKey: Self.pendingKey)
    }

    private func savePendingToDefaults() {
        AppGroup.defaults.set(pendingWords, forKey: Self.pendingKey)
    }
}
