// DictusApp/Models/BackgroundModelDownloadService.swift
// The background URLSession that moves model bytes, its foreground fallback, and the state machine over both.
import Foundation
import UIKit
import DictusCore

/// Transfers model repository files in a background `URLSession`, one aligned byte
/// range at a time, and keeps a durable record of how far it got.
///
/// WHY THIS EXISTS (issue #449). Until it, the download was a foreground-only
/// `URLSessionConfiguration.ephemeral` session created per file, and its retry restarted
/// the current file from byte zero. A user who left Dictus during
/// `Encoder.mlmodelc/weights/weight.bin` — 445 MB of Parakeet's 483 MB payload — had the
/// transfer suspended with the process, met the 30 s stall detector on their return, and
/// watched the bar go back to 0%. Measured on a 15 Pro Max on 2026-08-28: three attempts,
/// 98 MB then 289 MB then the whole thing, and the only one that finished was the one
/// where the user did not touch their phone for four minutes.
///
/// Three things had to change together, and none of them works without the other two:
///
/// 1. **A background session.** `URLSessionConfiguration.background` transfers keep
///    running while the process is suspended and are handed back to the app when it
///    returns, so leaving Dictus stops costing anything.
/// 2. **Chunks instead of whole files.** A `URLSessionDownloadTask` writes to a temp
///    file the system owns and only reveals in `didFinishDownloadingTo`, which fires on
///    success alone — so the bytes of a whole-file task that never finished are
///    unreachable. Fixed 32 MB aligned ranges are moved out of that temp location the
///    moment each one lands, which is what makes progress durable rather than merely
///    in flight.
/// 3. **A manifest.** The chunk that is safe to ask for next is a fact about the disk,
///    and it has to survive the process to be worth anything. `ModelDownloadManifest`
///    holds it, alongside the exact repository revision the bytes came from.
///
/// WHY HTTP RANGE AND NOT `URLSession` RESUME DATA. The issue's implementation direction
/// asked for resume data first and byte ranges as the fallback. Resume data cannot carry
/// acceptance criterion 3 — force-quit Dictus mid-file, relaunch, keep the bytes. iOS
/// cancels a background session's tasks when the user force-quits and does not relaunch
/// the app, and resume data is only ever handed to a *running* process through
/// `didCompleteWithError`. A process that was killed receives nothing and has nothing to
/// resume from. The maintainer's own follow-up note on the issue specifies the range path
/// in full and never mentions resume data, so that is what is built here; the two are
/// deliberately not mixed, because resume data replays a request with a `Range` header of
/// its own and the interaction with ours is not something anyone should have to reason
/// about at 2 am.
///
/// WHY A SECOND, FOREGROUND SESSION (issue #707). On iOS 27.0.1, after a relaunch,
/// `nsurlsessiond` sometimes delivers nothing to the background session at all — adopted
/// tasks and freshly created ones alike — while the app sits in front of the user with the
/// network up. A `URLSessionConfiguration.default` session runs in this process and does
/// not depend on that daemon, so while the app is in the foreground a chunk the background
/// session has left silent is moved there (`SilentDownloadTaskWatchdog`,
/// `DownloadSessionPolicy`). The background session stays the primary path: the moment the
/// app enters the background, every chunk on the foreground session is handed back.
///
/// WHAT IT NEVER DOES: compile. A model that finishes downloading while Dictus is in the
/// background is left downloaded, and the Core ML prewarm waits for the foreground.
/// Issues #427 and #428 measured what an abandoned compile is worth in a suspended
/// process — nothing, and sometimes the process.
final class BackgroundModelDownloadService: NSObject, @unchecked Sendable {

    // MARK: - Configuration

    /// Stable across launches, which is the whole point: recreating a session with this
    /// identifier is what reconnects the app to transfers the system kept running.
    static let sessionIdentifier = "com.pivi.dictus.model-download"

    /// Bytes per aligned range request.
    ///
    /// The trade is between requests and re-paid bytes. Every chunk boundary is a
    /// durable savepoint, and every chunk in flight when the process dies is downloaded
    /// again. At 32 MB the 445 MB encoder costs 14 requests and a kill costs at most
    /// ~7% of it, against 100% before this existed.
    static let chunkSize: Int64 = 32 * 1024 * 1024

    /// How many chunks may be transferring at once.
    ///
    /// More than one so a suspended app does not stop dead the instant the current chunk
    /// lands and nobody is awake to ask for the next; few enough that a kill never puts
    /// more than 64 MB at risk.
    static let chunksInFlight = 2

    /// Seconds without a single received byte before a chunk is abandoned. Same value
    /// and same meaning as before (issue #207): `timeoutIntervalForRequest` is an IDLE
    /// timeout that resets whenever data arrives, so a slow connection never trips it.
    static let stallTimeout: TimeInterval = 30

    /// Attempts per file before the whole download fails (backoff 2s/4s/8s).
    static let maxAttemptsPerFile = 3

    /// Seconds the app must be foregrounded, with no network path and no byte arriving,
    /// before the transfer is reported as stalled (issue #492). Owned by
    /// `DownloadStallPolicy`, which is also where the choice of value is argued.
    static let offlineStallGrace = DownloadStallPolicy.offlineGrace

    // MARK: - Singleton

    static let shared = BackgroundModelDownloadService()

