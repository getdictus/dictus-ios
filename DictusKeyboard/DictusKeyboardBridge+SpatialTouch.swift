// DictusKeyboard/DictusKeyboardBridge+SpatialTouch.swift
//
// Where the finger landed, on the document side: the taps the spatial decoder reads on
// space (#1011) and what Adaptive touch learns from them (#1014), with the field gate that
// decides where it learns. Both are Hex's (github.com/anomalyco/hex, MIT, Copyright (c)
// 2026 Christopher Langton), ported in DictusCore/SpatialDecoder and
// DictusCore/AdaptiveTouch; their switches are `SpatialAutocorrect` and
// `AdaptiveTouchSwitch`.
import DictusCore
import UIKit

// MARK: - Spatial autocorrect (#1011)

extension DictusKeyboardBridge {
    /// Records where `typed` was tapped, for the spatial decoder. `context` is the
    /// document after the keystroke: the buffer keeps the tap only while it agrees with
    /// the token there.
    func noteSpatialTap(_ typed: String, context: String?, replacing: Bool = false) {
        guard SpatialAutocorrect.isOn else { return }
        spatialTouches.typed(
            typed, at: keyboardView?.lastTriggerPoint, keys: keyboardView?.spatialKeys(),
            token: SpatialTouchBuffer.token(before: context), replacing: replacing
        )
        // #1014: a letter key's letter. The accent key's vowel keeps the vowel key's tap, and
        // its apostrophe is no letter.
        guard !replacing, typed.count == 1, typed.first?.isLetter == true, let adaptive = adaptiveLearner else { return }
        adaptive.typed(typed, at: keyboardView?.lastTriggerPoint, slid: keyboardView?.lastTriggerSlid ?? false,
                       keys: keyboardView?.spatialKeys())
    }

    /// A backspace, which deleted the last character of `before`; the document now reads
    /// `after`.
    func noteSpatialDeletion(before: String?, after: String?) {
        guard SpatialAutocorrect.isOn else { return }
        spatialTouches.deleted(token: SpatialTouchBuffer.token(before: after))
        noteAdaptiveDeletion(before: before)
    }

    /// The delete swipe (#609) changed the text by whole words, deleted or given back; the
    /// document now reads `after`. The tap buffer follows the token as after a backspace.
    /// Adaptive touch cannot label a word-sized edit as it labels an erased letter, so it
    /// keeps only what the document still agrees with, as after any edit it did not make.
    func noteSpatialSlideEdit(after: String?) {
        guard SpatialAutocorrect.isOn else { return }
        spatialTouches.deleted(token: SpatialTouchBuffer.token(before: after))
        AdaptiveTouchSwitch.current?.hostChanged(before: after)
    }

    /// The taps of `word` and the keys they were made on, when the buffer holds them and
    /// the switch is on. Nil otherwise, and the engine then never consults the decoder.
    func spatialInput(for word: String) -> SpatialCorrection.Input? {
        // #1014: with Adaptive touch on and a profile in use, the taps are read with this
        // user's centres, and the stock ones are the baseline no correction may go past.
        AdaptiveTouchSwitch.runtime.decoderInput(
            spatialTouches.decoderInput(for: word, isOn: SpatialAutocorrect.isOn)
        )
    }

    /// Reads the Experiments switches the app may have changed while the keyboard was away:
    /// spatial autocorrect, Adaptive touch and the bilingual check here, from the same
    /// settings, then swipe typing. Called for every new keyboard view and at every
    /// appearance.
    func refreshExperiments(trigger: String) {
        let settings = KeyboardFeatureSettings.forKeyboard()
        let wasOn = SpatialAutocorrect.isOn
        let isOn = SpatialAutocorrect.refresh(settings)
        // The partner engine follows at the next `SuggestionState.setLanguage` (#1015).
        BilingualAutocorrect.refresh(settings)
        // Taps recorded under the other answer belong to no decode now.
        if isOn != wasOn { spatialTouches.clear() }
        let adaptiveOn = AdaptiveTouchSwitch.refresh(settings)
        let channel = AppDistribution.recorded()?.rawValue ?? "none"
        PersistentLog.log(.spatialAutocorrectConfigured(on: isOn, channel: channel, trigger: trigger))
        PersistentLog.log(.adaptiveTouchConfigured(on: adaptiveOn, trigger: trigger))
        // #1081: what it learned, from the learner in memory (the App Group file while off),
        // once per appearance and never per keystroke.
        PersistentLog.log(AdaptiveTouchSwitch.statusEvent())
        refreshSwipeTyping(trigger: trigger)
    }
}

