// DictusApp/Onboarding/WelcomePage.swift
// The intro step of onboarding: a three-page carousel of looping scenes, and "Get started".
import SwiftUI
import DictusCore

/// The intro carousel shown on first launch (#649 decision 15, #676, mock-ups `01a`,
/// `01b`, `01c`).
///
/// Three pages tell one story, the voice goes into the phone and comes out as text:
/// walking, the metro without network, the keyboard in a note. Each page loops its scene
/// (`IntroVideoView`) above a localized headline and subtitle. The user swipes between
/// them, or taps **Get started** on any page to begin the setup.
///
/// WHY THE PAGES TURN BY THEMSELVES (decided 2026-10-09 after the first device test):
/// the tester tapped **Get started** on page 1 and never saw pages 2 and 3. Like Wispr
/// Flow's opening carousel, this one moves 1 → 2 → 3 → 1 on its own until the button is
/// tapped, each page staying one full pass of its scene. The rules (when, how long, the
/// pause in the background) live in `IntroAutoAdvance` and `IntroDwellTimer`.
///
/// WHY SWIPEABLE PAGES HERE when `OnboardingView` refuses them for the steps: the steps
/// are prerequisites the user must not swipe past; these three pages are a preface with
/// nothing to set up, and the button is on every one of them.
///
/// WHY A PAGING ScrollView AND NOT A PAGED TabView: the swipe is the same, but a paged
/// TabView changes page instantly when the page is set in code (measured on the iOS 26.5
/// simulator, frame to frame at 20 fps, `withAnimation` or not), so the automatic turn
/// would cut instead of slide. A ScrollView with `.paging` and `scrollPosition` scrolls to
/// a page set in code with the same slide a swipe gives.
///
/// WHY THE DOTS AND THE BUTTON SIT OUTSIDE THE PAGES: they stay still while the pages
/// slide under them, as the mock-ups draw them.
///
/// No progress bar: the intro is before the work starts (`OnboardingStep.showsProgress`).
struct WelcomePage: View {
    let onNext: () -> Void

    @State private var page: OnboardingIntroScene = .walking

    /// The time spent on the current page. A new one for every page landed on, whether
    /// the carousel turned or the user swiped.
    @State private var dwell = IntroDwellTimer(dwellSeconds: OnboardingIntroScene.walking.loopSeconds)
    /// Bumped whenever `dwell` starts or stops, so the waiting task below restarts.
    @State private var dwellGeneration = 0
    /// The pages' opacity, lowered only during the fade of the 3 → 1 wrap.
    @State private var pagesOpacity: Double = 1

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(OnboardingIntroScene.allCases, id: \.self) { scene in
                        IntroScenePage(scene: scene, isCurrent: page == scene)
                            .containerRelativeFrame(.horizontal)
                            .id(scene)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: scrolledPage)
            .opacity(pagesOpacity)

            IntroPageDots(current: page)
                .padding(.top, 20)
                .padding(.bottom, 24)

            OnboardingPrimaryButton(Text("Get started"), action: onNext)
                .accessibilityIdentifier("onboarding.primary")
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        .onAppear(perform: startDwellOnCurrentPage)
        // A swipe and an automatic turn both land here: the page landed on gets its full time.
        .onChange(of: page) { startDwellOnCurrentPage() }
        .onChange(of: isAdvancing) { _, advancing in
            let now = Self.now
            if advancing {
                dwell.resume(at: now)
            } else {
                dwell.pause(at: now)
            }
            dwellGeneration += 1
        }
        .task(id: dwellGeneration) {
            guard dwell.isRunning else { return }
            // Restarted (cancelled) by any change of page or of `isAdvancing`.
            try? await Task.sleep(for: .seconds(dwell.remaining(at: Self.now)))
            guard !Task.isCancelled else { return }
            turnPage()
        }
    }

    /// The scroll view's page, bridged to `page`. The scroll view reports nil while no
    /// page is settled; the carousel keeps the last one.
    private var scrolledPage: Binding<OnboardingIntroScene?> {
        Binding(
            get: { page },
            set: { newPage in
                if let newPage { page = newPage }
            }
        )
    }

    // MARK: - Auto-advance

    /// Whether time counts on the page: the app in front, and neither VoiceOver nor Reduce
    /// Motion on (`IntroAutoAdvance.isEnabled`). It pauses with the scene's player when the
    /// app leaves the foreground, and resumes where it was.
    private var isAdvancing: Bool {
        scenePhase == .active
            && IntroAutoAdvance.isEnabled(voiceOverRunning: voiceOverEnabled, reduceMotion: reduceMotion)
    }

    /// A monotonic clock in seconds, for `IntroDwellTimer`. Not the wall clock, which the
    /// user or the network can move.
    private static var now: Double { ProcessInfo.processInfo.systemUptime }

    private func startDwellOnCurrentPage() {
        dwell = IntroDwellTimer(dwellSeconds: page.loopSeconds)
        if isAdvancing {
            dwell.resume(at: Self.now)
        }
        dwellGeneration += 1
    }

    /// Moves to the next page: a slide forward, like a swipe, from 1 to 2 and 2 to 3.
    ///
    /// WHY A FADE FOR 3 → 1: a scroll from the last page to the first slides back across
    /// the middle one, which reads as a rewind. The other way
    /// to keep sliding forward is a fourth page, a copy of the first, swapped for the real
    /// one once landed; but that copy plays its own player, and the two walking women would
    /// rarely be on the same frame at the swap, which shows as a hitch mid-stride. A short
    /// dip through the page colour (the videos' own background) has no such seam, and it
    /// reads as what it is: back to the start, as the dots say at the same moment.
    private func turnPage() {
        let next = page.nextPage
        guard page.wrapsToFirstPage else {
            withAnimation(.easeInOut(duration: 0.4)) { page = next }
            return
        }
        withAnimation(.easeIn(duration: 0.25)) {
            pagesOpacity = 0
        } completion: {
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { page = next }
            withAnimation(.easeOut(duration: 0.3)) { pagesOpacity = 1 }
        }
    }
}

