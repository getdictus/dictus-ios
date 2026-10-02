import XCTest
@testable import DictusCore

/// Format detection, the Ogg demuxer and both decoding paths, against small files
/// ffmpeg produced (#620). Every fixture is the same 2 s 440 Hz tone, so every path
/// must land on about 32 000 samples at 16 kHz.
final class SharedAudioDecodingTests: XCTestCase {

    private func fixture(_ name: String) throws -> URL {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/SharedAudio")
        return try XCTUnwrap(url, "missing fixture \(name)")
    }

    /// `minimumPeak` is lowered for the stereo fallback only: Apple's Opus decoder folds
    /// stereo to mono about 3 dB down (same waveform, measured correlation 0.9999).
    private func assertTwoSeconds(_ samples: [Float], minimumPeak: Float = 0.1,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let seconds = Double(samples.count) / SharedAudioDecoder.sampleRate
        XCTAssertEqual(seconds, 2.0, accuracy: 0.1, "decoded \(seconds)s", file: file, line: line)
        // A tone, not silence: the decoder must not hand back zeros of the right length.
        let peak = samples.map(abs).max() ?? 0
        XCTAssertGreaterThan(peak, minimumPeak, file: file, line: line)
    }

    // MARK: - Sniffing

    func testSniffRecognisesEveryFixtureByContentNotName() throws {
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice-20ms.ogg")), .ogg)
        // WhatsApp's `.opus` is an Ogg container.
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice-stereo-60ms.opus")), .ogg)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice-aac.m4a")), .mpeg4)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice-opus.m4a")), .mpeg4)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice.mp3")), .mp3)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("voice.wav")), .wav)
    }

    func testSniffSignatures() {
        XCTAssertEqual(SharedAudioFormat.sniff(Data("caff".utf8) + Data(count: 8)), .caf)
        XCTAssertEqual(SharedAudioFormat.sniff(Data("FORM\0\0\0\0AIFF".utf8)), .aiff)
        XCTAssertEqual(SharedAudioFormat.sniff(Data("FORM\0\0\0\0AIFC".utf8)), .aiff)
        XCTAssertEqual(SharedAudioFormat.sniff(Data("fLaC".utf8) + Data(count: 8)), .flac)
        XCTAssertEqual(SharedAudioFormat.sniff(Data("#!AMR\n".utf8) + Data(count: 6)), .amr)
        XCTAssertEqual(SharedAudioFormat.sniff(Data([0xFF, 0xFB, 0x90, 0x00])), .mp3)
        // Plain text, a PDF, too few bytes: refused, not guessed.
        XCTAssertNil(SharedAudioFormat.sniff(Data("hello world!".utf8)))
        XCTAssertNil(SharedAudioFormat.sniff(Data("%PDF-1.7 abc".utf8)))
        XCTAssertNil(SharedAudioFormat.sniff(Data([0x4F, 0x67])))
        // 0xFF followed by a reserved layer is not MPEG audio.
        XCTAssertNil(SharedAudioFormat.sniff(Data([0xFF, 0xE0, 0x00, 0x00])))
    }

    func testStoredExtensionMatchesTheContainer() {
        XCTAssertEqual(SharedAudioFormat.ogg.fileExtension, "ogg")
        XCTAssertEqual(SharedAudioFormat.mpeg4.fileExtension, "m4a")
    }

    // MARK: - Ogg demuxer

    func testDemuxReadsHeadAndPackets() throws {
        let stream = try OggOpusDemuxer.demux(Data(contentsOf: try fixture("voice-20ms.ogg")))
        XCTAssertEqual(stream.head.channelCount, 1)
        XCTAssertEqual(stream.head.preSkip, 312)
        // 2 s of 20 ms frames.
        XCTAssertEqual(stream.packets.count, 100, accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(stream.duration), 2.0, accuracy: 0.05)
        XCTAssertEqual(OggOpusDemuxer.samplesPerPacket(try XCTUnwrap(stream.packets.first)), 960)
    }

    func testDemuxReadsStereoSixtyMillisecondFrames() throws {
        let stream = try OggOpusDemuxer.demux(Data(contentsOf: try fixture("voice-stereo-60ms.opus")))
        XCTAssertEqual(stream.head.channelCount, 2)
        XCTAssertEqual(OggOpusDemuxer.samplesPerPacket(try XCTUnwrap(stream.packets.first)), 2880)
    }

    func testDurationProbeReadsOnlyTheEnds() throws {
        let duration = try XCTUnwrap(OggOpusDemuxer.duration(of: try fixture("voice-20ms.ogg")))
        XCTAssertEqual(duration, 2.0, accuracy: 0.05)
    }

    func testDemuxRefusesWhatIsNotOggOpus() {
        XCTAssertThrowsError(try OggOpusDemuxer.demux(Data("not an ogg file at all".utf8)))
        XCTAssertThrowsError(try OggOpusDemuxer.demux(Data()))
    }

    func testSamplesPerPacketFollowsTheTOCByte() {
        // config 1 (SILK 20 ms), code 0: one frame.
        XCTAssertEqual(OggOpusDemuxer.samplesPerPacket(Data([0b0000_1000])), 960)
        // config 31 (CELT 20 ms), code 1: two frames.
        XCTAssertEqual(OggOpusDemuxer.samplesPerPacket(Data([0b1111_1001])), 1920)
        // config 3 (SILK 60 ms), code 3 with a frame count of 2.
        XCTAssertEqual(OggOpusDemuxer.samplesPerPacket(Data([0b0001_1011, 0x02])), 5760)
        XCTAssertNil(OggOpusDemuxer.samplesPerPacket(Data()))
    }

    // MARK: - Decoding

    func testAssetReaderDecodesEveryContainer() async throws {
        for name in ["voice-20ms.ogg", "voice-aac.m4a", "voice-opus.m4a", "voice.mp3", "voice.wav"] {
            let samples = try await SharedAudioDecoder.decodeWithAssetReader(
                url: try fixture(name), maxSamples: 16_000 * 60)
            assertTwoSeconds(samples)
        }
    }

    /// The iOS 17/18 path, exercised directly: the Mac reads Ogg natively, so
    /// `decode` itself would never fall back here.
    func testOggFallbackDecodesMonoTwentyMillisecondNotes() throws {
        let samples = try SharedAudioDecoder.decodeOggOpus(url: try fixture("voice-20ms.ogg"), maxSamples: 16_000 * 60)
        assertTwoSeconds(samples)
    }

    func testOggFallbackDecodesStereoSixtyMillisecondNotes() throws {
        let samples = try SharedAudioDecoder.decodeOggOpus(
            url: try fixture("voice-stereo-60ms.opus"), maxSamples: 16_000 * 60)
        assertTwoSeconds(samples, minimumPeak: 0.06)
    }

    func testDecodeEndToEnd() async throws {
        let samples = try await SharedAudioDecoder.decode(url: try fixture("voice-stereo-60ms.opus"))
        assertTwoSeconds(samples)
    }

    // MARK: - Cap

    func testCapRefusesBeforeDecoding() async throws {
        do {
            _ = try await SharedAudioDecoder.decode(url: try fixture("voice-20ms.ogg"), maximumDuration: 0.5)
            XCTFail("a 2 s note must be refused under a 0.5 s cap")
        } catch let error as VoiceNoteDecodeError {
            XCTAssertEqual(error, .tooLong(seconds: 2))
        }
    }

    func testCapRefusesWhileDecodingWhenTheContainerSaysNothing() async throws {
        do {
            _ = try await SharedAudioDecoder.decodeWithAssetReader(url: try fixture("voice.wav"), maxSamples: 8_000)
            XCTFail("the sample-count cap must refuse")
        } catch let error as VoiceNoteDecodeError {
            guard case .tooLong = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testCapToleranceAcceptsANoteRoundedUpToTheCap() {
        XCTAssertFalse(SharedAudioDecoder.exceedsCap(600.4))
        XCTAssertFalse(SharedAudioDecoder.exceedsCap(601))
        XCTAssertTrue(SharedAudioDecoder.exceedsCap(601.5))
        XCTAssertEqual(SharedAudioDecoder.maximumDuration, 600)
    }

    func testUnknownContainerIsRefused() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-audio-\(UUID()).bin")
        try Data("definitely not audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await SharedAudioDecoder.decode(url: url)
            XCTFail("text must not decode")
        } catch let error as VoiceNoteDecodeError {
            XCTAssertEqual(error, .unrecognisedFormat)
        }
    }
}