// MARK: - Adaptive touch (#1014)

extension DictusKeyboardBridge {
    /// The learner, where this field lets it learn: autocorrect runs here (the host policy
    /// of #1004/#1005) and the field holds no secret (the typing journal's gate, #1002).
    /// Elsewhere what it holds of the words being typed goes.
    var adaptiveLearner: AdaptiveTouch? {
        guard let adaptive = AdaptiveTouchSwitch.current else { return nil }
        guard let state = suggestionState, state.autocorrectEnabled, state.hostPolicy.autocorrectAllowed,
              fieldHoldsNoSecret else {
            adaptive.forget()
            return nil
        }
        return adaptive
    }

    /// Secure entry, passwords, one-time codes and card numbers never teach.
    private var fieldHoldsNoSecret: Bool {
        guard let proxy = controller?.textDocumentProxy else { return false }
        // The gate itself is a pure DictusCore rule, in every build: TestFlight is a
        // Release build, and the journal only records in Debug ones.
        return TypingJournalFieldGate.skipReason(
            isSecureEntry: proxy.isSecureTextEntry ?? false,
            content: HostInputTraits.journalContent(proxy.textContentType)
        ) == nil
    }

    /// The text or the caret changed, maybe not by this keyboard: what the learner follows
    /// of the words being typed goes unless the document still agrees with it.
    func noteAdaptiveHostChange() {
        AdaptiveTouchSwitch.current?.hostChanged(before: controller?.textDocumentProxy.documentContextBeforeInput)
    }

    /// The keyboard appeared, in a field: a new session for the profile's evidence.
    func adaptiveTouchSessionBegan() {
        AdaptiveTouchSwitch.current?.beginSession()
    }

    /// Backspace deleted the last character of `before`.
    func noteAdaptiveDeletion(before: String?) {
        guard let adaptive = adaptiveLearner else { return }
        adaptive.willDelete(before: before)
    }

    /// How a word ended, for Adaptive touch: what autocorrect put in its place, and whether
    /// it revised the word before too (an elision across the space, #1006).
    struct AdaptiveWordEnd {
        var correction: String?
        /// A text replacement's phrase (#1022): not a correction, the shortcut teaches as
        /// typed (#1031).
        var expansion: String?
        var revisesPrevious = false
    }

    /// A word ended in `before` (the text before the cursor, still ending in it).
    func noteAdaptiveFinish(before: String?, _ end: AdaptiveWordEnd) {
        guard let adaptive = adaptiveLearner else { return }
        adaptive.finish(corrected: end.correction, expanded: end.expansion, previousRevised: end.revisesPrevious,
                        before: before)
    }

    /// Undo put `original` back over the autocorrection.
    func noteAdaptiveUndo(original: String) {
        guard let adaptive = adaptiveLearner else { return }
        adaptive.undone(original: original)
    }

    /// A suggestion is about to replace the word being typed. `overCorrection`: the user
    /// tapped what they typed while space would have corrected it.
    func noteAdaptivePick(replacement: String, overCorrection: Bool) {
        guard let adaptive = adaptiveLearner else { return }
        adaptive.picked(replacement: replacement, overCorrection: overCorrection,
                        before: controller?.textDocumentProxy.documentContextBeforeInput)
    }
}
