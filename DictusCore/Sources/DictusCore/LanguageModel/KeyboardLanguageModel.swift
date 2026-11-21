// DictusCore/Sources/DictusCore/LanguageModel/KeyboardLanguageModel.swift
// Runs the keyboard's language model off the caller's thread, within a time budget (#996).
import Foundation

/// The keyboard's language model behind a time budget (#996).
///
/// The model runs on its own serial queue, never on the caller's thread: the space bar
/// asks from the main thread, the suggestion bar from its background queue. A caller
/// waits at most `budget` for an answer and gets nil past it, or when no model is
/// loaded, and keeps the decision it would have made without the model.
///
/// WHY a cache: the bar asks about the word at every keystroke, so by the time the space
/// bar asks about the finished word, the bar's last request has usually answered it and
/// the space bar reads the answer without waiting. An answer that came too late for its
/// caller is still stored, for the next one.
///
/// WHY latest wins: a request waiting behind the running one is replaced by a newer one,
/// whose caller is the one still typing. The replaced caller gets nil at once.
public final class KeyboardLanguageModel: @unchecked Sendable {

    /// What a caller waits at most, in seconds (#996 brief: 15 ms).
    public static let defaultBudget: TimeInterval = 0.015

    /// One request's run on the model's queue, for the bench (#996).
    public struct Timing: Equatable, Sendable {
        /// A next-word request; otherwise a scoring one.
        public let isNextWords: Bool
        public let milliseconds: Double
    }

    private enum Request: Hashable {
        case score(readings: [String], context: String)
        case nextWords(context: String, limit: Int)
    }

    private enum Answer {
        case scores([Double]?)
        case words([String])
    }

    private final class Job {
        let request: Request
        /// What a next-word request accepts as a word; not part of the request's identity.
        let isWord: (String) -> Bool
        let done = DispatchGroup()
        /// Written once, before `done` is left; read only after it.
        var answer: Answer?

        init(request: Request, isWord: @escaping (String) -> Bool) {
            self.request = request
            self.isWord = isWord
            done.enter()
        }

        func finish(_ answer: Answer?) {
            self.answer = answer
            done.leave()
        }
    }

    private let queue = DispatchQueue(label: "com.pivi.dictus.language-model", qos: .userInitiated)
    /// nil waits for every answer: the bench, which measures quality and time apart.
    private let budget: TimeInterval?
    private let cacheCapacity: Int
    private let recordsTimings: Bool

    /// Only touched on `queue`.
    private var model: LanguageModelScoring?

    private let lock = NSLock()
    // Guarded by `lock`.
    private var loaded = false
    private var draining = false
    private var running: Job?
    private var pending: Job?
    private var cache: [Request: Answer] = [:]
    private var cacheOrder: [Request] = []
    private var timings: [Timing] = []

    public init(budget: TimeInterval? = KeyboardLanguageModel.defaultBudget, cacheCapacity: Int = 32,
                recordsTimings: Bool = false) {
        self.budget = budget
        self.cacheCapacity = cacheCapacity
        self.recordsTimings = recordsTimings
    }

    /// Loads a model on the model's queue; callers get nil until it is in.
    /// - Parameter make: opens the model; nil when it cannot (missing file, no llama.cpp).
    public func load(_ make: @escaping () -> LanguageModelScoring?) {
        queue.async { [self] in
            let opened = make()
            model = opened
            lock.lock()
            loaded = opened != nil
            clearCache()
            lock.unlock()
        }
    }

    /// Closes the model. Callers get nil from now on.
    public func unload() {
        lock.lock()
        loaded = false
        clearCache()
        lock.unlock()
        queue.async { [self] in model = nil }
    }

    /// Whether a model answers. False while it loads.
    public var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return loaded
    }

    /// Blocks until the queue has run everything submitted so far, a load included.
    public func waitForQueue() {
        queue.sync {}
    }

    /// `LanguageModelScoring.logProbabilities`, or nil without a model or past the budget.
    public func logProbabilities(of readings: [String], after context: String) -> [Double]? {
        guard case let .scores(scores)? = ask(.score(readings: readings, context: context), isWord: { _ in true })
        else { return nil }
        return scores
    }

    /// `LanguageModelScoring.nextWords`, or nil without a model or past the budget.
    public func nextWords(after context: String, limit: Int,
                          isWord: @escaping (String) -> Bool = { _ in true }) -> [String]? {
        guard case let .words(words)? = ask(.nextWords(context: context, limit: limit), isWord: isWord) else { return nil }
        return words
    }

    /// Every request run since the last call, oldest first. Empty unless `recordsTimings`.
    public func takeTimings() -> [Timing] {
        lock.lock()
        defer { lock.unlock() }
        let taken = timings
        timings = []
        return taken
    }

    private func ask(_ request: Request, isWord: @escaping (String) -> Bool) -> Answer? {
        lock.lock()
        guard loaded else { lock.unlock(); return nil }
        if let answer = cache[request] { lock.unlock(); return answer }
        let job: Job
        if let same = [running, pending].compactMap({ $0 }).first(where: { $0.request == request }) {
            job = same
        } else {
            job = Job(request: request, isWord: isWord)
            pending?.finish(nil)
            pending = job
            if !draining {
                draining = true
                queue.async { [self] in drain() }
            }
        }
        lock.unlock()

        let deadline: DispatchTime = budget.map { .now() + $0 } ?? .distantFuture
        guard job.done.wait(timeout: deadline) == .success else { return nil }
        return job.answer
    }

    private func drain() {
        while true {
            lock.lock()
            guard let job = pending else {
                draining = false
                lock.unlock()
                return
            }
            pending = nil
            running = job
            lock.unlock()

            let start = DispatchTime.now().uptimeNanoseconds
            let answer = run(job)
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

            lock.lock()
            running = nil
            if let answer, loaded { store(answer, for: job.request) }
            if recordsTimings {
                var isNextWords = true
                if case .score = job.request { isNextWords = false }
                timings.append(Timing(isNextWords: isNextWords, milliseconds: milliseconds))
            }
            lock.unlock()
            job.finish(answer)
        }
    }

    /// On `queue`.
    private func run(_ job: Job) -> Answer? {
        guard let model else { return nil }
        switch job.request {
        case let .score(readings, context):
            return .scores(model.logProbabilities(of: readings, after: context))
        case let .nextWords(context, limit):
            return .words(model.nextWords(after: context, limit: limit, isWord: job.isWord))
        }
    }

    /// Under `lock`.
    private func store(_ answer: Answer, for request: Request) {
        if cache.updateValue(answer, forKey: request) == nil { cacheOrder.append(request) }
        if cacheOrder.count > cacheCapacity {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    /// Under `lock`.
    private func clearCache() {
        cache = [:]
        cacheOrder = []
    }
}
