// tools/swipe-bench/Sources/swipe-bench/main.swift
// The swipe decoder bench (#948): synthetic swipes for every word of the held-out
// sentences, read by DictusCore's `SwipeDecoder` as it ships, scored as Hex scores its own
// (`android/benchmark/typing/README.md`, "Swipe typing"): the first reading right, the word
// among the first four (the one typed and the three the bar would offer), and the time each
// decode takes. Words of one key are tapped, not swiped, and words the decoder cannot read
// (not in the model, not one of English's contractions) are left out and counted.
//
//   swipe-bench [--langs en,fr,es,de] [--styles clean,neat,typical,sloppy] [--split test]
//               [--limit N] [--seed 1] [--out DIR] [--keys targets|keyboard|caps]
//   swipe-bench --memory [--langs en] [--styles typical]
//   swipe-bench --hex-paths FILE.tsv --langs en [--models DIR]   (local cross-check, see README)
//   swipe-bench --own-words [--langs …] [--styles …] [--own-sentences 200]   (#1090, OwnWords.swift)
import CoreGraphics
import DictusCore
import Foundation

// MARK: - Arguments

struct Options {
    var langs = ["en", "fr", "es", "de"]
    var styles = ["clean", "neat", "typical", "sloppy"]
    var split = "test"
    var limit = Int.max
    var seed = 1
    var out: String?
    var keys = LetterPage.KeySource.targets
    var memory = false
    var hexPaths: String?
    var models: String?
    var ownWords = false
    var ownSentences = 200
    var root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
}

func parse() -> Options {
    var o = Options()
    var args = CommandLine.arguments.dropFirst()
    func value() -> String {
        guard let v = args.popFirst() else { fatalError("missing value") }
        return v
    }
    while let a = args.popFirst() {
        switch a {
        case "--langs": o.langs = value().split(separator: ",").map(String.init)
        case "--styles": o.styles = value().split(separator: ",").map(String.init)
        case "--split": o.split = value()
        case "--limit": o.limit = Int(value()) ?? .max
        case "--seed": o.seed = Int(value()) ?? 1
        case "--out": o.out = value()
        case "--keys":
            guard let source = LetterPage.KeySource(rawValue: value()) else { fatalError("--keys targets|keyboard|caps") }
            o.keys = source
        case "--memory": o.memory = true
        case "--hex-paths": o.hexPaths = value()
        case "--root": o.root = URL(fileURLWithPath: value())
        case "--models": o.models = value()
        case "--own-words": o.ownWords = true
        case "--own-sentences": o.ownSentences = Int(value()) ?? 200
        default: fatalError("unknown argument \(a)")
        }
    }
    return o
}

// MARK: - Inputs

/// Added to seed * 7919 for the sentence loop, as Hex's generator has it (en 0, es 17, de 29, fr 37).
let seedOffset = ["en": 0, "es": 17, "de": 29, "fr": 37]

func sentences(_ o: Options, _ lang: String) -> [String] {
    let url = o.root.appendingPathComponent("tools/swipe-bench/sentences/\(lang)-\(o.split).tsv")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { fatalError("no \(url.path)") }
    return text.split(separator: "\n").filter { !$0.hasPrefix("#") }.map { String($0.split(separator: "\t")[2]) }
}

/// English's contractions as Dictus knows them (`englishProfile`), as you'd see them, each
/// at Hex's cost of a common contraction: Google Books splits "don't", so the model barely
/// has them (Hex reads its own list the same way, `SwipeTyping.swift`).
func englishContractions() -> [String] {
    let forms = englishProfile.overrides.values.filter { $0.contains("'") }
        + englishProfile.contextualContractions.map(\.contraction)
    return Set(forms.map { $0.hasPrefix("i'") ? "I" + $0.dropFirst() : $0 }).sorted()
}

func decoder(_ o: Options, _ lang: String) -> SwipeDecoder {
    let path = o.models.map { URL(fileURLWithPath: $0).appendingPathComponent("\(lang).hextm").path }
        ?? o.root.appendingPathComponent("DictusKeyboard/Resources/\(lang).hextm").path
    guard let model = SpatialDecoderModel(path: path) else { fatalError("no model at \(path)") }
    var decoder = SwipeDecoder(model: model)
    if lang == "en" {
        decoder.extraWords = SwipeDecoder.ExtraWords(
            englishContractions(), cost: { _ in SwipeDecoder.contractionCost }, model: model, contractions: true
        )
    }
    return decoder
}

