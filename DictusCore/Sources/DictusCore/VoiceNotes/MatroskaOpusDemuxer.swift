// DictusCore/Sources/DictusCore/VoiceNotes/MatroskaOpusDemuxer.swift
// Takes Opus packets out of a WebM / Matroska file, decoding nothing (#620 format audit).
import Foundation

/// Failures of the Matroska demuxer. Diagnostic only.
public enum MatroskaDemuxError: Error, Equatable {
    case notMatroska
    case truncated
    /// The file carries a picture: a video, refused whatever its type said.
    case hasVideo
    /// No Opus audio track. Vorbis-in-WebM exists and is rare in voice messages.
    case noOpusTrack
    /// A laced block. Audio muxers do not lace Opus in practice; refused rather than
    /// half-supported.
    case lacedBlock
}

/// A minimal EBML walker for the one case voice messages need: Opus audio in WebM.
///
/// ### Why it exists
///
/// AVFoundation does not open WebM or Matroska at all (measured on macOS 27, 2026-10-01:
/// `loadTracks` fails with "Ouverture impossible"), and browsers' `MediaRecorder` —
/// which web-based messengers record voice messages with — writes exactly that. The
/// container is simple enough to take apart here, and the packets then go to Apple's
/// Opus decoder through the same path as the Ogg fallback (`SharedAudioDecoder`).
///
/// Only what is needed is read: the tracks (to find the Opus track and to refuse a
/// video), its `CodecPrivate` (the `OpusHead`), and the blocks of that track.
public enum MatroskaOpusDemuxer {

    // Element IDs, with their length-marker bits, as the specification writes them.
    static let ebmlHeader: UInt32 = 0x1A45_DFA3
    static let segment: UInt32 = 0x1853_8067
    static let tracks: UInt32 = 0x1654_AE6B
    static let trackEntry: UInt32 = 0xAE
    static let trackNumber: UInt32 = 0xD7
    static let trackType: UInt32 = 0x83
    static let codecID: UInt32 = 0x86
    static let codecPrivate: UInt32 = 0x63A2
    static let cluster: UInt32 = 0x1F43_B675
    static let simpleBlock: UInt32 = 0xA3
    static let blockGroup: UInt32 = 0xA0
    static let block: UInt32 = 0xA1

    /// Masters whose children are read. Everything else is skipped by its size.
    static let masters: Set<UInt32> = [segment, tracks, trackEntry, cluster, blockGroup]

    struct Track {
        var number: UInt64?
        var type: UInt64?
        var codec: String?
        var privateData: Data?
    }

    /// Demux a whole file held in memory into the same shape the Ogg demuxer returns.
    public static func demux(_ data: Data) throws -> OggOpusStream {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, readID(bytes, at: 0)?.id == ebmlHeader else { throw MatroskaDemuxError.notMatroska }

        var tracks: [Track] = []
        var current: Track?
        var blocks: [(track: UInt64, payload: ArraySlice<UInt8>)] = []

        func walk(_ range: Range<Int>) throws {
            var offset = range.lowerBound
            while offset < range.upperBound {
                guard let (id, idLength) = readID(bytes, at: offset),
                      let (size, sizeLength) = readSize(bytes, at: offset + idLength) else {
                    throw MatroskaDemuxError.truncated
                }
                let bodyStart = offset + idLength + sizeLength
                // An unknown size (live recordings) runs to the end of the parent.
                let bodyEnd = size.map { min(bodyStart + Int(clamping: $0), range.upperBound) } ?? range.upperBound
                guard bodyStart <= bodyEnd else { throw MatroskaDemuxError.truncated }

                switch id {
                case trackEntry:
                    current = Track()
                    try walk(bodyStart..<bodyEnd)
                    if let finished = current { tracks.append(finished) }
                    current = nil
                case _ where masters.contains(id):
                    try walk(bodyStart..<bodyEnd)
                case trackNumber:
                    current?.number = unsigned(bytes[bodyStart..<bodyEnd])
                case trackType:
                    current?.type = unsigned(bytes[bodyStart..<bodyEnd])
                case codecID:
                    current?.codec = String(bytes: bytes[bodyStart..<bodyEnd], encoding: .ascii)?
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                case codecPrivate:
                    current?.privateData = Data(bytes[bodyStart..<bodyEnd])
                case simpleBlock, block:
                    guard let (trackNumber, length) = readSize(bytes, at: bodyStart), let trackNumber,
                          bodyStart + length + 3 <= bodyEnd else { throw MatroskaDemuxError.truncated }
                    let flags = bytes[bodyStart + length + 2]
                    guard (flags >> 1) & 0x03 == 0 else { throw MatroskaDemuxError.lacedBlock }
                    blocks.append((trackNumber, bytes[(bodyStart + length + 3)..<bodyEnd]))
                default:
                    break
                }
                offset = bodyEnd
            }
        }
        try walk(0..<bytes.count)

        // Type 1 is video. A WebM film is refused here even if it also has audio.
        if tracks.contains(where: { $0.type == 1 }) { throw MatroskaDemuxError.hasVideo }
        guard let opus = tracks.first(where: { $0.codec == "A_OPUS" }),
              let number = opus.number, let head = opus.privateData else {
            throw MatroskaDemuxError.noOpusTrack
        }
        let packets = blocks.filter { $0.track == number }.map { Data($0.payload) }
        let parsedHead = try OggOpusDemuxer.parseHead(head)
        // The container's own duration is optional and in another time base; the
        // packets say exactly how much audio there is.
        let total = packets.compactMap(OggOpusDemuxer.samplesPerPacket).reduce(0, +)
        return OggOpusStream(head: parsedHead, packets: packets,
                             finalGranulePosition: Int64(total))
    }

    /// Whether a Matroska file holds a video track. False when it is not Matroska.
    public static func hasVideoTrack(_ data: Data) -> Bool {
        demuxError(data) == .hasVideo
    }

    private static func demuxError(_ data: Data) -> MatroskaDemuxError? {
        do {
            _ = try demux(data)
            return nil
        } catch let error as MatroskaDemuxError {
            return error
        } catch {
            return nil
        }
    }

    // MARK: - EBML

    /// An element ID, marker bits kept, and its length in bytes (1 to 4).
    static func readID(_ bytes: [UInt8], at offset: Int) -> (id: UInt32, length: Int)? {
        guard offset < bytes.count else { return nil }
        let first = bytes[offset]
        let length = first.leadingZeroBitCount + 1
        guard length <= 4, offset + length <= bytes.count else { return nil }
        var id: UInt32 = 0
        for index in 0..<length { id = id << 8 | UInt32(bytes[offset + index]) }
        return (id, length)
    }

    /// A size (or a block's track number): marker bit removed, nil for "unknown".
    static func readSize(_ bytes: [UInt8], at offset: Int) -> (value: UInt64?, length: Int)? {
        guard offset < bytes.count else { return nil }
        let first = bytes[offset]
        let length = first.leadingZeroBitCount + 1
        guard length <= 8, offset + length <= bytes.count else { return nil }
        var value = UInt64(first) & (0xFF >> UInt64(length))
        var allOnes = value == (0xFF >> UInt64(length))
        for index in 1..<length {
            let byte = bytes[offset + index]
            value = value << 8 | UInt64(byte)
            allOnes = allOnes && byte == 0xFF
        }
        return (allOnes ? nil : value, length)
    }

    static func unsigned(_ slice: ArraySlice<UInt8>) -> UInt64 {
        slice.reduce(0) { $0 << 8 | UInt64($1) }
    }
}
