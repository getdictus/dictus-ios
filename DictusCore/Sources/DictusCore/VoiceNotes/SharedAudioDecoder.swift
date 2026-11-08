// DictusCore/Sources/DictusCore/VoiceNotes/SharedAudioDecoder.swift
// Turns a shared audio file into the 16 kHz mono Float32 every engine reads (#620).
import AudioToolbox
import AVFoundation
import Foundation

/// Why a shared file could not become samples. `diagnosticDescription` goes to the
/// log; the voice note list names the case in the user's language.
public enum VoiceNoteDecodeError: Error, Equatable, Sendable {
    /// No known container signature. Refused rather than guessed at.
    case unrecognisedFormat
    /// The container was recognised and the platform still could not read it.
    case unreadable(String)
    /// Longer than the cap. Carries the measured length, rounded down, in seconds.
    case tooLong(seconds: Int)
    /// Decoded to nothing.
    case empty
    /// A container Dictus recognises and cannot decode on any path (SILK).
    case unsupportedCodec(String)

    public var diagnosticDescription: String {
        switch self {
        case .unrecognisedFormat: return "unrecognised container"
        case .unreadable(let detail): return "unreadable: \(detail)"
        case .tooLong(let seconds): return "too long: \(seconds)s"
        case .empty: return "decoded to zero samples"
        case .unsupportedCodec(let codec): return "unsupported codec: \(codec)"
        }
    }
}

/// Decodes shared audio for transcription.
///
/// ### Two paths, chosen by measurement (#620 spike)
///
/// `AVAssetReader` first, for every container: it is the one API that read all six
/// formats the spike tried, including Opus inside `.m4a`, which `AVAudioFile` refuses.
/// Its output settings ask for 16 kHz mono Float32 directly, so resampling and
/// downmixing happen inside AVFoundation.
///
/// Ogg is the exception that needs a second path. AVFoundation reads it on iOS 26
/// (measured on the simulator), and is assumed not to on iOS 17 and 18. When the
/// reader fails on an Ogg file, `OggOpusDemuxer` takes the container apart and the
/// packets go to Apple's own Opus decoder through `AVAudioConverter`.
///
/// ### Why it lives in DictusCore
///
/// So the decoding is tested on the Mac against real files, including the fallback,
/// which no simulator in this repo can reach any other way. The keyboard extension
/// links DictusCore and never calls any of this.
public enum SharedAudioDecoder {

    /// What every STT engine in Dictus consumes.
    public static let sampleRate: Double = 16_000

    /// The longest voice note Dictus transcribes (#620 decision 8). At 64 KB/s of
    /// Float32 that is about 38 MB of samples, which DictusApp holds comfortably next
    /// to a loaded model.
    public static let maximumDuration: TimeInterval = 10 * 60

    /// A file is refused only past this much over the cap: containers round their
    /// durations, and a note that is "10:00" on the sender's screen must not fail.
    static let capTolerance: TimeInterval = 1

    /// The playable length of `url`, read from the container without decoding, or
    /// nil when the container does not say. Used to refuse a long file before it is
    /// decoded into memory, and by the share extension to refuse it before it is
    /// even copied.
    public static func probeDuration(of url: URL, format: SharedAudioFormat) async -> TimeInterval? {
        if format == .ogg, let duration = OggOpusDemuxer.duration(of: url) {
            return duration
        }
        if format == .matroska {
            return (try? Data(contentsOf: url, options: .mappedIfSafe))
                .flatMap { try? MatroskaOpusDemuxer.demux($0) }?.duration
        }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.isNumeric else { return nil }
        let seconds = duration.seconds
        return seconds > 0 ? seconds : nil
    }