// MARK: - Page

/// One page of the carousel: the scene, then its headline and subtitle.
private struct IntroScenePage: View {
    let scene: OnboardingIntroScene
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 0) {
            // The art takes the height the text leaves, and shrinks on a small screen
            // rather than pushing the text off it. 330 pt wide at most: the art area the
            // scenes were framed for (#667).
            IntroVideoView(scene: scene, isCurrent: isCurrent)
                .frame(maxWidth: 330, maxHeight: .infinity)
                .padding(.top, 8)

            IntroCaption(scene: scene)
                .padding(.top, 24)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
        }
        // One element for VoiceOver: the headline and the subtitle, read together.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Caption

/// The headline and subtitle of a page, in a block of the same height on every page.
///
/// WHY A FIXED HEIGHT (#649, comment of 2026-10-08): the subtitles run from two lines to
/// three. Sized to its own text, the block would be taller on the metro page, the art
/// above it would sit higher, and the carousel would jump on every swipe. The block is
/// as tall as the tallest of the three, with the text at its top, so the art and the
/// headline sit at the same place on every page.
///
/// WHY MEASURED AND NOT A CONSTANT: which subtitle is the longest, and how many lines it
/// takes, depends on the language, the screen width and the text size. Laying the three
/// captions out invisibly in the same space gives the tallest one's height in every case.
private struct IntroCaption: View {
    let scene: OnboardingIntroScene

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(OnboardingIntroScene.allCases, id: \.self) { other in
                IntroCaptionText(scene: other)
                    .hidden()
            }
            IntroCaptionText(scene: scene)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The text of one caption: the large centred headline and its subtitle, set as the
/// shell's centred pages set theirs (`OnboardingCenteredPage`).
private struct IntroCaptionText: View {
    let scene: OnboardingIntroScene

    var body: some View {
        VStack(spacing: 10) {
            scene.headline
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            scene.subtitle
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

private extension OnboardingIntroScene {
    /// The page's headline (mock-ups `01a`, `01b`, `01c`).
    var headline: Text {
        switch self {
        case .walking: return Text("Speak. Dictus writes.")
        case .metro: return Text("Even offline.")
        case .keyboard: return Text("In your keyboard.")
        }
    }

    /// The line under the headline.
    var subtitle: Text {
        switch self {
        case .walking:
            return Text("In all your apps, from the keyboard.")
        case .metro:
            return Text("On the metro or on a plane, Dictus still writes. Everything happens on your iPhone.")
        case .keyboard:
            return Text("In Notes, Messages or Mail: tap the mic, speak, and the text appears.")
        }
    }
}

// MARK: - Page dots

/// The page indicator: the current page a blue capsule, the others grey dots (mock-ups
/// `01a` to `01c`).
private struct IntroPageDots: View {
    let current: OnboardingIntroScene

    var body: some View {
        let scenes = OnboardingIntroScene.allCases
        HStack(spacing: 8) {
            ForEach(scenes, id: \.self) { scene in
                Capsule()
                    .fill(scene == current ? Color.dictusAccent : Self.otherPage)
                    .frame(width: scene == current ? 22 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: current)
        // One element for VoiceOver instead of three silent capsules.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Page \(position(of: current, in: scenes)) of \(scenes.count)"))
    }

    private func position(of scene: OnboardingIntroScene, in scenes: [OnboardingIntroScene]) -> Int {
        (scenes.firstIndex(of: scene) ?? 0) + 1
    }

    /// The other pages: a light grey on light, a slate on dark, as measured on the
    /// mock-ups.
    private static let otherPage = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x2F3849))
}
