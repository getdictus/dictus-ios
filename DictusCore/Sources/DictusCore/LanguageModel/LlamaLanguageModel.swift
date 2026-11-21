// DictusCore/Sources/DictusCore/LanguageModel/LlamaLanguageModel.swift
// A GGUF model run by llama.cpp on the CPU, for the keyboard (#996).
import Foundation

/// Opens the keyboard's language model: a GGUF file run by llama.cpp (#996). nil when
/// the file does not open, and always nil in a build without llama.cpp, which is every
/// build that did not run tools/keyboard-lm/build-llama.sh (CI included).
public enum LocalLanguageModel {
    public static func open(path: String) -> LanguageModelScoring? {
        #if canImport(llama)
        return LlamaLanguageModel.load(path: path)
        #else
        return nil
        #endif
    }

    /// Whether this build has llama.cpp at all.
    public static var isAvailable: Bool {
        #if canImport(llama)
        return true
        #else
        return false
        #endif
    }
}

#if canImport(llama)
import Accelerate
import llama

/// llama.cpp behind `LanguageModelScoring` (#996).
///
/// WHY mmap: the weights stay pages of the file, which iOS counts as clean memory and
/// leaves out of the extension's footprint, the number jetsam kills a keyboard on. What
/// counts is the KV cache, the compute buffer and the logits: +42 MB once loaded for
/// Qwen2.5-0.5B in a simulator (#996), against ~180 MB a keyboard may use on an iPhone 15
/// Pro Max.
///
/// WHY the KV cache is kept: the text before the word does not change while the word is
/// typed, so each request only feeds the model the tokens it has not seen.
///
/// WHY CPU only: a build with Metal compiles its shaders at the first load, 11 to 15 s in
/// the spike, and the requests here are a few tokens, where the GPU gains little.
final class LlamaLanguageModel: LanguageModelScoring {

    private static let backend: Void = {
        llama_log_set({ _, _, _ in }, nil)
        llama_backend_init()
    }()

    /// Sequence 0 holds the context; each reading or next word gets one of the others.
    private static let sequences = 8
    /// Logit rows per decode. Each costs the vocabulary's size in floats (600 KB for Qwen),
    /// and llama.cpp keeps the largest output buffer it was ever asked for.
    private static let maxOutputs = 8
    /// The context's last tokens the model reads. llama.cpp aborts on a batch larger
    /// than `n_batch` (256), and 200 characters of emoji or stacked accents can be more.
    private static let maxContextTokens = 128

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer
    private let vocabSize: Int
    /// A token that starts a word after a space (` maison`), and one that starts it at a line start (`Maison`).
    private let startsWordAfterSpace: [Bool]
    private let startsWordAtLineStart: [Bool]

    /// The tokens sequence 0 holds, and the logits after its last one.
    private var cached: [llama_token] = []
    private var cachedLogits: [Float] = []
    private var exponentials: [Float]

