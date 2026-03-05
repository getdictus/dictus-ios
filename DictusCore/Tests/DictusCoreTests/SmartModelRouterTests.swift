// DictusCore/Tests/DictusCoreTests/SmartModelRouterTests.swift
import XCTest
@testable import DictusCore

final class SmartModelRouterTests: XCTestCase {

    // MARK: - Short audio (< 5s) prefers fast model

    func testShortAudioSelectsFastModel() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 3.0,
            downloadedModels: ["openai_whisper-tiny", "openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-tiny")
    }

    // MARK: - Long audio (>= 5s) prefers accurate model

    func testLongAudioSelectsAccurateModel() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 8.0,
            downloadedModels: ["openai_whisper-tiny", "openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-small")
    }

    // MARK: - Single model always selected

    func testSingleModelAlwaysSelectedForShortAudio() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 3.0,
            downloadedModels: ["openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-small")
    }

    func testSingleModelAlwaysSelectedForLongAudio() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 8.0,
            downloadedModels: ["openai_whisper-tiny"]
        )
        XCTAssertEqual(result, "openai_whisper-tiny")
    }

    // MARK: - Threshold boundary

    func testExactThresholdSelectsAccurateModel() {
        // 5.0s is NOT "under 5s", so it should go accurate
        let result = SmartModelRouter.selectModel(
            audioDuration: 5.0,
            downloadedModels: ["openai_whisper-tiny", "openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-small")
    }

    func testJustUnderThresholdSelectsFastModel() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 4.9,
            downloadedModels: ["openai_whisper-tiny", "openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-tiny")
    }

    // MARK: - Multiple models available

    func testLongAudioSelectsFirstAccurateModel() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 10.0,
            downloadedModels: [
                "openai_whisper-tiny",
                "openai_whisper-base",
                "openai_whisper-small",
                "openai_whisper-medium"
            ]
        )
        XCTAssertEqual(result, "openai_whisper-small")
    }

    func testShortAudioSelectsBaseAsFastModel() {
        let result = SmartModelRouter.selectModel(
            audioDuration: 2.0,
            downloadedModels: ["openai_whisper-base", "openai_whisper-small"]
        )
        XCTAssertEqual(result, "openai_whisper-base")
    }
}
