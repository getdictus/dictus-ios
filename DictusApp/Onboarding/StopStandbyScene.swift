// DictusApp/Onboarding/StopStandbyScene.swift
// How to stop Dictus: the standby Live Activity's power button, drawn and looping (#681).
import SwiftUI
import DictusCore

/// The onboarding step that shows how to stop Dictus's standby (#681, #649 decision 19,
/// mock-ups `11-arreter-dictus-dynamic-island` and `11b-arreter-dictus-ecran-verrouille`).
///
/// WHY THIS STEP: between dictations Dictus keeps its engine warm, which is the orange
/// microphone dot, and users keep asking how to turn it off. The control exists, the power
/// button of the standby Live Activity (`StopStandbyIntent`), but it sits behind a long
/// press on the island and nobody finds it. The step comes right after the first dictation,
/// the moment that standby appears for real.
///
/// WHICH PICTURE: an iPhone with a Dynamic Island is shown the island (compact, long press,
/// expanded, tap the power button, gone); any other is shown the Lock Screen banner, which
/// carries the same button. `DeviceCapabilities.hasDynamicIsland` decides, from the model
/// identifier; the script is `StopStandbySceneScript`.
struct StopStandbyPage: View {
    let onNext: () -> Void

    /// Read once: the hardware does not change while the page is on screen.
    private let device = DeviceCapabilities.current()

    private var variant: StopStandbySceneScript.Variant {
        StopStandbySceneScript.Variant(hasDynamicIsland: device.hasDynamicIsland)
    }

    var body: some View {
        OnboardingPage(title: Text("To stop Dictus", comment: "Onboarding, how to stop Dictus step: title (#681)."),
                       subtitle: line) {
            StopStandbyCard(variant: variant)
        } bottom: {
            OnboardingPrimaryButton(Text("Got it"), action: onNext)
                .accessibilityIdentifier("onboarding.primary")
        }
        .onAppear {
            PersistentLog.log(.onboardingStopStandbyShown(
                variant: variant.rawValue, model: device.deviceModelIdentifier
            ))
        }
    }

    /// The line under the title. It names the gesture of the picture below it, so it
    /// changes with the variant.
    private var line: Text {
        switch variant {
        case .island:
            return Text("Between dictations, Dictus stays ready: that's the orange dot. To stop it, touch and hold the island.",
                        comment: "Onboarding, how to stop Dictus step, iPhone with a Dynamic Island: the line under the title. 'The island' is the Dynamic Island; the orange dot is iOS's microphone indicator (#681).")
        case .lockScreen:
            return Text("Between dictations, Dictus stays ready. To stop it, tap the power button on the Lock Screen.",
                        comment: "Onboarding, how to stop Dictus step, iPhone without a Dynamic Island: the line under the title (#681).")
        }
    }
}

// MARK: - Card

/// The white card: the three named steps above the phone on an island iPhone (mock-up 11),
/// the phone alone on the Lock Screen (mock-up 11b).
///
/// WHY THE STEPS ARE INSIDE THE PLAYER: the step lit follows the scene's clock, so they are
/// part of the drawing, paused and stilled with it.
private struct StopStandbyCard: View {
    let variant: StopStandbySceneScript.Variant

    private typealias Phone = OnboardingPhoneMetrics