    private override init() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "solutions.pivi.dictus.model-download"
        self.queue = queue
        super.init()
    }

    /// Serial queue that is BOTH the session's delegate queue and the only place any
    /// member below is read or written. That is what makes `@unchecked Sendable` true
    /// here: there is exactly one thread of control over this object's state.
    private let queue: OperationQueue

    /// Created on first use and never again — two live sessions sharing one background
    /// identifier is a documented crash.
    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        // The user is watching a progress bar; this is not a nice-to-have transfer the
        // system may defer to a better moment.
        configuration.isDiscretionary = false
        configuration.timeoutIntervalForRequest = Self.stallTimeout
        configuration.httpMaximumConnectionsPerHost = Self.chunksInFlight
        return URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
    }()

    /// The fallback session a chunk moves to when the background one has gone silent with
    /// the app in the foreground (#707). Created on first use, which most processes never
    /// reach; read through `foregroundSession`.
    ///
    /// WHY THE SAME DELEGATE AND THE SAME QUEUE. Its chunks are the same chunks, tagged the
    /// same way, and they have to land through exactly the same path — the range checks in
    /// `didFinishDownloadingTo`, the append in `handleChunkCompletion`, the attempt budget
    /// in `retryOrFail`. One delegate on one serial queue is what makes that true without a
    /// second copy of any of it: the callbacks tell the two sessions apart by the `session`
    /// argument they are handed (`sessionKind(of:)`), and nothing else differs.
    private var foregroundSessionStorage: URLSession?

    private var foregroundSession: URLSession {
        if let existing = foregroundSessionStorage { return existing }
        let configuration = URLSessionConfiguration.default
        // A REAL idle timeout, which is the point of this session: a task the network
        // stops feeding fails with `NSURLErrorTimedOut` after 30 s and goes through
        // `retryOrFail` like any transient failure. The watchdog never looks at these.
        configuration.timeoutIntervalForRequest = Self.stallTimeout
        configuration.httpMaximumConnectionsPerHost = Self.chunksInFlight
        // Wait for a route rather than fail at once, like the background session does by
        // definition. So a device with no network parks this task too, and #492's offline
        // policy stays the one place that tells the user, with the copy it already has —
        // instead of a fast `NSURLErrorNotConnectedToInternet` burning the file's three
        // attempts in six seconds.
        configuration.waitsForConnectivity = true
        // 32 MB range responses have no business in the shared URL cache.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let created = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        foregroundSessionStorage = created
        return created
    }

    private func session(_ kind: DownloadSessionKind) -> URLSession {
        switch kind {
        case .background: return backgroundSession
        case .foreground: return foregroundSession
        }
    }

    /// Which of the two sessions a delegate callback comes from. By identity, without
    /// creating the foreground session: a callback can only come from a session that exists.
    fileprivate func sessionKind(of session: URLSession) -> DownloadSessionKind {
        if let foreground = foregroundSessionStorage, session === foreground { return .foreground }
        return .background
    }

    /// Whether the silent-task watchdog has moved a chunk off the background session during
    /// the current foreground stay (#707). While it holds, every chunk requested in the
    /// foreground goes to the foreground session; see `DownloadSessionPolicy` for why it
    /// holds for the whole stay rather than for one chunk. Released when the app enters the
    /// background, and when the last run ends.
    private var foregroundFallbackEngaged = false

    /// In-flight downloads, keyed by catalogue model identifier. One per model, which is
    /// what makes reopening onboarding unable to start a second copy (criterion 6).
    private var runs: [String: DownloadRun] = [:]

    /// How each live task ended, keyed by session and `taskIdentifier` — an identifier is
    /// only unique within one session, and two sessions can hand out the same number.
    private var outcomes: [DownloadTaskKey: ChunkOutcome] = [:]

    /// Handed over by `AppDelegate` when iOS relaunches the app to deliver background
    /// events. Must be called on the main thread once the events are drained.
    private var backgroundCompletionHandler: (@Sendable () -> Void)?

    /// Watches the foreground and the network route while a transfer is live, and is the
    /// only thing that can notice a transfer iOS has parked (issue #492): a background
    /// session that loses connectivity delivers no callback at all, so the state machine
    /// below is never told and never fails. Runs only while there is a run to watch.
    ///
    /// Its tick also drives the silent-task watchdog (issues #690, #707), which needs the
    /// same two things — a clock while a transfer is live, and whether the user is looking —
    /// and nothing else. And its background notification is what hands the foreground
    /// session's chunks back (#707): the foreground session only ever holds a chunk while
    /// this watcher is running, because the watchdog that puts one there runs on its tick.
    private lazy var connectivity = DownloadConnectivityWatch(
        onEnterBackground: { [weak self] in
            self?.handOffOnEnterBackground()
        },
        onTick: { [weak self] observed in
            guard let self else { return }
            self.queue.addOperation { [weak self] in
                // Offline first: a run it fails is gone before the watchdog looks, so a
                // parked task is never moved to a session that can only park it again.
                self?.reportOfflineStalls(observed: observed)
                self?.moveSilentBackgroundTasks()
            }
        }
    )

    /// Seconds after a task is adopted or created at which its state is logged a second
    /// time. Ten, as in #690: long enough for a healthy task to show `received` moving, and
    /// well inside the watchdog's 30 s, so a device log says what the task was doing before
    /// the watchdog decides anything about it.
    static let taskStateRecheckDelay: TimeInterval = 10

    #if DEBUG
    /// Debug builds only, never release: with the launch argument
    /// `-DictusDebugHoldBackgroundTasks`, a task `start()` creates on the background session
    /// WHILE THE APP IS IN THE FOREGROUND is never resumed (#707). It sits `suspended` with
    /// no byte, which is one of the two shapes of the device wedge, so the silent-task
    /// watchdog and the move to the foreground session can be driven on a simulator, where
    /// `nsurlsessiond` has never been seen to stall. A task created in the background — the
    /// hand-off's re-issue — runs normally, so the hand-off can be seen to carry the
    /// download on. Adopted tasks are untouched: they belong to the system's daemon.
    ///
    /// Remembered across launches: `-DictusDebugHoldBackgroundTasks YES` turns it on and
    /// `NO` turns it off for good. A launch iOS makes in the background carries no launch
    /// argument, and on the simulator one follows almost every backgrounding (the process
    /// is killed on its first background wake), so an argument read once would silently
    /// stop holding halfway through a run.
    private static let holdsBackgroundTasks: Bool = {
        let key = "DictusDebugHoldBackgroundTasks"
        let defaults = UserDefaults.standard
        // `bool(forKey:)` reads the argument domain first; writing it back to the app's
        // own domain is what the next launch, with no argument, reads.
        if ProcessInfo.processInfo.arguments.contains("-\(key)") {
            defaults.set(defaults.bool(forKey: key), forKey: key)
        }
        return defaults.bool(forKey: key)
    }()
    #endif

    // MARK: - Public API

    /// Runs (or joins) the transfer of one model and returns when every file is on disk.
    ///
    /// Calling this for a model already transferring attaches to that run instead of
    /// starting anything: same tasks, same manifest, one more progress observer. That is
    /// acceptance criterion 6 — reopening onboarding cannot launch a second download.
    ///
    /// - Parameters:
    ///   - manifest: the freshly listed repository state. Merged with whatever is already
    ///     on disk; a manifest that describes a different revision or file set replaces it.
    ///   - destination: directory that maps to the repository root.
    ///   - onProgress: called on the delegate queue — hop to the main actor for UI.
    func run(
        manifest: ModelDownloadManifest,
        destination: URL,
        onProgress: @escaping @Sendable (ModelRepoDownloader.Progress) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.addOperation { [self] in
                let run = adopt(manifest: manifest, destination: destination)
                run.observers.append(onProgress)
                run.continuations.append(continuation)
                // A caller that has just joined gets the full offline grace period,
                // whatever this run was doing before it arrived — a run rebuilt by
                // `restore()` minutes ago must not be declared stalled on the first tick.
                run.lastProgressDate = Date()
                run.emitProgress(force: true)
                connectivity.start()
                pump(run)
            }
        }
    }

    /// Recreates the background session so the system hands back transfers that outlived
    /// the process, and rebuilds a run for every manifest still on disk.
    ///
    /// Called once, from `AppDelegate`, before anything else can touch a model.
    ///
    /// It deliberately does NOT resume a download that has no live task. A relaunch with
    /// zero tasks is the force-quit shape, and restarting the transfer from here would
    /// mean downloading half a gigabyte for a user who has not asked for anything yet.
    /// `ModelManager` decides that, from the foreground, and its call lands on the very
    /// run this rebuilt.
    ///
    /// WHAT IT LOGS ABOUT THE TASKS IT ADOPTS (issue #690). After iOS killed Dictus on the
    /// Full Access change, the task adopted here delivered nothing for minutes, in the
    /// foreground with the network up, and no line said why. Each adopted task's state,
    /// byte count and error are logged now and again `taskStateRecheckDelay` later,
    /// which is what tells a suspended task from a running one that is not being fed.
    /// The watchdog unblocks the run whatever the answer; these lines say what it was.
    func restore() {
        queue.addOperation { [self] in
            let manifests = ManifestStore.loadAll()
            for (identifier, manifest) in manifests {
                guard let destination = Self.destinationDirectory(for: identifier) else { continue }
                _ = adopt(manifest: manifest, destination: destination)
            }
            // The background session only: the foreground one dies with its process and
            // has nothing to hand back.
            backgroundSession.getAllTasks { [self] tasks in
                queue.addOperation { [self] in
                    let now = Date()
                    var adopted: [URLSessionDownloadTask] = []
                    for task in tasks {
                        guard let download = task as? URLSessionDownloadTask,
                              let tag = ModelDownloadTaskTag.decode(task.taskDescription),
                              let run = runs[tag.modelIdentifier],
                              tag.fileIndex == run.manifest.currentFileIndex else {
                            cancelUnclaimed(task)
                            continue
                        }
                        run.inFlight.insert(tag.chunkIndex)
                        // The watchdog's clock starts at adoption: no byte has arrived in
                        // this process yet, and it cannot know when the last one did in
                        // the previous one.
                        run.tasks[tag.chunkIndex] = ChunkTask(
                            task: download,
                            session: .background,
                            origin: .adoptedFromPreviousProcess,
                            lastByteAt: now
                        )
                        run.liveChunkBytes[tag.chunkIndex] = download.countOfBytesReceived
                        adopted.append(download)
                    }
                    PersistentLog.log(.modelDownloadSessionRestored(
                        tasks: adopted.count,
                        models: manifests.count
                    ))
                    for task in adopted {
                        logState(of: task, phase: "restore", origin: .adoptedFromPreviousProcess, session: .background)
                    }
                    for run in runs.values where !run.inFlight.isEmpty {
                        run.emitProgress(force: true)
                    }
                    if !adopted.isEmpty {
                        scheduleTaskStateRecheck(
                            of: adopted,
                            phase: "restore+10s",
                            origin: .adoptedFromPreviousProcess,
                            session: .background
                        )
                    }
                }
            }
        }
    }

    /// Cancels a task the session handed back that no run can take, and says why.
    ///
    /// Two shapes, named apart in the log. `restoreUnclaimed`: no manifest on disk claims
    /// the task, or its tag is unreadable — nothing would ever consume its bytes.
    /// `restoreStaleFile`: the model has a run, but the task fetches a file the manifest
    /// has moved past.
    ///
    /// WHY A `restoreStaleFile` TASK IS MARKED ABANDONED (issue #701). Its model HAS a
    /// run, so without the mark its `-999` completion would reach `handleChunkCompletion`,
    /// and two things would go wrong there. `-999` is not retryable, so `retryOrFail` would
    /// fail the whole download over a cancel of our own. And before that, the chunk index
    /// would be cleared from `inFlight`, `tasks` and `liveChunkBytes`, which are keyed by
    /// chunk of the CURRENT file — freeing the slot of a live chunk that happens to share
    /// the number. The mark makes `didCompleteWithError` drop the completion at its
    /// `isAbandoned` guard, exactly like a cancel from `DownloadRun.cancel(chunk:caller:)`.
    ///
    /// A `restoreUnclaimed` task needs no mark: no run will ever receive its completion.
    private func cancelUnclaimed(_ task: URLSessionTask) {
        let tag = ModelDownloadTaskTag.decode(task.taskDescription)
        let run = tag.flatMap { runs[$0.modelIdentifier] }
        let caller: TaskCancelCaller = run == nil ? .restoreUnclaimed : .restoreStaleFile
        PersistentLog.log(.modelDownloadTaskCancelled(
            name: tag?.modelIdentifier ?? "?",
            path: tag.flatMap { tag in run?.pathOfFile(tag.fileIndex) } ?? "?",
            chunk: tag?.chunkIndex ?? -1,
            caller: caller.rawValue
        ))
        // Before `cancel()`, so the mark is in place whenever the completion arrives. Only
        // ever a background-session task: `restore()` lists no other session.
        run?.abandonedTasks.insert(DownloadTaskKey(session: .background, identifier: task.taskIdentifier))
        task.cancel()
    }

    /// Logs tasks a second time, `taskStateRecheckDelay` after they were adopted by
    /// `restore()` or created by `start()`, so a device log shows whether each one moved.
    ///
    /// The tasks are kept by reference rather than re-listed: one the watchdog or a hand-off
    /// has cancelled meanwhile is no longer listed by `getAllTasks`, and its state at that
    /// moment is part of the answer.
    ///
    /// #690 also listed every OTHER task the session held at that point, as `origin=new`.
    /// Since #707 every task `start()` creates logs its own `start` and `start+10s` lines,
    /// on whichever session holds it, so that listing would only repeat them.
    private func scheduleTaskStateRecheck(
        of tasks: [URLSessionDownloadTask],
        phase: String,
        origin: DownloadTaskOrigin,
        session: DownloadSessionKind
    ) {
        let delay = Self.taskStateRecheckDelay
        // Strong captures, like `restore()`'s: this is the process-long singleton.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [self] in
            queue.addOperation { [self] in
                for task in tasks {
                    logState(of: task, phase: phase, origin: origin, session: session)
                }
            }
        }
    }

    /// One `modelDownloadTaskState` line for a task, as URLSession describes it.
    private func logState(
        of task: URLSessionTask,
        phase: String,
        origin: DownloadTaskOrigin,
        session: DownloadSessionKind
    ) {
        let tag = ModelDownloadTaskTag.decode(task.taskDescription)
        let run = tag.flatMap { runs[$0.modelIdentifier] }
        PersistentLog.log(.modelDownloadTaskState(
            name: tag?.modelIdentifier ?? "?",
            path: tag.flatMap { tag in run?.pathOfFile(tag.fileIndex) } ?? "?",
            chunk: tag?.chunkIndex ?? -1,
            phase: phase,
            origin: origin.rawValue,
            session: session.rawValue,
            state: Self.describe(task.state),
            receivedBytes: task.countOfBytesReceived,
            error: (task.error as NSError?).map { "\($0.domain)/\($0.code)" } ?? "none"
        ))
    }

    private static func describe(_ state: URLSessionTask.State) -> String {
        switch state {
        case .running: return "running"
        case .suspended: return "suspended"
        case .canceling: return "canceling"
        case .completed: return "completed"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }

    /// Identifiers with a manifest on disk that has not finished transferring.
    /// Read straight from the file system so a fresh process can answer it.
    static func interruptedModelIdentifiers() -> [String] {
        ManifestStore.loadAll()
            .filter { !$0.value.isTransferComplete }
            .keys
            .sorted()
    }

    /// Whether a transfer for this model is already under way — a manifest on disk that
    /// has not finished. Read straight from the file system, so it answers in a process
    /// that has done nothing yet.
    static func hasUnfinishedTransfer(for identifier: String) -> Bool {
        guard let manifest = ManifestStore.load(identifier) else { return false }
        return !manifest.isTransferComplete
    }

    /// Durable progress of an interrupted download, for a screen that has to show
    /// something before the first delegate callback of this process arrives.
    static func persistedProgress(for identifier: String) -> ModelRepoDownloader.Progress? {
        guard let manifest = ManifestStore.load(identifier) else { return nil }
        return ModelRepoDownloader.Progress(
            bytesDownloaded: manifest.receivedBytes,
            totalBytes: manifest.totalBytes,
            completedFiles: manifest.completedFileCount,
            totalFiles: manifest.files.count
        )
    }

    /// Throws away everything a model's interrupted download is holding: the manifest,
    /// the partials, the chunks. Called by the "Delete partial download" path and by
    /// model deletion, both of which mean the user wants the disk space back.
    func discardStaging(for identifier: String) {
        queue.addOperation { [self] in
            if let run = runs[identifier] {
                run.cancelAllTasks(caller: .discardStaging)
                finish(run, error: CancellationError())
            }
            ManifestStore.discard(identifier)
        }
    }

    /// Handed the completion handler iOS gives the app delegate when it relaunches to
    /// deliver background events. Kept until the session says it has no more.
    func setBackgroundCompletionHandler(_ handler: @escaping @Sendable () -> Void) {
        queue.addOperation { [self] in
            backgroundCompletionHandler = handler
            // Touch the session so it exists and starts draining. Without this the
            // handler would sit here until something else happened to create it.
            _ = backgroundSession
        }
    }

    /// The directory a model's repository files land in, resolved from the catalogue
    /// rather than persisted: an app container path is not stable across installs.
    static func destinationDirectory(for identifier: String) -> URL? {
        ModelRepoDownloader.destinationDirectory(for: identifier)
    }

    // MARK: - Run lifecycle (delegate queue only)

    /// Returns the run for this model, creating it or replacing its manifest as needed.
    private func adopt(manifest: ModelDownloadManifest, destination: URL) -> DownloadRun {
        if let existing = runs[manifest.modelIdentifier] {
            // A live run wins over a fresh listing of the same download — its tasks are
            // already moving. Only a listing that describes something ELSE (a new
            // revision, a changed file set) is allowed to replace it.
            if existing.manifest.describesSameDownload(
                repositoryID: manifest.repositoryID,
                revision: manifest.revision,
                files: manifest.files,
                chunkSize: manifest.chunkSize
            ) {
                return existing
            }
            existing.cancelAllTasks(caller: .listingReplaced)
            finish(existing, error: CancellationError())
            ManifestStore.discard(manifest.modelIdentifier)
        }

        var merged = manifest
        if let stored = ManifestStore.load(manifest.modelIdentifier),
           stored.describesSameDownload(
                repositoryID: manifest.repositoryID,
                revision: manifest.revision,
                files: manifest.files,
                chunkSize: manifest.chunkSize
           ) {
            merged = stored
            // The caller listed the cache directory a moment ago; that reading wins over
            // whatever the stored manifest last believed about which files are published.
            merged.applyOnDiskCompletion(Set(manifest.files.filter(\.completed).map(\.path)))
        } else {
            ManifestStore.discard(manifest.modelIdentifier)
        }

        let run = DownloadRun(manifest: merged, destination: destination)
        runs[manifest.modelIdentifier] = run
        ManifestStore.save(run.manifest)
        return run
    }

    /// Moves the run forward: publish what is finished, ask for what is next.
    private func pump(_ run: DownloadRun) {
        guard !run.isFinished else { return }

        while let fileIndex = run.manifest.currentFileIndex {
            let file = run.manifest.files[fileIndex]
            let destination = run.destination.appendingPathComponent(file.path)

            // Already published — by an earlier run, or by the retry-in-place path that
            // skips files on disk. Costs nothing and keeps the manifest honest.
            if FileManager.default.fileExists(atPath: destination.path) {
                complete(file: fileIndex, in: run)
                continue
            }

            // Hugging Face answers HTTP 500 for a zero-byte file, so it is created here
            // instead of asked for. Unchanged behaviour from the previous downloader.
            if file.size == 0 {
                do {
                    try FileManager.default.createDirectory(
                        at: destination.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                } catch {
                    finish(run, error: error)
                    return
                }
                FileManager.default.createFile(atPath: destination.path, contents: Data())
                complete(file: fileIndex, in: run)
                continue
            }

            if run.manifest.isFileFullyReceived(at: fileIndex) {
                // A refused publication has already decided what happens next — a
                // scheduled retry or the end of the run — and must not fall through into
                // the enqueue below, which would start the retry immediately and skip
                // the backoff it was just given.
                guard publish(file: fileIndex, in: run) else { return }
                continue
            }

            let next = run.manifest.chunksToEnqueue(
                ofFileAt: fileIndex,
                inFlight: run.inFlight,
                alreadyStored: ManifestStore.storedChunkIndices(
                    run.manifest.modelIdentifier,
                    fileIndex: fileIndex
                ),
                window: Self.chunksInFlight
            )
            for chunkIndex in next {
                start(chunk: chunkIndex, ofFile: fileIndex, in: run)
            }
            return
        }

        // Nothing left to take: every file is published.
        ManifestStore.discard(run.manifest.modelIdentifier)
        finish(run, error: nil)
    }

    /// Marks a file done without touching disk — it is already where it belongs.
    private func complete(file index: Int, in run: DownloadRun) {
        run.manifest.markCompleted(fileAt: index)
        run.inFlight.removeAll()
        run.tasks.removeAll()
        run.liveChunkBytes.removeAll()
        run.attempts = 0
        ManifestStore.save(run.manifest)
        run.emitProgress(force: true)
    }

    private func start(chunk chunkIndex: Int, ofFile fileIndex: Int, in run: DownloadRun) {
        let file = run.manifest.files[fileIndex]
        guard let span = run.manifest.span(ofChunk: chunkIndex, inFileAt: fileIndex),
              let url = Self.fileURL(manifest: run.manifest, path: file.path) else {
            finish(run, error: ModelRepoDownloader.DownloadError.invalidResponse)
            return
        }

        var request = URLRequest(url: url)
        let rangeValue = span.end.map { HTTPRangeResume.rangeHeaderValue(start: span.start, end: $0) }
            ?? HTTPRangeResume.rangeHeaderValue(start: span.start)
        request.setValue(rangeValue, forHTTPHeaderField: "Range")
        // `If-Range` turns "give me these bytes" into "give me these bytes only if the
        // file is still the one I already hold part of". Without it a repository that
        // changed under us answers 206 with the new file's bytes at the old file's
        // offset, and the result is a file of exactly the right length made of two
        // different downloads — which nothing downstream can detect.
        if span.start > 0, let validator = file.validator {
            request.setValue(validator, forHTTPHeaderField: "If-Range")
        }

        // Background unless the watchdog has found the background session silent during
        // this foreground stay (#707). A chunk is only ever on one of the two: `start` is
        // only reached for a chunk out of `inFlight`, and a chunk leaves `inFlight` only
        // when its task completed or was cancelled as abandoned.
        let kind = DownloadSessionPolicy.session(
            appInForeground: connectivity.conditions.foregroundSince != nil,
            fallbackEngaged: foregroundFallbackEngaged
        )
        let task = session(kind).downloadTask(with: request)
        task.taskDescription = ModelDownloadTaskTag(
            modelIdentifier: run.manifest.modelIdentifier,
            fileIndex: fileIndex,
            chunkIndex: chunkIndex
        ).encoded
        run.inFlight.insert(chunkIndex)
        // The watchdog's clock starts at creation, so a task that never delivers its first
        // byte is still measured.
        run.tasks[chunkIndex] = ChunkTask(
            task: task,
            session: kind,
            origin: .createdByThisProcess,
            lastByteAt: Date()
        )
        run.liveChunkBytes[chunkIndex] = 0

        // A resume is the FIRST chunk this run asks for on a file starting anywhere but
        // byte zero. Logging every non-zero offset instead called each ordinary step to
        // the next chunk a resume, which made the line worthless for the one question it
        // answers: did returning to Dictus cost the user their bytes.
        if run.markFileStarted(fileIndex), span.start > 0 {
            PersistentLog.log(.modelDownloadResumed(
                name: run.manifest.modelIdentifier,
                path: file.path,
                offsetMB: Int(span.start / 1_000_000),
                totalMB: Int(max(0, file.size) / 1_000_000),
                source: run.continuations.isEmpty ? "relaunch" : "manifest"
            ))
        }
        #if DEBUG
        if kind == .background, Self.holdsBackgroundTasks, connectivity.conditions.foregroundSince != nil {
            // Left suspended on purpose: see `holdsBackgroundTasks`.
            logState(of: task, phase: "start", origin: .createdByThisProcess, session: kind)
            scheduleTaskStateRecheck(of: [task], phase: "start+10s", origin: .createdByThisProcess, session: kind)
            return
        }
        #endif
        task.resume()
        // The diagnosis #707 asked for: right after `resume()` and ten seconds later, so a
        // replacement that sits `suspended` reads apart from one `running` with no bytes.
        logState(of: task, phase: "start", origin: .createdByThisProcess, session: kind)
        scheduleTaskStateRecheck(of: [task], phase: "start+10s", origin: .createdByThisProcess, session: kind)
    }

    /// Verifies an assembled partial and moves it into the cache directory.
    /// - Returns: whether the file was published; false means this run is retrying or over.
    @discardableResult
    private func publish(file index: Int, in run: DownloadRun) -> Bool {
        let file = run.manifest.files[index]
        let partial = ManifestStore.partialURL(run.manifest.modelIdentifier, fileIndex: index)
        let destination = run.destination.appendingPathComponent(file.path)

        if let failure = ModelFileIntegrity.verify(
            fileAt: partial,
            expectedSize: file.size,
            expectedSHA256: file.sha256
        ) {
            PersistentLog.log(.modelDownloadIntegrityFailed(
                name: run.manifest.modelIdentifier,
                path: file.path,
                reason: failure.logReason
            ))
            ManifestStore.discardFile(run.manifest.modelIdentifier, fileIndex: index)
            run.manifest.resetFile(at: index)
            ManifestStore.save(run.manifest)
            retryOrFail(
                run,
                error: ModelRepoDownloader.DownloadError.integrityFailed(path: file.path)
            )
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Remove any stale destination, then move — atomically publishing a complete
            // file or nothing. The property everything downstream leans on: a file that
            // exists is a file that finished (see `WhisperModelRepository`).
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: partial, to: destination)
        } catch {
            finish(run, error: error)
            return false
        }

        ManifestStore.discardFile(run.manifest.modelIdentifier, fileIndex: index)
        complete(file: index, in: run)
        return true
    }

    /// One more attempt at the current file, or the end of the road for this download.
    private func retryOrFail(_ run: DownloadRun, error: Error) {
        run.attempts += 1
        guard run.attempts < Self.maxAttemptsPerFile,
              ModelRepoDownloader.isRetryable(error),
              let fileIndex = run.manifest.currentFileIndex else {
            finish(run, error: error)
            return
        }

        PersistentLog.log(.modelDownloadStalled(
            name: run.manifest.modelIdentifier,
            path: run.manifest.files[fileIndex].path,
            timeoutSeconds: Int(Self.stallTimeout),
            attempt: run.attempts
        ))

        let delay = pow(2.0, Double(run.attempts))
        let identifier = run.manifest.modelIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.queue.addOperation {
                guard let live = self.runs[identifier], !live.isFinished else { return }
                self.pump(live)
            }
        }
    }

    /// Fails every live transfer that the device has no route to move, while somebody
    /// is watching it (issue #492).
    ///
    /// WHY IT HAS TO BE US. A background `URLSession` waits for connectivity by
    /// definition. Lose the network mid-download and iOS parks the tasks: no bytes, no
    /// `didCompleteWithError`, nothing for the state machine above to act on. Measured on
    /// device on 2026-09-05, airplane mode produced three minutes and twelve seconds of
    /// complete silence under a frozen progress bar, and the only way out was a force
    /// quit. `timeoutIntervalForRequest` does not cover it: that is an idle timeout on a
    /// running task, and a parked task is not running.
    ///
    /// WHY `finish` AND NOT `retryOrFail`. The attempt budget exists for transient
    /// transport failures, and this is not one — `DownloadStallPolicy` has already
    /// established that the device has no route at all, so a retry two seconds later can
    /// only park a second time and spend the user's remaining attempts saying nothing.
    ///
    /// WHAT STOPPING COSTS, exactly. Every chunk that LANDED is on disk and in the
    /// manifest, so the Retry resumes at the last chunk boundary — not at the byte the
    /// progress bar was showing. The chunks still in flight are cancelled with the run and
    /// their bytes are gone: `didFinishDownloadingTo` fires on success alone, so a
    /// cancelled task's partial file is one the system deletes and nothing here ever sees.
    /// At 32 MB a chunk and two in flight that is up to 64 MB re-paid on the retry, and on
    /// a file whose first chunk had not landed yet it legitimately reads as 0%. Measured
    /// on device on 2026-09-06: a cut inside the first chunk of a 176 MB `weight.bin`
    /// re-paid 49 MB. Cancelling is not what loses them — a chunk delivered to a run
    /// `finish` has already removed from `runs` is dropped by the guard in
    /// `didFinishDownloadingTo` anyway — but the choice to fail the run is.
    ///
    /// WHY ONLY RUNS WITH A CONTINUATION. A run nobody is awaiting is one `restore()`
    /// rebuilt and no screen has claimed yet. There is nowhere to deliver an error, and
    /// a stall the user cannot see is a stall not worth reporting.
    ///
    /// WHY THE READING IS RE-ASKED HERE. `observed` was taken on the watcher's queue and
    /// this runs on the session's delegate queue, behind whatever that queue was already
    /// doing — a 32 MB append, a burst of `didWriteData`. The gap matters because the
    /// moment connectivity returns is exactly the moment this queue fills up: every parked
    /// task resumes at once. A reading taken while the device was offline can therefore
    /// arrive here after it is online again, and `now` — sampled when this runs, not when
    /// the tick was raised — can meanwhile have passed the grace period. Judged on its own
    /// it would cancel a download that is working. `conditions` is asked again, one line
    /// before the decision, and it governs.
    private func reportOfflineStalls(observed: DownloadStallConditions, now: Date = Date()) {
        let current = connectivity.conditions
        // A copy: `finish` mutates `runs`.
        for run in Array(runs.values) where !run.isFinished && !run.continuations.isEmpty {
            guard DownloadStallPolicy.shouldReportStall(
                now: now,
                lastProgressAt: run.lastProgressDate,
                observed: observed,
                current: current,
                grace: Self.offlineStallGrace
            ) else { continue }

            let path = run.manifest.currentFileIndex.map { run.pathOfFile($0) } ?? "?"
            PersistentLog.log(.modelDownloadOffline(
                name: run.manifest.modelIdentifier,
                path: path,
                secondsWithoutProgress: Int(now.timeIntervalSince(run.lastProgressDate))
            ))
            // The parked tasks go with the run. Left alive they would deliver their
            // chunks into a run that no longer exists, which drops them anyway, and the
            // bytes would be paid for twice.
            run.cancelAllTasks(caller: .offlineStall)
            finish(run, error: ModelRepoDownloader.DownloadError.stalled(
                path: path,
                timeoutSeconds: Int(Self.offlineStallGrace)
            ))
        }
    }

    /// Cancels every background-session task that has gone
    /// `SilentDownloadTaskWatchdog.silenceLimit` without a byte while the app is in the
    /// foreground, and asks for its chunk again on the foreground session (#690, #707).
    ///
    /// WHY IT HAS TO BE US. Measured on device on 2026-10-09, three runs: after iOS killed
    /// Dictus on the Full Access change — and once after a user force-quit — the relaunch
    /// adopted the task the system kept, and that task then delivered nothing for 90 s,
    /// then 3 min 25 s, in the foreground with the network up and no error. The 30 s
    /// `timeoutIntervalForRequest` never fired. Nothing else here could notice: its chunk
    /// sits in `inFlight` so `pump` never asks for it again, and `DownloadStallPolicy` is
    /// silent by design while there is a route.
    ///
    /// WHY EVERY BACKGROUND TASK, AND WHY THE FOREGROUND SESSION (#707). #690 watched
    /// adopted tasks only and re-issued their chunk on the same background session. On
    /// device on 2026-10-11 that replacement stalled exactly like the task it replaced, and
    /// in a second capture two tasks this process had just created sat `running` with
    /// `received=0B`. The stall is the session's: a new task on it is no remedy, and a task
    /// is not safe from it for having been created here. So every background task is
    /// watched, and its chunk goes where the stall cannot follow it.
    ///
    /// WHAT IT COSTS, exactly. The cancelled task's bytes are gone with it —
    /// `didFinishDownloadingTo` fires on success alone — so at most one 32 MB chunk is
    /// downloaded again; every chunk that landed is on disk and in the manifest, and the
    /// re-issued request starts at the chunk boundary the manifest names. The cancel goes
    /// through the abandoned path, so its `-999` spends none of the file's attempts.
    ///
    /// WHY IT CANNOT LOOP. The fallback is engaged before `pump`, so the re-issued chunk —
    /// and every chunk after it during this foreground stay — goes to the foreground
    /// session, and `SilentDownloadTaskWatchdog` never cancels a task there.
    ///
    /// WHY IT CANNOT BRING #449 BACK. The foreground reading is the watcher's current one,
    /// taken on this queue a line before the decision, not the one the tick carried: an app
    /// that has gone to the background since reads `nil` here and nothing is cancelled.
    private func moveSilentBackgroundTasks(now: Date = Date()) {
        let foregroundSince = connectivity.conditions.foregroundSince
        // A copy: `pump` can end a run, which mutates `runs`.
        for run in Array(runs.values) where !run.isFinished {
            var moved = false
            for (chunkIndex, entry) in run.tasks.sorted(by: { $0.key < $1.key }) {
                guard SilentDownloadTaskWatchdog.shouldCancel(
                    now: now,
                    session: entry.session,
                    lastByteAt: entry.lastByteAt,
                    foregroundSince: foregroundSince
                ) else { continue }

                PersistentLog.log(.modelDownloadBackgroundTaskSilent(
                    name: run.manifest.modelIdentifier,
                    path: run.pathOfFile(run.fileIndex(of: entry.task) ?? -1),
                    chunk: chunkIndex,
                    origin: entry.origin.rawValue,
                    secondsWithoutByte: Int(now.timeIntervalSince(entry.lastByteAt))
                ))
                run.cancel(chunk: chunkIndex, caller: .silentTaskWatchdog)
                moved = true
            }
            guard moved else { continue }
            // Before `pump`: it is what sends the re-issued chunk to the foreground session.
            foregroundFallbackEngaged = true
            // The chunk has left `inFlight`, so the manifest offers it again: same span,
            // same `If-Range`, on the foreground session.
            pump(run)
        }
    }

    /// Called on the main thread from the `didEnterBackground` notification while a
    /// transfer is watched. Secures the seconds the hand-off needs, then runs it on the
    /// delegate queue.
    ///
    /// WHY A BACKGROUND TASK ASSERTION. The process is about to be suspended, and the
    /// delegate queue may be busy with a 32 MB append when the notification lands. Without
    /// the assertion, a suspension that came first would leave the chunk on a session that
    /// no longer runs: its bytes lost anyway, a 30 s timeout on the user's return, and the
    /// background throttle never given the chunk to work on. With it, the cancel and the
    /// re-issue happen before iOS suspends us. It is released as soon as both are done.
    private func handOffOnEnterBackground() {
        let assertion = BackgroundTimeAssertion(name: "dictus.modelDownload.handOff")
        queue.addOperation { [self] in
            handOffForegroundTasks()
            assertion.end()
        }
    }

    /// Cancels every chunk on the foreground session and asks for it again on the
    /// background session, because the app is leaving the foreground (#707).
    ///
    /// WHAT IT COSTS, exactly. A cancelled download task's bytes are unreachable, so each
    /// chunk handed back is downloaded again from its boundary: at most 64 MB with two in
    /// flight. Not handing back costs the same bytes — a default session's task stops with
    /// the suspended process and then times out — plus the whole background stay.
    ///
    /// WHY THE FALLBACK IS RELEASED. It is what `start` reads to pick a session. The
    /// watcher already reads "background" by the time this runs (see
    /// `DownloadConnectivityWatch.onEnterBackground`), which alone routes every chunk to the
    /// background session; releasing the fallback as well means the next foreground stay
    /// starts on the background session too. If that session is still silent then, the
    /// watchdog moves the chunk again.
    private func handOffForegroundTasks() {
        foregroundFallbackEngaged = false
        // A copy: `pump` can end a run, which mutates `runs`.
        for run in Array(runs.values) where !run.isFinished {
            var handedBack = false
            for (chunkIndex, entry) in run.tasks.sorted(by: { $0.key < $1.key })
            where DownloadSessionPolicy.shouldHandBack(taskOn: entry.session) {
                run.cancel(chunk: chunkIndex, caller: .backgroundHandOff)
                handedBack = true
            }
            if handedBack { pump(run) }
        }
    }

    /// Ends a run: everyone waiting is told, and the model is no longer in flight.
    private func finish(_ run: DownloadRun, error: Error?) {
        guard !run.isFinished else { return }
        run.isFinished = true
        runs.removeValue(forKey: run.manifest.modelIdentifier)
        if runs.isEmpty {
            connectivity.stop()
            // The next download starts on the background session, like any other.
            foregroundFallbackEngaged = false
        }
        let continuations = run.continuations
        run.continuations.removeAll()
        run.observers.removeAll()
        for continuation in continuations {
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }
    }

    // MARK: - URL construction

    /// The canonical, commit-pinned resolver URL for one repository file.
    ///
    /// Never the redirected CDN URL: those carry a short-lived signature and are
    /// worthless the moment they are persisted (maintainer's note on issue #449).
    static func fileURL(manifest: ModelDownloadManifest, path: String) -> URL? {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(
            string: "https://huggingface.co/\(manifest.repositoryID)"
                + "/resolve/\(manifest.revision)/\(encoded)"
        )
    }

    // MARK: - Chunk outcome

    /// How one chunk task ended, recorded in `didFinishDownloadingTo` and acted on in
    /// `didCompleteWithError` — the only callback URLSession guarantees fires once per
    /// task, and therefore the only safe place to move the state machine.
    fileprivate enum ChunkOutcome {
        case stored(validator: String?)
        case restartFile(reason: String)
        case failed(Error)
    }

    fileprivate func record(outcome: ChunkOutcome, for key: DownloadTaskKey) {
        outcomes[key] = outcome
    }

    fileprivate func takeOutcome(for key: DownloadTaskKey) -> ChunkOutcome? {
        outcomes.removeValue(forKey: key)
    }

    fileprivate func run(for tag: ModelDownloadTaskTag) -> DownloadRun? {
        runs[tag.modelIdentifier]
    }

    fileprivate func handleChunkCompletion(
        tag: ModelDownloadTaskTag,
        run: DownloadRun,
        outcome: ChunkOutcome?,
        transportError: Error?
    ) {
        run.inFlight.remove(tag.chunkIndex)
        run.tasks.removeValue(forKey: tag.chunkIndex)
        run.liveChunkBytes.removeValue(forKey: tag.chunkIndex)
        guard !run.isFinished else { return }

        if let transportError {
            let mapped = Self.mapped(transportError, path: run.pathOfFile(tag.fileIndex))
            retryOrFail(run, error: mapped)
            return
        }

        switch outcome {
        case .stored(let validator):
            run.manifest.setValidator(validator, ofFileAt: tag.fileIndex)
            // The offset the partial is authoritative up to, read BEFORE the manifest
            // advances. `append` truncates to it first, which is what makes the whole
            // operation replayable: a process that died between writing bytes and saving
            // the manifest left bytes past this point, and they are dropped rather than
            // appended to a second time.
            let appendAt = run.manifest.files[tag.fileIndex].appendedBytes
            let absorbed = run.manifest.absorbContiguousChunks(
                ofFileAt: tag.fileIndex,
                available: ManifestStore.storedChunkIndices(
                    run.manifest.modelIdentifier,
                    fileIndex: tag.fileIndex
                )
            )
            do {
                try ManifestStore.append(
                    chunks: absorbed,
                    ofFile: tag.fileIndex,
                    model: run.manifest.modelIdentifier,
                    startingAt: appendAt
                )
            } catch {
                finish(run, error: error)
                return
            }
            run.attempts = 0
            ManifestStore.save(run.manifest)
            run.emitProgress(force: !absorbed.isEmpty)
            pump(run)

        case .restartFile:
            ManifestStore.discardFile(run.manifest.modelIdentifier, fileIndex: tag.fileIndex)
            run.manifest.resetFile(at: tag.fileIndex)
            ManifestStore.save(run.manifest)
            run.cancelAllTasks(caller: .fileRestart)
            run.inFlight.removeAll()
            run.liveChunkBytes.removeAll()
            run.emitProgress(force: true)
            pump(run)

        case .failed(let error):
            retryOrFail(run, error: error)

        case nil:
            // No outcome and no error means `didFinishDownloadingTo` never ran, which
            // URLSession only does for a cancelled task.
            retryOrFail(run, error: ModelRepoDownloader.DownloadError.invalidResponse)
        }
    }

    /// The assembled chunk is not the length the span asked for, or `nil` when it is.
    ///
    /// This is what validates a span the client resumed itself, where the response header
    /// only describes the final leg. A short chunk appended into the partial would leave
    /// a file of the wrong length made of misaligned bytes, and nothing downstream but
    /// the SHA-256 would notice.
    private static func lengthMismatch(at location: URL, span: ModelDownloadChunkSpan) -> String? {
        guard let end = span.end else { return nil }
        let expected = end - span.start + 1
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: location.path),
              let actual = (attributes[.size] as? NSNumber)?.int64Value else {
            return "chunk-length-unreadable"
        }
        return actual == expected ? nil : "chunk-length-\(actual)-expected-\(expected)"
    }

    /// Turns a URLSession transport error into the vocabulary the model card speaks.
    private static func mapped(_ error: Error, path: String) -> Error {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorTimedOut else {
            return error
        }
        return ModelRepoDownloader.DownloadError.stalled(
            path: path,
            timeoutSeconds: Int(stallTimeout)
        )
    }

    fileprivate func drainBackgroundEventsIfNeeded() {
        guard let handler = backgroundCompletionHandler else { return }
        backgroundCompletionHandler = nil
        DispatchQueue.main.async { handler() }
    }
}

