// DictusApp/Onboarding/AnimatedScenePlayer.swift
// Plays a drawn, looping, silent scene: the shared component of #649 decision 12 (#679).
import SwiftUI
import DictusCore

/// Plays a scene drawn in SwiftUI on a loop (#649 decisions 12 and 14, #679).
///
/// The scene is a function of time: `content` is asked for the drawing at a moment of the
/// loop, and this view decides which moment. That split is what makes it reusable. A scene
/// knows nothing about the onboarding, What's new or the Pro hub cards (#216); each of
/// them puts the same player where it wants, with its own frame around it.
///
/// WHY A FUNCTION OF TIME AND NOT CHAINED ANIMATIONS: a scene of 10 to 20 s chained out of
/// `withAnimation` completions drifts, cannot be paused, and starts wherever the last
/// completion left it when the view comes back. A pure "time → drawing" restarts exactly,
/// pauses exactly, and gives a still frame for free. The script of the first scene lives
/// in DictusCore (`SmartModesSceneScript`), where it is tested.
///
/// WHY `TimelineView(.animation)`: it redraws on the display's own refresh, and only while
/// the view is on screen and not paused, so a scene costs nothing on a page that left.
///
/// The rules of play:
/// - It pauses when the app leaves the foreground and resumes where it was
///   (`SceneLoopClock`), like the intro's videos.
/// - With Reduce Motion on, it shows the scene's still moment and never moves.
/// - It is silent, decorative and takes no touches: the page's title and line carry the
///   meaning for VoiceOver, and a tap on a drawn key must not look like it should work.
/// - It never gates anything. The page around it decides when Next is enabled, and for a
///   scene that is always (decision 8).
struct AnimatedScenePlayer<Content: View>: View {
    /// One pass of the scene, in seconds.
    let loopSeconds: Double
    /// The moment shown with Reduce Motion on.
    let stillSeconds: Double
    /// The drawing at a moment of the loop, in seconds from its start.
    @ViewBuilder let content: (Double) -> Content

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var clock: SceneLoopClock

    init(loopSeconds: Double, stillSeconds: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.loopSeconds = loopSeconds
        self.stillSeconds = stillSeconds
        self.content = content
        _clock = State(initialValue: SceneLoopClock(loopSeconds: loopSeconds))
    }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { _ in
            // The timeline's date only triggers the redraw; the moment comes from the
            // pausable clock, so the time spent in the background is not counted.
            content(currentTime)
        }
        .onAppear { setPlaying(isPlaying) }
        .onDisappear { setPlaying(false) }
        .onChange(of: isPlaying) { _, playing in setPlaying(playing) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Private

    /// Whether the loop is running: the app in front and Reduce Motion off.
    private var isPlaying: Bool {
        scenePhase == .active && !reduceMotion
    }

    private var currentTime: Double {
        reduceMotion ? stillSeconds : clock.loopTime(at: Self.now)
    }

    private func setPlaying(_ playing: Bool) {
        if playing {
            clock.resume(at: Self.now)
        } else {
            clock.pause(at: Self.now)
        }
    }

    /// A monotonic clock in seconds. Not the wall clock, which the user or the network
    /// can move.
    private static var now: Double { ProcessInfo.processInfo.systemUptime }
}
