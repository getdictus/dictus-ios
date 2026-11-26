// DictusKeyboard/DictusKeyboardBridge+SwipeTyping.swift
//
// Swipe typing's document side (#948): the word a swipe types, the readings the bar offers
// for it, and what Delete, space and the next key do right after it. After Hex's
// `FullKeyboardEngine` swipe methods (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// ios/HEXShared/FullKeyboard/Engine/FullKeyboardEngine.swift and
// FullKeyboardEngine+SwipeTyping.swift; MIT, Copyright (c) 2026 Christopher Langton, full
// notice in DictusCore's SwipeTypingText.swift), rewritten on Dictus's bridge: the text
// rules are DictusCore's `SwipeTypingText` and `SwipedWord`.
import DictusCore
import UIKit

extension DictusKeyboardBridge: SwipeTypingOutput {

    // MARK: - On or off

    /// Gives the keyboard view a swipe controller when swipe typing acts, and takes it away
    /// otherwise. Called for every new keyboard view and at every appearance, which is when
    /// a switch changed in the app can first be seen.
    ///
    /// With the switch off (its default), in the App Store build, outside English, French,
    /// Spanish and German, or without the language's model, the view holds no controller: the keyboard
    /// is exactly the keyboard without swipe typing. The line logged says which.
    func refreshSwipeTyping(trigger: String) {
        guard let view = keyboardView else { return }
        // The bar is shared by every keyboard instance (`SuggestionState.shared`): a swipe's
        // readings left from the last appearance belong to a record this view never had.
        if let state = suggestionState, state.mode == .swipeAlternatives || state.mode == .swipePreview {
            state.clear()
        }
        let settings = KeyboardFeatureSettings.forKeyboard()
        let language = SupportedLanguage.active
        var availability = SwipeTypingText.availability(settings, language: language)
        let model = availability == .on ? SpatialAutocorrect.decoder(for: language.rawValue)?.model : nil
        if availability == .on, model == nil { availability = .language }
        let channel = AppDistribution.recorded()?.rawValue ?? "none"
        PersistentLog.log(.swipeTypingConfigured(on: availability == .on, channel: channel, reason: "\(trigger):\(availability.rawValue)"))

        guard let model else {
            view.swipeTyping = nil
            swipedWord = nil
            return
        }
        let showsTrail = settings.isSwipeTrailEffective
        if let current = view.swipeTyping, current.language == model.language, (current.trail != nil) == showsTrail {
            return
        }
        let controller = SwipeTypingController(model: model, showsTrail: showsTrail)
        controller.output = self
        // A field with no suggestion bar (an address, a password, a URL) takes no swipes:
        // there would be nowhere to offer the other readings.
        controller.allowsSwipes = { [weak self] in self?.suggestionState?.hostPolicy.suggestionsAllowed ?? false }
        view.swipeTyping = controller
    }

    // MARK: - SwipeTypingOutput

    func swipeTypingContextBefore() -> String? {
        controller?.textDocumentProxy.documentContextBeforeInput
    }

    func swipeTypingDidBegin() {
        suggestionState?.showSwipePreview(nil)
    }

    func swipeTypingPreview(_ readings: [String]) {
        guard let first = readings.first else { return }
        let before = swipeTypingContextBefore()
        let casing = swipeCasing(before: before)
        let written = nounsCapitalised(ownWordsWritten([first]), before: before)[0]
        suggestionState?.showSwipePreview(SwipeTypingText.cased(written, capital: casing.capital, capsLock: casing.capsLock))
    }

