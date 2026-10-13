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
    /// Height of the top row (back chevron and progress bar), kept on steps without a bar
    /// so the content below does not shift when the bar appears. Also the width of each of
    /// the row's two side slots (#700).
    static let topBarHeight: CGFloat = 32
    /// Gap between the safe area and the top row.
    static let topBarTopPadding: CGFloat = 8
    /// Everything the top row takes above a page. The model preparation screen leaves the
    /// same height empty in the app, where there is no bar, so its ring sits at the same y
    /// in the onboarding and in the app (#708).
    static let topRowHeight: CGFloat = topBarTopPadding + topBarHeight
    /// Gap between the primary button and the Skip row under it (#700).
    static let skipRowSpacing: CGFloat = 12
}

// MARK: - Progress bar

/// Segmented progress bar: steps done in solid blue, the current step in pale blue, the
/// rest grey (#675).
///
/// WHY SEGMENTS FROM `OnboardingStep.progressSteps`: the bar shows the steps that wear
/// it, in order, so a step added later by a #649 sub-issue gets its segment by existing.
/// A skipped step keeps its segment and reads as done once passed; a Pro step hidden on a
/// device that can never run Smart Modes has none (#677).
struct OnboardingProgressBar: View {
    let step: OnboardingStep
    /// `SmartModeAvailability.deviceIsCapable`, which decides whether the Pro steps exist.
    let deviceCanRunSmartModes: Bool

    var body: some View {
        let steps = OnboardingStep.progressSteps(deviceCanRunSmartModes: deviceCanRunSmartModes)
        let current = step.progressIndex(deviceCanRunSmartModes: deviceCanRunSmartModes) ?? 0
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

/// The row above every page: the back chevron where the step has one (#700) and the
/// progress bar.
///
/// WHY TWO SLOTS ON EVERY STEP, OF THE SAME WIDTH (#700, decided after the device test of
/// the back chevron): the bar used to take whatever width the controls left, so it shrank
/// and moved when the chevron or Skip appeared. Like an iOS navigation bar, the row now
/// reserves a leading and a trailing slot of the chevron's width on every step, empty when
/// there is nothing to put in them, so the bar is centred and has the same frame on every
/// step. Skip left this row for `OnboardingSkipRow`, under the primary button: with it
/// gone, the trailing slot only balances the leading one.
struct OnboardingTopBar: View {
    let step: OnboardingStep
    let deviceCanRunSmartModes: Bool
    /// nil when the step has no back control (`OnboardingStep.stepBack`).
    let onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let onBack {
                    // A standard iOS back chevron (#700), leading-aligned in its slot so it
                    // lines up with the page's title.
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.semibold))
                            // The accent, as the system tints its own back chevron.
                            .foregroundStyle(Color.dictusAccent)
                            .frame(
                                width: OnboardingMetrics.topBarHeight,
                                height: OnboardingMetrics.topBarHeight,
                                alignment: .leading
                            )
                            // The row is 32 pt high; the tap area reaches the 44 pt minimum.
                            .contentShape(Rectangle().inset(by: -6))
                    }
                    .accessibilityLabel(Text("Back"))
                    .accessibilityIdentifier("onboarding.back")
                } else {
                    Color.clear
                }
            }
            .frame(width: OnboardingMetrics.topBarHeight)
            if step.showsProgress {
                OnboardingProgressBar(step: step, deviceCanRunSmartModes: deviceCanRunSmartModes)
            } else {
                Spacer()
            }
            Color.clear
                .frame(width: OnboardingMetrics.topBarHeight)
        }
        .frame(height: OnboardingMetrics.topBarHeight)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
    }
}

// MARK: - Skip row

/// What the Skip link under the primary button does, set by `OnboardingView` on the step
/// that offers it (`OnboardingStep.isSkippable`), nil elsewhere.
///
/// WHY THE ENVIRONMENT: the action belongs to the flow (it decides where Skip lands), while
/// the row is drawn by the page's shell, several views down. Passing it through every
/// page's initializer would make each page carry a parameter only the shell reads.
struct OnboardingSkipAction {
    let perform: () -> Void
}

private struct OnboardingSkipActionKey: EnvironmentKey {
    static let defaultValue: OnboardingSkipAction? = nil
}

extension EnvironmentValues {
    var onboardingSkip: OnboardingSkipAction? {
        get { self[OnboardingSkipActionKey.self] }
        set { self[OnboardingSkipActionKey.self] = newValue }
    }
}

