// DictusKeyboard/Vendored/Models/KeyboardHeightProvider.swift
// Vendored from giellakbd-ios Keyboard/Models/KeyboardHeightProvider.swift
// Stripped: import Sentry, SentrySDK.capture calls

import UIKit

typealias KeyboardHeight = (portrait: CGFloat, landscape: CGFloat)

struct KeyboardHeightProvider {
    private static let portraitDeviceHeight: CGFloat = {
        let size = UIScreen.main.bounds.size
        return max(size.height, size.width)
    }()

    private static let landscapeDeviceHeight: CGFloat = {
        let size = UIScreen.main.bounds.size
        return min(size.height, size.width)
    }()

    /// Returns keyboard height for a given device and orientation, optionally adjusted for custom row counts
    static func height(
        for deviceContext: DeviceContext,
        traitCollection: UITraitCollection,
        rowCount: Int? = nil
    ) -> CGFloat {
        let heights = heights(for: deviceContext, traitCollection: traitCollection)
        let isLandscape = deviceContext.isLandscape
        let baseHeight = isLandscape ? heights.landscape : heights.portrait

        guard let rowCount = rowCount else {
            return baseHeight
        }

        let normalRowCount: CGFloat = deviceContext.isLargeIPad ? 5.0 : 4.0
        let rowHeight = baseHeight / normalRowCount
        var adjustedHeight = rowHeight * CGFloat(rowCount)

        if !deviceContext.isLargeIPad, rowCount > 4, isLandscape {
            adjustedHeight -= 40
        }

        return adjustedHeight
    }

    private static func heights(for deviceContext: DeviceContext, traitCollection: UITraitCollection) -> KeyboardHeight {
        if deviceContext.isIPhoneAppRunningOnIPad(traitCollection: traitCollection) {
            let portrait: CGFloat = deviceContext.isLargeIPad ? 328 : 258
            let landscape = portrait - 56
            return (portrait: portrait, landscape: landscape)
        }

        if let override = deviceOverride(for: deviceContext) {
            return override
        }

        if let height = height(forDiagonal: deviceContext.device.diagonal) {
            return height
        }

        return fallbackHeight(for: deviceContext)
    }

    private static func deviceOverride(for deviceContext: DeviceContext) -> KeyboardHeight? {
        switch deviceContext.device {
        case .simulator(let inner):
            return deviceOverride(for: DeviceContext(device: inner, isLandscape: deviceContext.isLandscape))
        case .iPhoneXSMax, .iPhone11ProMax:
            return (portrait: 272, landscape: 196)
        default:
            return nil
        }
    }

    private static func height(forDiagonal diagonal: Double) -> KeyboardHeight? {
        if let screenSize = ScreenSize(diagonal: diagonal) {
            return heightForScreenSize(screenSize)
        }

        if let nearest = nearestScreenSize(to: diagonal) {
            return heightForScreenSize(nearest)
        }

        return nil
    }

    private static func nearestScreenSize(to diagonal: Double, maxDistance: Double = 0.2) -> ScreenSize? {
        // Stripped: SentrySDK.capture call for unrecognized screen sizes

        guard let nearest = ScreenSize.allCases.min(by: { size1, size2 in
            let distance1 = abs(size1.rawValue - diagonal)
            let distance2 = abs(size2.rawValue - diagonal)
            return distance1 < distance2
        }) else {
            return nil
        }

        let distance = abs(nearest.rawValue - diagonal)
        guard distance <= maxDistance else {
            return nil
        }

        return nearest
    }

    private static func heightForScreenSize(_ screenSize: ScreenSize) -> KeyboardHeight {
        switch screenSize {
        case .size4_7:
            return (portrait: 262, landscape: 208)
        case .size5_4:
            return (portrait: 272, landscape: 198)
        case .size5_5:
            return (portrait: 272, landscape: 208)
        case .size5_8:
            return (portrait: 262, landscape: 196)
        case .size6_1, .size6_3, .size6_5:
            return (portrait: 262, landscape: 206)
        case .size6_7, .size6_9:
            return (portrait: 272, landscape: 206)
        case .size7_9, .size8_3, .size9_7, .size10_2, .size10_5, .size11_0:
            return (portrait: 318, landscape: 404)
        case .size10_9:
            return (portrait: 314, landscape: 398)
        case .size12_9, .size13_0:
            return (portrait: 384, landscape: 476)
        }
    }

    private static func fallbackHeight(for deviceContext: DeviceContext) -> KeyboardHeight {
        if deviceContext.isPad {
            let landscape = landscapeDeviceHeight / 2.0 - 70
            return (portrait: 384, landscape: landscape)
        } else if deviceContext.isPhone {
            return (portrait: 262, landscape: 203)
        } else {
            let portraitHeight = portraitDeviceHeight / 3.0
            let landscapeHeight = portraitHeight - 56
            return (portrait: portraitHeight, landscape: landscapeHeight)
        }
    }
}

enum ScreenSize: Double, CaseIterable {
    case size4_7 = 4.7
    case size5_4 = 5.4
    case size5_5 = 5.5
    case size5_8 = 5.8
    case size6_1 = 6.1
    case size6_3 = 6.3
    case size6_5 = 6.5
    case size6_7 = 6.7
    case size6_9 = 6.9
    case size7_9 = 7.9
    case size8_3 = 8.3
    case size9_7 = 9.7
    case size10_2 = 10.2
    case size10_5 = 10.5
    case size10_9 = 10.9
    case size11_0 = 11.0
    case size12_9 = 12.9
    case size13_0 = 13.0

    init?(diagonal: Double) {
        self.init(rawValue: diagonal)
    }
}
