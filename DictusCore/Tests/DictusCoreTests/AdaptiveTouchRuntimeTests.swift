// DictusCore/Tests/DictusCoreTests/AdaptiveTouchRuntimeTests.swift
import CoreGraphics
import XCTest
@testable import DictusCore

/// Adaptive touch's Experiments switch as the keyboard runs it (#1014): off, it labels
/// nothing, writes nothing and leaves the decoder its stock centres; on, it learns.
final class AdaptiveTouchRuntimeTests: XCTestCase {
    private static let keys = SpatialDecoderTests.keys(SpatialDecoderTests.qwerty)
    private static let bias = CGVector(dx: 0, dy: 0.25)

    /// A suite and a file of its own: the App Group's are live state on a developer machine.
    private let suite = "AdaptiveTouchRuntimeTests.\(UUID().uuidString)"
    private var defaults = UserDefaults.standard
    private let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("adaptive-touch.bin")
    private var learnersMade = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        learnersMade = 0
    }

    override func tearDown() {
        AdaptiveTouch.waitForWrites()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        super.tearDown()
    }

    private func runtime() -> AdaptiveTouchRuntime {
        AdaptiveTouchRuntime { [unowned self] in
            learnersMade += 1
            return AdaptiveTouch(storage: .file(url), defaults: defaults)
        }
    }

    private func settings(adaptive: Bool, spatial: Bool, channel: BuildChannel = .testBuild) -> KeyboardFeatureSettings {
        let settings = KeyboardFeatureSettings(store: defaults, channel: channel)
        settings.adaptiveTouch = adaptive
        settings.spatialAutocorrect = spatial
        return settings
    }

    /// Types sentences as the bridge does, through `runtime.current` (nil while off), each
    /// tap `bias` keycaps below the key centre, a session per sentence.
    private func type(through runtime: AdaptiveTouchRuntime, sessions: Int) {
        for _ in 0..<sessions {
            runtime.current?.beginSession()
            var text = ""
            for word in ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dogs", "with", "might"] {
                for c in word {
                    text.append(c)
                    let centre = Self.keys.centres[c] ?? .zero
                    runtime.current?.typed(String(c), at: CGPoint(x: centre.x, y: centre.y + Self.bias.dy * 54),
                                           slid: false, keys: Self.keys)
                }
                runtime.current?.finish(before: text)
                text += " "
            }
        }
        runtime.save()
        AdaptiveTouch.waitForWrites()
    }

    private var stockInput: SpatialCorrection.Input {
        SpatialCorrection.Input(taps: SpatialDecoderTests.taps("the", on: Self.keys), keys: Self.keys)
    }

    /// A profile already in use on disk, as a keyboard that learned while the switch was on
    /// leaves it.
    private func learnProfileOnDisk() throws {
        let learner = AdaptiveTouch(storage: .file(url), defaults: defaults)
        let on = AdaptiveTouchRuntime { learner }
        on.refresh(settings(adaptive: true, spatial: true))
        type(through: on, sessions: 12)
        XCTAssertNotNil(learner.personalKeys(for: Self.keys), "the profile is in use")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    private func assertCutOff(_ runtime: AdaptiveTouchRuntime, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(runtime.isOn, file: file, line: line)
        XCTAssertNil(runtime.current, "no learner, so no tap is labelled", file: file, line: line)
        type(through: runtime, sessions: 12)
        XCTAssertEqual(learnersMade, 0, "nothing ever built a learner", file: file, line: line)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "no file written", file: file, line: line)
    }

    // MARK: - Off

    func testOffLabelsNothingWritesNothing() {
        let runtime = runtime()
        runtime.refresh(settings(adaptive: false, spatial: true))
        assertCutOff(runtime)
    }

    func testOffTheDecoderGetsTheStockKeysEvenWithAProfileOnDisk() throws {
        try learnProfileOnDisk()
        let runtime = runtime()
        runtime.refresh(settings(adaptive: false, spatial: true))
        let input = runtime.decoderInput(stockInput)
        XCTAssertEqual(input?.keys, Self.keys)
        XCTAssertNil(input?.baseline, "no personal keys, no baseline")
        XCTAssertEqual(learnersMade, 0)
    }

    func testSpatialOffCutsItWithAdaptiveOn() throws {
        let runtime = runtime()
        runtime.refresh(settings(adaptive: true, spatial: false))
        assertCutOff(runtime)

        try learnProfileOnDisk()
        XCTAssertNil(runtime.decoderInput(stockInput)?.baseline)
    }

    func testTheAppStoreChannelIgnoresAStoredTrue() {
        let runtime = runtime()
        let stored = settings(adaptive: true, spatial: true, channel: .appStore)
        XCTAssertTrue(stored.adaptiveTouch, "the store holds true")
        XCTAssertFalse(runtime.refresh(stored))
        assertCutOff(runtime)
    }

    // MARK: - On

    func testOnLearnsWritesAndHandsTheDecoderPersonalKeys() throws {
        let runtime = runtime()
        XCTAssertTrue(runtime.refresh(settings(adaptive: true, spatial: true)))
        type(through: runtime, sessions: 12)
        let learner = try XCTUnwrap(runtime.current)
        XCTAssertGreaterThan(learner.model.contexts.map(\.accepted).max() ?? 0, 0, "taps were labelled")
        XCTAssertEqual(learnersMade, 1, "one learner for the process")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "what was learned is written")

        let input = try XCTUnwrap(runtime.decoderInput(stockInput))
        XCTAssertEqual(input.baseline, Self.keys, "the stock centres stay the baseline")
        XCTAssertNotEqual(input.keys, Self.keys, "the decoder reads the personal centres")
        XCTAssertNil(runtime.decoderInput(nil), "no spatial input, nothing to move")
    }

    func testTurningItOffDropsTheLearner() throws {
        let runtime = runtime()
        runtime.refresh(settings(adaptive: true, spatial: true))
        type(through: runtime, sessions: 12)
        XCTAssertNotNil(runtime.decoderInput(stockInput)?.baseline)

        XCTAssertFalse(runtime.refresh(settings(adaptive: false, spatial: true)))
        XCTAssertNil(runtime.current)
        XCTAssertNil(runtime.decoderInput(stockInput)?.baseline, "back to the stock centres at once")
    }

    // MARK: - Reset

    func testTheResetDeletesTheFileAndTheKeyboardStartsOver() throws {
        let runtime = runtime()
        runtime.refresh(settings(adaptive: true, spatial: true))
        type(through: runtime, sessions: 12)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // The Experiments page's « Reset adaptive touch ».
        AdaptiveTouchStore.requestReset(defaults: defaults, url: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "the file is gone")

        // The keyboard's next appearance: a refresh, then a session.
        runtime.refresh(settings(adaptive: true, spatial: true))
        let learner = try XCTUnwrap(runtime.current)
        learner.beginSession()
        XCTAssertEqual(learner.model.contexts.map(\.accepted).max(), 0, "starts over")
        XCTAssertNil(runtime.decoderInput(stockInput)?.baseline)
        runtime.save()
        AdaptiveTouch.waitForWrites()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "nothing old is written back")
    }
}
