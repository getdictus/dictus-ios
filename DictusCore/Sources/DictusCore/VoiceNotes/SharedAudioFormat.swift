// DictusCore/Sources/DictusCore/VoiceNotes/SharedAudioFormat.swift
// What container a shared audio file really is, read from its first bytes (#620).
import Foundation

/// The container of an audio file handed to Dictus through the share sheet.
///
/// ### Why the bytes and not the file name
///
/// The name a sharing app gives a file is a hint, not a fact. WhatsApp hands over
/// `.opus` files that are Ogg containers, Telegram uses `.ogg` or `.oga` for the same
/// thing, and Voice Memos' `.m4a` can hold AAC or, measured in the #620 spike, Opus —
/// which `AVAudioFile` refuses (-50) while `AVAssetReader` reads it. The share
/// extension copies the file into the App Group under a name of its own choosing,
/// and the extension it picks comes from here, so the app's decoder sees a name that
/// matches the content even when the sender's did not.
public enum SharedAudioFormat: String, Codable, Sendable, CaseIterable {
    /// Ogg container. In practice Ogg Opus: every voice note WhatsApp, Telegram and
    /// Signal send. Ogg Vorbis shares the magic and is decoded by the same path when
    /// the platform can.
    case ogg
    /// ISO base media (`ftyp` box): `.m4a`, `.mp4`, `.mov` audio. AAC or Opus inside.
    case mpeg4
    /// MPEG-1/2 layer III, with or without an ID3 tag in front.
    case mp3
    /// RIFF/WAVE.
    case wav
    /// Apple Core Audio Format.
    case caf
    /// AIFF / AIFF-C.
    case aiff
    /// Native FLAC.
    case flac
    /// AMR narrow-band, which some Android senders still produce.
    case amr
    /// Raw AAC in ADTS frames, no container. What a received Signal voice note from an
    /// Android sender is, under a `.m4a` name (measured, Radar, 2026-10-01). AVFoundation
    /// reads it only when the file is named `.aac`, which is why the stored name follows
    /// the content.
    case adts
    /// WebM / Matroska: what a browser's `MediaRecorder` writes. AVFoundation does not
    /// open it; `MatroskaOpusDemuxer` takes Opus out of it.
    case matroska
    /// WeChat's SILK v3. Recognised so it can be refused by name: no Apple decoder reads
    /// SILK and Dictus ships none.
    case silk

    /// The extension the share extension stores the file under. Chosen so that
    /// `AVURLAsset`, which infers the container from the extension before it sniffs,
    /// is never told the wrong thing.
    public var fileExtension: String {
        switch self {
        case .ogg: return "ogg"
        case .mpeg4: return "m4a"
        case .mp3: return "mp3"
        case .wav: return "wav"
        case .caf: return "caf"
        case .aiff: return "aiff"
        case .flac: return "flac"
        case .amr: return "amr"
        case .adts: return "aac"
        case .matroska: return "webm"
        case .silk: return "silk"
        }
    }

    /// Whether Dictus can decode this container on some path. Only SILK is refused.
    public var isSupported: Bool { self != .silk }

    /// How many leading bytes `sniff` needs. Twelve covers every signature below.
    public static let sniffLength = 12

    /// Identify the container from the first bytes of the file, or nil when none
    /// matches — in which case the file is refused rather than guessed at.
    public static func sniff(_ data: Data) -> SharedAudioFormat? {
        let bytes = [UInt8](data.prefix(sniffLength))
        func ascii(_ range: Range<Int>) -> String? {
            guard bytes.count >= range.upperBound else { return nil }
            return String(bytes: bytes[range], encoding: .ascii)
        }

        if ascii(0..<4) == "OggS" { return .ogg }
        if ascii(4..<8) == "ftyp" { return .mpeg4 }
        if ascii(0..<4) == "RIFF", ascii(8..<12) == "WAVE" { return .wav }
        if ascii(0..<4) == "caff" { return .caf }
        if ascii(0..<4) == "FORM", let kind = ascii(8..<12), kind == "AIFF" || kind == "AIFC" { return .aiff }
        if ascii(0..<4) == "fLaC" { return .flac }
        if ascii(0..<5) == "#!AMR" { return .amr }
        if bytes.count >= 4, bytes[0] == 0x1A, bytes[1] == 0x45, bytes[2] == 0xDF, bytes[3] == 0xA3 { return .matroska }
        // WeChat writes the SILK magic at offset 0 or after one 0x02 byte.
        if ascii(0..<9) == "#!SILK_V3" || ascii(1..<10) == "#!SILK_V3" { return .silk }
        if ascii(0..<3) == "ID3" { return .mp3 }
        // ADTS: the 12-bit sync word, then a layer field of 00 — the value MPEG audio
        // reserves, and the one ADTS always carries. Checked before MP3 for that reason.
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] & 0xF6 == 0xF0 { return .adts }
        // A bare MPEG audio frame: an 11-bit sync word, then a layer field that is
        // not "reserved". Layer III is 01 in those two bits; layers I and II are
        // accepted too because AVFoundation decodes them by the same path.
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] & 0xE0 == 0xE0, bytes[1] & 0x06 != 0 {
            return .mp3
        }
        return nil
    }

    /// Read the first bytes of `url` and identify them.
    public static func sniff(contentsOf url: URL) -> SharedAudioFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: sniffLength) else { return nil }
        return sniff(data)
    }
}
