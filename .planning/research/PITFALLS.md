# Pitfalls Research

**Domain:** iOS keyboard dictation app — v1.2 Beta Ready (logging, Audio Bridge, CoreML precompilation, model download UX, animation fixes, TestFlight deployment)
**Researched:** 2026-03-11
**Confidence:** HIGH (based on project history, Apple documentation, WhisperKit issues, and v1.0/v1.1 lessons learned)

**Context:** Dictus is a shipped two-process iOS keyboard dictation app (keyboard extension + main app). v1.0 and v1.1 are complete. The keyboard extension has a 50MB memory limit. AVAudioSession management has been a recurring source of bugs. Darwin notifications handle cross-process IPC. Previous attempts at auto-return used private APIs that crashed or were rejected. The existing `PersistentLog` writes to App Group with no concurrency protection and no privacy redaction.

---

## Critical Pitfalls

### Pitfall 1: PersistentLog Concurrent Write Corruption from Two Processes

**What goes wrong:**
The current `PersistentLog.log()` dispatches to `DispatchQueue.global(qos: .utility)` which creates a new queue per process. When the keyboard extension and DictusApp both call `PersistentLog.log()` simultaneously (which happens during every dictation flow), two processes open `FileHandle(forWritingTo:)` on the same file, both `seekToEndOfFile()`, and both write. Result: interleaved bytes, truncated lines, or a corrupted file. The `trimIfNeeded()` method is even worse — it reads the entire file, then writes a trimmed version with `write(to:atomically:true)`, which creates a temp file and renames. If the other process has the file open for writing, the rename can fail silently or the other process writes to the now-deleted old file.

This is not theoretical. The keyboard extension and app process run concurrently during every dictation session. The more verbose the logging (which is the whole point of v1.2 production logging), the more frequent the collisions.

**Why it happens:**
`DispatchQueue.global` is process-local. A serial queue in the keyboard extension provides no serialization with a serial queue in DictusApp. Cross-process file coordination requires either `NSFileCoordinator` or POSIX file locks (`flock`/`fcntl`). The current implementation uses neither.

**How to avoid:**
1. Use `NSFileCoordinator` with `NSFilePresenter` for all log file writes. Both processes register as presenters, and writes are coordinated through the system
2. Simpler alternative: use POSIX `flock(fd, LOCK_EX)` before writing and `flock(fd, LOCK_UN)` after. This is lighter weight than NSFileCoordinator
3. Simplest alternative: each process writes to its OWN log file (`dictus_app.log`, `dictus_keyboard.log`). The log viewer in Settings merges and sorts by timestamp. This eliminates cross-process contention entirely and is the recommended approach
4. Replace `FileHandle.seekToEndOfFile()` with `O_APPEND` mode opens: `open(path, O_WRONLY | O_APPEND | O_CREAT)`. The OS guarantees atomic append for writes under `PIPE_BUF` (4096 bytes on iOS), even across processes

**Warning signs:**
Log file shows garbled lines, missing entries, or entries from one process disappearing after the other process trims. Log file size grows unexpectedly or drops to zero.

**Phase to address:**
Logging phase (first phase of v1.2) — this is the foundation. Must be fixed before adding more logging.

---

### Pitfall 2: Logging Dictated Text Violates GDPR and Triggers App Store Rejection

**What goes wrong:**
Production logging naturally wants to capture "what happened" — including the transcription result for debugging accuracy issues. But logging user-dictated text means storing user speech content on disk. This violates:
- **GDPR Article 5(1)(c)** — data minimization: you are storing personal data (what users said) that is not necessary for app functionality
- **App Store Guideline 5.1.1** — keyboard extensions that store keystrokes or user input face rejection. Apple's review specifically checks keyboard extensions for data exfiltration
- **Apple's OSLog privacy model** — by default, `os.log` redacts dynamic string content in production builds (shows `<private>`). But `PersistentLog` writes to a plain text file with ZERO redaction. Every `PersistentLog.log("Transcription: \(result)")` call persists user speech in cleartext

The existing `DictationCoordinator.swift` has ~20 log/print calls. If any log the transcription result, model input, or audio buffer content, this is a ship-blocker.

**Why it happens:**
During development, logging everything helps debugging. The transition from debug logging to production logging requires an explicit privacy audit, which is easy to skip under time pressure.