// MARK: - URLSession delegate

/// Callback contract this relies on, unchanged from the previous downloader:
/// - `didWriteData` fires repeatedly as bytes arrive;
/// - `didFinishDownloadingTo` fires on success, and the temp file at `location` is
///   deleted the moment the callback returns, so the move MUST happen inside it;
/// - `didCompleteWithError` fires exactly once per task, after `didFinishDownloadingTo`
///   on success, which makes it the single place the state machine may advance.
extension BackgroundModelDownloadService: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let tag = ModelDownloadTaskTag.decode(downloadTask.taskDescription),
              let run = run(for: tag) else { return }
        let key = DownloadTaskKey(session: sessionKind(of: session), identifier: downloadTask.taskIdentifier)
        // Only the task that holds the chunk now speaks for it. A task the watchdog or a
        // hand-off has just cancelled can still deliver a last `didWriteData` (#707), and
        // its byte count must not overwrite the one of the task that replaced it.
        guard run.tasks[tag.chunkIndex]?.key == key else { return }
        run.liveChunkBytes[tag.chunkIndex] = totalBytesWritten
        // Every byte is proof the transfer is alive, whatever `NWPathMonitor` believes —
        // and, for the silent-task watchdog, proof this task is not the wedge (#707).
        let now = Date()
        run.lastProgressDate = now
        run.tasks[tag.chunkIndex]?.lastByteAt = now
        run.emitProgress(force: false)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let key = DownloadTaskKey(session: sessionKind(of: session), identifier: downloadTask.taskIdentifier)
        guard let tag = ModelDownloadTaskTag.decode(downloadTask.taskDescription),
              let run = run(for: tag),
              let response = downloadTask.response as? HTTPURLResponse,
              let span = run.manifest.span(ofChunk: tag.chunkIndex, inFileAt: tag.fileIndex) else {
            return
        }

        let path = run.pathOfFile(tag.fileIndex)
        let status = response.statusCode
        if status == 429 || status == 503 {
            record(
                outcome: .failed(ModelRepoDownloader.DownloadError.rateLimited(statusCode: status)),
                for: key
            )
            return
        }

        let decision = HTTPRangeResume.decide(
            statusCode: status,
            contentRangeHeader: response.value(forHTTPHeaderField: "Content-Range"),
            expectedStart: span.start,
            expectedEnd: span.end,
            expectedTotal: run.manifest.files[tag.fileIndex].size > 0
                ? run.manifest.files[tag.fileIndex].size
                : nil
        )

        switch decision {
        case .appendFrom, .appendResumedSpan:
            // The header cannot vouch for a span the client resumed itself, and it is
            // cheap to stop trusting it here for every chunk: a chunk is a known number
            // of bytes, and a short one is the only shape that could corrupt the file.
            if case .appendResumedSpan(let legStart) = decision {
                PersistentLog.log(.diagnosticProbe(
                    component: "ModelDownload",
                    instanceID: run.manifest.modelIdentifier,
                    action: "clientResumedChunk",
                    details: "chunk=\(tag.chunkIndex) asked=\(span.start) lastLeg=\(legStart)"
                ))
            }
            if let reason = Self.lengthMismatch(at: location, span: span) {
                PersistentLog.log(.modelDownloadRangeRejected(
                    name: run.manifest.modelIdentifier,
                    path: path,
                    statusCode: status,
                    reason: reason
                ))
                record(
                    outcome: .failed(
                        ModelRepoDownloader.DownloadError.rangeRefused(path: path, reason: reason)
                    ),
                    for: key
                )
                return
            }
            do {
                try ManifestStore.store(
                    chunkAt: location,
                    model: run.manifest.modelIdentifier,
                    fileIndex: tag.fileIndex,
                    chunkIndex: tag.chunkIndex
                )
            } catch {
                record(outcome: .failed(error), for: key)
                return
            }
            let validator = response.value(forHTTPHeaderField: "ETag")
            PersistentLog.log(.modelDownloadChunk(
                name: run.manifest.modelIdentifier,
                path: path,
                index: tag.chunkIndex,
                count: run.manifest.chunkCount(ofFileAt: tag.fileIndex),
                statusCode: status,
                host: response.url?.host ?? "unknown",
                validated: validator != nil
            ))
            record(outcome: .stored(validator: validator), for: key)

        case .restartFromZero(let reason):
            PersistentLog.log(.modelDownloadRangeRejected(
                name: run.manifest.modelIdentifier,
                path: path,
                statusCode: status,
                reason: reason
            ))
            record(outcome: .restartFile(reason: reason), for: key)

        case .reject(let reason):
            PersistentLog.log(.modelDownloadRangeRejected(
                name: run.manifest.modelIdentifier,
                path: path,
                statusCode: status,
                reason: reason
            ))
            // NOT `httpError`: 206 is a success, and reporting "erreur 206" to a user
            // was both wrong and unactionable. A refused range is our own guard talking,
            // and it is retryable — the bytes on disk are untouched.
            record(
                outcome: .failed(
                    ModelRepoDownloader.DownloadError.rangeRefused(path: path, reason: reason)
                ),
                for: key
            )
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let key = DownloadTaskKey(session: sessionKind(of: session), identifier: task.taskIdentifier)
        let outcome = takeOutcome(for: key)
        guard let tag = ModelDownloadTaskTag.decode(task.taskDescription),
              let run = run(for: tag) else {
            return
        }
        // A task this run cancelled itself (a file restart, a discarded download, a move to
        // or from the foreground session) is not the network failing, and must not spend
        // one of the file's three attempts.
        guard !run.isAbandoned(key) else { return }
        handleChunkCompletion(tag: tag, run: run, outcome: outcome, transportError: error)
    }

    /// Only ever called for the background session: a default session has no events to
    /// deliver to a relaunched app.
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        drainBackgroundEventsIfNeeded()
    }
}