    var body: some View {
        AnimatedScenePlayer(
            loopSeconds: StopStandbySceneScript.loopSeconds,
            stillSeconds: StopStandbySceneScript.stillSeconds(variant)
        ) { time in
            let frame = StopStandbySceneScript.frame(at: time, variant: variant)
            VStack(spacing: 0) {
                if variant == .island {
                    StopStandbyChips(lit: frame.chip)
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                }
                OnboardingPhoneCard(end: .top) {
                    screen(frame)
                        .clipShape(Phone.screenShape(end: .top))
                        .padding(.horizontal, Phone.phoneFrameWidth)
                        .padding(.top, Phone.phoneFrameWidth)
                }
            }
        }
        .background(Color.dictusSurface)
        // Rounded at the bottom too, as both mock-ups draw it. At the top: concentric with
        // the phone when the phone is the first thing in the card, the shell's card radius
        // above the steps.
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: OnboardingMetrics.cardCornerRadius,
            bottomTrailingRadius: OnboardingMetrics.cardCornerRadius,
            topTrailingRadius: topRadius,
            style: .continuous
        ))
    }

    private var topRadius: CGFloat {
        variant == .island ? OnboardingMetrics.cardCornerRadius : Phone.cardCornerRadius
    }

    @ViewBuilder
    private func screen(_ frame: StopStandbySceneScript.Frame) -> some View {
        switch variant {
        case .island: StopStandbyIslandScreen(frame: frame)
        case .lockScreen: StopStandbyLockScreen(frame: frame)
        }
    }
}

/// "1 Island › 2 Long press › 3 Stop" above the phone (mock-up 11). Every number in blue,
/// the step the scene is on tinted.
private struct StopStandbyChips: View {
    let lit: StopStandbySceneScript.Chip?

    var body: some View {
        HStack(spacing: 8) {
            chip(.island, Text("Island", comment: "Onboarding, how to stop Dictus step: first of three steps above the drawing, the Dynamic Island. One short word (#681)."))
            chevron
            chip(.longPress, Text("Long press", comment: "Onboarding, how to stop Dictus step: second of three steps above the drawing, touching and holding the island. Two short words (#681)."))
            chevron
            chip(.stop, Text("Stop", comment: "Onboarding, how to stop Dictus step: third of three steps above the drawing, tapping the power button. One short word (#681)."))
        }
        .font(.subheadline.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .animation(.easeInOut(duration: 0.25), value: lit)
    }

    private func chip(_ step: StopStandbySceneScript.Chip, _ label: Text) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(step.rawValue)")
                .foregroundStyle(Color.dictusAccent)
            label
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(step == lit ? Self.litFill : Self.fill))
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    /// A step at rest: the grouped grey on light, the page's navy on dark.
    private static let fill = Color(light: Color(hex: 0xF2F2F7), dark: Color(hex: 0x0A1628))
    /// The step on screen: a pale accent, as the mock-up's third chip.
    private static let litFill = Color.dictusAccent.opacity(0.14)
}

// MARK: - Metrics

/// The drawn screen, in points of a 402 pt wide iPhone (the mock-ups' width), scaled to
/// the card as one picture like the Smart Modes scene (`SmartModesSceneMetrics`).
///
/// The Live Activity's own numbers repeat `DictusLiveActivity` (DictusWidgets), which the
/// app cannot import. The island's sizes are iOS's, measured on a 402 pt iPhone; the
/// widget does not choose them.
private enum StopStandbyMetrics {
    static let screenWidth: CGFloat = 402
    /// The part of the screen the card shows, from the top. Sized so the whole card, the
    /// steps above the phone included, sits above the button on a 874 pt iPhone without
    /// scrolling; the Lock Screen has no steps, so it shows more of its screen.
    static func screenHeight(_ variant: StopStandbySceneScript.Variant) -> CGFloat {
        variant == .island ? 470 : 550
    }

    // The Dynamic Island.
    static let islandTop: CGFloat = 11
    /// The bare camera cut-out, with no activity.
    static let bareSize = CGSize(width: 126, height: 37)
    /// The compact island holding the logo bars and "On".
    static let compactSize = CGSize(width: 196, height: 37)
    /// The expanded island with the standby layout (leading and trailing regions only).
    static let expandedSize = CGSize(width: 372, height: 84)
    static let expandedCornerRadius: CGFloat = 42
    static let expandedSideInset: CGFloat = 22

    /// `expandedTrailing`, `.standby`: two 32 pt circles, 10 pt apart.
    static let islandButton: CGFloat = 32
    static let islandButtonSpacing: CGFloat = 10