**How to avoid:**
1. Use Apple's `os.Logger` with privacy annotations as the primary logging API: `logger.info("Transcription completed: \(result, privacy: .private)")`. In production, this redacts automatically. In debug (attached to Xcode), it shows the value
2. For `PersistentLog` (file-based), define strict categories: NEVER log user input text, audio content, or transcription results to file. Only log events, durations, error codes, and model names
3. Create a `LogSanitizer` that strips or hashes any string longer than 50 characters before writing to persistent logs. Transcriptions are always longer than 50 characters; model names and error codes are shorter
4. Pre-submission audit: `grep -r "lastTranscription\|transcriptionResult\|documentContext" *.swift` in all files that call any log function. Remove or redact every match
5. Add a PrivacyInfo.xcprivacy entry for `NSPrivacyCollectedDataTypes` if ANY user data touches disk, even temporarily

**Warning signs:**
App Store review rejection citing Guideline 5.1.1. GDPR complaint from EU user who exports their data. Privacy-conscious beta tester reads the log file from Settings and sees their dictated text.

**Phase to address:**
Logging phase — define the privacy policy for logs BEFORE writing any new logging code. This is a design decision, not an afterthought.

---

### Pitfall 3: Audio Bridge Private API Usage Causes App Store Rejection

**What goes wrong:**
The "Audio Bridge" pattern for cold start auto-return needs the app to programmatically return the user to the previous app after launching. Previous v1.0/v1.1 attempts used:
- `UIApplication.shared.perform(#selector(NSXPCConnection.suspend))` — sent user to Home Screen, not previous app
- `LSApplicationWorkspace` — private API, crashes on iOS 18+
- `_hostBundleID` via KVC on `NSExtensionContext` — crashes with keypath exception

Apple's static analysis tool (`otool` / App Thinning) detects private API usage in binaries even if called via `#selector` or `NSStringFromSelector`. Rejection message: "Your app contains or references non-public APIs: [API name]". This blocks TestFlight external distribution AND App Store submission.

**Why it happens:**
There is genuinely no public API to navigate the user from App A back to App B. Apple considers this a security boundary. Competitors like Wispr Flow likely use one of: (a) a technique that Apple has whitelisted for their specific app, (b) an undocumented-but-not-private API that Apple tolerates, or (c) a creative use of legitimate APIs (NSUserActivity, Handoff, UIScene lifecycle) that achieves the same effect.

**How to avoid:**
1. Do NOT use any API that starts with underscore (`_`), belongs to `LSApplicationWorkspace`, or uses `performSelector` on undocumented selectors
2. Research the "Audio Bridge" approach via legitimate APIs only:
   - **Option A**: App opens, immediately calls `UIApplication.shared.open(URL(string: "shortcuts://")!)` to open a Shortcuts action that returns to the previous app. Requires user to install a shortcut — poor UX but public API
   - **Option B**: Use `BGTaskScheduler` to schedule a background task, then immediately background the app via no user interaction. The system handles returning to the frontmost app. Risk: iOS may not foreground the previous app
   - **Option C**: Use Picture-in-Picture (PiP) mode with a tiny transparent video. PiP allows the app to "appear" backgrounded while maintaining audio. The previous app returns to foreground naturally. Requires `AVPictureInPictureController` and a video asset
   - **Option D**: Accept the limitation. Optimize cold start to be <1.5 seconds total (launch + WhisperKit load + recording start). Show a "Return to keyboard" instruction. User taps status bar "< Back"
3. Before implementing ANY auto-return technique, test it through TestFlight external review. Apple's review catches private APIs that local testing does not

**Warning signs:**
Binary scan warnings from `xcodebuild -exportArchive`. App Store Connect "Invalid Binary" email within 24 hours of upload. Rejection citing "non-public API usage."

**Phase to address:**
Audio Bridge phase — spike research first (1-2 days). Choose between Option C (PiP) or Option D (accept limitation + optimize speed). Do not spend more than 3 days on auto-return if no public API solution is found.

---

### Pitfall 4: CoreML Compilation of Large Turbo v3 Kills the App on Low-Memory Devices

**What goes wrong:**
CoreML model compilation (`.mlmodel` to `.mlmodelc` or ANE compilation at runtime) is extremely memory-intensive for large models. The WhisperKit Large Turbo v3 model (`openai_whisper-large-v3-v20240930_turbo`) triggers `ANECompilerService` which:
- Spawns a helper process that allocates 1-3GB of memory during compilation
- Takes 30-120 seconds depending on device (longer on A14/A15 chips)
- Can fail entirely on devices with 4GB RAM (iPhone 12, 13 mini, SE 3rd gen) with error: `MILCompileForANE error: failed to compile ANE model`
- Blocks the ANE for ALL other apps during compilation — camera, Siri, and other ML features become unresponsive