    /// Whether the file carries a video track.
    ///
    /// The share extension accepts `public.mpeg` since the #620 rework, because Signal
    /// hands a received voice note over as MP3 frames in a `.mpg` file, which iOS types
    /// as video. A real film shares that type, so a candidate is checked for being
    /// audio only before it is taken: an MPEG-4 container is asked for its tracks here,
    /// and anything `SharedAudioFormat.sniff` does not recognise — an MPEG program
    /// stream, which is what a real `.mpg` film is — never gets this far.
    public static func hasVideoTrack(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        let video = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        return !video.isEmpty
    }

    /// Whether a note of this length is over the cap.
    public static func exceedsCap(_ duration: TimeInterval,
                                  maximum: TimeInterval = maximumDuration) -> Bool {
        duration > maximum + capTolerance
    }

    /// Decode `url` to 16 kHz mono Float32.
    ///
    /// - Parameter maximumDuration: the cap. Enforced twice: from the container's own
    ///   duration before decoding, and from the sample count while decoding, because a
    ///   container that lies about its length (or does not state one) must not be able
    ///   to make DictusApp allocate an hour of audio.
    public static func decode(url: URL,
                              maximumDuration: TimeInterval = maximumDuration) async throws -> [Float] {
        guard let format = SharedAudioFormat.sniff(contentsOf: url) else {
            throw VoiceNoteDecodeError.unrecognisedFormat
        }
        if let duration = await probeDuration(of: url, format: format),
           exceedsCap(duration, maximum: maximumDuration) {
            throw VoiceNoteDecodeError.tooLong(seconds: Int(duration))
        }
        let maxSamples = Int((maximumDuration + capTolerance) * sampleRate)

        guard format.isSupported else { throw VoiceNoteDecodeError.unsupportedCodec(format.rawValue) }

        let samples: [Float]
        if format == .matroska {
            // AVFoundation does not open WebM at all (measured); straight to the demuxer.
            samples = try decodeMatroskaOpus(url: url, maxSamples: maxSamples)
        } else {
            do {
                samples = try await decodeWithAssetReader(url: url, maxSamples: maxSamples)
            } catch let error as VoiceNoteDecodeError where error != .unrecognisedFormat {
                // A cap refusal is not a reason to try again.
                if case .tooLong = error { throw error }
                if format == .ogg {
                    // The iOS 17/18 path for Ogg Opus.
                    samples = try decodeOggOpus(url: url, maxSamples: maxSamples)
                } else {
                    // AudioToolbox's file API reaches decoders AVAssetReader does not
                    // offer for a bare file, AMR on iOS being the case in point.
                    samples = try decodeWithExtAudioFile(url: url, maxSamples: maxSamples)
                }
            }
        }
        guard !samples.isEmpty else { throw VoiceNoteDecodeError.empty }
        return samples
    }

    // MARK: - AVAssetReader

