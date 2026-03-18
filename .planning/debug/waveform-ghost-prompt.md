# Prompt: Fix Ghost BrandWaveform Instances in iOS Keyboard Extension

## Context

Dictus is an iOS app (Swift/SwiftUI, iOS 17+) with a **keyboard extension** for voice dictation. The architecture:

- **DictusApp** — Main app. Runs the audio engine + Parakeet STT in background (`UIBackgroundModes:audio`). Writes recording state to App Group.
- **DictusKeyboard** — Keyboard extension. Reads state from App Group via Darwin notifications. Shows a recording overlay with animated waveform during dictation.
- **DictusCore** — Shared SPM framework. Contains `BrandWaveform` (the waveform view).

Recording flow: User taps mic in keyboard → keyboard shows overlay with `BrandWaveform` → app records in background → transcription → text inserted → overlay hides.

## The Bug

**Ghost `BrandWaveform` instances accumulate in the keyboard extension.** Each recording cycle creates a new BrandWaveform, but old instances' `TimelineView` (with `CADisplayLink`) keep running forever. After 3-4 recordings, there are 2-3 concurrent waveform animation loops, all consuming CPU. Ghosts persist even after the overlay is hidden.

### Log Evidence (log 43 — latest build)

```
# During 4th recording — TWO KBD heartbeats at the same second (different renderTick = different instances):
[16:13:09] <KBD> waveformHeartbeat renderTick=1107 avgLevel=0.436 energyCount=30  ← GHOST (frozen avgLevel)
[16:13:09] <KBD> waveformHeartbeat renderTick=131  avgLevel=0.845 energyCount=19  ← REAL (live audio data)

# After overlay hides — ghost keeps running FOREVER:
[16:13:13] <KBD> overlayHidden status=ready
[16:13:13] <KBD> waveformDisappeared refreshID=353 renderTick=353  ← real waveform's onDisappear fires
[16:13:15] <KBD> waveformHeartbeat renderTick=1503 avgLevel=0.436 energyCount=30  ← GHOST still alive
[16:13:17] <KBD> waveformHeartbeat renderTick=1717 avgLevel=0.436 energyCount=30  ← GHOST
[16:13:19] <KBD> waveformHeartbeat renderTick=1869 avgLevel=0.436 energyCount=30  ← GHOST
[16:13:21] <KBD> waveformHeartbeat renderTick=2029 avgLevel=0.436 energyCount=30  ← GHOST
[16:13:23] <KBD> waveformHeartbeat renderTick=2150 avgLevel=0.436 energyCount=30  ← GHOST (12s after overlay hidden!)
```

### How ghosts are born (traced from logs)

During cold start or keyboard reappear while recording is active:

```
# 1. Overlay appears, BrandWaveform A created:
waveformAppeared refreshID=0 energyCount=0 killed=false     ← Instance A

# 2. Keyboard disappears during app switch:
keyboardDidDisappear
waveformDisappeared refreshID=84 renderTick=84               ← A's onDisappear fires, killed=true

# 3. Status changes while keyboard is invisible — SwiftUI recreates overlay:
statusChanged from=idle to=recording                          ← showsOverlay becomes true
waveformAppeared refreshID=0 energyCount=6 killed=false       ← Instance B created

# 4. Keyboard reappears, rapid status updates cause ANOTHER overlay recreation:
keyboardDidAppear
statusChanged from=idle to=recording (x5 rapid)              ← objectWillChange storms
overlayShown status=recording
waveformAppeared refreshID=0 energyCount=9 killed=false       ← Instance C created! B is now a GHOST

# Now B and C both run. B's onDisappear NEVER fires. B becomes permanent ghost.
```

The root cause: SwiftUI's conditional rendering (`if showsOverlay { RecordingOverlay(...) }`) combined with `.animation(.easeOut(duration: 0.25), value: showsOverlay)` means when `showsOverlay` flips false→true rapidly, the OLD overlay is still animating out while a NEW one animates in. Both contain a BrandWaveform with its own TimelineView/CADisplayLink. If the old one's `onDisappear` doesn't fire (SwiftUI animation interference), it becomes an immortal ghost.

## Current Code

### BrandWaveform.swift (DictusCore — shared framework)

```swift
public struct BrandWaveform: View {
    public let energyLevels: [Float]
    public var maxHeight: CGFloat = 80
    public var isProcessing: Bool = false
    public var isActive: Bool = true  // pauses TimelineView when false (used by APP side)

    @State private var killed = false
    @State private var displayLevels: [Float] = Array(repeating: 0, count: 30)
    @State private var renderTick: Int = 0
    @State private var lastRenderTime: Date = .distantPast
    @State private var lastHeartbeatTime: Date = .distantPast

    private let barCount = 30
    private let smoothingFactor: Float = 0.3
    private let decayFactor: Float = 0.85

    public var body: some View {
        TimelineView(.animation(paused: !isActive && !isProcessing)) { timeline in
            waveformContent(processingPhase: ...)
                .onAppear {
                    killed = false  // Reset in case @State was preserved
                    displayLevels = targetLevels()
                    lastRenderTime = Date()
                }
                .onDisappear {
                    killed = true  // Kill switch — should stop animation
                }
                .onChange(of: timeline.date) { _ in
                    guard !killed else { return }
                    updateDisplayLevels()  // 60fps lerp toward energyLevels
                }
                .onChange(of: energyLevels) { _ in
                    guard !killed else { return }
                    updateDisplayLevels()  // Fallback ~5Hz from App Group
                }
        }
    }

    // Canvas-based rendering (30 bars), lerp/decay smoothing, heartbeat logging every 2s
    private func updateDisplayLevels() {
        guard !killed else { return }
        // ... lerp/decay logic, heartbeat logging
        renderTick += 1
    }
}
```