    // The Lock Screen banner (`lockScreenView`, `.standby`).
    static let bannerTop: CGFloat = 236
    static let bannerSideInset: CGFloat = 14
    static let bannerPadding: CGFloat = 16
    static let bannerButton: CGFloat = 36
    static let bannerButtonSpacing: CGFloat = 8
    static let bannerCornerRadius: CGFloat = 24
    static var bannerHeight: CGFloat { bannerPadding * 2 + bannerButton }

    /// The island's centre with no activity and compact: where the finger holds.
    static var islandPressPoint: CGPoint {
        CGPoint(x: screenWidth / 2, y: islandTop + compactSize.height / 2)
    }

    /// The power button's centre in the expanded island.
    static var islandPowerPoint: CGPoint {
        let trailingEdge = screenWidth / 2 + expandedSize.width / 2 - expandedSideInset
        let micCentre = trailingEdge - islandButton / 2
        return CGPoint(
            x: micCentre - islandButton - islandButtonSpacing,
            y: islandTop + expandedSize.height / 2
        )
    }

    /// The power button's centre in the Lock Screen banner.
    static var bannerPowerPoint: CGPoint {
        let trailingEdge = screenWidth - bannerSideInset - bannerPadding
        let micCentre = trailingEdge - bannerButton / 2
        return CGPoint(
            x: micCentre - bannerButton - bannerButtonSpacing,
            y: bannerTop + bannerHeight / 2
        )
    }
}

// MARK: - Island screen

/// An island iPhone's Home Screen with the standby in its Dynamic Island. iOS's own UI,
/// so drawn (#649 decision 13); the island's content is the widget's standby layout.
private struct StopStandbyIslandScreen: View {
    let frame: StopStandbySceneScript.Frame

    private typealias Metrics = StopStandbyMetrics

