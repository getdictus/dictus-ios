// DictusCore/Sources/DictusCore/VoiceNotes/OggOpusDemuxer.swift
// Splits an Ogg Opus file into its Opus packets, without decoding anything (#620).
import Foundation

/// The `OpusHead` identification header (RFC 7845 §5.1).
public struct OpusHead: Equatable, Sendable {
    /// 1 or 2 for the files voice messengers send. Mapping family 1 (up to 8
    /// channels) is accepted too; the decoder downmixes whatever it gets.
    public let channelCount: Int
    /// Samples at 48 kHz the decoder must drop from the start of the stream. Opus
    /// encoders prepend this much priming; keeping it shifts every word late.
    public let preSkip: Int
    /// The rate the sender recorded at. Informational only: Opus always decodes at
    /// 48 kHz, whatever this says.
    public let inputSampleRate: Int
}

/// What the demuxer found in an Ogg Opus file.
public struct OggOpusStream: Equatable, Sendable {
    public let head: OpusHead
    /// Every audio packet in order, header packets excluded.
    public let packets: [Data]
    /// The last granule position the file declares, at 48 kHz. Nil when no page
    /// carried one (a truncated file).
    public let finalGranulePosition: Int64?

    /// Playable length, in seconds, from the container alone. Nil when unknown.
    public var duration: TimeInterval? {
        guard let granule = finalGranulePosition, granule > Int64(head.preSkip) else { return nil }
        return TimeInterval(granule - Int64(head.preSkip)) / 48_000
    }
}

/// Failures of the demuxer. Diagnostic only; the user is told the file could not
/// be read, which is the one thing they can act on.
public enum OggOpusDemuxError: Error, Equatable {
    case notOgg
    case truncatedPage
    case notOpus
    case malformedHead
}

/// A minimal Ogg demuxer for the one codec voice messengers use.
///
/// ### Why this exists at all
///
/// iOS 17 and 18 do not open Ogg Opus through AVFoundation (ASSUMED in the #620
/// spike: Safari gained Ogg Opus in 18.4, and the iOS 26.5 simulator reads it
/// natively). Dictus supports iOS 17, and a WhatsApp voice note is the first thing a
/// user will share, so on those systems the container has to be taken apart here and
/// the packets fed to Apple's own Opus decoder (`kAudioFormatOpus`). No libopus, no
/// licence question — only the container is parsed in Swift.
///
/// ### Why a pure value type
///
/// The container format is fully specified (RFC 3533, RFC 7845) and the parsing is
/// byte arithmetic, so it is tested on the Mac against files ffmpeg produced, which
/// is the only way to exercise the iOS 17 path without an iOS 17 device.
public enum OggOpusDemuxer {

    /// One Ogg page header, as far as this demuxer needs it.
    struct Page {
        let headerType: UInt8
        let granulePosition: Int64
        let serial: UInt32
        let segmentSizes: [Int]
        let bodyRange: Range<Int>
        let nextOffset: Int

        /// Bit 0x01: the first packet on this page continues one from the previous page.
        var continuesPacket: Bool { headerType & 0x01 != 0 }
    }

    /// Parse the page starting at `offset`.
    static func page(in bytes: [UInt8], at offset: Int) throws -> Page {
        guard offset + 27 <= bytes.count else { throw OggOpusDemuxError.truncatedPage }
        guard bytes[offset] == 0x4F, bytes[offset + 1] == 0x67,
              bytes[offset + 2] == 0x67, bytes[offset + 3] == 0x53 else {
            throw OggOpusDemuxError.notOgg
        }
        let headerType = bytes[offset + 5]
        let granule = Int64(bitPattern: littleEndian(bytes, at: offset + 6, count: 8))
        let serial = UInt32(truncatingIfNeeded: littleEndian(bytes, at: offset + 14, count: 4))
        let segmentCount = Int(bytes[offset + 26])
        let tableStart = offset + 27
        guard tableStart + segmentCount <= bytes.count else { throw OggOpusDemuxError.truncatedPage }
        let sizes = (0..<segmentCount).map { Int(bytes[tableStart + $0]) }
        let bodyStart = tableStart + segmentCount
        let bodyEnd = bodyStart + sizes.reduce(0, +)
        guard bodyEnd <= bytes.count else { throw OggOpusDemuxError.truncatedPage }
        return Page(headerType: headerType, granulePosition: granule, serial: serial,
                    segmentSizes: sizes, bodyRange: bodyStart..<bodyEnd, nextOffset: bodyEnd)
    }

