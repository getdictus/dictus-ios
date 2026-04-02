// DictusKeyboard/TextPrediction/SuggestionState.swift
// Observable state for the suggestion bar UI, bridging TextPredictionEngine to SwiftUI.
import UIKit
import DictusCore

/// The current mode of the suggestion bar.
///
/// WHY an enum:
/// The suggestion bar displays different content depending on context:
/// - idle: empty bar (user just typed a space or field is empty)
/// - completions: showing word completions for partial input
/// - corrections: showing spell corrections for a complete misspelled word
/// The UI layer uses this to style the bar differently per mode.
enum SuggestionMode {
    case idle
    case completions
    case corrections
}

/// Tracks the last autocorrection so the user can undo it.
///
/// WHY:
/// Autocorrect can be wrong. iOS convention is that tapping the suggestion bar
/// after an autocorrection undoes it. We store the original + corrected word
/// and whether a space was auto-inserted, so undo can restore exact state.
struct AutocorrectState {
    let originalWord: String
    let correctedWord: String
    let insertedSpace: Bool
}

/// Observable suggestion state for SwiftUI binding.
///
/// WHY ObservableObject:
/// The suggestion bar is a SwiftUI view that needs to reactively update when
/// suggestions change. @Published properties trigger SwiftUI re-renders
/// automatically when the engine produces new suggestions.
///
/// WHY a separate class from TextPredictionEngine:
/// Separation of concerns: TextPredictionEngine is pure logic (testable without UI),
/// SuggestionState is the UI-facing adapter that holds @Published state and
/// handles UITextDocumentProxy interaction.
class SuggestionState: ObservableObject {

    @Published var suggestions: [String] = []
    @Published var mode: SuggestionMode = .idle
    @Published var currentWord: String = ""

    /// Tracks the last autocorrection for undo support.
    var lastAutocorrect: AutocorrectState?

    /// Words the user has rejected autocorrection for (undo'd).
    /// After undo, the same word should not be re-corrected on the next space.
    /// Cleared when the user starts typing a new word.
    var rejectedWords: Set<String> = []

    private let engine = TextPredictionEngine()

    /// Serial background queue for suggestion computation.
    /// WHY serial: Ensures suggestion computations don't race each other.
    /// WHY .userInitiated: Suggestions are user-facing but not blocking the touch pipeline.
    private let suggestionQueue = DispatchQueue(
        label: "com.pivi.dictus.suggestions",
        qos: .userInitiated
    )

    /// Current in-flight suggestion work. Cancelled when a new keystroke arrives.
    /// WHY DispatchWorkItem: Thread-safe cancellation built into GCD.
    /// Without coalescing, rapid typing queues 6-10 suggestion computations per second,
    /// all running to completion. With coalescing, only the latest keystroke runs.
    private var currentSuggestionWork: DispatchWorkItem?

    /// Whether autocorrect is enabled (reads from App Group shared preferences).
    var autocorrectEnabled: Bool {
        AppGroup.defaults.object(forKey: SharedKeys.autocorrectEnabled) as? Bool ?? true
    }

    /// Updates suggestions based on the current text input state.
    ///
    /// Called on every keystroke from the keyboard view.
    ///
    /// HOW IT WORKS:
    /// 1. Extract the last partial word from the text before the cursor
    /// 2. If it's a single accentable vowel, switch to accent mode
    /// 3. Otherwise, get word completions from the engine
    /// 4. If no partial word (after space/newline), go idle
    ///
    /// WHY UITextDocumentProxy:
    /// In a keyboard extension, we can't access the text field directly.
    /// UITextDocumentProxy is Apple's API for reading text around the cursor.
    /// documentContextBeforeInput gives us the text before the cursor position.
    func update(proxy: UITextDocumentProxy) {
        guard let context = proxy.documentContextBeforeInput, !context.isEmpty else {
            clear()
            return
        }

        // If text ends with space or newline, no partial word to complete
        if let lastChar = context.last, lastChar.isWhitespace || lastChar.isNewline {
            clear()
            return
        }

        // Extract the last word using substring enumeration
        let partial = extractLastWord(from: context)
        guard !partial.isEmpty else {
            clear()
            return
        }

        currentWord = partial

        // Show word completions
        let completions = engine.suggestions(for: partial)
        if completions.isEmpty {
            suggestions = []
            mode = .idle
        } else {
            suggestions = completions
            mode = .completions
        }
    }

    /// Async suggestion update: takes pre-read context string (read on main thread),
    /// then dispatches computation to background. Cancels previous in-flight work.
    ///
    /// WHY a separate method from update(proxy:):
    /// update(proxy:) reads UITextDocumentProxy directly and runs synchronously on main.
    /// updateAsync takes a pre-read context string so the heavy computation
    /// (extractLastWord + engine lookups) runs on a background queue.
    /// The synchronous update() is still used by delete/undo paths where fresh proxy
    /// context is needed immediately.
    func updateAsync(context: String?) {
        guard let context = context, !context.isEmpty else {
            clear()
            return
        }

        // If text ends with whitespace, no partial word
        if let lastChar = context.last, lastChar.isWhitespace || lastChar.isNewline {
            clear()
            return
        }

        // Cancel previous in-flight computation
        currentSuggestionWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let partial = self.extractLastWord(from: context)
            guard !partial.isEmpty else {
                DispatchQueue.main.async { self.clear() }
                return
            }

            // Compute on background
            let completions = self.engine.suggestions(for: partial)

            // Publish on main thread (required for @Published)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Check cancellation before publishing stale results
                guard !(self.currentSuggestionWork?.isCancelled ?? true) else { return }

                self.currentWord = partial
                if !completions.isEmpty {
                    self.suggestions = completions
                    self.mode = .completions
                } else {
                    self.suggestions = []
                    self.mode = .idle
                }
            }
        }

        currentSuggestionWork = work
        suggestionQueue.async(execute: work)
    }

    /// Delegates spell-checking to the engine.
    /// Returns the best correction and alternatives for a misspelled word, or nil if correct.
    func performSpellCheck(_ word: String) -> (correction: String, alternatives: [String])? {
        return engine.spellCheck(word)
    }

    /// Resets the suggestion state to idle.
    func clear() {
        suggestions = []
        mode = .idle
        currentWord = ""
    }

    /// Updates the prediction engine's language.
    func setLanguage(_ lang: String) {
        engine.setLanguage(lang)
    }

    // MARK: - Private

    /// Extracts the last word from a text context string.
    ///
    /// WHY manual extraction:
    /// We use Swift's built-in word boundary detection via enumerateSubstrings
    /// to correctly handle Unicode, apostrophes in French (l'homme), and
    /// other edge cases. This is more reliable than splitting on spaces.
    private func extractLastWord(from text: String) -> String {
        var lastWord = ""
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { substring, _, _, _ in
            if let word = substring {
                lastWord = word
            }
        }
        return lastWord
    }
}
