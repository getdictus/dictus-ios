// DictusCore/Sources/DictusCore/OnboardingPhoneFit.swift
// How wide the drawn iPhone of an onboarding scene is, so it fits the height it has (#700).
import Foundation

/// The width of the card holding an onboarding scene's drawn iPhone (`OnboardingPhoneCard`).
///
/// WHY (#700): the Smart Modes scene shows the bottom of a phone, and its subject, the
/// keyboard's mic, is the last row of the drawing. Sized to the page's width, the card is
/// taller than what a 667 pt screen leaves under the title once the button and the Skip row
/// are reserved, so the mic went under the fold. The card now takes the page's width when
/// the height allows it, as before, and otherwise narrows until the whole drawing fits:
/// the scene keeps its proportions and nothing in it is cut.
///
/// WHY IN DICTUSCORE: it is arithmetic with edge cases, and the app target has no test
/// bundle.
public enum OnboardingPhoneFit {
    /// The card's width.
    ///
    /// - Parameters:
    ///   - availableWidth: the width the page gives the card.
    ///   - availableHeight: the height left for the card under the title.
    ///   - sceneAspectRatio: the scene's width over its height.
    ///   - horizontalChrome: what the card adds around the scene across (insets and the
    ///     phone's outline, both sides).
    ///   - verticalChrome: what the card adds to the scene's height (the inset and the
    ///     outline at the end the card shows; the other end is cut).
    /// - Returns: `availableWidth` when the drawing fits at that width, a narrower width
    ///   that makes it exactly as tall as `availableHeight` otherwise, and never less than
    ///   the chrome itself.
    public static func cardWidth(
        availableWidth: Double,
        availableHeight: Double,
        sceneAspectRatio: Double,
        horizontalChrome: Double,
        verticalChrome: Double
    ) -> Double {
        guard sceneAspectRatio > 0, availableWidth > horizontalChrome else { return max(availableWidth, 0) }
        let fullWidthHeight = (availableWidth - horizontalChrome) / sceneAspectRatio + verticalChrome
        guard fullWidthHeight > availableHeight else { return availableWidth }
        let sceneWidth = max(availableHeight - verticalChrome, 0) * sceneAspectRatio
        return sceneWidth + horizontalChrome
    }
}