// MARK: - Who cancelled a task

/// The code paths that cancel a model download task, as they appear in the
/// `caller=` field of `modelDownloadTaskCancelled` (#690).
private enum TaskCancelCaller: String {
    /// `restore()`: the session handed back a task no manifest claims.
    case restoreUnclaimed
    /// `restore()`: the task fetches a file its model's manifest has moved past.
    case restoreStaleFile
    /// `discardStaging`: the user deleted the partial download or the model.
    case discardStaging
    /// `adopt`: a fresh listing describes a different download, which replaces the run.
    case listingReplaced
    /// `reportOfflineStalls`: no network path while the user watched (#492).
    case offlineStall
    /// A refused range that restarts the file from byte zero.
    case fileRestart
    /// The silent-task watchdog moving a chunk off the background session (#690, #707).
    /// Was `adoptedWatchdog` while it watched adopted tasks only.
    case silentTaskWatchdog
    /// The app entered the background: a chunk on the foreground session goes back to the
    /// background one (#707).
    case backgroundHandOff
}

// MARK: - Which task holds which chunk

/// A task, as both sessions' callbacks can name it.
///
/// WHY NOT `taskIdentifier` ALONE (#707). An identifier is unique within one session, and
/// the foreground session numbers its tasks independently of the background one: both
/// can hold a task 3 at the same moment. Every map that used to be keyed by the identifier
/// — outcomes, abandoned tasks — would then confuse a cancelled background task with the
/// live foreground task that replaced it, and drop a good chunk or fail a run over our own
/// cancel.
private struct DownloadTaskKey: Hashable {
    let session: DownloadSessionKind
    let identifier: Int
}