If this happens during onboarding (user just downloaded the model and expects to use it immediately), the app appears frozen, the system may kill it for exceeding memory limits, or the user force-quits. The model is then in a partially compiled state, and subsequent launches may repeatedly fail.

**Why it happens:**
`ANECompilerService` compiles the full model graph for the Neural Engine on first load. This is a one-time cost per model per device, but it is enormous for large models. Apple's system does not expose progress, cancellation, or memory budget controls for this compilation. WhisperKit's `prewarmModels()` triggers this compilation but cannot control its resource usage.

**How to avoid:**
1. Gate Large Turbo v3 behind a device capability check: only offer it on devices with >= 6GB RAM (`ProcessInfo.processInfo.physicalMemory >= 6_000_000_000`). On 4GB devices, cap at the `small` or `base` model
2. Run CoreML compilation on a background thread with `Task.detached(priority: .utility)` — never on MainActor. Show a non-dismissable progress modal: "Preparing model for your device... This may take 1-2 minutes"
3. Use `beginBackgroundTask(withName:)` to request background time if the user leaves the app during compilation. But note: background tasks get only ~30 seconds, which is insufficient for large model compilation. Warn users: "Please keep Dictus open while the model prepares"
4. Implement retry-with-cleanup: if compilation fails, delete the model's `.mlmodelc` directory and re-download. Corrupted partial compilations cause permanent failures otherwise (WhisperKit issue #171)
5. Pre-compile during onboarding, NOT on first dictation. The onboarding flow should: download model -> compile model -> verify model loads -> proceed. Never let the user reach the keyboard with an uncompiled model
6. For the v1.2 "CoreML pre-compilation during onboarding" feature: add a `ModelCompilationManager` that tracks compilation state per model in App Group UserDefaults (`modelName_compiled: true/false`). Check this flag before every `WhisperKit.init()` call

**Warning signs:**
App hangs for 30+ seconds with no UI feedback after model download. Xcode memory gauge spikes to 2GB+. Device becomes hot during model preparation. Crash reports with jetsam reason code `REASON_MEMORY_PRESSURE`.

**Phase to address:**
Model download UX phase and CoreML precompilation phase — these MUST be implemented together. Never ship model download without compilation progress UI.

---

### Pitfall 5: TestFlight Submission Fails Due to Missing Privacy Manifest or Mismatched Entitlements

