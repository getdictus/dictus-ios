// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyExportFidelityTests.swift
// The polish export's `raw` is the ENGINE's output, not the vocabulary's (#80).
import XCTest
@testable import DictusCore

/// #80's corpus has to be mined from the polish debug exports, so a feature that
/// rewrote `raw` on its way past was corrupting the record its own validation
/// depends on. Found by the maintainer during the device test of 2026-09-10.
final class VocabularyExportFidelityTests: XCTestCase {

    private let engineText = "on déploie sur cubernetes ce soir"
    private let correctedText = "on déploie sur Kubernetes ce soir"

    private func metrics() -> PolishMetrics {
        PolishMetrics(
            engine: "apple-fm", mode: "natural", targetLanguage: .french,
            detectedLanguage: "fr", rawCharCount: engineText.count,
            polishedCharCount: correctedText.count, latencyMs: 1, outcome: .success
        )
    }

    func testRawCarriesTheEngineTextAndTheCorrectionSitsBesideIt() {
        let entry = PolishDebugEntry(
            raw: engineText,
            vocabularyCorrected: correctedText,
            polished: "On déploie sur Kubernetes ce soir.",
            metrics: metrics()
        )
        XCTAssertEqual(entry.raw, engineText, "the export must show what the engine produced")
        XCTAssertEqual(entry.vocabularyCorrected, correctedText)
    }

    /// The identity that keeps every export written before this feature, and every
    /// export by a user with no terms, exactly what it always was.
    func testNoVocabularyLeavesTheEntryShapedAsItAlwaysWas() {
        let entry = PolishDebugEntry(
            raw: engineText, polished: "On déploie sur cubernetes ce soir.", metrics: metrics()
        )
        XCTAssertEqual(entry.raw, engineText)
        XCTAssertNil(entry.vocabularyCorrected)
    }

    func testAnEntryWrittenBeforeTheFieldExistedStillDecodes() {
        // The ring holds seven days of events, so a build that adds a field has to
        // read what the previous one wrote. Encode an entry, strip the new key, and
        // decode what a previous build's line looks like.
        guard let data = try? PolishEventStore.encoder.encode(
            PolishDebugEntry(raw: engineText, vocabularyCorrected: correctedText,
                             polished: "x", metrics: metrics())
        ),
            var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return XCTFail("the entry should encode")
        }
        object.removeValue(forKey: "vocabularyCorrected")
        guard let stripped = try? JSONSerialization.data(withJSONObject: object),
              let decoded = try? PolishEventStore.decoder.decode(
                  PolishDebugEntry.self, from: stripped
              ) else {
            return XCTFail("a line written by a previous build must still decode")
        }
        XCTAssertEqual(decoded.raw, engineText)
        XCTAssertNil(decoded.vocabularyCorrected, "absent must read as 'the two are the same'")
    }

    /// The invariant `DictationTranscript` exists to make unforgeable: nil unless
    /// the pass changed something, so nothing extra is carried, written to the App
    /// Group, or recorded for the users who never touch the feature.
    func testTheEngineTextIsCarriedOnlyWhenItDiffers() {
        let unchanged = DictationTranscript(engine: engineText, corrected: engineText)
        XCTAssertEqual(unchanged.text, engineText)
        XCTAssertNil(unchanged.engineRaw)

        let rewritten = DictationTranscript(engine: engineText, corrected: correctedText)
        XCTAssertEqual(rewritten.text, correctedText, "downstream gets the user's spelling")
        XCTAssertEqual(rewritten.engineRaw, engineText, "and the engine's words are kept to be recorded")
    }

    /// The seam itself: with no vocabulary the factory is the identity, which is
    /// #80's pre-registered bar seen from the call site.
    func testTheFactoryIsTheIdentityWithNoVocabulary() {
        let transcript = DictationTranscript(
            engine: engineText, corrected: CustomVocabulary.corrected(engineText, entries: [])
        )
        XCTAssertEqual(transcript.text, engineText)
        XCTAssertNil(transcript.engineRaw)
    }

    func testAPendingDictationCarriesItAcrossTheProcessBoundary() {
        let pending = PendingDictation(
            raw: correctedText,
            engineRaw: engineText,
            policy: .snapshot(),
            recordingDuration: 3,
            documentIdentifier: nil
        )
        guard let data = try? JSONEncoder().encode(pending),
              let decoded = try? JSONDecoder().decode(PendingDictation.self, from: data) else {
            return XCTFail("the record must survive the App Group round trip")
        }
        XCTAssertEqual(decoded.raw, correctedText, "the keyboard still types the user's spelling")
        XCTAssertEqual(decoded.engineRaw, engineText)
    }

    func testAPendingDictationWrittenWithoutTheFieldStillDecodes() {
        let pending = PendingDictation(
            raw: correctedText, policy: .snapshot(), recordingDuration: 3, documentIdentifier: nil
        )
        XCTAssertNil(pending.engineRaw)
    }
}