/// The one task that holds a chunk, with what the watchdog and the hand-off need to know
/// about it.
private struct ChunkTask {
    let task: URLSessionDownloadTask
    /// The session it runs on, decided once when it was created or adopted.
    let session: DownloadSessionKind
    /// Logged on the watchdog's line; decides nothing.
    let origin: DownloadTaskOrigin
    /// When it last delivered a byte in this process, or when it was created or adopted,
    /// before the first. The silent-task watchdog's clock.
    var lastByteAt: Date

    var key: DownloadTaskKey {
        DownloadTaskKey(session: session, identifier: task.taskIdentifier)
    }
}

// MARK: - Background time for the hand-off

/// A `beginBackgroundTask` assertion that can be ended from any thread, once.
///
/// `@unchecked Sendable` is honest: the one mutable member is behind a lock, and both
/// `UIApplication` calls are documented as safe off the main thread.
private final class BackgroundTimeAssertion: @unchecked Sendable {
    private let lock = NSLock()
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        let identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            // Out of time: release it, or iOS kills the process. The hand-off still runs
            // when the queue gets to it, in the next background wake or the next launch.
            self?.end()
        }
        lock.lock()
        self.identifier = identifier
        lock.unlock()
    }

    func end() {
        lock.lock()
        let identifier = identifier
        self.identifier = .invalid
        lock.unlock()
        guard identifier != .invalid else { return }
        // The cancel lines the hand-off just logged are on disk before the process may be
        // suspended, like `ColdStartResolution` does before releasing its own assertion.
        PersistentLog.flush()
        UIApplication.shared.endBackgroundTask(identifier)
    }
}

