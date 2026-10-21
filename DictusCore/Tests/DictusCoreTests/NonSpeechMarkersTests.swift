// DictusCore/Tests/DictusCoreTests/NonSpeechMarkersTests.swift
// A transcription made only of non-speech markers is "no words detected" (#766).
import XCTest
@testable import DictusCore

final class NonSpeechMarkersTests: XCTestCase {

    // MARK: - Marker only: nothing was said

    func test_frenchMarkers_areNotSpeech() {
        for text in ["(musique)", "[Musique]", "[Musique].", "(Musique) .", "(rires)", "[Applaudissements]"] {
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), "", text)
        }
    }

    func test_englishMarkers_areNotSpeech() {
        for text in ["[Music]", "(music)", "[BLANK_AUDIO]", "[Music]!", "(upbeat music)…"] {
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), "", text)
        }
    }

    func test_severalMarkers_areNotSpeech() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[Musique] (musique) [Music]."), "")
    }

    func test_ellipsisAndPunctuationOnly_areNotSpeech() {
        for text in ["...", "…", " . ", "?!", "- -", ",", "« »"] {
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), "", text)
        }
    }

    func test_whitespaceOnly_isNotSpeech() {
        for text in ["", " ", "\n", " \t\n "] {
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), "", text)
        }
    }

    // MARK: - Mixed: the words stay, the markers go

    func test_markerBeforeWords_isDropped() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[Musique] Bonjour à tous."), "Bonjour à tous.")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[Musique]. Bonjour à tous."), "Bonjour à tous.")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "(music), « Oui »"), "« Oui »")
    }

    func test_markerInsideWords_leavesOneSpace() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Hello (music) everyone"), "Hello everyone")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Bonjour[Music]monde"), "Bonjour monde")
    }

    func test_markerAfterWords_keepsTheirPunctuation() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "On se voit demain. [Musique]"), "On se voit demain.")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "See you tomorrow [Music]."), "See you tomorrow.")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "...et voilà [Music]"), "...et voilà")
    }

    // MARK: - Normal text is untouched

    func test_normalText_isOnlyTrimmed() {
        for text in ["Bonjour, ça va ?", "Hello world.", "Attends... je réfléchis", "Rendez-vous à 15 h", "42"] {
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), text, text)
            XCTAssertEqual(NonSpeechMarkers.spokenText(in: "  \(text)\n"), text, text)
        }
    }

    func test_normalText_keepsLeadingPunctuation() {
        // The leading-punctuation cleanup only runs after a marker was removed.
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "« Oui », dit-il."), "« Oui », dit-il.")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "...et voilà"), "...et voilà")
    }
}