// MARK: - Memory

func heapInUse() -> Int {
    var stats = malloc_statistics_t()
    malloc_zone_statistics(nil, &stats)
    return Int(stats.size_in_use)
}

/// What jetsam counts against an app extension (dirty and compressed memory), its peak since
/// the process started, and the resident size, which also counts the clean, file-backed
/// pages of a mapped model.
func footprint() -> (phys: Int, peak: Int, resident: Int) {
    var vm = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let ok = withUnsafeMutablePointer(to: &vm) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    guard ok == KERN_SUCCESS else { return (0, 0, 0) }
    return (Int(vm.phys_footprint), Int(vm.ledger_phys_footprint_peak), Int(vm.resident_size))
}

func mb(_ bytes: Int) -> String { String(format: "%.2f MB", Double(bytes) / 1_048_576) }
func kb(_ bytes: Int) -> String { String(format: "%.0f KB", Double(bytes) / 1024) }

// MARK: - Scoring

struct Tally {
    var words = 0
    var swiped = 0
    var oneKey = 0
    var noKey = 0
    var unreadable = 0
    var first = 0
    var top4 = 0
    var ms: [Double] = []
    var maxScored = 0

    var row: String {
        let sorted = ms.sorted()
        func at(_ q: Double) -> Double { sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * q))] }
        let n = Double(max(1, swiped))
        return String(format: "%d | %.1f%% | %.1f%% | %.2f / %.2f ms", swiped, 100 * Double(first) / n, 100 * Double(top4) / n,
                      at(0.5), at(0.95))
    }
}

struct Swipe {
    var points: [CGPoint]
    var times: [Double]
    var word: String
    var previous: String?
}

/// Whether the decoder can read `word` at all: the model has it, or it's an extra word.
func readable(_ word: String, _ decoder: SwipeDecoder) -> Bool {
    decoder.model.contains(word) || decoder.extraWords.texts.contains { $0.lowercased() == word }
}

func score(_ swipe: Swipe, _ decoder: SwipeDecoder, _ page: LetterPage, _ tally: inout Tally, log: inout [String], logging: Bool) {
    let clock = ContinuousClock()
    var reading: SwipeDecoder.Reading?
    let elapsed = clock.measure {
        reading = decoder.read(swipe.points, times: swipe.times, keys: page.keys, previous: swipe.previous, limit: 4)
    }
    guard let reading else { return }
    let ms = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
    let texts = reading.candidates.map { $0.text.lowercased() }
    tally.swiped += 1
    tally.ms.append(ms)
    tally.maxScored = max(tally.maxScored, reading.scored)
    if texts.first == swipe.word { tally.first += 1 }
    if texts.contains(swipe.word) { tally.top4 += 1 }
    if logging {
        log.append("\(swipe.word)\t\(swipe.previous ?? "")\t\(texts.joined(separator: "|"))\t\(String(format: "%.3f", ms))")
    }
}

// MARK: - Runs

/// Every word of the sentences, swiped as `style`'s finger would, one at a time: each path
/// is drawn, read and dropped, so nothing but the tally outlives a swipe.
func run(_ o: Options, lang: String, style: String, decoder: SwipeDecoder, page: LetterPage, log: inout [String],
         logging: Bool? = nil, readableBy: SwipeDecoder? = nil) -> Tally {
    guard let noise = Noise.named(style) else { fatalError("unknown style \(style)") }
    let centres = page.capsInPitches
    var rng = SplitMix64(seed: UInt64(o.seed * 7919 + (seedOffset[lang] ?? 0)))
    var tally = Tally()
    tally.ms.reserveCapacity(16_000)
    for sentence in sentences(o, lang).prefix(o.limit) {
        let sloppiness = exp(rng.gaussian() * noise.sloppiness)
        var previous: String?
        for word in sentence.split(separator: " ").map(String.init) {
            tally.words += 1
            defer { previous = word }
            guard let sequence = SwipePaths.keySequence(word, centres: centres) else {
                tally.noKey += 1
                continue
            }
            guard sequence.count >= 2 else {
                tally.oneKey += 1
                continue
            }
            let (points, times) = SwipePaths.swipeTimed(sequence.compactMap { centres[$0] }, noise: noise, sloppiness: sloppiness,
                                                        rng: &rng, onLetter: page.onLetter)
            guard readable(word, readableBy ?? decoder) else {
                tally.unreadable += 1
                continue
            }
            let cgPoints = points.map {
                CGPoint(x: min(max($0.0 * Double(page.pitch.width), 0), Double(page.width)), y: $0.1 * Double(page.pitch.height))
            }
            score(Swipe(points: cgPoints, times: times, word: word, previous: previous), decoder, page, &tally, log: &log,
                  logging: logging ?? (o.out != nil))
        }
    }
    return tally
}