    var body: some View {
        GeometryReader { geometry in
            screen
                .frame(width: Metrics.screenWidth, height: Metrics.screenHeight(.island), alignment: .top)
                .scaleEffect(geometry.size.width / Metrics.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Metrics.screenWidth / Metrics.screenHeight(.island), contentMode: .fit)
    }

    private var screen: some View {
        // WHY CLIPPED AND TOP-ALIGNED: the icon grid runs past the part of the screen the
        // card shows; without it the overflow would be centred and push the island up.
        ZStack(alignment: .top) {
            LinearGradient(colors: [Self.wallpaperTop, Self.wallpaperBottom], startPoint: .top, endPoint: .bottom)
            SceneHomeIcons()
                .padding(.top, 104)
            SceneStatusBar()
            island
                .padding(.top, Metrics.islandTop)
        }
        .overlay(alignment: .topLeading) {
            if let finger = frame.finger {
                SceneFinger(isPressed: finger.isPressed)
                    .opacity(finger.opacity)
                    .position(fingerPoint(finger))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: frame.activity)
        .animation(.easeInOut(duration: 0.2), value: frame.isPowerLit)
    }

    private var island: some View {
        let size = islandSize
        return ZStack {
            RoundedRectangle(
                cornerRadius: frame.activity == .expanded ? Metrics.expandedCornerRadius : size.height / 2,
                style: .continuous
            )
            .fill(Color.black)
            .shadow(color: .black.opacity(frame.activity == .expanded ? 0.25 : 0), radius: 14, y: 6)

            switch frame.activity {
            case .compact:
                compactContent
                    .transition(.opacity)
            case .expanded:
                expandedContent
                    .transition(.opacity)
            case .none:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var islandSize: CGSize {
        switch frame.activity {
        case .none: return Metrics.bareSize
        case .compact: return Metrics.compactSize
        case .expanded: return Metrics.expandedSize
        }
    }

    /// `compactLeading` / `compactTrailing`, `.standby`: the logo bars, then "On".
    private var compactContent: some View {
        HStack {
            SceneLogoBars()
                .frame(width: 20, height: 14)
            Spacer(minLength: 0)
            Text(verbatim: LiveActivityStrings.on)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
    }

    /// `expandedLeading` / `expandedTrailing`, `.standby`.
    private var expandedContent: some View {
        HStack(spacing: 8) {
            SceneLogoBars()
                .frame(width: 24, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Dictus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(verbatim: LiveActivityStrings.on)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: Metrics.islandButtonSpacing) {
                ScenePowerButton(
                    diameter: Metrics.islandButton,
                    iconOpacity: 0.8,
                    fillOpacity: 0.15,
                    isLit: frame.isPowerLit,
                    isPressed: frame.finger.map { $0.isPressed && $0.travel == 1 } ?? false
                )
                SceneMicButton(diameter: Metrics.islandButton)
            }
        }
        .padding(.horizontal, Metrics.expandedSideInset)
    }

    /// From the island's centre, where it holds, to the power button.
    private func fingerPoint(_ finger: StopStandbySceneScript.Finger) -> CGPoint {
        let from = Metrics.islandPressPoint
        let to = Metrics.islandPowerPoint
        let travel = CGFloat(finger.travel)
        return CGPoint(x: from.x + (to.x - from.x) * travel, y: from.y + (to.y - from.y) * travel)
    }

    /// A pale blue Home Screen on light, a navy one on dark, as the mock-ups draw it.
    private static let wallpaperTop = Color(light: Color(hex: 0xA3BBE7), dark: Color(hex: 0x1F2C4D))
    private static let wallpaperBottom = Color(light: Color(hex: 0xC9D6EF), dark: Color(hex: 0x2B3B60))
}

/// The status bar either side of the island: the time, then signal, Wi-Fi and battery.
/// The expanded island covers it, as on the device.
private struct SceneStatusBar: View {
    var body: some View {
        HStack {
            Text(verbatim: "9:41")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 110)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 110)
        }
        .foregroundStyle(.primary)
        .frame(height: StopStandbyMetrics.compactSize.height)
        .padding(.top, StopStandbyMetrics.islandTop)
        .padding(.horizontal, 6)
    }
}

/// The Home Screen's icons, as blank rounded squares: the scene is about the island.
private struct SceneHomeIcons: View {
    var body: some View {
        VStack(spacing: 30) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 30) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Self.icon)
                            .frame(width: 64, height: 64)
                    }
                }
            }
        }
    }

    private static let icon = Color(light: Color.white.opacity(0.45), dark: Color.white.opacity(0.12))
}

// MARK: - Lock Screen

/// An iPhone's Lock Screen with the standby banner under the clock (`lockScreenView`,
/// `.standby`). The banner is the widget's layout; the rest is iOS, drawn.
private struct StopStandbyLockScreen: View {
    let frame: StopStandbySceneScript.Frame

    private typealias Metrics = StopStandbyMetrics

    var body: some View {
        GeometryReader { geometry in
            screen
                .frame(width: Metrics.screenWidth, height: Metrics.screenHeight(.lockScreen), alignment: .top)
                .scaleEffect(geometry.size.width / Metrics.screenWidth, anchor: .topLeading)
        }
        .aspectRatio(Metrics.screenWidth / Metrics.screenHeight(.lockScreen), contentMode: .fit)
    }

