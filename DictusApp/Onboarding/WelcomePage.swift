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
/// WHY A SWIPEABLE TabView HERE when `OnboardingView` refuses one for the steps: the
/// steps are prerequisites the user must not swipe past; these three pages are a preface
/// with nothing to set up, and the button is on every one of them.
///
/// WHY THE DOTS AND THE BUTTON SIT OUTSIDE THE PAGES: they stay still while the pages
/// slide under them, as the mock-ups draw them. The system page dots are hidden because
/// they are white, made for a dark backdrop, and vanish on the light grey.
///
/// No progress bar: the intro is before the work starts (`OnboardingStep.showsProgress`).
struct WelcomePage: View {
    let onNext: () -> Void

    @State private var page: OnboardingIntroScene = .walking

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(OnboardingIntroScene.allCases, id: \.self) { scene in
                    IntroScenePage(scene: scene, isCurrent: page == scene)
                        .tag(scene)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            IntroPageDots(current: page)
                .padding(.top, 20)
                .padding(.bottom, 24)

            OnboardingPrimaryButton(Text("Get started"), action: onNext)
                .accessibilityIdentifier("onboarding.primary")
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
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