    /// The swipe lifted: its best reading goes in, after a space unless the text before
    /// ends in one or in opening punctuation, with a capital when shift is on or the swipe's
    /// own space starts a sentence (all capitals with caps lock); the next three wait in
    /// the bar. Nothing goes in when it read as nothing.
    func swipeTypingDidEnd(readings: [String]) {
        guard let proxy = controller?.textDocumentProxy, !readings.isEmpty else {
            restoreBarAfterDroppedSwipe()
            return
        }
        KeyboardState.shared.invalidateDictationUndo(reason: "swipe")
        learnWordMovedPast()
        // The undo chip offered to undo a correction of the word before; it is behind a
        // new word now.
        suggestionState?.pendingUndo = nil

        let before = proxy.documentContextBeforeInput
        let casing = swipeCasing(before: before)
        let cased = SwipeTypingText.unique(nounsCapitalised(ownWordsWritten(readings), before: before).map {
            SwipeTypingText.cased($0, capital: casing.capital, capsLock: casing.capsLock)
        })
        let record = SwipedWord(word: cased[0], addedSpace: casing.addsSpace, alternatives: Array(cased.dropFirst()))

        let mirrorBefore = mirrorLength()
        proxy.insertText(record.inserted)
        observeMirror(before: mirrorBefore, inserted: record.inserted.count)
        noteSwipedWordInserted(record.word)
        swipedWord = record
        // One tick per word the lift types, the key tap's own (`keyTapped` honours the
        // Haptique setting): Pierre's device test, 2026-11-24. None while the finger moves,
        // none for a swipe that read as nothing (the `guard` above), none for a tap that slid
        // (its tick came on touch-down, like any tap's). Hex gives none on lift.
        HapticFeedback.keyTapped()

        // Shift is one-shot, as after a typed letter.
        if keyboardView?.page == .shifted {
            keyboardView?.page = .normal
            isManualShift = false
        }
        updateCapitalization()
        updateAccentKeyDisplay()
        suggestionState?.showSwipeAlternatives(SwipeTypingText.barOrder(record.alternatives))
    }

    func swipeTypingDidCancel() {
        restoreBarAfterDroppedSwipe()
    }

    /// The user's own words for the swipe (#1090): adopted learned words, contact names and
    /// text replacements, by the rules of `SwipeOwnWords.words`.
    func swipeTypingOwnWords() -> [String] {
        SwipeOwnWords.words(
            learnedUses: UserDictionary.shared.allLearnedWords,
            lexiconWords: TextPredictionEngine.shared.lexiconWords
        )
    }

    /// A swipe that typed nothing gives the bar back: the readings of the word a swipe typed
    /// before it, while that word is still before the cursor, else the usual suggestions.
    private func restoreBarAfterDroppedSwipe() {
        let before = swipeTypingContextBefore()
        if let record = swipedWord, !hasSelection, record.isBeforeCursor(before) {
            suggestionState?.showSwipeAlternatives(SwipeTypingText.barOrder(record.alternatives))
        } else {
            suggestionState?.updateAsync(context: before)
        }
    }

    /// Whether the host has text selected: an edit then replaces the selection, so nothing
    /// that counts on the cursor sitting right after the swiped word applies.
    private var hasSelection: Bool {
        guard let selected = controller?.textDocumentProxy.selectedText else { return false }
        return !selected.isEmpty
    }

    // MARK: - Right after a swiped word

    /// Delete's count right after a swipe: the word and the space it added, when the text
    /// still ends with them and nothing is selected. Nil otherwise, and Delete deletes one
    /// character (or the selection).
    func swipedWordDeletionCount(before: String?) -> Int? {
        guard let record = swipedWord, !hasSelection else { return nil }
        return record.deletionCount(before: before)
    }

    /// Whether the word before the cursor is the one a swipe just typed.
    func isSwipedWordBeforeCursor() -> Bool {
        swipedWord?.isBeforeCursor(swipeTypingContextBefore()) ?? false
    }

    /// A letter, digit or opening mark tapped right after a swipe goes in after a space, as
    /// Apple's keyboard keeps one pending after a swiped word ("hello" then "w" types
    /// "hello w"); punctuation that goes against a word ("hello,") does not.
    func spaceAfterSwipedWord(before character: String) {
        guard let record = swipedWord, SwipeTypingText.startsNextWord(character),
              let proxy = controller?.textDocumentProxy, !hasSelection,
              record.isBeforeCursor(proxy.documentContextBeforeInput)
        else { return }
        swipedWord = nil
        let mirrorBefore = mirrorLength()
        proxy.insertText(" ")
        observeMirror(before: mirrorBefore, inserted: 1)
        mirrorSync.noteBoundaryInserted(reason: "swipe-space", atLength: mirrorLength())
        lastInsertedCharacter = " "
    }