/// Hex's own paths (`swipe_paths.py`'s output, gunzipped), moved onto Dictus's keys: Hex
/// draws on a grid of key pitches whose top-left letter is at (0.5, 0.5).
func runHexPaths(_ file: String, lang: String, decoder: SwipeDecoder, page: LetterPage, log: inout [String]) -> Tally {
    guard let text = try? String(contentsOfFile: file, encoding: .utf8) else { fatalError("no \(file)") }
    let topLeft: Character = lang == "fr" ? "a" : "q"
    guard let origin = page.capsInPitches[topLeft] else { fatalError("no \(topLeft) key") }
    var tally = Tally()
    for line in text.split(separator: "\n") where !line.hasPrefix("#") {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count == 5 else { continue }
        let word = String(fields[2])
        tally.words += 1
        guard readable(word, decoder) else {
            tally.unreadable += 1
            continue
        }
        var points: [CGPoint] = []
        var times: [Double] = []
        for triple in fields[4].split(separator: " ") {
            let v = triple.split(separator: ",").compactMap { Double($0) }
            guard v.count == 3 else { continue }
            points.append(CGPoint(x: (v[0] - 0.5 + origin.0) * Double(page.pitch.width), y: (v[1] - 0.5 + origin.1) * Double(page.pitch.height)))
            times.append(v[2])
        }
        let previous = fields[3].isEmpty ? nil : String(fields[3])
        score(Swipe(points: points, times: times, word: word, previous: previous), decoder, page, &tally, log: &log, logging: true)
    }
    return tally
}

// MARK: - Main

let options = parse()
let before = footprint()
if options.memory {
    // One language and style, in a fresh process. A swipe's path is drawn, read and
    // dropped before the next, so the peak footprint past what the setup left is the most
    // any one swipe (its path, then its decode) needed at once.
    let lang = options.langs[0], style = options.styles[0]
    let decoder = decoder(options, lang)
    guard let page = LetterPage(lang, source: options.keys) else { fatalError("no layout") }
    _ = sentences(options, lang)
    var noLog: [String] = []
    let heap = heapInUse()
    let loaded = footprint()
    let tally = run(options, lang: lang, style: style, decoder: decoder, page: page, log: &noLog)
    let heapAfter = heapInUse()
    let end = footprint()
    // The allocator keeps freed pages for reuse; this hands them back, as memory pressure
    // would make it.
    malloc_zone_pressure_relief(nil, 0)
    let relieved = footprint()
    print("""
        memory, \(lang) \(style), \(tally.swiped) swipes (\(tally.maxScored) words scored at most in one)
        - model: \(mb(decoder.model.byteCount)) mapped read-only; resident size \(mb(before.resident)) at launch, \
        \(mb(loaded.resident)) loaded, \(mb(end.resident)) after the swipes (its clean pages, which iOS can drop)
        - footprint: \(mb(before.phys)) at launch, \(mb(loaded.phys)) loaded, peak \(mb(end.peak)) during the swipes, \
        \(mb(end.phys)) after them, \(mb(relieved.phys)) once the allocator returns its free pages
        - one swipe needed at most \(mb(end.peak - loaded.phys)) above the loaded footprint, freed when it returns
        - heap in use before the swipes \(kb(heap)), after \(kb(heapAfter)): \(kb(heapAfter - heap)) more, \
        the tally's \(tally.ms.count) times reserved ahead (128 KB); nothing of the decoder's
        """)
    exit(0)
}

