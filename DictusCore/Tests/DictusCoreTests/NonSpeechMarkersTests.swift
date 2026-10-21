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

    func test_unknownBracketedContentAlone_isNotSpeech() {
        // Rule 1 holds for ANY bracketed content, not only the known markers.
        for text in ["(quelque chose)", "[inconnu].", "(upbeat music) [Bell rings]"] {
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

    func test_knownMarkers_areCaseInsensitive_andAllowPunctuationInside() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[MUSIQUE] Bonjour"), "Bonjour")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Bonjour [ Rires... ] à tous"), "Bonjour à tous")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Hello [BLANK_AUDIO] there"), "Hello there")
    }

    func test_germanAndSpanishMarkers_inMixedText_areDropped() {
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[Musik] Guten Tag"), "Guten Tag")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Guten Tag (Geräusch)"), "Guten Tag")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "(risas) Hola a todos"), "Hola a todos")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Hola [Música]."), "Hola.")
    }

    // MARK: - Mixed: other bracketed text is the user's

    func test_legitimateParenthesis_inMixedText_isKept() {
        let text = "Rendez-vous demain (salle 212) à 9h"
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: text), text)
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Voir [annexe] page 3"), "Voir [annexe] page 3")
    }

    func test_unknownMarker_inMixedText_isKept_knownOneDropped() {
        XCTAssertEqual(
            NonSpeechMarkers.spokenText(in: "[Musique] Rendez-vous demain (salle 212) à 9h"),
            "Rendez-vous demain (salle 212) à 9h")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "(upbeat music) Hello"), "(upbeat music) Hello")
    }

    func test_unclosedMarker_isNotFiltered() {
        // Rule 3: "[Musique" is not a marker, and it holds letters.
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "[Musique"), "[Musique")
        XCTAssertEqual(NonSpeechMarkers.spokenText(in: "Bonjour (rires"), "Bonjour (rires")
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