    static func decodeWithAssetReader(url: URL, maxSamples: Int) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw VoiceNoteDecodeError.unreadable("loadTracks: \(error.localizedDescription)")
        }
        guard let track = tracks.first else { throw VoiceNoteDecodeError.unreadable("no audio track") }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            throw VoiceNoteDecodeError.unreadable("reader: \(error.localizedDescription)")
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw VoiceNoteDecodeError.unreadable("cannot add output") }
        reader.add(output)
        guard reader.startReading() else {
            throw VoiceNoteDecodeError.unreadable("startReading: \(reader.error?.localizedDescription ?? "-")")
        }

        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            let count = length / MemoryLayout<Float>.size
            guard count > 0 else { continue }
            let start = samples.count
            samples.append(contentsOf: repeatElement(0, count: count))
            let floatSize = MemoryLayout<Float>.size
            let status: OSStatus = samples.withUnsafeMutableBytes { raw in
                // `raw` covers the whole array; the copy lands after what was there.
                guard let base = raw.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * floatSize,
                                                  destination: base.advanced(by: start * floatSize))
            }
            guard status == kCMBlockBufferNoErr else {
                throw VoiceNoteDecodeError.unreadable("copyDataBytes \(status)")
            }
            if samples.count > maxSamples {
                reader.cancelReading()
                throw VoiceNoteDecodeError.tooLong(seconds: Int(Double(samples.count) / sampleRate))
            }
        }
        if reader.status == .failed {
            throw VoiceNoteDecodeError.unreadable("reading: \(reader.error?.localizedDescription ?? "-")")
        }
        return samples
    }

    // MARK: - Ogg Opus fallback

    /// Demux an Ogg Opus file and decode its packets with Apple's Opus decoder.
    static func decodeOggOpus(url: URL, maxSamples: Int) throws -> [Float] {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw VoiceNoteDecodeError.unreadable("read: \(error.localizedDescription)")
        }
        let stream: OggOpusStream
        do {
            stream = try OggOpusDemuxer.demux(data)
        } catch {
            throw VoiceNoteDecodeError.unreadable("demux: \(error)")
        }
        if let duration = stream.duration, Double(maxSamples) < duration * sampleRate {
            throw VoiceNoteDecodeError.tooLong(seconds: Int(duration))
        }
        let pcm48k = try decodeOpusPackets(stream)
        return try resample(pcm48k, from: 48_000, to: sampleRate)
    }

    /// Demux a WebM / Matroska file and decode its Opus track with Apple's decoder.
    static func decodeMatroskaOpus(url: URL, maxSamples: Int) throws -> [Float] {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw VoiceNoteDecodeError.unreadable("read: \(error.localizedDescription)")
        }
        let stream: OggOpusStream
        do {
            stream = try MatroskaOpusDemuxer.demux(data)
        } catch MatroskaDemuxError.noOpusTrack {
            throw VoiceNoteDecodeError.unsupportedCodec("matroska-non-opus")
        } catch {
            throw VoiceNoteDecodeError.unreadable("matroska: \(error)")
        }
        if let duration = stream.duration, Double(maxSamples) < duration * sampleRate {
            throw VoiceNoteDecodeError.tooLong(seconds: Int(duration))
        }
        return try resample(try decodeOpusPackets(stream), from: 48_000, to: sampleRate)
    }

    /// Decode through `ExtAudioFile`, asking for 16 kHz mono Float32.
    static func decodeWithExtAudioFile(url: URL, maxSamples: Int) throws -> [Float] {
        var fileRef: ExtAudioFileRef?
        var status = ExtAudioFileOpenURL(url as CFURL, &fileRef)
        guard status == noErr, let file = fileRef else {
            throw VoiceNoteDecodeError.unreadable("ExtAudioFileOpenURL \(status)")
        }
        defer { ExtAudioFileDispose(file) }
        var client = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat,
                                         UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &client)
        guard status == noErr else { throw VoiceNoteDecodeError.unreadable("client format \(status)") }

        var samples: [Float] = []
        let chunk = 4096
        var buffer = [Float](repeating: 0, count: chunk)
        while true {
            var frames = UInt32(chunk)
            let read: OSStatus = buffer.withUnsafeMutableBytes { raw in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                    mNumberChannels: 1, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress))
                return ExtAudioFileRead(file, &frames, &list)
            }
            guard read == noErr else { throw VoiceNoteDecodeError.unreadable("ExtAudioFileRead \(read)") }
            if frames == 0 { break }
            samples.append(contentsOf: buffer.prefix(Int(frames)))
            if samples.count > maxSamples {
                throw VoiceNoteDecodeError.tooLong(seconds: Int(Double(samples.count) / sampleRate))
            }
        }
        return samples
    }

    /// Opus packets to mono Float32 at 48 kHz, priming and end padding removed.
    static func decodeOpusPackets(_ stream: OggOpusStream) throws -> [Float] {
        let channels = AVAudioChannelCount(min(stream.head.channelCount, 2))
        guard let firstPacket = stream.packets.first,
              let framesPerPacket = OggOpusDemuxer.samplesPerPacket(firstPacket) else {
            throw VoiceNoteDecodeError.empty
        }
        var description = AudioStreamBasicDescription(
            mSampleRate: 48_000,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(framesPerPacket),
            mBytesPerFrame: 0,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let inputFormat = AVAudioFormat(streamDescription: &description),
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                               channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw VoiceNoteDecodeError.unreadable("no Opus decoder on this system")
        }
        // The decoder folds stereo to mono itself. Measured on macOS 27: a stereo note
        // comes out about 3 dB quieter than through AVAssetReader, with the same
        // waveform (correlation 0.9999), which no STT engine here is sensitive to.
        converter.downmix = true

        let maxPacketSize = stream.packets.map(\.count).max() ?? 0
        let largestFrameCount = stream.packets.compactMap(OggOpusDemuxer.samplesPerPacket).max() ?? framesPerPacket
        var mono: [Float] = []
        mono.reserveCapacity(stream.packets.count * framesPerPacket)

        for packet in stream.packets {
            let input = AVAudioCompressedBuffer(format: inputFormat, packetCapacity: 1,
                                                maximumPacketSize: max(maxPacketSize, 1))
            packet.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                input.data.copyMemory(from: base, byteCount: packet.count)
            }
            input.byteLength = UInt32(packet.count)
            input.packetCount = 1
            // Per-packet frame count: voice notes are not uniform, and the decoder
            // has to be told how much this packet holds when it differs from the
            // stream description's nominal value.
            let packetFrames = OggOpusDemuxer.samplesPerPacket(packet) ?? framesPerPacket
            input.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: packetFrames == framesPerPacket ? 0 : UInt32(packetFrames),
                mDataByteSize: UInt32(packet.count)
            )

            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                frameCapacity: AVAudioFrameCount(largestFrameCount)) else {
                throw VoiceNoteDecodeError.unreadable("output buffer")
            }
            var supplied = false
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
                if supplied {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                supplied = true
                inputStatus.pointee = .haveData
                return input
            }
            if status == .error {
                throw VoiceNoteDecodeError.unreadable("opus: \(conversionError?.localizedDescription ?? "-")")
            }
            appendMono(output, to: &mono)
        }

        // Drop the encoder's priming at the start, and the padding of the last packet
        // at the end: the final granule says where the audio really stops.
        let preSkip = min(stream.head.preSkip, mono.count)
        var trimmed = Array(mono.dropFirst(preSkip))
        if let granule = stream.finalGranulePosition {
            let playable = Int(granule) - stream.head.preSkip
            if playable > 0, playable < trimmed.count { trimmed.removeLast(trimmed.count - playable) }
        }
        return trimmed
    }

    /// Average the channels of a non-interleaved buffer into `mono`.
    private static func appendMono(_ buffer: AVAudioPCMBuffer, to mono: inout [Float]) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard frames > 0, channels > 0 else { return }
        if channels == 1 {
            mono.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frames))
            return
        }
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels { sum += channelData[channel][frame] }
            mono.append(sum / Float(channels))
        }
    }

    /// Mono Float32 from one rate to another, through `AVAudioConverter`.
    static func resample(_ samples: [Float], from inputRate: Double, to outputRate: Double) throws -> [Float] {
        guard !samples.isEmpty else { return [] }
        guard inputRate != outputRate else { return samples }
        guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: inputRate,
                                              channels: 1, interleaved: false),
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: outputRate,
                                               channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
              let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw VoiceNoteDecodeError.unreadable("resampler")
        }
        input.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress, let target = input.floatChannelData?[0] else { return }
            target.update(from: base, count: samples.count)
        }
        let capacity = AVAudioFrameCount(Double(samples.count) * outputRate / inputRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw VoiceNoteDecodeError.unreadable("resampler output")
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .endOfStream
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        if status == .error {
            throw VoiceNoteDecodeError.unreadable("resample: \(conversionError?.localizedDescription ?? "-")")
        }
        guard let data = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
    }
}
