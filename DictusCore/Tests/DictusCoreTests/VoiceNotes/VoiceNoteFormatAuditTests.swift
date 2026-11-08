import XCTest
@testable import DictusCore

/// The #620 format audit (2026-10-01): every container a messenger can hand over is
/// identified by its bytes, stored under a name that matches them, and decoded — or
/// refused by name. Fixtures are ffmpeg-made 2 s tones (the AMR one is silence: no
/// AMR encoder exists on a Mac).
final class VoiceNoteFormatAuditTests: XCTestCase {

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/SharedAudio"))
    }

    /// The share extension's path: sniff, store under the sniffed extension, decode.
    private func decodeAsShared(_ name: String) async throws -> (SharedAudioFormat, [Float]) {
        let source = try fixture(name)
        let format = try XCTUnwrap(SharedAudioFormat.sniff(contentsOf: source), "\(name) not recognised")
        let storage = VoiceNoteStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let drop = try VoiceNoteInbox.drop(copying: source, format: format, durationSeconds: nil, storage: storage)
        let note = try XCTUnwrap(VoiceNoteInbox.ingest(storage: storage).first { $0.id == drop.id })
        return (format, try await SharedAudioDecoder.decode(url: try XCTUnwrap(storage.audioURL(for: note))))
    }

    func testEveryAcceptedFormatIsDetectedByContentAndDecodes() async throws {
        let cases: [(String, SharedAudioFormat)] = [
            ("voice-aac.m4a", .mpeg4),
            ("voice-opus.m4a", .mpeg4),
            ("radar-adts.m4a", .adts),          // raw ADTS AAC under a .m4a name (Radar)
            ("voice.mp3", .mp3),                // with an ID3 tag
            ("signal-voice.mpg", .mp3),         // bare MP3 frames in a .mpg (Signal)
            ("voice-20ms.ogg", .ogg),           // Ogg Opus
            ("voice-stereo-60ms.opus", .ogg),   // WhatsApp's .opus
            ("voice-vorbis.ogg", .ogg),         // Ogg Vorbis
            ("voice.wav", .wav),
            ("voice.caf", .caf),
            ("voice.aiff", .aiff),
            ("voice.flac", .flac),
            ("voice.webm", .matroska),          // WebM Opus (browser MediaRecorder)
            ("silence.amr", .amr)
        ]
        for (name, expected) in cases {
            let (format, samples) = try await decodeAsShared(name)
            XCTAssertEqual(format, expected, name)
            XCTAssertEqual(Double(samples.count) / SharedAudioDecoder.sampleRate, 2.0, accuracy: 0.15, name)
        }
    }

    func testTheStoredNameFollowsTheContent() {
        XCTAssertEqual(SharedAudioFormat.adts.fileExtension, "aac")
        XCTAssertEqual(SharedAudioFormat.matroska.fileExtension, "webm")
        XCTAssertEqual(SharedAudioFormat.sniff(Data([0xFF, 0xF1, 0x4C, 0x40])), .adts)
        XCTAssertEqual(SharedAudioFormat.sniff(Data([0xFF, 0xF9, 0x4C, 0x40])), .adts)
        // Layer III stays MP3.
        XCTAssertEqual(SharedAudioFormat.sniff(Data([0xFF, 0xFB, 0x90, 0x00])), .mp3)
    }

    func testVideosAreRefusedWhateverTheirContainer() async throws {
        XCTAssertNil(SharedAudioFormat.sniff(contentsOf: try fixture("film.mpg")))
        let mp4 = await SharedAudioDecoder.hasVideoTrack(try fixture("film.mp4"))
        XCTAssertTrue(mp4)
        XCTAssertTrue(MatroskaOpusDemuxer.hasVideoTrack(try Data(contentsOf: try fixture("film.webm"))))
        XCTAssertFalse(MatroskaOpusDemuxer.hasVideoTrack(try Data(contentsOf: try fixture("voice.webm"))))
    }

    func testWeChatSilkIsRecognisedAndRefusedByName() async throws {
        let url = try fixture("wechat.silk")
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: url), .silk)
        XCTAssertFalse(SharedAudioFormat.silk.isSupported)
        do {
            _ = try await SharedAudioDecoder.decode(url: url)
            XCTFail("SILK must be refused")
        } catch let error as VoiceNoteDecodeError {
            XCTAssertEqual(error, .unsupportedCodec("silk"))
        }
    }

    func testMatroskaDemuxReadsOpusHeadAndPackets() throws {
        let stream = try MatroskaOpusDemuxer.demux(try Data(contentsOf: try fixture("voice.webm")))
        XCTAssertEqual(stream.head.channelCount, 1)
        XCTAssertGreaterThan(stream.packets.count, 50)
        XCTAssertEqual(try XCTUnwrap(stream.duration), 2.0, accuracy: 0.05)
        XCTAssertThrowsError(try MatroskaOpusDemuxer.demux(Data("not webm".utf8)))
    }

    /// A real Radar note (raw ADTS AAC named .m4a), when `DICTUS_RADAR_SAMPLE` points at
    /// one. Never committed: it is someone's voice. The 2026-10-01 sample is 81 s.
    func testARealRadarSampleWhenProvided() async throws {
        guard let path = ProcessInfo.processInfo.environment["DICTUS_RADAR_SAMPLE"],
              FileManager.default.isReadableFile(atPath: path) else {
            throw XCTSkip("set DICTUS_RADAR_SAMPLE to a received Radar .m4a to run this")
        }
        let url = URL(fileURLWithPath: path)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: url), .adts)
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("radar-\(UUID()).aac")
        try FileManager.default.copyItem(at: url, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }
        let samples = try await SharedAudioDecoder.decode(url: copy)
        XCTAssertGreaterThan(samples.count, 16_000 * 60)
    }
}