    static func load(path: String, threads: Int32 = 4) -> LlamaLanguageModel? {
        _ = backend
        var modelParameters = llama_model_default_params()
        modelParameters.load_mode = LLAMA_LOAD_MODE_MMAP
        // Repacking copies the weights into dirty memory, which the footprint counts.
        modelParameters.use_extra_bufts = false
        modelParameters.n_gpu_layers = 0
        guard let model = llama_model_load_from_file(path, modelParameters) else { return nil }

        var contextParameters = llama_context_default_params()
        // 128 tokens of context and five readings of a few tokens each.
        contextParameters.n_ctx = 256
        contextParameters.n_batch = 256
        // The compute buffer scales with it: 256 cost 18 MB in the spike, 32 cost 2 MB.
        contextParameters.n_ubatch = 32
        contextParameters.n_seq_max = UInt32(sequences)
        contextParameters.kv_unified = true
        contextParameters.n_threads = threads
        contextParameters.n_threads_batch = threads
        contextParameters.no_perf = true
        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            return nil
        }
        return LlamaLanguageModel(model: model, context: context)
    }

    private init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        vocab = llama_model_get_vocab(model)
        vocabSize = Int(llama_vocab_n_tokens(vocab))
        var afterSpace = [Bool](repeating: false, count: vocabSize)
        var atLineStart = [Bool](repeating: false, count: vocabSize)
        for index in 0..<vocabSize {
            let token = llama_token(index)
            let bytes = Self.piece(token, vocab: vocab)
            let kind = PieceKind(bytes)
            afterSpace[index] = kind.startsWordAfterSpace
            atLineStart[index] = kind.beginsWithLetter
        }
        startsWordAfterSpace = afterSpace
        startsWordAtLineStart = atLineStart
        exponentials = [Float](repeating: 0, count: vocabSize)
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    // MARK: - LanguageModelScoring

    func logProbabilities(of readings: [String], after text: String) -> [Double]? {
        guard !readings.isEmpty else { return [] }
        let (base, separator) = Self.split(text)
        let wholeContext = tokenize(base)
        // The same leading tokens go from the context and every reading, so they still line up.
        let dropped = max(0, wholeContext.count - Self.maxContextTokens)
        let contextTokens = Array(wholeContext.dropFirst(dropped))
        let full = readings.map { Array(tokenize(base + separator + $0).dropFirst(dropped)) }
        // The readings share the context's tokens up to where the first of them differs.
        let shared = full.map { Self.commonPrefix(contextTokens, $0) }.min() ?? 0
        guard shared >= 1, full.allSatisfy({ $0.count > shared }), evaluate(Array(contextTokens[0..<shared])) else {
            return nil
        }
        let tails = full.map { Array($0[shared...]) }
        var scores = [Double](repeating: 0, count: readings.count)
        let first = logNormalizer(cachedLogits)
        for (index, tail) in tails.enumerated() {
            scores[index] = Double(cachedLogits[Int(tail[0])] - first)
        }

        // A reading of several tokens is fed on its own sequence but its last token: the
        // row after token j scores token j + 1.
        //
        // WHY no word-boundary term: each row costs the whole vocabulary's output layer,
        // 152k entries for Qwen, about 5 ms on the Mac's CPU, and that layer is most of a
        // request's time. A boundary row per reading doubled it. The vocabulary's own
        // merges stand in for it: ` trouve` is one token, so ` trou` alone does not carry
        // the mass of `trouve`.
        let memory = llama_get_memory(context)
        let multiToken = tails.indices.filter { tails[$0].count > 1 }
        for group in Self.groups(multiToken.map { tails[$0].count - 1 }).map({ $0.map { multiToken[$0] } }) {
            var items: [BatchItem] = []
            for (slot, index) in group.enumerated() {
                let sequence = llama_seq_id(slot + 1)
                llama_memory_seq_rm(memory, sequence, -1, -1)
                llama_memory_seq_cp(memory, 0, sequence, -1, -1)
                for (offset, token) in tails[index].dropLast().enumerated() {
                    items.append(BatchItem(token: token, position: shared + offset, sequence: sequence, output: true))
                }
            }
            let decoded = decode(items)
            defer { for slot in group.indices { llama_memory_seq_rm(memory, llama_seq_id(slot + 1), -1, -1) } }
            guard decoded else { return nil }
            var row = 0
            for index in group {
                let tail = tails[index]
                for offset in 0..<(tail.count - 1) {
                    guard let logits = llama_get_logits_ith(context, Int32(row)) else { return nil }
                    scores[index] += Double(logits[Int(tail[offset + 1])] - logNormalizer(logits))
                    row += 1
                }
            }
        }
        return scores
    }

    func nextWords(after text: String, limit: Int) -> [String] {
        let (base, separator) = Self.split(text)
        let tokens = Array(tokenize(base).suffix(Self.maxContextTokens))
        guard !tokens.isEmpty, evaluate(tokens) else { return [] }
        let starts = separator.isEmpty ? startsWordAtLineStart : startsWordAfterSpace
        // WHY whole-word tokens only: extending a token into a word costs one pass over the
        // output layer per step, 40 to 60 ms for three Qwen words on the simulator. Common
        // words are one token in these vocabularies, and the logits after the context are
        // already there.
        var words: [String] = []
        for token in Self.best(cachedLogits, count: limit, where: { starts[$0] }) {
            // A token holding half of a multi-byte letter is not a word.
            guard let word = String(bytes: Self.piece(token, vocab: vocab), encoding: .utf8)?.trimmingCharacters(in: .whitespaces),
                  !word.isEmpty, !words.contains(word) else { continue }
            words.append(word)
        }
        return words
    }

    // MARK: - Context

    /// The text the model reads, from a line start, and what goes between it and the next
    /// word. A trailing space belongs to the next word's first token in these vocabularies.
    private static func split(_ text: String) -> (base: String, separator: String) {
        let line = "\n" + text
        guard line.hasSuffix(" ") else { return (line, "") }
        var base = line
        while base.hasSuffix(" ") { base.removeLast() }
        return (base, " ")
    }

    /// Puts `tokens` in sequence 0, feeding only what the cache lacks, and keeps the
    /// logits after the last one.
    private func evaluate(_ tokens: [llama_token]) -> Bool {
        let memory = llama_get_memory(context)
        var common = Self.commonPrefix(cached, tokens)
        if common == tokens.count, cached.count == tokens.count, !cachedLogits.isEmpty { return true }
        // The last token is fed again when the cache already holds it: its logits are needed.
        if common == tokens.count { common -= 1 }
        // A model whose cache cannot drop a tail (sliding window, recurrent) starts over.
        if !llama_memory_seq_rm(memory, 0, llama_pos(common), -1) {
            llama_memory_seq_rm(memory, 0, -1, -1)
            common = 0
        }
        cached = Array(tokens[0..<common])
        cachedLogits = []
        let fresh = tokens[common...].enumerated().map { offset, token in
            BatchItem(token: token, position: common + offset, sequence: 0, output: offset == tokens.count - common - 1)
        }
        guard decode(fresh), let logits = llama_get_logits_ith(context, -1) else {
            llama_memory_seq_rm(memory, 0, -1, -1)
            cached = []
            return false
        }
        cachedLogits = Array(UnsafeBufferPointer(start: logits, count: vocabSize))
        cached = tokens
        return true
    }

    // MARK: - Decoding

    private struct BatchItem {
        let token: llama_token
        let position: Int
        let sequence: llama_seq_id
        let output: Bool
    }

    private func decode(_ items: [BatchItem]) -> Bool {
        guard !items.isEmpty else { return true }
        var batch = llama_batch_init(Int32(items.count), 0, 1)
        defer { llama_batch_free(batch) }
        for (index, item) in items.enumerated() {
            batch.token[index] = item.token
            batch.pos[index] = llama_pos(item.position)
            batch.n_seq_id[index] = 1
            // llama_batch_init allocated one sequence slot per token (n_seq_max = 1).
            batch.seq_id[index]?.pointee = item.sequence
            batch.logits[index] = item.output ? 1 : 0
        }
        batch.n_tokens = Int32(items.count)
        return llama_decode(context, batch) == 0
    }

    /// Readings packed into decodes of at most `maxOutputs` rows and `sequences - 1` readings.
    private static func groups(_ counts: [Int]) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        var rows = 0
        for (index, count) in counts.enumerated() {
            if !current.isEmpty && (rows + count > maxOutputs || current.count == sequences - 1) {
                groups.append(current)
                current = []
                rows = 0
            }
            current.append(index)
            rows += count
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    /// The log of the softmax's normalizer over one row of logits.
    private func logNormalizer(_ logits: UnsafePointer<Float>) -> Float {
        let count = vDSP_Length(vocabSize)
        var maximum: Float = 0
        vDSP_maxv(logits, 1, &maximum, count)
        var shift = -maximum
        var size = Int32(vocabSize)
        var total: Float = 0
        exponentials.withUnsafeMutableBufferPointer { buffer in
            guard let out = buffer.baseAddress else { return }
            vDSP_vsadd(logits, 1, &shift, out, 1, count)
            vvexpf(out, out, &size)
            vDSP_sve(out, 1, &total, count)
        }
        return maximum + logf(total)
    }

    private static func best(_ logits: [Float], count: Int, where allowed: (Int) -> Bool) -> [llama_token] {
        var top: [(Int, Float)] = []
        for (index, value) in logits.enumerated() where allowed(index) {
            guard top.count < count || value > top[top.count - 1].1 else { continue }
            let at = top.firstIndex { $0.1 < value } ?? top.count
            top.insert((index, value), at: at)
            if top.count > count { top.removeLast() }
        }
        return top.map { llama_token($0.0) }
    }

    // MARK: - Tokens

    private func tokenize(_ text: String) -> [llama_token] {
        let utf8 = Array(text.utf8CString)
        let length = Int32(utf8.count - 1)
        var tokens = [llama_token](repeating: 0, count: Int(length) + 8)
        let count = llama_tokenize(vocab, utf8, length, &tokens, Int32(tokens.count), true, false)
        return count > 0 ? Array(tokens.prefix(Int(count))) : []
    }

    private static func piece(_ token: llama_token, vocab: OpaquePointer) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 64)
        let count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        guard count > 0 else { return [] }
        return buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
    }

    private static func commonPrefix(_ lhs: [llama_token], _ rhs: [llama_token]) -> Int {
        var common = 0
        while common < min(lhs.count, rhs.count), lhs[common] == rhs[common] { common += 1 }
        return common
    }
}

/// Whether a token's text starts or carries on a word, from its first bytes. A byte of
/// 0x80 or above starts or carries on a non-ASCII letter (`é`, split or whole) in these
/// byte-level vocabularies.
struct PieceKind {
    let beginsWithLetter: Bool
    let startsWordAfterSpace: Bool

    init(_ bytes: [UInt8]) {
        guard let first = bytes.first else {
            beginsWithLetter = false
            startsWordAfterSpace = false
            return
        }
        beginsWithLetter = Self.isLetter(first)
        startsWordAfterSpace = first == 0x20 && bytes.count > 1 && Self.isLetter(bytes[1])
    }

    private static func isLetter(_ byte: UInt8) -> Bool {
        byte >= 0x80 || (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }
}
#endif
