// tools/keyboard-bench/DeviceContext.swift
// Stands in for DictusKeyboard/Vendored/Models/DeviceContext.swift, which needs
// DeviceKit, a package the bench does not build. The layout code asks it two
// questions: is this an iPad (no), is it landscape (no), and SystemKeys asks whether
// the screen has a sensor housing (yes). The bench replays an iPhone 17 held upright,
// so those are its real answers, not placeholders.
import UIKit

struct DeviceContext {
    static let current = DeviceContext()
    let isLandscape = false
    let isPad = false
    let isLargeIPad = false
    let hasSensorHousing = true

    func shouldUseIPadLayout(traitCollection: UITraitCollection) -> Bool { false }
}
