// DictusApp/Onboarding/IntroVideoView.swift
// One intro scene: its looping silent video, or its still frame when the file is missing (#676).
import AVFoundation
import SwiftUI
import UIKit
import DictusCore

/// The art of one intro page: the scene's video looping in place, silent, in the render
/// that matches the system appearance (#649 decision 15, #676).
///
/// WHY A VIDEO FILE AND NOT AN ANIMATION: the scenes are drawn in code by #667, then
/// exported as videos so the app needs no animation dependency. AVFoundation is part of
/// iOS.
///
/// WHY THE STILL FRAME UNDERNEATH: two jobs.
/// - A page whose video is not in the bundle shows its still instead, so the carousel
///   works without the files, and adding them needs no code change (the lookup is by name,
///   `OnboardingIntroScene.videoResourceName(dark:)`).
/// - While the video loads, the still covers the empty player. The video starts on the
///   very frame the still was taken from (`stillFrameSeconds`), so the hand-over is
///   invisible.
///
/// Decorative: VoiceOver reads the page's headline and subtitle, not the art.
struct IntroVideoView: View {
    let scene: OnboardingIntroScene
    /// Whether this page is the one on screen. Only that page plays; the others hold their
    /// still frame, so a page swiped to starts on the same picture it was showing.
    let isCurrent: Bool

    /// Width over height of the videos and stills: 1000 × 1440 px, the 330 × 476 pt art
    /// area at 3× (#667).
    static let aspectRatio: CGFloat = 1000.0 / 1440.0

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    /// Whether the player has a frame on screen, so the still can go.
    @State private var isVideoVisible = false

    var body: some View {
        ZStack {
            if !isVideoVisible {
                // The asset catalog picks the light or dark render by itself.
                Image(scene.stillImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            if let url = videoURL {
                LoopingVideoPlayer(
                    url: url,
                    startSeconds: scene.stillFrameSeconds,
                    isPlaying: isCurrent && scenePhase == .active,
                    onFirstFrame: { isVideoVisible = true }
                )
                // A new appearance is a new file: build a new player for it rather than
                // swapping the item under the looper.
                .id(url)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .onChange(of: colorScheme) {
            // The new file's player starts hidden; show the new still until it has a frame.
            isVideoVisible = false
        }
        .accessibilityHidden(true)
    }

    /// The video for the current appearance, or nil when it is not in the app's bundle.
    private var videoURL: URL? {
        Bundle.main.url(
            forResource: scene.videoResourceName(dark: colorScheme == .dark),
            withExtension: OnboardingIntroScene.videoExtension
        )
    }
}

// MARK: - Player

/// An `AVPlayerLayer` looping one file seamlessly, muted, starting at `startSeconds`.
///
/// WHY AVQueuePlayer + AVPlayerLooper: it is Apple's gapless loop. The looper keeps copies
/// of the item queued, so the end of one pass runs into the start of the next with no
/// seek and no blank frame. #667 rendered each file so its last frame leads into its first.
///
/// WHY NOT AVKit's `VideoPlayer`: it draws playback controls. The scene is art, not a
/// clip the user plays.
private struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    let startSeconds: Double
    let isPlaying: Bool
    let onFirstFrame: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, startSeconds: startSeconds)
    }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = context.coordinator.player
        context.coordinator.attach(to: view.playerLayer, onFirstFrame: onFirstFrame)
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        context.coordinator.setPlaying(isPlaying)
    }

    static func dismantleUIView(_ view: PlayerLayerView, coordinator: Coordinator) {
        coordinator.stop()
        view.playerLayer.player = nil
    }

    /// Owns the player and its looper for as long as the view lives.
    @MainActor
    final class Coordinator {
        let player: AVQueuePlayer
        private let looper: AVPlayerLooper
        private let startTime: CMTime
        private var itemObservation: NSKeyValueObservation?
        private var displayObservation: NSKeyValueObservation?
        /// Set once the first pass has been moved to `startTime`. Playing before that would
        /// show the start of the file for a moment.
        private var isPositioned = false
        private var wantsToPlay = false
        private var onFirstFrame: (() -> Void)?
        private weak var layer: AVPlayerLayer?

        init(url: URL, startSeconds: Double) {
            let player = AVQueuePlayer()
            // Silent: the files have no audio track, and muting makes sure no future file
            // can play sound over the user's music.
            player.isMuted = true
            // A looping intro must not keep the screen awake: the system's auto-lock
            // applies as it does to any page.
            player.preventsDisplaySleepDuringVideoPlayback = false
            player.allowsExternalPlayback = false
            self.player = player
            self.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            self.startTime = CMTime(seconds: startSeconds, preferredTimescale: 600)
        }

        /// Starts watching for the first item to be ready (to move it to the still's
        /// moment) and for the layer's first frame (to hide the still).
        func attach(to layer: AVPlayerLayer, onFirstFrame: @escaping () -> Void) {
            self.onFirstFrame = onFirstFrame
            self.layer = layer
            itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { player, _ in
                // KVO calls back on the thread that changed the value; the player's state
                // is only touched from the main actor.
                Task { @MainActor [weak self] in
                    self?.watchFirstItem(player.currentItem)
                }
            }
            displayObservation = layer.observe(\.isReadyForDisplay, options: [.new]) { layer, _ in
                Task { @MainActor [weak self] in
                    self?.reportFirstFrameIfShown(layer)
                }
            }
        }

        func setPlaying(_ playing: Bool) {
            wantsToPlay = playing
            guard isPositioned else { return }
            if playing {
                player.play()
            } else {
                player.pause()
            }
        }

        func stop() {
            player.pause()
            looper.disableLooping()
            itemObservation = nil
            displayObservation = nil
        }

        // MARK: Private

        private var statusObservation: NSKeyValueObservation?

        /// Waits for the first queued item to be ready, then moves it to the still's moment.
        ///
        /// WHY WAIT: seeking an item before it is ready to play is not reliable. Until it is,
        /// the still covers the player.
        private func watchFirstItem(_ item: AVPlayerItem?) {
            guard !isPositioned, statusObservation == nil, let item else { return }
            statusObservation = item.observe(\.status, options: [.initial, .new]) { item, _ in
                guard item.status == .readyToPlay else { return }
                Task { @MainActor [weak self] in
                    self?.position(item)
                }
            }
        }

        private func position(_ item: AVPlayerItem) {
            guard !isPositioned else { return }
            statusObservation = nil
            // Zero tolerance: the exact frame of the still, not the nearest keyframe.
            item.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isPositioned = true
                    self.setPlaying(self.wantsToPlay)
                    // The layer may have been ready before the seek ended, in which case
                    // its observation has already fired.
                    if let layer = self.layer {
                        self.reportFirstFrameIfShown(layer)
                    }
                }
            }
        }

        private func reportFirstFrameIfShown(_ layer: AVPlayerLayer) {
            guard layer.isReadyForDisplay, isPositioned, let onFirstFrame else { return }
            self.onFirstFrame = nil
            onFirstFrame()
        }
    }
}

/// A view whose backing layer is the `AVPlayerLayer`, so it resizes with the view.
private final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // The cast cannot fail: `layerClass` makes every instance's layer an AVPlayerLayer.
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}
