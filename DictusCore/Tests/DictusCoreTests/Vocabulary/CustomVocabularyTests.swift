// DictusCore/Tests/DictusCoreTests/Vocabulary/CustomVocabularyTests.swift
// The gate both halves of the app go through, and the identity it has to keep (#80).
//
// Replaces `VocabularyGlossaryTests`, deleted with the glossary in #536. The three
// assertions kept here never depended on it: they pin the entitlement, the pass and
// the pre-registered bar that a user who stored nothing gets their input back.
import XCTest
@testable import DictusCore

final class CustomVocabularyTests: XCTestCase {

    /// `corrected` is the gate both consumers go through, and its identity branch is
    /// what makes the bar hold at runtime rather than only in the matcher.
    func testCorrectedHandsBackItsInputWhenNothingIsStored() {
        let raw = "Le déploiement est passé sans incident."
        XCTAssertEqual(CustomVocabulary.corrected(raw, entries: []), raw)
    }

    func testCorrectedAppliesTheVocabularyWhenEntriesArePassedIn() {
        guard let entry = VocabularyEntry(term: "Kubernetes", variants: ["cubernetes"]) else {
            return XCTFail("entry should be constructible")
        }
        XCTAssertEqual(
            CustomVocabulary.corrected("on déploie sur cubernetes", entries: [entry]),
            "on déploie sur Kubernetes"
        )
    }

    func testTheVocabularyGateIsTheProFeatureToggleAndNotJustTheSubscription() {
        // Same shape as `HistoryAvailability.isEntitled`: a subscriber who switched
        // the feature off in Settings has said what they want.
        XCTAssertEqual(ProFeature.vocabulary.settingsKey, SharedKeys.vocabularyEnabled)
        XCTAssertEqual(
            VocabularyAvailability.isEntitled, FeatureGate.isAvailable(.vocabulary)
        )
    }
}