**What goes wrong:**
Since May 2024, Apple requires `PrivacyInfo.xcprivacy` in ALL apps submitted to App Store Connect (including TestFlight). Keyboard extensions that use certain APIs must declare them. Dictus uses:
- **UserDefaults** (App Group suite) — requires `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (App Group access)
- **File timestamp APIs** — if logging writes check file modification dates
- **Active keyboard APIs** — if `needsInputModeSwitchKey` or related APIs are used
- **System boot time** — if any timing code uses `ProcessInfo.processInfo.systemUptime`

Missing ANY of these declarations causes App Store Connect to reject the binary with "ITMS-91053: Missing API declaration." This blocks both TestFlight internal and external distribution.

Additionally, keyboard extensions require matching entitlements between the main app and extension:
- Both must list the same App Group ID (`group.com.pivi.dictus`)
- The extension must have `com.apple.security.application-groups` entitlement
- The provisioning profiles for BOTH targets must include the App Group capability
- If signing migrates to a new developer account (as planned in v1.2), ALL provisioning profiles must be regenerated with the new team ID

**Why it happens:**
Privacy manifest is a relatively new requirement. Developers who have only tested locally or on TestFlight internal (which previously did not enforce this) get blocked when submitting for external testing. Entitlement mismatches are common when changing developer accounts because the App Group ID is tied to the team ID prefix.

**How to avoid:**
1. Create `PrivacyInfo.xcprivacy` for BOTH targets (DictusApp AND DictusKeyboard) BEFORE attempting any TestFlight upload
2. Required declarations for Dictus:
   - `NSPrivacyAccessedAPICategoryUserDefaults` — reason `CA92.1` (app group container)
   - `NSPrivacyAccessedAPICategoryFileTimestamp` — reason `C617.1` (if log file timestamps are used)
   - `NSPrivacyAccessedAPICategoryDiskSpace` — only if checking available disk space for model downloads
3. When migrating to a new developer account: the App Group ID changes from `group.com.pivi.dictus` (old team) to potentially a different prefix. This breaks ALL cross-process communication. Solution: keep the same App Group ID string but ensure both new provisioning profiles include it
4. Test the full upload pipeline early: Archive -> Upload to App Store Connect -> Check processing status. Do this BEFORE writing any v1.2 code, with the current v1.1 codebase, to validate the signing/manifest/entitlement chain
5. TestFlight external distribution requires App Review. Budget 1-3 days for the first review. Common rejection reasons for keyboard extensions: missing privacy policy URL, Full Access justification not in App Review notes, missing `NSMicrophoneUsageDescription` explanation

**Warning signs:**
"ITMS-91053" error during upload. "Invalid Binary" email from App Store Connect. "Profile doesn't include entitlement" error during archive export.

**Phase to address:**
TestFlight deployment phase — but validate the upload pipeline in the FIRST phase as a smoke test. Do not wait until the end to discover signing/manifest issues.

---

## Moderate Pitfalls

### Pitfall 6: AVAudioSession Conflicts Between App and Keyboard During Audio Bridge

**What goes wrong:**
The Audio Bridge pattern requires both the keyboard extension and DictusApp to interact with the audio system. The keyboard detects mic tap and signals the app. The app activates the audio session for recording. But:
- If the keyboard extension has ANY active audio session (even inactive/deactivated), it can interfere with the app's session activation
- WhisperKit internally calls `AVAudioSession.sharedInstance().setCategory(.record)` and `setActive(true)` inside `startRecordingLive()`. This overrides any configuration you set beforehand
- The `setAllowHapticsAndSystemSoundsDuringRecording(true)` must be called AFTER `startRecordingLive()`, not before (learned in v1.0/v1.1)
- `setActive(true)` fails when called from background with error `2003329396` (NSOSStatusErrorDomain). The app MUST be in foreground or have an already-active session

On cold start, the Audio Bridge flow is: keyboard taps mic -> URL scheme opens app -> app is in foreground -> configures audio -> starts recording -> needs to background itself for auto-return. The moment the app backgrounds, if the audio session was not already active and recording, it cannot be reactivated.

**Why it happens:**
AVAudioSession is per-process but the system manages a single audio route. Two processes (keyboard + app) competing for the audio route creates conflicts that iOS resolves unpredictably.

**How to avoid:**
1. The keyboard extension should NEVER configure or activate its own AVAudioSession. Only the DictusApp process should own the audio session
2. On cold start URL launch: `configureAudioSession()` synchronously in `application(_:open:options:)` BEFORE returning. The app is guaranteed to be in foreground at this point
3. Keep using `collectSamples()` (not `stopRecording()`) between recordings so the audio session stays active — this was a hard-won v1.0 lesson
4. If implementing PiP-based auto-return: the audio session must be category `.playAndRecord` (not just `.record`) for PiP to work. Ensure WhisperKit's internal session configuration is compatible

**Warning signs:**
`AUIOClient_StartIO failed` errors. Silent recordings (audio engine running but no samples captured). Haptics stop working after dictation (audio session override).

**Phase to address:**
Audio Bridge phase — audio session management must be designed alongside the auto-return mechanism, not separately.

---

### Pitfall 7: SwiftUI Animation @State Not Resetting in Persistent Keyboard Views

**What goes wrong:**
The keyboard extension's root view persists for the lifetime of the extension process. Unlike normal SwiftUI views that are created and destroyed with navigation, `KeyboardRootView` stays alive across app switches, keyboard dismissals, and reappearances. This causes:
- `@State` properties that track animation state (e.g., `isRecording`, `showTranscription`, `waveformPhase`) retain their values across keyboard invocations. If the user dismisses the keyboard while recording, `isRecording` is still `true` when the keyboard reappears
- `withAnimation` blocks that were mid-flight when the keyboard was dismissed leave the view in an intermediate state. SwiftUI does not resume or cancel animations when the view reappears
- `.onAppear` does NOT fire when the keyboard reappears (the view was never removed from the hierarchy). Only `viewWillAppear` on the `UIInputViewController` fires reliably

The v1.2 "intermittent recording/transcription animation bug" is almost certainly caused by stale `@State` in the persistent keyboard view.

**Why it happens:**
SwiftUI's lifecycle assumes views are ephemeral. Keyboard extensions violate this assumption. The `UIInputViewController` keeps its view hierarchy alive, so `@State`, `@StateObject`, and `@ObservedObject` all persist.

**How to avoid:**
1. Use `NotificationCenter` to bridge `viewWillAppear` from the `UIInputViewController` to SwiftUI views. Post a custom notification in `viewWillAppear`, observe it in SwiftUI views, and reset animation state
2. For recording state specifically: always re-read the ground truth from App Group UserDefaults in `viewWillAppear`, not from `@State`. If UserDefaults says `dictationStatus == .idle` but `@State isRecording == true`, force reset
3. Never use `.onAppear` for state initialization in keyboard extension views. It fires once when the extension loads and never again
4. For async state updates from Darwin notifications: always dispatch to `MainActor` and use `withAnimation(.none)` to reset state, then apply the intended animation. This prevents "animation from previous state" artifacts
5. The existing `NotificationCenter.viewWillAppear` bridge pattern (used for mode refresh in v1.1) should be extended to cover ALL animation-related state

**Warning signs:**
Recording overlay visible when keyboard appears but no recording is active. Waveform animation frozen mid-frame. "Transcription ready" message stuck from a previous session. Animation plays in reverse direction.

**Phase to address:**
Animation fix phase — this is the root cause of the "intermittent recording/transcription animation bug." Fix the state management pattern before fixing individual animations.

---

### Pitfall 8: Model Download UX Blocks Main Thread During Progress Updates

**What goes wrong:**
Model downloads for WhisperKit can be 50-500MB. The download progress must be shown in a modal UI during onboarding. Common implementation mistakes:
- Updating `@Published var progress: Double` on every `URLSessionDownloadDelegate` callback. For large files, this fires hundreds of times per second, causing SwiftUI to re-render the progress view at an unsustainable rate
- Running `FileManager.moveItem` (to move the downloaded temp file to the App Group container) on the main thread. For a 500MB file, this can take 2-5 seconds and freezes the UI
- Not handling download interruption (user kills app mid-download). The partially downloaded file wastes disk space and the next attempt starts from zero
- Not checking available disk space before download. A 500MB model on a 16GB device with 1GB free will fail with a cryptic `NSURLErrorDomain` error

**Why it happens:**
URLSession delegates fire on a background queue by default, but updating SwiftUI `@Published` properties requires MainActor. Naive bridging (`DispatchQueue.main.async { self.progress = newValue }`) floods the main thread.

**How to avoid:**
1. Throttle progress updates to 10Hz maximum: only update the published property if at least 100ms have elapsed since the last update. Use a `Date` comparison, not a timer
2. Move file operations (`moveItem`, `removeItem`, `createDirectory`) to a background task. Show a "Preparing model..." step in the UI while this happens
3. Implement download resumption: use `URLSession.downloadTask(withResumeData:)` to resume interrupted downloads. Store resume data in App Group UserDefaults
4. Check disk space before download: `FileManager.default.attributesOfFileSystem(forPath:)[.systemFreeSize]`. Require 2x the model size as free space (download + extraction)
5. Show file size in the download UI so users know what to expect: "Downloading Small French model (150 MB)"

**Warning signs:**
UI jank during download (progress bar stutters). App killed by watchdog during file move. Downloads restart from zero after app switch.

**Phase to address:**
Model download UX phase — design the download flow with all error states before coding.

---

### Pitfall 9: ANE Resource Contention During CoreML Pre-compilation Breaks Other Apps

**What goes wrong:**
When `ANECompilerService` compiles a model for the Neural Engine, it monopolizes the ANE. During this time:
- The camera app's ML features (face detection, scene classification) become slow or unavailable
- Siri's on-device speech recognition degrades
- Other apps using CoreML experience increased latency
- The system may throttle or kill the compilation if the device overheats

If the user switches to the camera during model compilation, the camera may fail to detect faces or apply portrait mode. The user blames their phone, not Dictus.

**Why it happens:**
The ANE is a shared resource with no public priority or scheduling API. `ANECompilerService` runs at default priority and does not yield to other processes.

**How to avoid:**
1. Only trigger CoreML compilation when the user explicitly initiates it (model download or onboarding). Never compile in the background opportunistically
2. Show a clear modal that says "Preparing model... Other apps may be slower during this process. Please keep Dictus open." This sets expectations
3. Pause compilation if the app backgrounds: check `UIApplication.shared.applicationState` and defer if not `.active`. Resume when the app returns to foreground
4. Set `MLModelConfiguration.computeUnits = .cpuAndGPU` for compilation of the large model to avoid ANE entirely. The trade-off: inference will be slower without ANE, but compilation succeeds on all devices. Then offer an "Optimize for speed" option that triggers ANE compilation separately
5. On 4GB RAM devices (iPhone 12, 13 mini): skip ANE compilation for Large Turbo v3 entirely. Use CPU+GPU inference. The model works, just ~2x slower

**Warning signs:**
Device becomes very warm during onboarding. Other apps visibly lag. Compilation takes >2 minutes with no progress feedback.

**Phase to address:**
CoreML precompilation phase — must be designed with ANE awareness. Cannot be a simple "call prewarmModels() in the background."

---

## Minor Pitfalls

### Pitfall 10: ISO8601DateFormatter Allocation in Every Log Call

**What goes wrong:**
The current `PersistentLog.log()` creates a new `ISO8601DateFormatter()` on every call. `DateFormatter` allocation is expensive (~0.5ms per instance). At high logging frequency (10-50 calls per dictation session), this adds measurable overhead. In the keyboard extension where every millisecond of latency matters for key press responsiveness, this adds up.

**How to avoid:**
Use a static `ISO8601DateFormatter` instance. `DateFormatter` is thread-safe for formatting (reading) since iOS 7. Store as `private static let formatter = ISO8601DateFormatter()`.

**Phase to address:** Logging phase — trivial fix during logging system rewrite.

---

### Pitfall 11: beginBackgroundTask Not Ended Causes Watchdog Kill

**What goes wrong:**
If `beginBackgroundTask(withName:expirationHandler:)` is called to protect CoreML compilation or recording, but `endBackgroundTask()` is never called (e.g., the completion path throws an error and skips the cleanup), iOS kills the app after the expiration handler fires. The expiration handler itself must complete in <1 second or the app is killed immediately.

**How to avoid:**
Always use a `defer` block: `let taskID = UIApplication.shared.beginBackgroundTask { ... }; defer { UIApplication.shared.endBackgroundTask(taskID) }`. Never rely on normal control flow to call `endBackgroundTask`.

**Phase to address:** Audio Bridge phase — any background execution must use this pattern.

---

### Pitfall 12: App Group ID Change During Developer Account Migration

**What goes wrong:**
v1.2 includes "Migrate Xcode signing to professional developer account." The App Group ID (`group.com.pivi.dictus`) is embedded in both targets' entitlements. If the new developer account's provisioning profiles do not include this exact App Group ID, ALL cross-process communication breaks: Darwin notifications still work (they are system-level), but UserDefaults suite access and shared file container access fail silently. The keyboard extension can no longer read dictation status, transcription results, or model preferences.

**How to avoid:**
1. Register the SAME App Group ID (`group.com.pivi.dictus`) in the NEW developer account's portal before generating provisioning profiles
2. Test cross-process UserDefaults read/write on a real device with the new profiles BEFORE merging any v1.2 code
3. If the App Group ID must change: implement a migration that copies all data from the old container to the new one on first launch

**Warning signs:**
Keyboard shows "No model selected" after account migration. Dictation status stuck on "idle" even while app is recording. Transcription never reaches the keyboard.

**Phase to address:** TestFlight deployment phase — test this FIRST after account migration, before any other work.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Logging user text for debugging | Faster bug diagnosis for transcription issues | GDPR violation, App Store rejection, user trust damage | Never in production. Use redacted hashes only |
| Skipping file locking on logs | Simpler implementation, works in single-process testing | Log corruption in production when both processes write | Never — use per-process log files from day one |
| Hardcoding background task timeout (30s) | Quick implementation | iOS changes the timeout between versions. App killed without warning | Never — always use `UIApplication.shared.backgroundTimeRemaining` |
| Skipping Privacy Manifest | Saves 30 minutes of configuration | Blocks ALL TestFlight and App Store submissions | Never — required since May 2024 |
| Using `.cpuAndNeuralEngine` for all models | Best inference performance | Compilation fails on 4GB devices for large models | Only for small/base models. Gate large models behind RAM check |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| WhisperKit `prewarmModels()` | Calling on MainActor, blocking UI for 30-120s | Call from `Task.detached(priority: .utility)`. Show progress modal. Handle failure with model deletion + re-download |
| App Group UserDefaults from extension | Calling `.synchronize()` and assuming cross-process consistency | `.synchronize()` is deprecated and unreliable cross-process. Read on demand, never cache. Use Darwin notifications to signal "data ready" |
| TestFlight upload with keyboard extension | Uploading without testing entitlements match between app and extension | Archive, export, and inspect the `.ipa` entitlements with `codesign -d --entitlements -` before uploading |
| CoreML model compilation | Assuming compilation is fast because model download was fast | Compilation takes 10-120x longer than download. Show a separate "Preparing" step with its own progress indicator |
| AVAudioSession from background | Calling `setActive(true)` from background state | Only activate from foreground. Use `didBecomeActive` (not `willEnterForeground`) as the trigger |
| Developer account migration | Assuming App Group survives team ID change | Register same App Group ID in new account. Test UserDefaults cross-process access on device before shipping |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Progress updates flooding MainActor during download | UI stutters, dropped frames, watchdog kill | Throttle to 10Hz with Date comparison | Downloads > 100MB |
| DateFormatter allocation per log line | Keystroke latency increases | Static formatter instance | > 20 log calls per second |
| CoreML compilation on main thread | App appears frozen, force-quit by user | `Task.detached(priority: .utility)` | Any model larger than "base" |
| Unthrottled Darwin notification posting | System drops notifications, IPC becomes unreliable | Minimum 50ms between posts | > 20 notifications per second |
| PersistentLog trimIfNeeded on every write | File I/O blocks logging queue, log entries delayed | Trim only when line count exceeds 2x max (trim from 400 to 200, not from 201 to 200) | > 50 log entries per session |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Logging transcription text to PersistentLog | User speech stored in cleartext in App Group container. Accessible by any debugger or file browser | Never log user content. Log event names and durations only. Use OSLog `.private` for development |
| Storing audio buffer in App Group for cross-process transfer | Raw audio of user speech persisted on disk | Transfer audio via shared memory or immediately delete after transcription. Never persist audio files |
| Logging model download URLs with auth tokens | API keys exposed in log files | Strip query parameters from URLs before logging |
| Privacy manifest omitting UserDefaults declaration | App Store Connect rejects binary | Declare all required-reason APIs in PrivacyInfo.xcprivacy for both targets |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| CoreML compilation with no progress indicator | User thinks app froze, force-quits, model is corrupted | Non-dismissable modal with progress bar and time estimate |
| Model download fails silently on low disk space | User waits, nothing happens, no error message | Check disk space before download, show clear error: "Need 300MB free space" |
| Auto-return fails, user stranded in DictusApp | User confused about how to get back to keyboard, abandons flow | Show prominent "Tap < Back to return to your keyboard" instruction with arrow pointing to status bar |
| Recording animation stuck from previous session | User sees recording indicator but nothing is recording, loses trust | Reset all animation state in `viewWillAppear`, re-read ground truth from UserDefaults |
| Large model offered on 4GB device, compilation fails | User downloads 500MB model, waits 2 minutes, gets error, wasted data | Filter model list by device RAM. Show "Recommended" tag on models that work well on their device |

## "Looks Done But Isn't" Checklist

- [ ] **Logging system:** Concurrent writes from two processes tested — verify with simultaneous logging from keyboard and app on a real device
- [ ] **Logging privacy:** No user text in log files — grep for `lastTranscription`, `result`, `documentContext` in all log calls
- [ ] **Privacy Manifest:** PrivacyInfo.xcprivacy exists in BOTH DictusApp AND DictusKeyboard targets — verify both are embedded in the archive
- [ ] **TestFlight upload:** Entitlements match between app and extension — run `codesign -d --entitlements -` on both binaries in the exported .ipa
- [ ] **CoreML compilation:** Tested on a 4GB RAM device (iPhone 12/13 mini) — verify large model compilation does not crash
- [ ] **Model download:** Tested with network interruption mid-download — verify resume works or clean restart happens (no corrupted partial files)
- [ ] **Audio Bridge:** Tested cold start flow on a device where app was force-quit — verify recording starts successfully within 3 seconds
- [ ] **Animation state:** Tested keyboard dismiss during active recording, then keyboard reappear — verify no stale animation state
- [ ] **Developer account migration:** Cross-process UserDefaults read/write tested on device with new provisioning profiles
- [ ] **Background task:** Every `beginBackgroundTask` has a matching `endBackgroundTask` in ALL code paths including error paths

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Log file corruption from concurrent writes | LOW | Delete log file, implement per-process files, re-deploy |
| User text logged to file in production | HIGH | Issue privacy notice to affected users, delete log files via app update, update privacy policy |
| App Store rejection for private API | MEDIUM | Remove offending code, re-archive, re-submit. 1-3 day turnaround |
| CoreML compilation fails on user device | MEDIUM | Add fallback to CPU+GPU compute units. Offer smaller model. Delete corrupted .mlmodelc |
| Entitlement mismatch after account migration | MEDIUM | Re-generate provisioning profiles with correct App Group, re-archive, re-upload |
| Privacy Manifest missing | LOW | Add PrivacyInfo.xcprivacy, re-archive, re-upload. 30-minute fix |
| Stale animation state | LOW | Implement viewWillAppear bridge, reset all @State on keyboard appearance |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Log concurrent write corruption | Logging (Phase 1) | Simultaneous log writes from both processes produce valid interleaved output |
| Log privacy violation | Logging (Phase 1) | `grep` audit finds zero user-content strings in log calls |
| Private API rejection | Audio Bridge (Phase 2) | TestFlight external review passes without API rejection |
| CoreML compilation crash | CoreML + Model UX (Phase 3) | Large Turbo v3 compiles successfully on iPhone 12 (4GB) or gracefully falls back |
| Privacy Manifest missing | TestFlight (Phase 4) | App Store Connect accepts the binary without ITMS-91053 errors |
| AVAudioSession conflicts | Audio Bridge (Phase 2) | Cold start recording works within 3 seconds on force-quit device |
| Stale animation @State | Animation fix (Phase 1-2) | Keyboard dismiss during recording, re-appear shows clean idle state |
| Model download UX | Model UX (Phase 3) | Download interrupted and resumed successfully. Progress UI smooth at 60fps |
| ANE contention | CoreML (Phase 3) | Camera app works normally during model compilation on test device |
| Entitlement mismatch | TestFlight (Phase 4) | Cross-process UserDefaults work on device with new developer account profiles |
| Background task not ended | Audio Bridge (Phase 2) | No watchdog kills in 24-hour soak test with repeated dictation cycles |
| App Group ID migration | TestFlight (Phase 4) | Keyboard reads model preference set by app after account migration |

## Sources

- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) — HIGH confidence
- [Apple: Adding a privacy manifest to your app or third-party SDK](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk) — HIGH confidence
- [Apple: OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy) — HIGH confidence
- [Apple: Extending your app's background execution time](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time) — HIGH confidence
- [Apple: App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — HIGH confidence
- [Apple: App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — HIGH confidence
- [WhisperKit issue #171: Error calling prewarmModels()](https://github.com/argmaxinc/WhisperKit/issues/171) — HIGH confidence
- [WhisperKit issue #268: Unable to load model (very slow)](https://github.com/argmaxinc/WhisperKit/issues/268) — MEDIUM confidence
- [Apple ml-stable-diffusion issue #255: ANECompiler FAILED](https://github.com/apple/ml-stable-diffusion/issues/255) — MEDIUM confidence
- [Apple ml-stable-diffusion issue #291: Memory issues on 4GB devices](https://github.com/apple/ml-stable-diffusion/issues/291) — MEDIUM confidence
- [Apple Developer Forums: UIApplication Background Task Notes](https://developer.apple.com/forums/thread/85066) — HIGH confidence
- [Apple Developer Forums: NSUserDefaults for App Group suite](https://developer.apple.com/forums/thread/728434) — MEDIUM confidence
- [fatbobman: Common Pitfalls Caused by Delayed State Updates in SwiftUI](https://fatbobman.com/en/posts/serious-issues-caused-by-delayed-state-updates-in-swiftui/) — MEDIUM confidence
- [SwiftUI Lab: Safely Updating The View State](https://swiftui-lab.com/state-changes/) — MEDIUM confidence
- [CocoaLumberjack issue #439: Retrieving log files from extensions](https://github.com/CocoaLumberjack/CocoaLumberjack/issues/439) — LOW confidence
- [Dictus project: background-recording-session.md](/.planning/debug/background-recording-session.md) — HIGH confidence (project history)
- [Dictus project: cross-process-transcription-not-received.md](/.planning/debug/cross-process-transcription-not-received.md) — HIGH confidence (project history)

---
*Pitfalls research for: Dictus v1.2 Beta Ready*
*Researched: 2026-03-11*