/// The row under the primary button: the discreet Skip, centred, on the steps that offer
/// it, and the same row left empty on every other step (#700).
///
/// WHY RESERVED ON EVERY STEP: the row takes the same height whether Skip is there or not,
/// so the primary button sits at the same height on every step. An empty row is a hidden
/// label: invisible, out of the accessibility tree, and as tall as the link would be at the
/// current text size.
///
/// WHY `.footnote` IN GREY: the bottom block's other small print (*Nothing you type leaves
/// your iPhone*) is footnote secondary, and Skip is the least important thing on the step.
/// It is also the smallest row that still reads: about 16 pt at the default size, where
/// `.body` would take 21.
///
/// WHY THE TAP AREA REACHES PAST THE ROW: the label is about 16 pt high, short of the
/// 44 pt minimum. The area grows by the 12 pt gap above (up to the button's edge, never
/// over it) and 16 pt below, into the bottom padding, without making the row any taller.
struct OnboardingSkipRow: View {
    @Environment(\.onboardingSkip) private var skip

    var body: some View {
        ZStack {
            Text("Skip")
                .font(.footnote)
                .lineLimit(1)
                .hidden()
                .accessibilityHidden(true)
            if let skip {
                Button(action: skip.perform) {
                    Text("Skip")
                        .font(.footnote)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, OnboardingMetrics.skipRowSpacing)
                        .padding(.bottom, 16)
                        .contentShape(Rectangle())
                        .padding(.horizontal, -16)
                        .padding(.top, -OnboardingMetrics.skipRowSpacing)
                        .padding(.bottom, -16)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.skip")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page layout

/// A page of the shell: large left-aligned title and subtitle, the page's content, then
/// an optional footnote, the buttons pinned to the bottom, and the Skip row under them
/// (#675, #700).
///
/// WHY THE CONTENT SCROLLS: the mock-ups are drawn at 402 × 874 pt. On a 667 pt screen
/// (iPhone SE, every iPad in compatibility mode), the language and keyboard pages would
/// clip; a scroll view that only bounces when it overflows keeps the button reachable
/// and costs nothing where everything fits.
///
/// WHY A PAGE CAN OPT OUT (`scrolls: false`, #700): a scene whose subject sits at the
/// bottom of its drawing (the mic of the Smart Modes scene) loses that subject under the
/// fold on a short screen. Such a page gets the height left under the title instead, and
/// fits its drawing into it (`OnboardingScenePage`).
struct OnboardingPage<Content: View, Bottom: View, TitleAccessory: View>: View {
    let title: Text
    let subtitle: Text?
    /// False for a page whose content fits itself into the height left under the title.
    var scrolls = true
    @ViewBuilder let titleAccessory: TitleAccessory
    @ViewBuilder let content: Content
    @ViewBuilder let bottom: Bottom

    /// - Parameter titleAccessory: drawn at the trailing end of the title's first line,
    ///   like the Smart Mode pick's `n / 3` counter (#677).
    init(
        title: Text,
        subtitle: Text? = nil,
        scrolls: Bool = true,
        @ViewBuilder titleAccessory: () -> TitleAccessory,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrolls = scrolls
        self.titleAccessory = titleAccessory()
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        VStack(spacing: 0) {
            if scrolls {
                ScrollView {
                    page
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                page
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            VStack(spacing: 12) {
                bottom
                OnboardingSkipRow()
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
    }

    /// The title, then the content: in the scroll view, or in the height left above the
    /// buttons when the page does not scroll.
    private var page: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: title, subtitle: subtitle) { titleAccessory }
                .padding(.top, OnboardingMetrics.titleTopPadding)
                .padding(.bottom, 24)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
        .padding(.bottom, 16)
    }
}

extension OnboardingPage where TitleAccessory == EmptyView {
    /// A page with nothing beside its title, which is every page but the Smart Mode pick.
    init(
        title: Text,
        subtitle: Text? = nil,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            scrolls: scrolls,
            titleAccessory: { EmptyView() },
            content: content,
            bottom: bottom
        )
    }
}

/// The large left-aligned title and its subtitle, with an optional accessory at the
/// trailing end of the title.
struct OnboardingHeader<Accessory: View>: View {
    let title: Text
    let subtitle: Text?
    @ViewBuilder let accessory: Accessory

    init(title: Text, subtitle: Text?, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                title
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessory
            }
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

extension OnboardingHeader where Accessory == EmptyView {
    init(title: Text, subtitle: Text?) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
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
                OnboardingSkipRow()
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

/// "Parakeet v3 · 34 %" in a small capsule above the buttons, while the model downloads
/// (mock-ups `04-apple-intelligence`, `05-scene-smart-modes`, `06-vos-3-smart-modes`). The
/// steps that fall within the download show it, so the user sees the transfer still moving.
/// Nothing once the download is over or before it starts.
///
/// WHY ONE VIEW: the Smart Mode pick (#677), the Apple Intelligence step (#683) and the
/// Smart Modes scene (#679) were built side by side, each needing the same pill.
struct OnboardingDownloadPill: View {
    @ObservedObject var modelManager: ModelManager
    let modelIdentifier: String

    var body: some View {
        if modelManager.modelStates[modelIdentifier] == .downloading,
           let model = ModelInfo.forIdentifier(modelIdentifier) {
            let fraction = Double(modelManager.downloadProgress[modelIdentifier] ?? 0)
            HStack(spacing: 8) {
                // A ring drawn by hand: a determinate circular `ProgressView` is not drawn
                // as a ring on every iOS version the app supports. A sliver at 0 % so the
                // ring reads as started.
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.12), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: max(0.02, fraction))
                        .stroke(Color.dictusAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
                .animation(.easeInOut(duration: 0.3), value: fraction)

                (Text(verbatim: "\(model.displayName) · ")
                    + Text(fraction, format: .percent.precision(.fractionLength(0))))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.dictusSurface))
            .accessibilityElement(children: .combine)
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

/// A drawn iPhone inside a card, cropped so the phone runs off one edge of it. `content` is
/// the phone's screen.
///
/// - `.top` (mock-up `03-clavier-dans-les-reglages`): the top of the phone, cut at the
///   card's bottom edge.
/// - `.bottom` (mock-up `05-scene-smart-modes`, #679): the bottom of the phone, where the
///   keyboard is, cut at the card's top edge.
///
/// WHY CONCENTRIC CORNERS (decided 2026-10-09): the card's corner radius is the phone's plus
/// the gap between them (`phoneCornerRadius + phoneInset`), so the gap stays the same width
/// all the way round the corners. The first version had a card corner tighter than the
/// phone's, and the gap pinched at the corners. Every onboarding screen that shows a drawn
/// iPhone uses this view, so the rule holds everywhere by construction.
enum OnboardingPhoneMetrics {
    /// The phone's corner radius, at the end the card shows.
    static let phoneCornerRadius: CGFloat = 44
    /// The gap between the card's edge and the phone's outer edge, at the sides and at the
    /// end the card shows.
    static let phoneInset: CGFloat = 10
    /// Concentric with the phone: its radius plus the gap.
    static let cardCornerRadius: CGFloat = phoneCornerRadius + phoneInset
    /// The phone outline's width, drawn inside the phone's shape.
    static let phoneFrameWidth: CGFloat = 7
    /// How far the phone runs past the card's cut edge, so the crop cuts through it.
    static let overrun: CGFloat = 24
    /// The phone's outline: a light grey on light, a slate on dark.
    static let phoneFrame = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x2A3346))

    /// The phone's screen: the outline's inner curve at the end the card shows, square at
    /// the cut. A scene clipped to it never sits under the frame (#679, #681).
    static func screenShape(end: OnboardingPhoneEnd) -> UnevenRoundedRectangle {
        let radius = phoneCornerRadius - phoneFrameWidth
        let showsBottom = end == .bottom
        return UnevenRoundedRectangle(
            topLeadingRadius: showsBottom ? 0 : radius,
            bottomLeadingRadius: showsBottom ? radius : 0,
            bottomTrailingRadius: showsBottom ? radius : 0,
            topTrailingRadius: showsBottom ? 0 : radius,
            style: .continuous
        )
    }
}

/// Which end of the drawn iPhone an `OnboardingPhoneCard` shows.
enum OnboardingPhoneEnd {
    /// The status bar end; the phone runs off the card's bottom edge.
    case top
    /// The home indicator end; the phone runs off the card's top edge.
    case bottom
}

/// The drawn iPhone in its card. Metrics in `OnboardingPhoneMetrics` (a generic view
/// cannot hold static stored properties).
///
/// `header` sits inside the card, above the phone, which then runs off under it instead
/// of off the card's edge: the voice notes scene's chips (#680, mock-up
/// `07a-scene-memos-vocaux`). Most cards have none.
struct OnboardingPhoneCard<Content: View, Header: View>: View {
    /// The end of the phone the card shows.
    var end: OnboardingPhoneEnd = .top
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    private typealias Metrics = OnboardingPhoneMetrics

    init(end: OnboardingPhoneEnd = .top,
         @ViewBuilder header: () -> Header,
         @ViewBuilder content: () -> Content) {
        self.end = end
        self.header = header()
        self.content = content()
    }

    /// Whether `header` draws anything. `EmptyView` is the type of "no header".
    private var hasHeader: Bool { Header.self != EmptyView.self }

    var body: some View {
        let showsTop = end == .top
        let phoneRadius = Metrics.phoneCornerRadius
        let phoneShape = UnevenRoundedRectangle(
            topLeadingRadius: showsTop ? phoneRadius : 0,
            bottomLeadingRadius: showsTop ? 0 : phoneRadius,
            bottomTrailingRadius: showsTop ? 0 : phoneRadius,
            topTrailingRadius: showsTop ? phoneRadius : 0,
            style: .continuous
        )
        // Concentric at the end that shows the phone. At the cut edge the card is a plain
        // card: rounded like the shell's others when the phone runs off its top (#679,
        // mock-up 05), straight when it runs off its bottom (mock-up 03).
        let concentric = Metrics.cardCornerRadius
        let cutEdge = OnboardingMetrics.cardCornerRadius
        let cardShape = UnevenRoundedRectangle(
            topLeadingRadius: showsTop ? concentric : cutEdge,
            bottomLeadingRadius: showsTop ? 0 : concentric,
            bottomTrailingRadius: showsTop ? 0 : concentric,
            topTrailingRadius: showsTop ? concentric : cutEdge,
            style: .continuous
        )
        let overrunEdge: Edge.Set = showsTop ? .bottom : .top
        let phone = content
            .frame(maxWidth: .infinity, alignment: .leading)
            // The phone is drawn taller than the card so the crop below cuts through it:
            // no edge at the cut, the phone runs off the card.
            .background(phoneShape.fill(Color.dictusBackground).padding(overrunEdge, -Metrics.overrun))
            .overlay(
                phoneShape
                    .strokeBorder(Metrics.phoneFrame, lineWidth: Metrics.phoneFrameWidth)
                    .padding(overrunEdge, -Metrics.overrun)
            )
        VStack(spacing: 0) {
            if hasHeader {
                header
                // Under a header the phone is cut at its own edge, so its overrun does
                // not run up over the header.
                phone.clipped()
            } else {
                phone
            }
        }
        .padding(.horizontal, Metrics.phoneInset)
        .padding(showsTop ? .top : .bottom, Metrics.phoneInset)
        .background(cardShape.fill(Color.dictusSurface))
        // Rounded where the phone shows, cut through the phone at the other edge.
        .clipShape(cardShape)
    }
}

extension OnboardingPhoneCard where Header == EmptyView {
    /// A card with the phone alone, which is every card but the voice notes scene's.
    init(end: OnboardingPhoneEnd = .top, @ViewBuilder content: () -> Content) {
        self.init(end: end, header: { EmptyView() }, content: content)
    }
}

// MARK: - Fit to height

/// Shows `content` whole in the height it is given: at its natural size when that fits,
/// scaled down uniformly, from its top centre, when it does not. Never clipped.
///
/// WHY (#680, Pierre's device test of 18dc4e99): a scene page used to scroll its card like
/// any other page. While the model downloads, the download pill takes a row above *Next*,
/// the scroll view gets shorter, and the bottom of the drawn iPhone went under the page's
/// edge: on an iPhone 15 Pro Max the keyboard's globe row touched the card's edge and the
/// phone's frame was gone. A picture of a phone must read as a whole phone, pill or no
/// pill, on every screen, so the card shrinks instead.
///
/// WHY SCALE AND NOT RE-LAYOUT: the scenes are drawn at fixed point sizes and scaled as one
/// picture (`SmartModesScene`); the card around them is drawn the same way. Scaling the
/// card as a whole keeps the phone, its frame and the card's corners in proportion.
struct OnboardingFitToHeight<Content: View>: View {
    @ViewBuilder let content: Content

    /// The content's height at the full width, measured.
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let scale = naturalHeight > geometry.size.height && naturalHeight > 0
                ? geometry.size.height / naturalHeight
                : 1
            content
                .frame(width: geometry.size.width)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { naturalHeight = $0 }
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }
}

// MARK: - Drawn Settings pieces

// The parts of a drawn iOS Settings page that more than one step draws: the keyboard step
// (Settings > Apps > Dictus) and the Apple Intelligence step (Settings > Siri > Language,
// #683). Only iOS system UI is drawn this way (#649 decision 13).

/// A step number in a circle: accent while the loop points at it, grey otherwise.
struct OnboardingStepBadge: View {
    let number: Int
    let isLit: Bool

    var body: some View {
        Text(verbatim: "\(number)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isLit ? Color.white : Color.secondary)
            .frame(width: 26, height: 26)
            .background(Circle().fill(isLit ? Color.dictusAccent : Color.primary.opacity(0.08)))
            .animation(.easeInOut(duration: 0.25), value: isLit)
    }
}

/// A Settings row icon: a white symbol on a coloured (or gradient) rounded square.
struct DictusIconTileSymbol: View {
    let systemName: String
    let fill: AnyShapeStyle

    init(systemName: String, fill: Color) {
        self.systemName = systemName
        self.fill = AnyShapeStyle(fill)
    }

    init(systemName: String, fill: some ShapeStyle) {
        self.systemName = systemName
        self.fill = AnyShapeStyle(fill)
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill))
    }
}

extension View {
    /// A white (or dark surface) inset group, as in Settings.
    func onboardingSettingsGroup() -> some View {
        background(Color.dictusSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