    /// Demux a whole file held in memory.
    ///
    /// Only the first logical stream is read: a voice note is one stream, and a
    /// chained or multiplexed file is something no messenger sends.
    public static func demux(_ data: Data) throws -> OggOpusStream {
        let bytes = [UInt8](data)
        var offset = 0
        var serial: UInt32?
        var packets: [Data] = []
        var pending: [UInt8] = []
        var finalGranule: Int64?

        while offset < bytes.count {
            let page = try page(in: bytes, at: offset)
            offset = page.nextOffset
            if serial == nil { serial = page.serial }
            guard page.serial == serial else { continue }
            // A page that does not continue a packet invalidates a dangling one. Ogg
            // allows that only for a damaged stream, and the honest answer there is
            // to drop the fragment rather than glue two unrelated halves together.
            if !page.continuesPacket { pending.removeAll() }

            var cursor = page.bodyRange.lowerBound
            for size in page.segmentSizes {
                pending.append(contentsOf: bytes[cursor..<(cursor + size)])
                cursor += size
                // A lacing value below 255 ends the packet; 255 means it goes on.
                if size < 255 {
                    packets.append(Data(pending))
                    pending.removeAll()
                }
            }
            // -1 is "no packet ends on this page": not a position.
            if page.granulePosition >= 0 { finalGranule = page.granulePosition }
        }

        guard let first = packets.first else { throw OggOpusDemuxError.notOpus }
        let head = try parseHead(first)
        // Packet 2 is OpusTags. Anything after it is audio.
        guard packets.count >= 2, String(bytes: packets[1].prefix(8), encoding: .ascii) == "OpusTags" else {
            throw OggOpusDemuxError.notOpus
        }
        return OggOpusStream(head: head, packets: Array(packets.dropFirst(2)), finalGranulePosition: finalGranule)
    }

    /// Read the duration from the container without demuxing every packet: the head
    /// for the pre-skip, the last page for the final granule. Used to refuse a file
    /// over the length cap before anything is decoded into memory.
    public static func duration(of url: URL) -> TimeInterval? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let headBytes = try? handle.read(upToCount: 4096),
              let firstPage = try? page(in: [UInt8](headBytes), at: 0) else { return nil }
        let headPacket = Data([UInt8](headBytes)[firstPage.bodyRange])
        guard let head = try? parseHead(headPacket),
              let size = try? handle.seekToEnd() else { return nil }
        // An Ogg page is at most 65 307 bytes, so the last one starts inside this tail.
        let tailLength = min(size, 65_536 + 27)
        try? handle.seek(toOffset: size - tailLength)
        guard let tail = try? handle.readToEnd() else { return nil }
        let granule = lastGranulePosition(in: [UInt8](tail))
        return OggOpusStream(head: head, packets: [], finalGranulePosition: granule).duration
    }

    /// The granule of the last complete page in `bytes`, scanning backwards for the
    /// capture pattern.
    static func lastGranulePosition(in bytes: [UInt8]) -> Int64? {
        guard bytes.count >= 27 else { return nil }
        var index = bytes.count - 27
        while index >= 0 {
            if bytes[index] == 0x4F, bytes[index + 1] == 0x67, bytes[index + 2] == 0x67,
               bytes[index + 3] == 0x53, let page = try? page(in: bytes, at: index),
               page.granulePosition >= 0 {
                return page.granulePosition
            }
            index -= 1
        }
        return nil
    }

    static func parseHead(_ packet: Data) throws -> OpusHead {
        let bytes = [UInt8](packet)
        guard bytes.count >= 19, String(bytes: bytes[0..<8], encoding: .ascii) == "OpusHead" else {
            throw OggOpusDemuxError.notOpus
        }
        let channels = Int(bytes[9])
        guard channels > 0 else { throw OggOpusDemuxError.malformedHead }
        return OpusHead(
            channelCount: channels,
            preSkip: Int(littleEndian(bytes, at: 10, count: 2)),
            inputSampleRate: Int(littleEndian(bytes, at: 12, count: 4))
        )
    }

    /// Samples per channel, at 48 kHz, that one Opus packet decodes to (RFC 6716 §3.1).
    ///
    /// Needed because Apple's decoder is fed one packet at a time with an explicit
    /// frame count, and voice notes are not uniform: WhatsApp encodes 20 ms frames,
    /// Telegram has shipped 60 ms ones, and a packet may carry several frames.
    public static func samplesPerPacket(_ packet: Data) -> Int? {
        guard let toc = packet.first else { return nil }
        let config = Int(toc >> 3)
        let frameSize: Int
        switch config {
        case 0...11:
            // SILK: 10, 20, 40, 60 ms.
            frameSize = [480, 960, 1920, 2880][config % 4]
        case 12...15:
            // Hybrid: 10, 20 ms.
            frameSize = [480, 960][config % 2]
        default:
            // CELT: 2.5, 5, 10, 20 ms.
            frameSize = [120, 240, 480, 960][config % 4]
        }
        let frameCount: Int
        switch toc & 0x03 {
        case 0: frameCount = 1
        case 1, 2: frameCount = 2
        default:
            guard packet.count >= 2 else { return nil }
            frameCount = Int(packet[packet.startIndex + 1] & 0x3F)
        }
        guard frameCount > 0 else { return nil }
        return frameSize * frameCount
    }

    private static func littleEndian(_ bytes: [UInt8], at offset: Int, count: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<count {
            value |= UInt64(bytes[offset + index]) << (8 * UInt64(index))
        }
        return value
    }
}
