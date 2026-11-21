// DictusCore/Sources/DictusCore/TextCorrection/CorrectedWordAccents.swift
// A trie correction written with the accents the accent pass would give it (#1006).
import Foundation

/// Runs the word a trie correction writes through the accent pass, with the previous
/// word, as a typed word is (#1006). `est zrrive` is corrected to `arrive`, and after
/// `est` the accent pass writes `arrivé`. `il zrrive` stays `arrive`.
///
/// The trie finds the letters and cannot read the context, and the accent pass reads the
/// context but only ran on the word as typed.
public enum CorrectedWordAccents {

    /// `proposal` with its correction accented when the accent pass restores one. The
    /// alternatives trade places with it, so the bar still offers the bare form. An
    /// ambiguous decision and a suggestion leave the proposal as it is.
    /// - Parameter restore: the accent pass for one word, the previous word bound in.
    public static func restored(
        _ proposal: CorrectionProposal,
        restore: (String) -> AccentRestoration.Decision
    ) -> CorrectionProposal {
        guard case let .autocorrect(correction, alternatives) = proposal,
              case let .restore(accented) = restore(correction), accented != correction else { return proposal }
        let others = alternatives.map { $0 == accented ? correction : $0 }
        return .autocorrect(accented, alternatives: others.contains(correction) ? others : [correction] + others.prefix(1))
    }
}