// MARK: - One model's transfer

/// Live state of one model's download. Touched only on the service's delegate queue.
private final class DownloadRun {
    var manifest: ModelDownloadManifest
    let destination: URL

    /// Chunk indices of the current file that have a task running.
    var inFlight: Set<Int> = []
    /// The one live task per in-flight chunk, on whichever session holds it, so a restart
    /// can stop them and the watchdog and the hand-off can tell where each one runs.
    /// One entry per chunk is what keeps two sessions from both holding the same chunk.
    var tasks: [Int: ChunkTask] = [:]
    /// Tasks this run cancelled itself, whose completion must not count as a failure —
    /// including a stale-file task `restore()` cancelled on its behalf (#701). Keyed by
    /// session as well as identifier (#707): see `DownloadTaskKey`.
    var abandonedTasks: Set<DownloadTaskKey> = []
    /// Bytes received so far per in-flight chunk, for the percentage between savepoints.
    var liveChunkBytes: [Int: Int64] = [:]
    /// Consecutive failures on the current file. Reset by any chunk that lands.
    var attempts = 0
    /// When a byte last arrived, for the offline stall predicate (issue #492). Set at
    /// creation so a run that has not received anything yet still gets a grace period.
    var lastProgressDate = Date()
    var isFinished = false

    var continuations: [CheckedContinuation<Void, Error>] = []
    var observers: [@Sendable (ModelRepoDownloader.Progress) -> Void] = []

