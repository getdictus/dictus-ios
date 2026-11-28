// Probe (#1101): what UITextChecker (en_US) says of each word, and what one call costs.
// Built for the iOS Simulator and run there with `simctl spawn`:
//   xcrun swiftc -target arm64-apple-ios17.0-simulator \
//       -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -O textchecker_probe.swift -o probe
//   xcrun simctl spawn <udid> ./probe word1 word2 ...
import UIKit
let words = CommandLine.arguments.dropFirst().map { $0 }
let checker = UITextChecker()
print("available:", UITextChecker.availableLanguages.contains("en_US"))
var times: [Double] = []
for w in words {
    let ns = w as NSString
    let t0 = DispatchTime.now().uptimeNanoseconds
    let r = checker.rangeOfMisspelledWord(in: w, range: NSRange(location: 0, length: ns.length), startingAt: 0, wrap: false, language: "en_US")
    let t1 = DispatchTime.now().uptimeNanoseconds
    times.append(Double(t1 - t0) / 1000)
    let valid = r.location == NSNotFound
    let guesses = valid ? [] : (checker.guesses(forWordRange: NSRange(location: 0, length: ns.length), in: w, language: "en_US") ?? [])
    print("\(w)\t\(valid ? "valid" : "misspelled")\t\(guesses.prefix(4).joined(separator: ","))")
}
let sorted = times.sorted()
if !sorted.isEmpty {
    print("calls \(sorted.count) p50 \(sorted[sorted.count/2]) us p95 \(sorted[Int(Double(sorted.count)*0.95)]) us max \(sorted[sorted.count - 1]) us")
}
