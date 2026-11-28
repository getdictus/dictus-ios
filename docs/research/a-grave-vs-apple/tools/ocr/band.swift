import Foundation
import Vision
import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOf: URL(fileURLWithPath: a[1]))!
let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let h = Double(cg.height), w = Double(cg.width), top = Double(a[2])!, bottom = Double(a[3])!
let crop = cg.cropping(to: CGRect(x: 0, y: top * h, width: w, height: (bottom - top) * h))!
let req = VNRecognizeTextRequest(); req.recognitionLevel = .accurate; req.recognitionLanguages = ["fr-FR"]; req.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: crop).perform([req])
print((req.results ?? []).sorted { $0.boundingBox.minX < $1.boundingBox.minX }.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " | "))
