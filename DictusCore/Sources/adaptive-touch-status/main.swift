// DictusCore/Sources/adaptive-touch-status/main.swift
//
// Decodes an Adaptive touch file (#1014) exported from a Debug build (#1081) and prints the
// summary the keyboard logs at each appearance (`adaptiveTouchStatus ...`), then each
// context's counts and the offset of every key it learned. Runs on the Mac:
//
//   swift run --package-path DictusCore -c release adaptive-touch-status adaptive-touch.bin
//
// The file holds no letters: its contexts are keyed by a hash of the letter page (the letters
// on each row and the key pitch). The tool names the slots with every shipped letter page
// (AZERTY, QWERTY, QWERTZ) whose rows give that hash at some pitch, which it prints.
// `--rows "azertyuiop qsdfghjklm wxcvbn"` tries other rows; `--reset-at <seconds>` reads the
// file as a keyboard would after a reset at that time.
import DictusCore
import Foundation

let usage = "usage: adaptive-touch-status <adaptive-touch.bin> [--rows \"row1 row2 row3\"] [--reset-at <seconds>]"
var arguments = Array(CommandLine.arguments.dropFirst())
var pages = AdaptiveTouchGeometry.shippedLetterPages
var resetAt: TimeInterval = 0
var path: String?
while !arguments.isEmpty {
    let argument = arguments.removeFirst()
    switch argument {
    case "--rows":
        guard let value = arguments.first else { fatalError(usage) }
        arguments.removeFirst()
        pages = [AdaptiveTouchGeometry.LetterPage(name: "rows", rows: value.split(separator: " ").map(Array.init))]
    case "--reset-at":
        guard let value = arguments.first.flatMap(TimeInterval.init) else { fatalError(usage) }
        arguments.removeFirst()
        resetAt = value
    default:
        path = argument
    }
}
guard let path else {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}
guard let data = FileManager.default.contents(atPath: path) else {
    FileHandle.standardError.write(Data("no file at \(path)\n".utf8))
    exit(1)
}
guard let model = AdaptiveTouchModel(data: data) else {
    print("unreadable: \(data.count) bytes, not a whole version-1 file of \(AdaptiveTouchModel.byteCount) bytes with a valid checksum")
    exit(1)
}

let matches = AdaptiveTouchGeometry.identify(model, pages: pages)
for geometry in Set(model.contexts.map(\.geometry)) where geometry != 0 {
    let hex = String(format: "%016llx", geometry)
    if let match = matches[geometry] {
        print("geometry \(hex): \(match.page) letter page, key pitch \(match.pitch.width) x \(match.pitch.height) pt")
    } else {
        print("geometry \(hex): no letter page matches; slots are unnamed")
    }
}
let letters = matches.mapValues(\.letters)
print("")
print(AdaptiveTouchStatus.report(model: model, letters: letters, resetAt: resetAt), terminator: "")