    /// A tap on one of the bar's readings after a swipe: it takes the swiped word's place,
    /// and the word joins the readings offered.
    func replaceSwipedWord(with reading: String) {
        guard let proxy = controller?.textDocumentProxy, let record = swipedWord,
              !hasSelection,
              let change = record.replacing(with: reading, before: proxy.documentContextBeforeInput) else {
            // The text moved under the bar: offer nothing rather than glue a word on.
            swipedWord = nil
            suggestionState?.clear()
            return
        }
        let mirrorBefore = mirrorLength()
        for _ in 0..<change.deleteCount {
            proxy.deleteBackward()
        }
        proxy.insertText(change.insert)
        observeMirror(before: mirrorBefore, deleted: change.deleteCount, inserted: change.insert.count)
        noteSwipedWordInserted(change.insert)
        swipedWord = change.record
        updateCapitalization()
        updateAccentKeyDisplay()
        suggestionState?.showSwipeAlternatives(SwipeTypingText.barOrder(change.record.alternatives))
    }

    // MARK: - Helpers

    /// The readings as the user writes them (#1090, `SwipeOwnWords.written`): a contact or an
    /// app name in its casing, by the lexicon's decision tap typing uses, an adopted learned
    /// word as the user types it (« Apple » mid-sentence).
    private func ownWordsWritten(_ readings: [String]) -> [String] {
        let dictionary = UserDictionary.shared
        let learned = dictionary.allLearnedWords
        return readings.map { reading in
            SwipeOwnWords.written(
                reading,
                lexiconDecision: { TextPredictionEngine.shared.lexiconDecision(for: $0) },
                learned: { word in
                    learned[word].map { SwipeOwnWords.Learned(uses: $0, casing: dictionary.casing(of: word)) }
                }
            )
        }
    }

    /// German readings as German writes them: a noun with its capital ("Haus", "Straße"),
    /// a verb or an adjective in lowercase ("gehen", "groß"), from `de.capitals` and the word
    /// before. The readings of any other language are returned as they are.
    private func nounsCapitalised(_ readings: [String], before: String?) -> [String] {
        guard let language = keyboardView?.swipeTyping?.language,
              let capitals = SpatialAutocorrect.capitals(for: language) else { return readings }
        return capitals.written(readings, before: before)
    }

    /// How a swiped word goes in at the cursor.
    private struct SwipeCasing {
        let capital: Bool
        let capsLock: Bool
        /// Whether it needs a space before it.
        let addsSpace: Bool
    }

    private func swipeCasing(before: String?) -> SwipeCasing {
        let page = keyboardView?.page
        let addsSpace = SwipeTypingText.needsSpace(before: before)
        let capital = SwipeTypingText.startsWithCapital(
            shifted: page == .shifted, before: before, addsSpace: addsSpace,
            autocapitalization: Self.autocapitalization(controller?.textDocumentProxy.autocapitalizationType)
        )
        return SwipeCasing(capital: capital, capsLock: page == .capslock, addsSpace: addsSpace)
    }

    /// The last two characters the keyboard put in, which the adaptive accent key reads.
    private func noteSwipedWordInserted(_ word: String) {
        lastInsertedCharacter = word.last.map(String.init)
        secondToLastInsertedCharacter = word.dropLast().last.map(String.init)
    }

    /// `UITextAutocapitalizationType` in DictusCore's terms; a host that says nothing gets
    /// sentences, as `updateCapitalization` assumes.
    private static func autocapitalization(_ type: UITextAutocapitalizationType?) -> SwipeTypingText.Autocapitalization {
        guard let type else { return .sentences }
        switch type {
        case .none: return .none
        case .words: return .words
        case .allCharacters: return .allCharacters
        case .sentences: return .sentences
        @unknown default: return .sentences
        }
    }
}
