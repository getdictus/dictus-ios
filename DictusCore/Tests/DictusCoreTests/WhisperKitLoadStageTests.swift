// DictusCore/Tests/DictusCoreTests/WhisperKitLoadStageTests.swift
import XCTest
@testable import DictusCore

final class WhisperKitLoadStageTests: XCTestCase {

    /// WhisperKit 0.18.0's `Logging.debug(_ items: Any...)` forwards its variadic array as a
    /// single item, so the callback receives the array's description, brackets and quotes
    /// included. These are the strings it actually hands over.
    func testReadsEveryStageWhisperKitLogsWhileLoading() {
        let expected: [(String, WhisperKitLoadStage)] = [
            (#"["Prewarming models..."]"#, .prewarmPassStarted),
            (#"["Loading models..."]"#, .loadPassStarted),
            (#"["Loading feature extractor"]"#, .melSpectrogramStarted),
            (#"["Loaded feature extractor"]"#, .melSpectrogramDone),
            (#"["Loading text decoder prefill data"]"#, .prefillStarted),
            (#"["Loaded text decoder prefill data"]"#, .prefillDone),
            (#"["Loading text decoder"]"#, .textDecoderStarted),
            (#"["Loaded text decoder in 0.00s"]"#, .textDecoderDone),
            (#"["Loading audio encoder"]"#, .audioEncoderStarted),
            (#"["Loaded audio encoder in 12.34s"]"#, .audioEncoderDone)
        ]
        for (message, stage) in expected {
            XCTAssertEqual(WhisperKitLoadStage(logMessage: message), stage, message)
        }
    }

    func testReadsTheBareMessageToo() {
        XCTAssertEqual(WhisperKitLoadStage(logMessage: "Loading audio encoder"), .audioEncoderStarted)
    }

    /// The folder line carries the app container path, and decoding lines carry the user's
    /// words. Neither may reach the debug log through this parser.
    func testDropsEverythingElse() {
        let dropped = [
            #"["Loading models from /private/var/mobile/Containers/Shared/AppGroup/X with prewarmMode: true"]"#,
            #"["Loaded models for whisper size: large-v3 in 3.64s"]"#,
            #"["[0.00 --> 2.00] Bonjour à tous"]"#,
            ""
        ]
        for message in dropped {
            XCTAssertNil(WhisperKitLoadStage(logMessage: message), message)
        }
    }
}