    private var screen: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Self.wallpaperTop, Self.wallpaperBottom], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 0) {
                // Today's date in the app's language, as the Lock Screen writes it: in
                // French "lundi 12 octobre", not "Lundi", hence the sentence context.
                Text(Date.now, format: Date.FormatStyle(capitalizationContext: .middleOfSentence)
                    .weekday(.wide).day().month(.wide))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(verbatim: "9:41")
                    .font(.system(size: 100, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, 54)

            if frame.activity == .expanded {
                banner
                    .padding(.top, Metrics.bannerTop)
                    .padding(.horizontal, Metrics.bannerSideInset)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .overlay(alignment: .topLeading) {
            if let finger = frame.finger {
                SceneFinger(isPressed: finger.isPressed)
                    .opacity(finger.opacity)
                    .position(Metrics.bannerPowerPoint)
            }
        }
        .animation(.easeOut(duration: 0.3), value: frame.activity)
        .animation(.easeInOut(duration: 0.2), value: frame.isPowerLit)
    }

    /// `lockScreenView`, `.standby`: logo, "Dictus / On", power and mic.
    private var banner: some View {
        HStack(spacing: 12) {
            SceneLogoBars()
                .frame(width: 28, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Dictus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(verbatim: LiveActivityStrings.on)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: Metrics.bannerButtonSpacing) {
                ScenePowerButton(
                    diameter: Metrics.bannerButton,
                    iconOpacity: 0.7,
                    fillOpacity: 0.1,
                    isLit: frame.isPowerLit,
                    isPressed: frame.finger?.isPressed ?? false
                )
                SceneMicButton(diameter: Metrics.bannerButton)
            }
        }
        .padding(Metrics.bannerPadding)
        .frame(height: Metrics.bannerHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.bannerCornerRadius, style: .continuous)
                .fill(Color(hex: 0x0A1628))
        )
    }

    /// A blue wallpaper, the same in light and dark: the Lock Screen is the user's, not
    /// the app's, and the mock-up draws one.
    private static let wallpaperTop = Color(hex: 0x213C8C)
    private static let wallpaperBottom = Color(hex: 0x3E80FF)
}

// MARK: - Live Activity pieces

/// The power button (`StopStandbyIntent`), lit with the accent ring while the finger
/// heads for it (mock-ups 11 and 11b).
private struct ScenePowerButton: View {
    let diameter: CGFloat
    let iconOpacity: Double
    let fillOpacity: Double
    let isLit: Bool
    let isPressed: Bool

    var body: some View {
        Image(systemName: "power")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(iconOpacity))
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(Color.white.opacity(isPressed ? fillOpacity + 0.15 : fillOpacity)))
            .overlay(
                Circle()
                    .strokeBorder(Color.dictusAccent, lineWidth: 3)
                    .padding(-5)
                    .opacity(isLit ? 1 : 0)
            )
            .scaleEffect(isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
    }
}

/// The record button next to it.
private struct SceneMicButton: View {
    let diameter: CGFloat

    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(Color.dictusAccent))
    }
}

/// The widget's `MiniLogoBars` at standby, still: the app icon's three bars, the centre
/// one in the brand gradient, the sides white at 45 % and 65 %.
private struct SceneLogoBars: View {
    private static let levels: [CGFloat] = [0.43, 1.0, 0.64]

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(2.5, DictusLogoGeometry.barWidth(forHeight: geometry.size.width))
            let spacing = max(0, (geometry.size.width - barWidth * 3) / 2)
            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(fill(index))
                        .frame(width: barWidth, height: Self.levels[index] * geometry.size.height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func fill(_ index: Int) -> AnyShapeStyle {
        switch index {
        case 1:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0x6BA3FF), Color(hex: 0x2563EB)], startPoint: .top, endPoint: .bottom
            ))
        case 0:
            return AnyShapeStyle(Color.white.opacity(0.45))
        default:
            return AnyShapeStyle(Color.white.opacity(0.65))
        }
    }
}

// MARK: - Live Activity strings

/// The words the standby Live Activity shows, read from the widget extension's own
/// catalog, so the drawing says exactly what the island says ("Actif" in French).
///
/// WHY NOT `String(localized:)`: that would extract the key into the app's catalog, which
/// would then own a second translation free to drift from the widget's. Same reason as
/// `KeyboardStrings` for the keyboard's captions.
private enum LiveActivityStrings {
    private static let bundle: Bundle = Bundle.main.builtInPlugInsURL
        .map { $0.appendingPathComponent("DictusWidgets.appex") }
        .flatMap(Bundle.init(url:)) ?? .main

    /// `"On"`: the standby is on, ready to record.
    static var on: String {
        bundle.localizedString(forKey: "On", value: "On", table: "Localizable")
    }
}
