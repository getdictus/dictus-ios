#!/usr/bin/env swift
// scripts/generate-app-icon.swift
// Generates Dictus app icon PNGs (1024x1024) from brand kit specifications.
// Usage: swift scripts/generate-app-icon.swift

import CoreGraphics
import Foundation
#if canImport(ImageIO)
import ImageIO
#endif

let size: CGFloat = 1024

// MARK: - Color helpers

func rgb(_ hex: UInt32) -> (CGFloat, CGFloat, CGFloat) {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return (r, g, b)
}

func cgColor(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
    let (r, g, b) = rgb(hex)
    return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, alpha])!
}

// MARK: - Brand colors

let bgStart = cgColor(0x0D2040) // gradient top-left
let bgEnd = cgColor(0x071020)   // gradient bottom-right
let barGradientStart = cgColor(0x6BA3FF) // center bar top
let barGradientEnd = cgColor(0x2563EB)   // center bar bottom

// MARK: - Bar geometry (scaled from 80pt viewBox to 1024px)
// Original viewBox: 80x80
// Bars in original: widths=9, heights=18/42/27
// Scale factor: 1024/80 = 12.8, but we scale bars larger for readability (~60% fill)
//
// The bars occupy x:19-61 (42pt wide) in an 80pt icon = 52.5% width
// We want bars to fill ~60% of the icon area, so we scale them up proportionally
// and center them.

let scaleFactor: CGFloat = 1024.0 / 80.0  // 12.8

// Bar width scaled and increased by 20% for better visibility at small sizes
let barWidth: CGFloat = 9.0 * scaleFactor * 1.2    // ~138px
let cornerRadius: CGFloat = 4.5 * scaleFactor * 1.2 // ~69px

// Bar heights (proportionally scaled, increased by 20%)
let barHeights: [CGFloat] = [
    18.0 * scaleFactor * 1.2,  // left:  ~276px
    42.0 * scaleFactor * 1.2,  // center: ~645px
    27.0 * scaleFactor * 1.2,  // right: ~414px
]

// Spacing between bars (proportionally scaled)
let barSpacing: CGFloat = (35.5 - 19.0 - 9.0) * scaleFactor * 1.2 // gap between bar1 and bar2

// Total bars width = 3 * barWidth + 2 * barSpacing
let totalBarsWidth = 3.0 * barWidth + 2.0 * barSpacing

// Center horizontally
let startX = (size - totalBarsWidth) / 2.0

// Center vertically: tallest bar (center, 645px) should be centered
let tallestBarHeight = barHeights[1]
let centerY = (size - tallestBarHeight) / 2.0

// Bar X positions
let barXPositions: [CGFloat] = [
    startX,
    startX + barWidth + barSpacing,
    startX + 2.0 * (barWidth + barSpacing),
]

// Bar Y positions: each bar is bottom-aligned to the center bar's bottom
let bottomY = centerY + tallestBarHeight
let barYPositions: [CGFloat] = [
    bottomY - barHeights[0],
    centerY,
    bottomY - barHeights[2],
]

// Bar opacities (left=0.45, center=1.0, right=0.65)
let barOpacities: [CGFloat] = [0.45, 1.0, 0.65]

// MARK: - Drawing functions

func drawBackground(_ ctx: CGContext) {
    // 135-degree gradient: from top-left to bottom-right
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [bgStart, bgEnd] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size, y: size),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

func drawBars(_ ctx: CGContext, tinted: Bool = false) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    for i in 0..<3 {
        let rect = CGRect(
            x: barXPositions[i],
            y: barYPositions[i],
            width: barWidth,
            height: barHeights[i]
        )
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        if tinted {
            // Monochrome: black bars on transparent background
            ctx.setFillColor(CGColor(gray: 0, alpha: barOpacities[i]))
            ctx.fill(rect)
        } else if i == 1 {
            // Center bar: gradient fill
            let barGradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [barGradientStart, barGradientEnd] as CFArray,
                locations: [0.0, 1.0]
            )!
            ctx.drawLinearGradient(
                barGradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        } else {
            // Side bars: white with opacity
            ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1, 1, 1, barOpacities[i]])!)
            ctx.fill(rect)
        }

        ctx.restoreGState()
    }
}

func savePNG(_ ctx: CGContext, to path: String) {
    guard let image = ctx.makeImage() else {
        print("ERROR: Failed to create image")
        return
    }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("ERROR: Failed to create image destination at \(path)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("OK: \(path)")
    } else {
        print("ERROR: Failed to write \(path)")
    }
}

// MARK: - Generate icons

let sizeInt = Int(size)

// Standard icon (light mode) -- dark background with colored bars
func generateStandard(outputPath: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: sizeInt,
        height: sizeInt,
        bitsPerComponent: 8,
        bytesPerRow: sizeInt * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("ERROR: Failed to create context")
        return
    }

    drawBackground(ctx)
    drawBars(ctx)
    savePNG(ctx, to: outputPath)
}

// Dark mode icon -- same as standard (already dark-themed)
func generateDark(outputPath: String) {
    generateStandard(outputPath: outputPath)
}

// Tinted icon -- monochrome bars on transparent background
// iOS applies the user's chosen tint color
func generateTinted(outputPath: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: sizeInt,
        height: sizeInt,
        bitsPerComponent: 8,
        bytesPerRow: sizeInt * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("ERROR: Failed to create context")
        return
    }

    // Transparent background (context is already clear)
    drawBars(ctx, tinted: true)
    savePNG(ctx, to: outputPath)
}

// MARK: - Main

let scriptDir = CommandLine.arguments[0]
let projectDir: String
if let range = scriptDir.range(of: "/scripts/") {
    projectDir = String(scriptDir[scriptDir.startIndex..<range.lowerBound])
} else {
    // Fallback: assume we're run from project root
    projectDir = FileManager.default.currentDirectoryPath
}

let assetDir = projectDir + "/DictusApp/Assets.xcassets/AppIcon.appiconset"

// Create directory if needed
try? FileManager.default.createDirectory(atPath: assetDir, withIntermediateDirectories: true)

print("Generating Dictus app icons (1024x1024)...")
print("Output directory: \(assetDir)")

generateStandard(outputPath: assetDir + "/AppIcon-1024.png")
generateDark(outputPath: assetDir + "/AppIcon-1024-dark.png")
generateTinted(outputPath: assetDir + "/AppIcon-1024-tinted.png")

print("Done.")