### RecordingOverlay.swift (DictusKeyboard)

```swift
struct RecordingOverlay: View {
    let dictationStatus: DictationStatus
    let waveformEnergy: [Float]
    let elapsedSeconds: Double
    let onCancel: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { geo in
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    BrandWaveform(
                        energyLevels: dictationStatus == .requested ? [] : waveformEnergy,
                        maxHeight: geo.size.height * 0.7,
                        isProcessing: dictationStatus == .transcribing
                    )
                    .padding(.horizontal, 2)
                    // NOTE: .id(waveformRefreshID) was removed — it caused ghost storms
                    Spacer(minLength: 0)
                }
            }
            footer
        }
    }
}
```

### KeyboardRootView.swift (DictusKeyboard)

```swift
struct KeyboardRootView: View {
    @StateObject private var state = KeyboardState()

    private var showsOverlay: Bool {
        state.dictationStatus == .requested
            || state.dictationStatus == .recording
            || state.dictationStatus == .transcribing
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsOverlay {
                RecordingOverlay(
                    dictationStatus: state.dictationStatus,
                    waveformEnergy: state.waveformEnergy,
                    elapsedSeconds: state.recordingElapsed,
                    onCancel: { state.requestCancel() },
                    onStop: { state.requestStop() }
                )
                .frame(height: totalContentHeight)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            } else {
                ToolbarView(...)
                KeyboardView(...)
            }
        }
        .animation(.easeOut(duration: 0.25), value: showsOverlay)
    }
}
```

### KeyboardState.swift (DictusKeyboard)

`KeyboardState` is an `ObservableObject` that:
- Listens to Darwin notifications (`statusChanged`, `waveformUpdate`, `transcriptionReady`)
- Reads `DictationStatus` and `[Float]` waveform energy from App Group UserDefaults
- Publishes `dictationStatus`, `waveformEnergy`, `recordingElapsed`
- Has a watchdog timer (5s timeout) to detect stale recording states
- `refreshFromDefaults()` reads current status from App Group, can fire `objectWillChange.send()` multiple times during rapid state transitions

Key detail: `refreshFromDefaults()` calls `objectWillChange.send()` even when status hasn't changed (for force-refresh after process suspension), which triggers SwiftUI to re-evaluate the body and potentially recreate the overlay.

## What was already tried (and failed)

1. **`killed` flag** — `@State private var killed = false`, set to `true` in `onDisappear`, reset to `false` in `onAppear`. All `onChange` handlers guard with `guard !killed`. **Problem**: ghosts' `onDisappear` never fires (SwiftUI doesn't call it on orphaned views during animation transitions).

2. **`.id(waveformRefreshID)`** — Changed `.id()` on BrandWaveform to force recreation on keyboard reappear. **Problem**: rapid `.id()` changes during cold start created even MORE ghost instances. Was removed.

3. **`isActive` parameter** — Added to pause `TimelineView(.animation(paused:))` on the APP side when not recording. **Works for APP, not for KBD** — the KBD BrandWaveform always has `isActive: true` (default) because it only exists inside the overlay which is only shown during active states.

## What needs to be fixed

The keyboard's BrandWaveform ghosts must be eliminated. The solution must:

1. **Prevent ghost creation**: When the overlay is rapidly hidden/shown (during app switch or cold start), ensure only ONE BrandWaveform instance exists at a time.
2. **Kill orphaned instances**: If a ghost IS created, its TimelineView/CADisplayLink must stop promptly (within 1-2 frames).
3. **Not break the real waveform**: The visible waveform must still animate at 60fps during recording and show the sine wave during transcription.
4. **Work in keyboard extension context**: Memory limit ~50MB, no `UIApplication.shared`, extension process can be suspended/resumed by iOS at any time.

## Possible approaches to explore

- **Remove the `.animation()` on `showsOverlay`** to prevent overlapping insert/remove transitions (simplest, but loses the animation)
- **Use a shared `ObservableObject` token** that only the most-recent BrandWaveform instance holds — others auto-pause
- **Replace `TimelineView` with a `Timer`-based approach** that can be explicitly invalidated
- **Use `withTransaction` to disable animations** on rapid showsOverlay changes
- **Debounce `showsOverlay`** — delay hiding by 100ms to absorb rapid status flips
- **Move waveform state out of BrandWaveform** into the parent (KeyboardState) so there's only one animation source regardless of how many BrandWaveform views exist

## Files to modify

- `DictusCore/Sources/DictusCore/Design/BrandWaveform.swift` — the waveform view
- `DictusKeyboard/Views/RecordingOverlay.swift` — the overlay containing the waveform
- `DictusKeyboard/KeyboardRootView.swift` — the root view with `if showsOverlay` conditional
- `DictusKeyboard/KeyboardState.swift` — the state manager (if moving animation state out)

## Build & test

```bash
xcodebuild build -scheme DictusApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet
```

To verify the fix, grep for `waveformHeartbeat` in the logs:
- **Good**: At most 1 `<KBD>` heartbeat per 2-second interval during recording, 0 after overlay hides
- **Bad**: Multiple `<KBD>` heartbeats with different `renderTick` values at the same time, or heartbeats continuing after `overlayHidden`
