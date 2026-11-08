// docs/research/598-short-line-language-check/ios_read.swift
// Built for the iOS Simulator by compare-ios-simulator.sh (#598): reads a JSON array of
// strings, writes a JSON array of [top code, confidence] per string.
import Foundation
import NaturalLanguage
let input = CommandLine.arguments[1], output = CommandLine.arguments[2]
let texts = try! JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: input)))
var rows: [[String]] = []
for t in texts {
    let r = NLLanguageRecognizer(); r.processString(t)
    let top = r.languageHypotheses(withMaximum: 1).max { $0.value < $1.value }
    rows.append([top?.key.rawValue ?? "", String(top?.value ?? 0)])
}
try! JSONEncoder().encode(rows).write(to: URL(fileURLWithPath: output))
print("read \(texts.count) on \(ProcessInfo.processInfo.operatingSystemVersionString)")
