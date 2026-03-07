#!/usr/bin/env swift
// scripts/generate-app-icon.swift
// Generates Dictus app icon PNGs (1024x1024) from brand kit specifications.
// Usage: swift scripts/generate-app-icon.swift
//
// Source of truth: assets/brand/dictus-brand-kit.html
// SVG viewBox: 80x80, scale factor: 1024/80 = 12.8
// All coordinates are direct SVG values * 12.8, NO additional multiplier.

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

// MARK: - Brand colors (standard / light variant)

let bgStart = cgColor(0x0D2040)           // gradient top-left
let bgEnd = cgColor(0x071020)             // gradient bottom-right
let barGradientStart = cgColor(0x6BA3FF)  // center bar top
let barGradientEnd = cgColor(0x2563EB)    // center bar bottom

// Dark variant colors (brand kit "Sur fond surface")
let darkBgStart = cgColor(0x1C2333)
let darkBgEnd = cgColor(0x111827)
let darkBarGradientStart = cgColor(0x93C5FD)  // brighter blue for dark bg
let darkBarGradientEnd = cgColor(0x3B82F6)

// MARK: - Bar geometry (exact brand kit SVG coordinates * scaleFactor)
// viewBox: 80x80 -> 1024x1024
// Scale factor: 1024 / 80 = 12.8
//
// Brand kit SVG bars:
//   Bar 1 (left):   x=19,   y=34, w=9, h=18, rx=4.5
//   Bar 2 (center): x=35.5, y=22, w=9, h=42, rx=4.5
//   Bar 3 (right):  x=52,   y=29, w=9, h=27, rx=4.5
//
// Bar bottoms are STAGGERED (not aligned):
//   Bar 1 bottom: 34 + 18 = 52
//   Bar 2 bottom: 22 + 42 = 64
//   Bar 3 bottom: 29 + 27 = 56

let scaleFactor: CGFloat = 1024.0 / 80.0  // 12.8

// Bar positions: absolute from SVG, scaled by 12.8
let barXPositions: [CGFloat] = [
    19.0 * scaleFactor,    // 243.2
    35.5 * scaleFactor,    // 454.4
    52.0 * scaleFactor,    // 665.6
]

let barYPositions: [CGFloat] = [
    34.0 * scaleFactor,    // 435.2
    22.0 * scaleFactor,    // 281.6
    29.0 * scaleFactor,    // 371.2
]

let barWidths: [CGFloat] = [
    9.0 * scaleFactor,     // 115.2
    9.0 * scaleFactor,     // 115.2
    9.0 * scaleFactor,     // 115.2
]

let barHeights: [CGFloat] = [
    18.0 * scaleFactor,    // 230.4
    42.0 * scaleFactor,    // 537.6
    27.0 * scaleFactor,    // 345.6
]

let cornerRadius: CGFloat = 4.5 * scaleFactor  // 57.6

// Default bar opacities (left=0.45, center=1.0, right=0.65)
let defaultBarOpacities: [CGFloat] = [0.45, 1.0, 0.65]

// Dark variant opacities (slightly dimmer, matching brand kit surface variant)
let darkBarOpacities: [CGFloat] = [0.35, 1.0, 0.55]

// MARK: - Drawing functions

/// Draw background gradient. Accepts custom gradient colors for dark variant.
func drawBackground(
    _ ctx: CGContext,
    gradientStart: CGColor? = nil,
    gradientEnd: CGColor? = nil
) {
    let startColor = gradientStart ?? bgStart
    let endColor = gradientEnd ?? bgEnd

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [startColor, endColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    // 135-degree gradient: from top-left to bottom-right
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size, y: size),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
}

/// Draw the 3 waveform bars. Supports tinted mode and opacity/gradient overrides.
func drawBars(
    _ ctx: CGContext,
    tinted: Bool = false,
    barOpacityOverrides: [CGFloat]? = nil,
    barGradStart: CGColor? = nil,
    barGradEnd: CGColor? = nil
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let opacities = barOpacityOverrides ?? defaultBarOpacities
    let gradStart = barGradStart ?? barGradientStart
    let gradEnd = barGradEnd ?? barGradientEnd

    for i in 0..<3 {
        let rect = CGRect(
            x: barXPositions[i],
            y: barYPositions[i],
            width: barWidths[i],
            height: barHeights[i]
        )
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        if tinted {
            // Monochrome: black bars on transparent background
            ctx.setFillColor(CGColor(gray: 0, alpha: opacities[i]))
            ctx.fill(rect)
        } else if i == 1 {
            // Center bar: gradient fill
            let barGradient = CGGradient(
                colorsSpace: colorSpace,
                colors: [gradStart, gradEnd] as CFArray,
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
            ctx.setFillColor(CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1, 1, 1, opacities[i]])!)
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

/// Standard icon (light mode) -- dark navy background with colored bars
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

/// Dark mode icon -- surface gradient background, brighter bars, no stroke glow
func generateDark(outputPath: String) {
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

    // Dark variant: surface gradient background
    drawBackground(ctx, gradientStart: darkBgStart, gradientEnd: darkBgEnd)
    // Dimmer side bars, brighter center gradient
    drawBars(
        ctx,
        barOpacityOverrides: darkBarOpacities,
        barGradStart: darkBarGradientStart,
        barGradEnd: darkBarGradientEnd
    )
    savePNG(ctx, to: outputPath)
}

/// Tinted icon -- monochrome bars on transparent background
/// iOS applies the user's chosen tint color
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
print("Scale factor: \(scaleFactor) (1024/80, no additional multiplier)")

generateStandard(outputPath: assetDir + "/AppIcon-1024.png")
generateDark(outputPath: assetDir + "/AppIcon-1024-dark.png")
generateTinted(outputPath: assetDir + "/AppIcon-1024-tinted.png")

print("Done.")
