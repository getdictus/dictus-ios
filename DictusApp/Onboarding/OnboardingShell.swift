// DictusApp/Onboarding/OnboardingShell.swift
// The onboarding's visual shell (#675): progress bar, Skip slot, page layout, buttons.
import SwiftUI
import DictusCore

// WHY A SHELL SEPARATE FROM THE PAGES (#649 decision 13, #675): the onboarding's frame is
// new, drawn from the approved mock-ups (Superwhisper's visual language on the app's own
// colours), while what sits inside a page is the app as it is today. Keeping the frame in
// one file means every page, and every step the later #649 sub-issues add, wears the same
// title, buttons and progress bar without restating their sizes.
//
// Colours: light is the app's grouped grey (`dictusBackground`, #F2F2F7) with white cards
// (`dictusSurface`), dark is the app's dark (#0A1628) with its surface (#161C2C). Both come
// from the existing adaptive tokens, so the shell follows the system appearance like the
// rest of the app.

// MARK: - Metrics

/// Spacing shared by every page, so a page change never moves the title or the button.
enum OnboardingMetrics {
    /// Leading and trailing margin of the page content (24 pt in the mock-ups).
    static let horizontalPadding: CGFloat = 24
    /// Gap between the progress bar row and the title.
    static let titleTopPadding: CGFloat = 32
    /// Height of the primary button.
    static let buttonHeight: CGFloat = 56
    /// Gap between the primary button and the bottom safe area.
    static let buttonBottomPadding: CGFloat = 8
    /// Corner radius of the white cards.
    static let cardCornerRadius: CGFloat = 24
    /// Height of the top row (progress bar and Skip), kept on steps without a bar so the
    /// content below does not shift when the bar appears.
    static let topBarHeight: CGFloat = 32
}

// MARK: - Progress bar

/// Segmented progress bar: steps done in solid blue, the current step in pale blue, the
/// rest grey (#675).
///
/// WHY SEGMENTS FROM `OnboardingStep.progressSteps`: the bar shows the steps that wear
/// it, in order, so a step added later by a #649 sub-issue gets its segment by existing.
/// A skipped step keeps its segment and reads as done once passed.
struct OnboardingProgressBar: View {
    let step: OnboardingStep

    var body: some View {
        let steps = OnboardingStep.progressSteps
        let current = step.progressIndex ?? 0
        HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, _ in
                Capsule()
                    .fill(color(forSegment: index, current: current))
                    .frame(height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        // One element for VoiceOver instead of five silent capsules.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(current + 1) of \(steps.count)"))
    }

    private func color(forSegment index: Int, current: Int) -> Color {
        if index < current {
            return .dictusAccent
        } else if index == current {
            // Pale blue: the accent over the page background. 40 % reads as the mock-up's
            // #A9C6FA on the light grey and as its dark navy blue on #0A1628.
            return .dictusAccent.opacity(0.4)
        } else {
            return Self.remaining
        }
    }

    /// The segments still ahead: a light grey on light, a slate on dark.
    private static let remaining = Color(light: Color(hex: 0xE2E2E8), dark: Color(hex: 0x232D40))
}

/// The row above every page: the progress bar, and the discreet Skip where the step
/// allows it (#675).
///
/// WHY THE SHELL DRAWS SKIP, NOT THE PAGE: the slot sits at the same place on every step
/// that has it, and stays put while the pages slide.
struct OnboardingTopBar: View {
    let step: OnboardingStep
    /// nil when the step has no Skip.
    let onSkip: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            if step.showsProgress {
                OnboardingProgressBar(step: step)
            } else {
                Spacer()
            }
            if let onSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("onboarding.skip")
            }
        }
        .frame(height: OnboardingMetrics.topBarHeight)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
    }
}

// MARK: - Page layout

