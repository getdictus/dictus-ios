import XCTest
@testable import DictusCore

/// The smaller rules of #620: chunking, the engine gate, the defaults, the Live
/// Activity content, the link, the Pro gate and the history record's new fields.
final class VoiceNoteRulesTests: XCTestCase {

    // MARK: - Chunker

    /// `seconds` of loud signal with one quiet 300 ms pause at each `pauses` second.
    private func speech(seconds: Double, pauses: [Double] = []) -> [Float] {
        let rate = SharedAudioDecoder.sampleRate
        var samples = (0..<Int(seconds * rate)).map { Float(sin(Double($0) * 0.3)) * 0.5 }
        for pause in pauses {
            let start = Int(pause * rate)
            for index in start..<min(start + Int(0.3 * rate), samples.count) { samples[index] = 0 }
        }
        return samples
    }

    func testAShortNoteIsOneChunk() {
        let samples = speech(seconds: 50)
        XCTAssertEqual(VoiceNoteChunker.ranges(for: samples), [0..<samples.count])
        XCTAssertTrue(VoiceNoteChunker.ranges(for: []).isEmpty)
    }

    func testChunksCoverTheWholeNoteWithoutOverlap() {
        let samples = speech(seconds: 600)
        let ranges = VoiceNoteChunker.ranges(for: samples)
        XCTAssertEqual(ranges.first?.lowerBound, 0)
        XCTAssertEqual(ranges.last?.upperBound, samples.count)
        for (left, right) in zip(ranges, ranges.dropFirst()) {
            XCTAssertEqual(left.upperBound, right.lowerBound)
        }
        // Ten minutes in at most 45 s parts: about fourteen progress steps.
        XCTAssertGreaterThanOrEqual(ranges.count, 14)
        XCTAssertLessThanOrEqual(ranges.count, 17)
        let longest = ranges.map(\.count).max() ?? 0
        XCTAssertLessThanOrEqual(Double(longest) / SharedAudioDecoder.sampleRate, 55.01)
    }

    func testTheCutLandsInThePause() {
        let samples = speech(seconds: 100, pauses: [40])
        let firstCut = VoiceNoteChunker.ranges(for: samples)[0].upperBound
        let cutSeconds = Double(firstCut) / SharedAudioDecoder.sampleRate
        XCTAssertEqual(cutSeconds, 40.15, accuracy: 0.2)
    }

    func testAShortTailIsMergedIntoThePreviousChunk() {
        // 50 s: 45 + 5 would leave a 5 s scrap, so it stays one chunk.
        XCTAssertEqual(VoiceNoteChunker.ranges(for: speech(seconds: 54)).count, 1)
        let ranges = VoiceNoteChunker.ranges(for: speech(seconds: 60))
        XCTAssertEqual(ranges.count, 2)
        XCTAssertGreaterThanOrEqual(Double(ranges[1].count) / SharedAudioDecoder.sampleRate, 10)
    }

    // MARK: - Engine gate

    @MainActor
    func testTheGateServesADictationBeforeAVoiceNoteThatWaitedLonger() async {
        let gate = EngineAccessGate()
        var order: [String] = []
        await gate.acquire(.voiceNote)

        let note = Task { @MainActor in
            await gate.acquire(.voiceNote); order.append("note"); gate.release()
        }
        await Task.yield()
        let dictation = Task { @MainActor in
            await gate.acquire(.dictation); order.append("dictation"); gate.release()
        }
        // Let both park behind the holder.
        while !(gate.isWaiting(.voiceNote) && gate.isWaiting(.dictation)) { await Task.yield() }

        gate.release()
        await dictation.value
        await note.value
        XCTAssertEqual(order, ["dictation", "note"])
        XCTAssertNil(gate.holder)
    }

    @MainActor
    func testAFreeGateIsTakenAtOnceAndReleasedByWithAccess() async {
        let gate = EngineAccessGate()
        let value = await gate.withAccess(.dictation) { () -> Int in
            XCTAssertEqual(gate.holder, .dictation)
            return 7
        }
        XCTAssertEqual(value, 7)
        XCTAssertNil(gate.holder)
    }

    // MARK: - Defaults

