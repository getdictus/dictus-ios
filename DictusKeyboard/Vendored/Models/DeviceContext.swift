// DictusKeyboard/Vendored/Models/DeviceContext.swift
// Vendored from giellakbd-ios Keyboard/Models/DeviceContext.swift
// Dependencies: DeviceKit (SPM)

import DeviceKit
import DictusCore
import UIKit

/// Centralized source of truth for device type, size, and orientation detection
/// Wraps DeviceKit's Device to provide additional computed properties
struct DeviceContext {
    let device: Device
    let isLandscape: Bool

    // MARK: - Device Property Accessors

    var isPad: Bool { device.isPad }
    var isPhone: Bool { device.isPhone }
    var hasSensorHousing: Bool { device.hasSensorHousing }

    var screenInches: CGFloat {
        let maxSupportedInches = 13.0
        return device.diagonal > 0
            ? device.diagonal
            : maxSupportedInches
    }

    // MARK: - iPad Size Categories

    var isMiniIPad: Bool {
        isPad && screenInches < 9
    }

    var isMediumIPad: Bool {
        isPad && !isMiniIPad && !isLargeIPad
    }

    var isLargeIPad: Bool {
        isPad && screenInches >= 12
    }

    // MARK: - Orientation-Specific iPad Categories

    var isLargeLandscape: Bool {
        isLargeIPad && isLandscape
    }

    var isSmallOrMediumLandscape: Bool {
        (isMiniIPad || isMediumIPad) && isLandscape
    }

    // MARK: - Trait Collection Helpers

    func shouldUseIPadLayout(traitCollection: UITraitCollection) -> Bool {
        isPad && traitCollection.userInterfaceIdiom == .pad
    }

    func isIPhoneAppRunningOnIPad(traitCollection: UITraitCollection) -> Bool {
        isPad && traitCollection.userInterfaceIdiom == .phone
    }

    // MARK: - Factory

    /// Orientation comes from the keyboard's own window scene since #982, through
    /// `KeyboardSceneOrientation`; it used to be `UIScreen.main.isDeviceLandscape`.
    static var current: DeviceContext {
        DeviceContext(
            device: Device.current,
            isLandscape: KeyboardSceneOrientation.current.isLandscape
        )
    }
}

// MARK: - Orientation from the keyboard's window scene (#982)

/// Reads the orientation of the panel the keyboard is actually drawn on.
///
/// WHY not `UIScreen.main`: on the iPhone Duo it is the cover panel's screen even when
/// the keyboard is on the inner panel (#785, #982), so inner landscape read as portrait.
/// A `UIWindowScene` belongs to one display, and its interface orientation is the one
/// the host app is laid out in, which is the one the keyboard must follow.
///
/// WHY a controller and not a scene is remembered: the scene is looked up from the
/// controller's view on every read, so it is never an old presentation's scene. iOS
/// caches input view controllers (#128), and the last one to appear is the one on
/// screen, so `viewWillAppear` hands itself over. When that view is not in a window
/// (a controller still in `viewDidLoad`, or the keyboard dismissed) there is no scene
/// to read, and `KeyboardOrientation.resolve` falls back to `UIScreen.main`, which is
/// exactly what was read before #982.
///
/// `weak`, so tracking a controller never keeps a cached one alive (#128).
enum KeyboardSceneOrientation {
    private static weak var controller: UIInputViewController?

    /// Called from `viewWillAppear`: the controller about to be on screen.
    static func track(_ controller: UIInputViewController) {
        self.controller = controller
    }

    /// The keyboard window scene, if the tracked controller is in a window. Both the
    /// view and the input view are tried, for the reason given on `isOnScreen`.
    static var scene: UIWindowScene? {
        controller?.viewIfLoaded?.window?.windowScene ?? controller?.inputView?.window?.windowScene
    }

    static var current: KeyboardOrientation {
        let interface = scene?.effectiveGeometry.interfaceOrientation ?? .unknown
        return KeyboardOrientation.resolve(
            sceneIsLandscape: interface == .unknown ? nil : interface.isLandscape,
            screenSize: UIScreen.main.bounds.size
        )
    }

    /// For the `computeKbHeight` log: the source, the scene's raw orientation
    /// (0 = none or unknown, 1 portrait, 3 / 4 landscape) and the scene's screen, which
    /// on the Duo is the panel `UIScreen.main` is not.
    static var probeDetails: String {
        let orientation = current
        let interface = scene?.effectiveGeometry.interfaceOrientation ?? .unknown
        let sceneScreen = scene.map { "\(Int($0.screen.bounds.width))x\(Int($0.screen.bounds.height))" } ?? "none"
        return "orientSource=\(orientation.source.rawValue) sceneOrient=\(interface.rawValue) sceneScreen=\(sceneScreen)"
    }
}
