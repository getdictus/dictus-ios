// DictusCore/Tests/DictusCoreTests/KeyboardOrientationTests.swift
// The keyboard's landscape decision (#982).
import XCTest
@testable import DictusCore

final class KeyboardOrientationTests: XCTestCase {

    /// The iPhone Duo's cover panel, which `UIScreen.main` reports on both panels (#785).
    private let coverPanel = CGSize(width: 466, height: 678)
    /// An iPhone 17's screen, portrait and landscape.
    private let phonePortrait = CGSize(width: 402, height: 874)
    private let phoneLandscape = CGSize(width: 874, height: 402)

    // MARK: - The #982 case

    /// Inner panel in landscape: the scene says landscape while the screen is the
    /// portrait-shaped cover. Before #982 this read portrait and drew the number row.
    func testDuoInnerLandscapeFollowsTheScene() {
        let orientation = KeyboardOrientation.resolve(sceneIsLandscape: true, screenSize: coverPanel)
        XCTAssertEqual(orientation, KeyboardOrientation(isLandscape: true, source: .scene))
    }

    func testDuoInnerPortraitFollowsTheScene() {
        let orientation = KeyboardOrientation.resolve(sceneIsLandscape: false, screenSize: coverPanel)
        XCTAssertEqual(orientation, KeyboardOrientation(isLandscape: false, source: .scene))
    }

    /// The scene wins in the other direction too: it is the only signal that knows
    /// which panel the keyboard is on.
    func testSceneWinsOverALandscapeShapedScreen() {
        let orientation = KeyboardOrientation.resolve(sceneIsLandscape: false, screenSize: phoneLandscape)
        XCTAssertEqual(orientation, KeyboardOrientation(isLandscape: false, source: .scene))
    }

    // MARK: - An ordinary iPhone, where both signals agree

    func testPhoneAgreesInBothOrientations() {
        XCTAssertEqual(
            KeyboardOrientation.resolve(sceneIsLandscape: false, screenSize: phonePortrait).isLandscape,
            KeyboardOrientation.resolve(sceneIsLandscape: nil, screenSize: phonePortrait).isLandscape
        )
        XCTAssertEqual(
            KeyboardOrientation.resolve(sceneIsLandscape: true, screenSize: phoneLandscape).isLandscape,
            KeyboardOrientation.resolve(sceneIsLandscape: nil, screenSize: phoneLandscape).isLandscape
        )
    }

    // MARK: - No scene: exactly the pre-#982 reading

    func testWithoutASceneTheScreenDecides() {
        XCTAssertEqual(
            KeyboardOrientation.resolve(sceneIsLandscape: nil, screenSize: phonePortrait),
            KeyboardOrientation(isLandscape: false, source: .screen)
        )
        XCTAssertEqual(
            KeyboardOrientation.resolve(sceneIsLandscape: nil, screenSize: phoneLandscape),
            KeyboardOrientation(isLandscape: true, source: .screen)
        )
    }

    /// `UIScreen.isDeviceLandscape` used a strict `>`: a square screen is portrait.
    func testSquareScreenIsPortraitAsBefore() {
        let orientation = KeyboardOrientation.resolve(sceneIsLandscape: nil, screenSize: CGSize(width: 500, height: 500))
        XCTAssertFalse(orientation.isLandscape)
    }

    func testSourceRawValuesAreWhatTheLogPrints() {
        XCTAssertEqual(KeyboardOrientation.Source.scene.rawValue, "scene")
        XCTAssertEqual(KeyboardOrientation.Source.screen.rawValue, "screen")
    }
}
