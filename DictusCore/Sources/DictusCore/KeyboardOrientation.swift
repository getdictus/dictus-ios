// DictusCore/Sources/DictusCore/KeyboardOrientation.swift
// Decides whether the keyboard is in landscape, and from which signal (#982).
import CoreGraphics

/// Whether the keyboard is in landscape, and which signal said so.
///
/// Before #982 the keyboard took landscape from `UIScreen.main.bounds` alone. On the
/// iPhone Duo that is the cover panel's screen (466×678 pt) even while the keyboard is
/// drawn on the inner panel, so inner landscape read as portrait: the number row,
/// which #331 keeps out of landscape, was drawn there, and the grid took the portrait
/// height. The keyboard's own window scene knows the orientation of the panel it is
/// actually on, so its answer comes first.
///
/// WHY the screen is still here as a fallback: a controller is built before its view
/// is in a window (`viewDidLoad` sizes the grid), and a scene can report `.unknown`.
/// In both cases the keyboard falls back to exactly what it read before #982, so a
/// missing scene can never be worse than the old behaviour.
///
/// Lives in DictusCore so the decision is unit-testable: the keyboard extension has
/// no test bundle. The UIKit side, which turns a `UIWindowScene` into
/// `sceneIsLandscape`, is `KeyboardSceneOrientation` in `DeviceContext.swift`.
public struct KeyboardOrientation: Equatable, Sendable {

    /// Which signal the answer came from. Logged on `computeKbHeight`, so a device
    /// capture says whether the scene was there to be read.
    public enum Source: String, Sendable {
        /// The keyboard's own window scene.
        case scene
        /// `UIScreen.main`, the pre-#982 input.
        case screen
    }

    public let isLandscape: Bool
    public let source: Source

    public init(isLandscape: Bool, source: Source) {
        self.isLandscape = isLandscape
        self.source = source
    }

    /// - Parameters:
    ///   - sceneIsLandscape: the keyboard window scene's interface orientation, or nil
    ///     when there is no scene yet or its orientation is unknown.
    ///   - screenSize: `UIScreen.main.bounds.size`.
    public static func resolve(sceneIsLandscape: Bool?, screenSize: CGSize) -> KeyboardOrientation {
        if let sceneIsLandscape {
            return KeyboardOrientation(isLandscape: sceneIsLandscape, source: .scene)
        }
        // Same comparison as the vendored `UIScreen.isDeviceLandscape` it replaces.
        return KeyboardOrientation(isLandscape: screenSize.width > screenSize.height, source: .screen)
    }
}
