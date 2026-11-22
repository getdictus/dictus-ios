// strip.swift <video> <out.png> <step>: stacks the text area (top of the screen) and the
// keyboard's top row of every frame `step` seconds apart into one image, labelled by time.
import AVFoundation
import AppKit

let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let step = Double(args[3]) ?? 1
let generator = AVAssetImageGenerator(asset: asset)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: 402, height: 874)
let duration = CMTimeGetSeconds(asset.duration)
let band = CGRect(x: 0, y: 60, width: 402, height: 140)   // the text, in points from the top
let key = CGRect(x: 0, y: 590, width: 402, height: 40)    // the keyboard's top row
var times: [Double] = []
var t = 0.5
while t < duration { times.append(t); t += step }
let rowH = band.height + key.height + 4
let size = NSSize(width: 402 * 2 + 10, height: CGFloat((times.count + 1) / 2) * rowH)
let canvas = NSImage(size: size)
canvas.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
for (i, time) in times.enumerated() {
    guard let image = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil) else { continue }
    let scale = CGFloat(image.width) / 402
    let col = CGFloat(i % 2), row = CGFloat(i / 2)
    let originX = col * (402 + 10)
    let top = size.height - row * rowH
    for (j, r) in [band, key].enumerated() {
        let crop = CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale)
        guard let part = image.cropping(to: crop) else { continue }
        let y = j == 0 ? top - band.height : top - band.height - key.height - 2
        NSImage(cgImage: part, size: r.size).draw(in: NSRect(x: originX, y: y, width: r.width, height: r.height))
    }
    let label = String(format: "%.1f s", time) as NSString
    label.draw(at: NSPoint(x: originX + 330, y: top - 16), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.red])
}
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
print(args[2], times.count, "frames")
