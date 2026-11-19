// OCR the predictive bar of a simulator screenshot: prints "x<TAB>text" per line found in the band.
import Foundation
import Vision
import AppKit
let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let top = Double(args[2])!, bottom = Double(args[3])!  // band, fraction of height from the top
guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
let h = Double(cg.height), w = Double(cg.width)
var slots: [(Double, CGImage)] = []
for i in 0..<3 {
    let c = cg.cropping(to: CGRect(x: Double(i) * w / 3, y: top * h, width: w / 3, height: (bottom - top) * h))!
    // Pad onto a larger white canvas: Vision misses a lone character in a tight crop.
    let W = c.width * 3, H = c.height * 3
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.interpolationQuality = .high; ctx.draw(c, in: CGRect(x: 0, y: 0, width: W, height: H))
    slots.append((Double(i), ctx.makeImage()!))
}
for (i, crop) in slots {
let req = VNRecognizeTextRequest()
req.recognitionLevel = .accurate
req.recognitionLanguages = ["fr-FR"]
req.usesLanguageCorrection = false
req.minimumTextHeight = 0
try VNImageRequestHandler(cgImage: crop).perform([req])
let text = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
print("\(Int(i))\t\(text)")
}