    private var startedFiles: Set<Int> = []
    private var lastReportedFraction: Double = -1
    private var lastReportDate = Date.distantPast

    init(manifest: ModelDownloadManifest, destination: URL) {
        self.manifest = manifest
        self.destination = destination
    }

    func pathOfFile(_ index: Int) -> String {
        manifest.files.indices.contains(index) ? manifest.files[index].path : "?"
    }

    /// Whether this is the first chunk this run has asked for on the given file.
    /// Answers true exactly once per file, which is what makes the resume line one per
    /// file rather than one per chunk.
    func markFileStarted(_ index: Int) -> Bool {
        startedFiles.insert(index).inserted
    }

    /// Stops every transfer of this run and remembers which tasks were stopped.
    ///
    /// WHY the identifiers are remembered: a cancelled task still delivers
    /// `didCompleteWithError`, with a cancellation error, some time after this returns.
    /// Without this set the state machine would read that as the network failing and
    /// spend one of the file's three attempts on a task it killed itself.
    func cancelAllTasks(caller: TaskCancelCaller) {
        for chunkIndex in tasks.keys.sorted() {
            cancel(chunk: chunkIndex, caller: caller)
        }
        tasks.removeAll()
        inFlight.removeAll()
        liveChunkBytes.removeAll()
    }