/// A page of the shell: large left-aligned title and subtitle, the page's content, then
/// an optional footnote and the buttons pinned to the bottom (#675).
///
/// WHY THE CONTENT SCROLLS: the mock-ups are drawn at 402 × 874 pt. On a 667 pt screen
/// (iPhone SE, every iPad in compatibility mode), the language and keyboard pages would
/// clip; a scroll view that only bounces when it overflows keeps the button reachable
/// and costs nothing where everything fits.
struct OnboardingPage<Content: View, Bottom: View>: View {
    let title: Text
    let subtitle: Text?
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    init(
        title: Text,
        subtitle: Text? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingHeader(title: title, subtitle: subtitle)
                        .padding(.top, OnboardingMetrics.titleTopPadding)
                        .padding(.bottom, 24)
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 12) {
                bottom
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
    }
}

/// The large left-aligned title and its subtitle.
struct OnboardingHeader: View {
    let title: Text
    let subtitle: Text?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                subtitle
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The page used by the intro, the microphone and the completion steps: an illustration
/// and a centred title and text, with the buttons at the bottom (#675). The mock-ups
/// centre these three because they have one thing to say and nothing to fill in.
struct OnboardingCenteredPage<Illustration: View, Bottom: View>: View {
    let title: Text
    let message: Text?
    @ViewBuilder let illustration: Illustration
    @ViewBuilder let bottom: Bottom

    init(
        title: Text,
        message: Text? = nil,
        @ViewBuilder illustration: () -> Illustration,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.title = title
        self.message = message
        self.illustration = illustration()
        self.bottom = bottom()
    }

    var body: some View {
        VStack(spacing: 0) {
            // WHY A GEOMETRY READER: the block is centred in the height left above the
            // buttons when it fits (`minHeight`), and scrolls instead of clipping when a
            // large Dynamic Type size makes it taller than that.
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        illustration
                            .padding(.bottom, 40)
                        title
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, 10)
                        if let message {
                            message
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            VStack(spacing: 12) {
                bottom
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
    }
}

// MARK: - Buttons

/// The large blue button at the bottom of every page (#675).
///
/// WHY LIQUID GLASS ON iOS 26 AND A GRADIENT BEFORE: the mock-ups draw a large blue glass
/// capsule. `glassEffect` tinted with the accent is that capsule, with the system's own
/// press response (`interactive()`); before iOS 26 the same capsule is filled with the
/// accent gradient and pressed with `GlassPressStyle`, the app's stand-in for that response.
struct OnboardingPrimaryButton: View {
    let title: Text
    var isEnabled = true
    let action: () -> Void

    init(_ title: Text, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: OnboardingMetrics.buttonHeight)
                .modifier(PrimaryCapsuleBackground())
                .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The blue capsule behind `OnboardingPrimaryButton`.
private struct PrimaryCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(.dictusAccent).interactive(), in: Capsule())
        } else {
            content
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(hex: 0x5C9BFF), .dictusAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .shadow(color: .dictusAccent.opacity(0.3), radius: 12, y: 4)
        }
    }
}

/// The large secondary button under the primary one, for a way out that must stay as
/// visible as the way forward (#683: *Later* on the Apple Intelligence step).
///
/// WHY THE SAME SIZE AS THE PRIMARY: the mock-up draws both capsules at full width and the
/// same height. A small text link would read as "you are not supposed to tap this", which
/// is the opposite of what an optional step means.
struct OnboardingSecondaryButton: View {
    let title: Text
    let action: () -> Void

    init(_ title: Text, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(height: OnboardingMetrics.buttonHeight)
                .background(Capsule().fill(Color.dictusSurface))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                .contentShape(Capsule())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
    }
}

// MARK: - Download pill

/// A small capsule above the buttons with the model's name and download progress, so a
/// step the user spends time on still shows the download running (mock-up
/// `04-apple-intelligence`). Absent when nothing is downloading.
struct OnboardingDownloadPill: View {
    @ObservedObject var modelManager: ModelManager
    let modelIdentifier: String