    func testDefaultsAreAutoDetectAndSummary() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "voicenote-\(UUID())"))
        let settings = VoiceNoteSettings.load(from: defaults)
        XCTAssertEqual(settings.language, .autoDetect)
        XCTAssertEqual(settings.mode, .smartMode(SmartModeCatalogue.summaryIdentifier))
        XCTAssertEqual(settings.mode.smartMode?.id, SmartModeCatalogue.summaryIdentifier)
    }

    func testDefaultsRoundTripAndUnknownValuesDegrade() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "voicenote-\(UUID())"))
        VoiceNoteSettings(language: .fixed(.german), mode: .transcriptOnly).save(to: defaults)
        XCTAssertEqual(VoiceNoteSettings.load(from: defaults),
                       VoiceNoteSettings(language: .fixed(.german), mode: .transcriptOnly))

        defaults.set("klingon", forKey: SharedKeys.voiceNoteLanguage)
        defaults.set("a-mode-from-the-future", forKey: SharedKeys.voiceNoteMode)
        let degraded = VoiceNoteSettings.load(from: defaults)
        XCTAssertEqual(degraded.language, .autoDetect)
        XCTAssertNil(degraded.mode.smartMode, "an unknown mode behaves as transcript only")
    }

    func testThePolicyNeverFollowsTheKeyboard() {
        let auto = VoiceNoteSettings().languagePolicy(activeModel: "parakeet-tdt-0.6b-v3", keyboardLanguage: .french)
        XCTAssertEqual(auto.mode, .autoDetect)
        XCTAssertEqual(auto.engine, .parakeet)
        let fixed = VoiceNoteSettings(language: .fixed(.english))
            .languagePolicy(activeModel: "openai_whisper-small", keyboardLanguage: .french)
        XCTAssertEqual(fixed.mode, .explicit(.english))
        XCTAssertEqual(fixed.sttLanguageCode, "en")
    }

    // MARK: - Live Activity content and link

    func testPreviewIsCutOnAWordAndFlattened() {
        let long = String(repeating: "mot ", count: 80)
        let preview = VoiceNoteActivityContent.trimmedPreview("Bonjour\n" + long)
        XCTAssertLessThanOrEqual(preview.count, VoiceNoteActivityContent.previewLength + 1)
        XCTAssertTrue(preview.hasPrefix("Bonjour mot"))
        XCTAssertTrue(preview.hasSuffix("mot…"))
        XCTAssertEqual(VoiceNoteActivityContent.trimmedPreview("court"), "court")
    }

    func testProgressIsClampedAndThePayloadStaysSmall() throws {
        let content = VoiceNoteActivityContent(headline: "Transcription d’un message vocal…",
                                               detail: "1 en cours, 3 en attente", progress: 1.7,
                                               preview: String(repeating: "é", count: 500), noteID: UUID())
        XCTAssertEqual(content.progress, 1)
        let state = DictusLiveActivityAttributesPayloadProbe.encodedSize(content)
        XCTAssertLessThan(state, 1024, "ActivityKit caps a content update at 4 KB")
    }

    func testTheLinkRoundTrips() throws {
        let id = UUID()
        let url = try XCTUnwrap(VoiceNoteActivityContent(headline: "x", noteID: id, isDone: true).url)
        XCTAssertEqual(url.absoluteString, "dictus://voice-note?id=\(id.uuidString)")
        XCTAssertEqual(VoiceNoteURL.target(of: url), .some(id))
        let list = try XCTUnwrap(VoiceNoteActivityContent(headline: "x").url)
        XCTAssertEqual(VoiceNoteURL.target(of: list), .some(nil))
        XCTAssertNil(VoiceNoteURL.target(of: try XCTUnwrap(URL(string: "dictus://dictate"))))
    }

    // MARK: - Pro gate

    func testShareDecision() {
        XCTAssertEqual(VoiceNoteAvailability.shareDecision(isEntitled: true, paywallVisible: false), .accept)
        XCTAssertEqual(VoiceNoteAvailability.shareDecision(isEntitled: true, paywallVisible: true), .accept)
        XCTAssertEqual(VoiceNoteAvailability.shareDecision(isEntitled: false, paywallVisible: true), .refuseNeedsPro)
        // #236: no subscription is named while the paywall is hidden.
        XCTAssertEqual(VoiceNoteAvailability.shareDecision(isEntitled: false, paywallVisible: false), .refuseUnavailable)
        XCTAssertFalse(VoiceNoteAvailability.mayTranscribe(isEntitled: false))
    }

    func testTheSummaryDependsOnAppleIntelligenceAndNothingElse() {
        XCTAssertNil(VoiceNoteAvailability.summaryUnavailableReason(engineState: .available))
        XCTAssertEqual(VoiceNoteAvailability.summaryUnavailableReason(engineState: .deviceNotEligible), .deviceNotEligible)
        XCTAssertEqual(VoiceNoteAvailability.summaryUnavailableReason(engineState: .appleIntelligenceNotEnabled),
                       .appleIntelligenceNotEnabled)
    }

    func testVoiceNotesAreAProFeatureWithTheirOwnSwitch() {
        XCTAssertEqual(ProFeature.voiceNotes.settingsKey, SharedKeys.voiceNotesEnabled)
        XCTAssertFalse(ProFeature.voiceNotes.requiresAppleIntelligence)
        XCTAssertEqual(ProFeature.allCases.last, .voiceNotes)
    }

    // MARK: - History record

    @MainActor
    func testARecordWrittenBeforeVoiceNotesReadsAsADictation() throws {
        let legacy = """
        [{"id":"\(UUID().uuidString)","text":"Bonjour","language":"fr","durationSeconds":3,
          "createdAt":"2026-09-01T10:00:00Z","sttProvider":"PK"}]
        """
        let records = try TranscriptionHistoryStore.decoder.decode([TranscriptionRecord].self, from: Data(legacy.utf8))
        XCTAssertEqual(records.first?.source, .dictation)
        XCTAssertNil(records.first?.summary)
    }

    @MainActor
    func testADictationIsEncodedExactlyAsBefore() throws {
        let record = TranscriptionRecord(text: "a", language: "fr", durationSeconds: 1, sttProvider: "PK")
        let json = String(decoding: try TranscriptionHistoryStore.encoder.encode(record), as: UTF8.self)
        XCTAssertFalse(json.contains("source"))
        XCTAssertFalse(json.contains("summary"))
    }

    @MainActor
    func testASharedFileRecordKeepsItsSourceAndSummary() throws {
        let id = UUID()
        let policy = VoiceNoteSettings().languagePolicy(activeModel: "parakeet-tdt-0.6b-v3", keyboardLanguage: .french)
        let record = TranscriptionRecord(id: id, text: "Long message", policy: policy, duration: 61, source: .sharedFile)
            .withSummary("Court", modeIdentifier: SmartModeCatalogue.summaryIdentifier)
        let data = try TranscriptionHistoryStore.encoder.encode(record)
        let decoded = try TranscriptionHistoryStore.decoder.decode(TranscriptionRecord.self, from: data)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.source, .sharedFile)
        XCTAssertEqual(decoded.summary, "Court")
        XCTAssertEqual(decoded.summaryModeIdentifier, SmartModeCatalogue.summaryIdentifier)
        XCTAssertEqual(decoded.language, TranscriptionRecord.autoDetectedCode)
        XCTAssertEqual(decoded.durationSeconds, 61)
    }

    @MainActor
    func testUpdateSummaryIsUngatedAndAppendStaysGated() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var entitled = true
        let store = TranscriptionHistoryStore(fileURL: url, isEntitled: { entitled })
        let record = try XCTUnwrap(store.append(TranscriptionRecord(text: "t", language: "fr", durationSeconds: 1,
                                                                     sttProvider: "PK", source: .sharedFile)))
        entitled = false
        store.updateSummary(id: record.id, to: "s", modeIdentifier: "summary")
        XCTAssertEqual(store.record(id: record.id)?.summary, "s")
        XCTAssertNil(store.append(TranscriptionRecord(text: "u", language: "fr", durationSeconds: 1, sttProvider: "PK")))
    }
}

/// Measures the encoded size of the content the way ActivityKit carries it.
private enum DictusLiveActivityAttributesPayloadProbe {
    static func encodedSize(_ content: VoiceNoteActivityContent) -> Int {
        (try? JSONEncoder().encode(content).count) ?? .max
    }
}
