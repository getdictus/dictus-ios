// DictusCore/Tests/DictusCoreTests/OnboardingIntroSceneTests.swift
// The intro carousel's pages and the video files they play (#676).
import XCTest
@testable import DictusCore

final class OnboardingIntroSceneTests: XCTestCase {

    func testThePagesTellTheStoryInOrder() {
        XCTAssertEqual(OnboardingIntroScene.allCases, [.walking, .metro, .keyboard])
    }

    func testVideoNamesFollowTheRenderScript() {
        XCTAssertEqual(OnboardingIntroScene.walking.videoResourceName(dark: false), "intro-a-light")
        XCTAssertEqual(OnboardingIntroScene.walking.videoResourceName(dark: true), "intro-a-dark")
        XCTAssertEqual(OnboardingIntroScene.metro.videoResourceName(dark: false), "intro-b-light")
        XCTAssertEqual(OnboardingIntroScene.metro.videoResourceName(dark: true), "intro-b-dark")
        XCTAssertEqual(OnboardingIntroScene.keyboard.videoResourceName(dark: false), "intro-c-light")
        XCTAssertEqual(OnboardingIntroScene.keyboard.videoResourceName(dark: true), "intro-c-dark")
    }

    func testEachSceneHasItsOwnStill() {
        let names = OnboardingIntroScene.allCases.map(\.stillImageName)
        XCTAssertEqual(names, ["intro-a-still", "intro-b-still", "intro-c-still"])
    }

    /// The video starts at the still's moment, so that moment has to fall inside the loop:
    /// 5.5 s for A and B, 6.5 s for C (`assets/onboarding/intro/README.md`).
    func testEachStillIsTakenInsideItsLoop() {
        for scene in OnboardingIntroScene.allCases {
            let seconds = scene.stillFrameSeconds
            XCTAssertGreaterThanOrEqual(seconds, 0)
            XCTAssertLessThan(seconds, scene.loopSeconds, "\(scene) still is past its loop")
        }
    }

    /// The loop lengths are the render's (165 frames at 30 fps for A and B, 195 for C).
    /// They are the carousel's dwell per page, so a scene re-rendered longer must change
    /// them too: the README states them, and this pins the two together.
    func testLoopLengthsMatchTheRenderReadme() throws {
        XCTAssertEqual(OnboardingIntroScene.walking.loopSeconds, 5.5)
        XCTAssertEqual(OnboardingIntroScene.metro.loopSeconds, 5.5)
        XCTAssertEqual(OnboardingIntroScene.keyboard.loopSeconds, 6.5)
        let readme = try String(contentsOf: repositoryRoot.appendingPathComponent("assets/onboarding/intro/README.md"), encoding: .utf8)
        XCTAssertTrue(readme.contains("intro-a-{light,dark}.mp4"))
        for (file, seconds) in [("intro-a-", "5.5 s"), ("intro-b-", "5.5 s"), ("intro-c-", "6.5 s")] {
            let row = readme.split(separator: "\n").first { $0.hasPrefix("| `\(file)") }
            XCTAssertNotNil(row, "no README row for \(file)")
            XCTAssertTrue(row?.hasSuffix("| \(seconds) |") == true, "\(file) loop is not \(seconds) in the README")
        }
    }

    func testThePagesTurnOneTwoThreeThenBackToOne() {
        XCTAssertEqual(OnboardingIntroScene.walking.nextPage, .metro)
        XCTAssertEqual(OnboardingIntroScene.metro.nextPage, .keyboard)
        XCTAssertEqual(OnboardingIntroScene.keyboard.nextPage, .walking)
        XCTAssertEqual(OnboardingIntroScene.allCases.filter(\.wrapsToFirstPage), [.keyboard])
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DictusCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DictusCore
            .deletingLastPathComponent() // repository root
    }

    /// The languages the intro art is drawn in (#771): one render per language, each in its
    /// `.lproj` folder, so `Bundle.main.url(forResource:)` picks the device's.
    private let introLocales = ["en", "fr"]

    /// The app finds each video by name in its bundle and falls back to the still frame
    /// when it is missing, so a renamed file would not fail the build: the page would just
    /// stop moving. Pin the names to the files #667 committed, in every language (#771).
    func testEveryVideoTheAppAsksForExistsInTheRepository() {
        let introFolder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // DictusCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // DictusCore
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("assets/onboarding/intro")
        for locale in introLocales {
            for scene in OnboardingIntroScene.allCases {
                for dark in [false, true] {
                    let file = introFolder
                        .appendingPathComponent("\(locale).lproj")
                        .appendingPathComponent(scene.videoResourceName(dark: dark))
                        .appendingPathExtension(OnboardingIntroScene.videoExtension)
                    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing \(locale).lproj/\(file.lastPathComponent)")
                }
            }
        }
    }

    /// Same pin for the stills: each image set exists in DictusApp's asset catalog with a
    /// light and a dark appearance, in English (unlocalized, the fallback) and in French
    /// (`"locale" : "fr"`, #771).
    func testEveryStillExistsInTheAssetCatalogInBothAppearances() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusApp/Assets.xcassets")
        for scene in OnboardingIntroScene.allCases {
            let imageSet = catalog.appendingPathComponent("\(scene.stillImageName).imageset")
            let contents = try String(contentsOf: imageSet.appendingPathComponent("Contents.json"), encoding: .utf8)
            XCTAssertTrue(contents.contains("\"dark\""), "\(scene.stillImageName) has no dark appearance")
            XCTAssertTrue(contents.contains("\"locale\" : \"fr\""), "\(scene.stillImageName) has no French still")
            let pngs = try FileManager.default.contentsOfDirectory(atPath: imageSet.path).filter { $0.hasSuffix(".png") }
            XCTAssertEqual(pngs.count, 2 * introLocales.count, "\(scene.stillImageName) should hold a light and a dark PNG per language")
            for png in pngs {
                XCTAssertTrue(contents.contains("\"\(png)\""), "\(png) is not listed in \(scene.stillImageName)'s Contents.json")
            }
        }
    }
}