if options.ownWords {
    // #1090: the dictionary's words with and without the user's own words, the same swipes
    // (same seed), then the own words themselves, mid-sentence, with and without.
    var dictionary = ["| Language | Style | Words swiped | First word right | Top 4 | With own words: first | Top 4 | First taken by an own word |",
                      "|---|---|---:|---:|---:|---:|---:|---:|"]
    var own = ["| Language | Style | Own words swiped | Before #1090: first, with casing | Top 4 | After: first, with casing | Top 4 |",
               "|---|---|---:|---:|---:|---:|---:|"]
    var notes: [String] = []
    print("own words read: \(OwnWordsSet.words.count) (\(OwnWordsSet.words.joined(separator: ", ")))")
    for lang in options.langs {
        let plain = decoder(options, lang)
        let mine = plain.withOwnWords(OwnWordsSet.words)
        guard let page = LetterPage(lang, source: options.keys) else { fatalError("no layout for \(lang)") }
        for style in options.styles {
            var logPlain: [String] = [], logMine: [String] = []
            let a = run(options, lang: lang, style: style, decoder: plain, page: page, log: &logPlain, logging: true)
            // The same words as the plain run: a sentence word the own words make readable is
            // left out of both, so the two runs score the same swipes.
            let b = run(options, lang: lang, style: style, decoder: mine, page: page, log: &logMine, logging: true, readableBy: plain)
            precondition(a.swiped == b.swiped, "the same swipes")
            let (stolen, once) = stolenFirsts(without: logPlain, with: logMine)
            let n = Double(max(1, a.swiped))
            dictionary.append(String(
                format: "| %@ | %@ | %d | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %d |", lang, style, a.swiped,
                100 * Double(a.first) / n, 100 * Double(a.top4) / n, 100 * Double(b.first) / n, 100 * Double(b.top4) / n,
                stolen.values.reduce(0, +)
            ))
            // Before #1090: the model's readings as the model spells them, nothing of the user's.
            let before = runOwnTargets(options, lang: lang, style: style, decoder: plain, page: page,
                                       sentences: options.ownSentences, writes: false)
            let after = runOwnTargets(options, lang: lang, style: style, decoder: mine, page: page,
                                      sentences: options.ownSentences, writes: true)
            own.append("| \(lang) | \(style) | \(after.swiped) | " + before.row.split(separator: "|").dropFirst().joined(separator: "|")
                       + " | " + after.row.split(separator: "|").dropFirst().joined(separator: "|") + " |")
            let worst = stolen.sorted { $0.value > $1.value }.prefix(6).map { "\($0.key) \($0.value)" }
            let missed = after.missed.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }
            let found = before.found.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }
            notes.append("\(lang) \(style): before #1090 found " + (found.isEmpty ? "none" : found.joined(separator: ", ")) + "; first taken \(worst.isEmpty ? "never" : worst.joined(separator: ", ")); "
                         + "learned-once words read: \(once + after.learnedOnceRead); own words missed: "
                         + (missed.isEmpty ? "none" : missed.joined(separator: ", ")))
        }
    }
    print(dictionary.joined(separator: "\n"))
    print("")
    print(own.joined(separator: "\n"))
    print("")
    print(notes.map { "- " + $0 }.joined(separator: "\n"))
    exit(0)
}

var table = ["| Language | Style | Words swiped | First word right | Top 4 | Decode, median / p95 |", "|---|---|---:|---:|---:|---:|"]
var notes: [String] = []
for lang in options.langs {
    let decoder = decoder(options, lang)
    guard let page = LetterPage(lang, source: options.keys) else { fatalError("no layout for \(lang)") }
    for style in options.hexPaths == nil ? options.styles : ["hex-paths"] {
        var log: [String] = []
        if options.out != nil { log.reserveCapacity(16_000) }
        let tally = options.hexPaths.map { runHexPaths($0, lang: lang, decoder: decoder, page: page, log: &log) }
            ?? run(options, lang: lang, style: style, decoder: decoder, page: page, log: &log)
        table.append("| \(lang) | \(style) | " + tally.row + " |")
        notes.append("\(lang) \(style): \(tally.words) words, \(tally.swiped) swiped, \(tally.oneKey) of one key (tapped), "
                     + "\(tally.noKey) with a letter without a key, \(tally.unreadable) the decoder can't read")
        if let out = options.out {
            try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            let file = URL(fileURLWithPath: out).appendingPathComponent("\(lang)-\(style).tsv")
            try? (["# word\tprevious\treadings (best first)\tms"] + log).joined(separator: "\n").appending("\n")
                .write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
print(table.joined(separator: "\n"))
print("")
print(notes.map { "- " + $0 }.joined(separator: "\n"))
