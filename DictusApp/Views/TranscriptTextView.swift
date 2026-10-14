// DictusApp/Views/TranscriptTextView.swift
// A saved transcript the user can select part of, with Add to Vocabulary next to Copy (#723).
import SwiftUI
import UIKit
import DictusCore

/// The text of a saved transcript, selectable word by word, whose edit menu offers
/// **Add to Vocabulary** beside the system's own Copy (#723).
///
/// ### WHY a `UITextView` and not SwiftUI's `Text` with `.textSelection(.enabled)`
///
/// Two reasons, and either would be enough. On iOS, `.textSelection` on a `Text`
/// selects the whole string: the long-press offers Copy and Share for all of it, so
/// there is no word to pick. And SwiftUI has no way to add an item to that menu.
/// `UITextView` gives the real selection handles, and its delegate builds the edit
/// menu (`textView(_:editMenuForTextIn:suggestedActions:)`, iOS 16, so inside the
/// iOS 17 floor). That is the native idiom the issue asks for: no chips, no custom
/// selection UI.
///
/// The single-range delegate method is the one implemented. Its multi-range
/// replacement exists only from iOS 26, and UIKit calls the single-range one with the
/// union range when the other is absent, which is what a transcript, one block of
/// plain text, ever has.
struct TranscriptTextView: UIViewRepresentable {

    let text: String

    /// Called with the variant the selection stands for (`ObservedVariant`) when the
    /// user picks **Add to Vocabulary**.
    let onAddToVocabulary: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        // The screen scrolls, not the text: with scrolling off the view reports its
        // full height, and `sizeThatFits` below can hand it to SwiftUI.
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        // Aligned with the `Text` this replaces: no inset, no line-fragment padding,
        // so the glass card's own padding is the only margin.
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        // `.dictusBody` is `.system(.body)`; this is its UIKit spelling, and it follows
        // Dynamic Type the way the SwiftUI font did.
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        // A transcript is words the user spoke. A date or a number turned into a link
        // would make a tap do something else than place the selection.
        view.dataDetectorTypes = []
        view.delegate = context.coordinator
        // Without this the text view asks for its single-line width and pushes the
        // card wider than the screen before `sizeThatFits` gets a say.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        // Compared first: setting `text` clears the selection, and SwiftUI calls this
        // on every body pass of the screen around it.
        if view.text != text {
            view.text = text
        }
        context.coordinator.onAddToVocabulary = onAddToVocabulary
    }

    /// The height the text needs at the width SwiftUI offers, so the view wraps like
    /// the `Text` it replaces instead of claiming one line or the whole screen.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {

        var onAddToVocabulary: ((String) -> Void)?

        /// The system menu, with **Add to Vocabulary** inserted right after its first
        /// group, the one that holds Copy.
        ///
        /// Returns nil — the system's own menu, untouched — whenever the item has
        /// nothing to offer: the selection is empty or too long to be a variant
        /// (`ObservedVariant`), or the vocabulary is not available. That last check is
        /// made here, when the menu opens, and not when the screen was built: the
        /// entitlement and the feature's switch can both change while the screen is
        /// open, and `VocabularyStore.add` would refuse the entry anyway.
        func textView(_ textView: UITextView,
                      editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let onAddToVocabulary,
                  VocabularyAvailability.isEntitled,
                  let text = textView.text,
                  let selected = Range(range, in: text),
                  let variant = ObservedVariant.from(selection: String(text[selected])) else {
                return nil
            }
            let add = UIAction(
                title: String(localized: "Add to Vocabulary",
                              comment: "Edit menu item on a selection in a saved transcript: opens the vocabulary sheet with the selection as the variant (#723)."),
                image: UIImage(systemName: ProFeature.vocabulary.icon)
            ) { _ in
                onAddToVocabulary(variant)
            }
            var children = suggestedActions
            children.insert(add, at: min(1, children.count))
            return UIMenu(children: children)
        }
    }
}