    /// Stops one chunk's transfer, remembers the task as abandoned for the same reason as
    /// `cancelAllTasks`, and frees the chunk so `pump` can ask for it again.
    ///
    /// The one place a run cancels a task, and it says who asked (#690): a `-999` in a
    /// device log with no `modelDownloadTaskCancelled` line before it was not ours.
    func cancel(chunk chunkIndex: Int, caller: TaskCancelCaller) {
        guard let entry = tasks.removeValue(forKey: chunkIndex) else { return }
        inFlight.remove(chunkIndex)
        liveChunkBytes.removeValue(forKey: chunkIndex)
        abandonedTasks.insert(entry.key)
        PersistentLog.log(.modelDownloadTaskCancelled(
            name: manifest.modelIdentifier,
            path: pathOfFile(fileIndex(of: entry.task) ?? -1),
            chunk: chunkIndex,
            caller: caller.rawValue
        ))
        entry.task.cancel()
    }

    /// The file a task fetches, read from its tag.
    func fileIndex(of task: URLSessionTask) -> Int? {
        ModelDownloadTaskTag.decode(task.taskDescription)?.fileIndex
    }

    /// Whether this completion belongs to a task this run cancelled on purpose.
    func isAbandoned(_ key: DownloadTaskKey) -> Bool {
        abandonedTasks.remove(key) != nil
    }

    /// Emits aggregate progress, throttled the same way the previous downloader was:
    /// `didWriteData` fires hundreds of times a second and each tick would otherwise
    /// hammer a `@Published` property on the main actor.
    func emitProgress(force: Bool) {
        guard !observers.isEmpty else { return }
        let live = liveChunkBytes.values.reduce(0, +)
        let progress = ModelRepoDownloader.Progress(
            bytesDownloaded: min(manifest.receivedBytes + live, manifest.totalBytes),
            totalBytes: manifest.totalBytes,
            completedFiles: manifest.completedFileCount,
            totalFiles: manifest.files.count
        )
        let now = Date()
        let shouldEmit = force
            || progress.fraction - lastReportedFraction >= 0.005
            || now.timeIntervalSince(lastReportDate) >= 0.3
        guard shouldEmit else { return }
        lastReportedFraction = progress.fraction
        lastReportDate = now
        for observer in observers {
            observer(progress)
        }
    }
}
