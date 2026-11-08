// DictusCore/Tests/DictusCoreTests/Polish/PolishShortLineReadingTests.swift
// The two short lines #598 is about, pinned as recogniser facts.
import XCTest
import NaturalLanguage

/// What `NLLanguageRecognizer` says about the two lines the language check refused a
/// correct output on (#598), and about the outputs they came from.
///
/// Facts about the recogniser, not about `PolishGuardrail`: they hold whatever fix #598
/// ends up with, and they are what `docs/research/598-short-line-language-check/` was
/// measured on. The recogniser's model ships with the OS, so a failure here after an OS
/// update means those numbers need re-taking (`run-readings.sh`), not that this code broke.
final class PolishShortLineReadingTests: XCTestCase {

    /// The Spanish bullet from PR #597's bench, copied from the Spanish transcript. The same
    /// three words are well-formed Portuguese in its pre-1990 European spelling, which is
    /// why the reading is confident and wrong rather than merely weak.
    func testTheSpanishBulletReadsAsPortuguese() {
        let top = topReading("Parece bastante correcto")
        XCTAssertEqual(top.code, "pt")
        XCTAssertGreaterThanOrEqual(top.confidence, 0.85, "at or above the segment floor, so it refuses")
    }

    /// The list the bullet sits in reads Spanish as a whole, with near-certainty. This is
    /// why reading the whole output would not have refused it — and measurement 2 of #598
    /// is what that costs elsewhere.
    func testTheListItSitsInReadsAsSpanishWhole() {
        let list = "- Las pruebas hechas ayer, sobre todo las más largas, funcionaron\n"
            + "- Creo que voy a poder exportar los logs tal cual\n"
            + "- Parece bastante correcto"
        let top = topReading(list)
        XCTAssertEqual(top.code, "es")
        XCTAssertGreaterThan(top.confidence, 0.99)
    }

    /// The Danish sentence from PR #588's bench, beside its Norwegian counterpart from the
    /// same fixture: the two languages write it identically but for a comma.
    func testTheDanishSentenceAndItsNorwegianTwinBothReadAsNorwegian() {
        XCTAssertEqual(topReading("Jeg tror, jeg kan eksportere loggene, som de er.").code, "nb")
        XCTAssertEqual(topReading("Så jeg tror jeg kan eksportere loggene som de er.").code, "nb")
    }

    private func topReading(_ text: String) -> (code: String?, confidence: Double) {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let top = recognizer.languageHypotheses(withMaximum: 1).max { $0.value < $1.value }
        return (top?.key.rawValue, top?.value ?? 0)
    }
}