    var body: some View {
        if modelManager.modelStates[modelIdentifier] == .downloading,
           let progress = modelManager.downloadProgress[modelIdentifier],
           let name = ModelInfo.forIdentifier(modelIdentifier)?.displayName {
            HStack(spacing: 8) {
                // A ring drawn by hand: a determinate circular `ProgressView` is not drawn
                // as a ring on every iOS version the app supports.
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.dictusAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
                .animation(.linear(duration: 0.3), value: progress)
                .accessibilityHidden(true)
                Text(verbatim: "\(name) · ") + Text("\(Int(progress * 100)) %")
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.dictusSurface))
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }
}

// MARK: - Cards

extension View {
    /// The shell's card: white on the light grey, the app's surface on dark.
    func onboardingCard(cornerRadius: CGFloat = OnboardingMetrics.cardCornerRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.dictusSurface)
        )
    }
}

// MARK: - Drawn iPhone in a card

/// The top of a drawn iPhone inside a card, cropped at the bottom so the phone runs off it
/// (#675 mock-up `03-clavier-dans-les-reglages`). `content` is the phone's screen.
///
/// WHY CONCENTRIC CORNERS (decided 2026-10-09): the card's corner radius is the phone's plus
/// the gap between them (`phoneCornerRadius + phoneInset`), so the gap stays the same width
/// all the way round the corners. The first version had a card corner tighter than the
/// phone's, and the gap pinched at the corners. Every onboarding screen that shows a drawn
/// iPhone uses this view, so the rule holds everywhere by construction.
enum OnboardingPhoneMetrics {
    /// The phone's top corner radius.
    static let phoneCornerRadius: CGFloat = 44
    /// The gap between the card's edge and the phone's outer edge, at the top and sides.
    static let phoneInset: CGFloat = 10
    /// Concentric with the phone: its radius plus the gap.
    static let cardCornerRadius: CGFloat = phoneCornerRadius + phoneInset
    /// The phone outline's width, drawn inside the phone's shape.
    static let phoneFrameWidth: CGFloat = 7
    /// How far the phone runs past the card's bottom edge, so the crop cuts through it.
    static let overrun: CGFloat = 24
    /// The phone's outline: a light grey on light, a slate on dark.
    static let phoneFrame = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x2A3346))
}

/// The drawn iPhone in its card. Metrics in `OnboardingPhoneMetrics` (a generic view
/// cannot hold static stored properties).
struct OnboardingPhoneCard<Content: View>: View {
    @ViewBuilder let content: Content

    private typealias Metrics = OnboardingPhoneMetrics

    var body: some View {
        let phoneShape = UnevenRoundedRectangle(
            topLeadingRadius: Metrics.phoneCornerRadius,
            topTrailingRadius: Metrics.phoneCornerRadius,
            style: .continuous
        )
        let cardShape = UnevenRoundedRectangle(
            topLeadingRadius: Metrics.cardCornerRadius,
            topTrailingRadius: Metrics.cardCornerRadius,
            style: .continuous
        )
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            // The phone is drawn taller than the card so the crop below cuts through it:
            // no bottom edge, the phone runs off the card.
            .background(phoneShape.fill(Color.dictusBackground).padding(.bottom, -Metrics.overrun))
            .overlay(
                phoneShape
                    .strokeBorder(Metrics.phoneFrame, lineWidth: Metrics.phoneFrameWidth)
                    .padding(.bottom, -Metrics.overrun)
            )
            .padding(.horizontal, Metrics.phoneInset)
            .padding(.top, Metrics.phoneInset)
            .background(cardShape.fill(Color.dictusSurface))
            // Rounded on top, cut straight below.
            .clipShape(cardShape)
    }
}

/// An uppercase section label above a card, like the grouped lists of the app and of iOS.
struct OnboardingSectionLabel: View {
    let text: Text

    var body: some View {
        text
            .font(.footnote.weight(.medium))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
