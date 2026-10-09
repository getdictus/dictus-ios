// DictusApp/Onboarding/ChecklistFrameRenderer.swift
// Renders the checklist card into the video frames Picture in Picture shows (#682).
import AVFoundation
import CoreMedia
import CoreVideo
import SwiftUI
import DictusCore

/// Turns a checklist state into a `CMSampleBuffer` for an `AVSampleBufferDisplayLayer`.
///
/// WHY FRAMES AT ALL (#649 decision 10): Picture in Picture only shows video. A checklist
/// drawn in code reaches it by being rendered, frame by frame, into a sample-buffer display
/// layer (`AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:…)`). No
/// recorded video ships, so the card stays localized and follows the line states live.
///
/// WHY `ImageRenderer`: it draws the very SwiftUI view the fallback shows inline
/// (`KeyboardSetupChecklistCard`), off screen, into a `CGImage`. It runs on the main actor.
@MainActor
final class ChecklistFrameRenderer {
    /// Pixels per point. 2 keeps the text sharp in a Picture in Picture window, which is
    /// smaller than the card, at a quarter of a 3× frame's memory.
    private static let scale: CGFloat = 2

    private let pixelWidth = Int(KeyboardSetupChecklistCard.size.width * scale)
    private let pixelHeight = Int(KeyboardSetupChecklistCard.size.height * scale)

    private var pool: CVPixelBufferPool?
    private var formatDescription: CMVideoFormatDescription?

    /// A frame showing `lines`, stamped at `time` on the layer's timebase, or nil when a
    /// Core Video or Core Media call fails (the caller keeps the previous frame up).
    func sampleBuffer(
        lines: [KeyboardSetupChecklistLineState],
        tickProgress: [Double],
        at time: CMTime
    ) -> CMSampleBuffer? {
        let renderer = ImageRenderer(content: KeyboardSetupChecklistCard(lines: lines, tickProgress: tickProgress))
        renderer.scale = Self.scale
        guard let image = renderer.cgImage,
              let pixelBuffer = makePixelBuffer(drawing: image) else {
            return nil
        }
        return makeSampleBuffer(from: pixelBuffer, at: time)
    }

    // MARK: - Core Video

    private func makePixelBuffer(drawing image: CGImage) -> CVPixelBuffer? {
        if pool == nil {
            // IOSurface-backed, so the display layer and the Picture in Picture window can
            // show the buffer without copying it.
            let attributes: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey: pixelWidth,
                kCVPixelBufferHeightKey: pixelHeight,
                kCVPixelBufferIOSurfacePropertiesKey: [String: Any]()
            ]
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
        }
        guard let pool else { return nil }

        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
              let buffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            // BGRA in memory: 32-bit little-endian with alpha first.
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        return buffer
    }

    // MARK: - Core Media

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, at time: CMTime) -> CMSampleBuffer? {
        if formatDescription == nil {
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &formatDescription
            )
        }
        guard let formatDescription else { return nil }

        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer else { return nil }

        // Shown as soon as it is enqueued: these frames are a live picture of a state, not
        // a timeline to be played back in order.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dictionary,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sampleBuffer
    }
}
