// DictusCore/Tests/DictusCoreTests/Polish/PolishScandinavianLanguageTests.swift
// The language check reads Danish as Norwegian, and refuses a faithful output (#587).
import XCTest
import NaturalLanguage
@testable import DictusCore

/// `PolishGuardrail` accepts a reading inside the continental Scandinavian set when the
/// expected language is also inside it, and nothing wider.
final class PolishScandinavianLanguageTests: XCTestCase {

    /// The measurement the exception exists for, pinned so it is a fact and not a story:
    /// this sentence is Danish, it is copied verbatim from a Danish transcript, and the
    /// recogniser calls it Norwegian with high confidence.
    func testTheRecogniserReadsThisDanishSentenceAsNorwegian() {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString("Jeg tror, jeg kan eksportere loggene, som de er.")
        let top = recognizer.languageHypotheses(withMaximum: 1).max { $0.value < $1.value }
        XCTAssertEqual(top?.key.rawValue, "nb")
        XCTAssertGreaterThan(top?.value ?? 0, 0.9)
    }

    /// The output the bench lost twice: four Danish paragraphs, one of which reads as
    /// Norwegian. It now passes, on the input's own detected language.
    func testAFaithfulDanishOutputIsAccepted() {
        let output = "Faktisk har jeg brugt den strukturerede tilstand i et stykke tid.\n\n"
            + "Så virkede alle de test, jeg lavede i går, især de lidt længere test.\n\n"
            + "Jeg tror, jeg kan eksportere loggene, som de er.\n\n"
            + "Men for mig ser det ret korrekt ud."
        XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: output, inputLanguageCode: "da"))
    }

    func testTheFourCodesAreMutuallyAccepted() {
        for read in ["da", "nb", "no", "sv"] {
            for expected in ["da", "nb", "no", "sv"] {
                XCTAssertTrue(PolishGuardrail.matches(read: read, expected: expected), "\(read) vs \(expected)")
            }
        }
    }

    /// The exception is four codes, not a notion of similar languages: everything #413
    /// refuses stays refused.
    func testNoOtherPairIsMadeCompatible() {
        let pairs = [("es", "pt"), ("pt", "es"), ("zh-Hans", "zh-Hant"), ("nl", "de"),
                     ("da", "de"), ("sv", "fi"), ("en", "nb"), ("fr", "en")]
        for (read, expected) in pairs {
            XCTAssertFalse(PolishGuardrail.matches(read: read, expected: expected), "\(read) vs \(expected)")
        }
    }

    /// The chat reply this check exists for, in a Scandinavian language, is still caught:
    /// an English answer on a Danish dictation.
    func testAnEnglishOutputOnADanishDictationIsStillRefused() {
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(
            polished: "Sure, here is the rewritten text you asked for, with the paragraphs separated.",
            inputLanguageCode: "da"
        ))
    }
}
