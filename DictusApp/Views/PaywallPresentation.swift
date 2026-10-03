// DictusApp/Views/PaywallPresentation.swift
// One way to open the Dictus Pro hub, shared by every entry point: it comes down from the top (#216).
import SwiftUI
import DictusCore

extension View {
    /// Presents the Dictus Pro hub over the whole screen.
    ///
    /// WHY modal rather than a push inside the tab's NavigationStack:
    /// the iOS 26 tab bar floats above scroll content instead of insetting it,
    /// so a pushed paywall had the tab bar sitting across its subscribe button.
    /// Hiding the bar for the duration of the push fixed that but moved the cost
    /// to the way back: the bar is only re-inserted once the pop animation has
    /// finished, and re-inserting it changes the safe area, so the screen behind
    /// visibly re-laid out — everything jumped upward a frame after landing.
    /// A cover never touches the tab bar at all, so the screen underneath is
    /// already whole when the paywall goes away.
    ///
    /// The purchase funnel is also the one place tab navigation should not be
    /// offered, which a cover gives for free rather than by suppression.
    ///
    /// WHY its own NavigationStack: the cover is presented outside the tab's
    /// stack, so the paywall would otherwise have no navigation bar to hang its
    /// close button on.
    ///
    /// **The hub comes down from the top, from every entry point** (#216 decisions
    /// 9 and 10): the Home header, the Settings row, the Home banner, the keyboard's
    /// pill. One place, one way to arrive. It is still a `fullScreenCover`, for every
    /// reason above; only its entrance is ours (`ProHubDropContainer`).
    ///
    /// `framing` is `.trialEnded` for the one presentation the app makes on its own,
    /// at the end of the reverse trial (#593); every entry point the user taps keeps
    /// the default. That one keeps the system's bottom-up cover: it is a sales page
    /// the app raised, not the hub the user pulled down (decision 3).
    func paywallCover(isPresented: Binding<Bool>, framing: PaywallFraming = .standard) -> some View {
        Group {
            if framing == .trialEnded {
                fullScreenCover(isPresented: isPresented) {
                    NavigationStack {
                        PaywallView(framing: framing)
                    }
                }
            } else {
                modifier(ProHubCover(isPresented: isPresented))
            }
        }
    }
}

/// Whether the hub can be reached from Settings and the Home header (#216).
///
/// `PremiumFlags.paywallVisible`, plus in DEBUG the forced entitlement (#577): under
/// the force the hub sells nothing (`ProHubBottomBlock.entitledWithoutPurchase`) and is
/// the only way to the Pro feature screens, so the maintainer can reach them, and feel
/// the header pull on a device, without shipping the flag. Release has one gate.
enum ProHubEntry {
    static var isReachable: Bool {
        #if DEBUG
        return PremiumFlags.paywallVisible || PremiumFlags.debugProEntitlementForced
        #else
        return PremiumFlags.paywallVisible
        #endif
    }
}

/// How the hub leaves when something inside it asks to close: its close button, the
/// thank-you screen's Continue.
///
/// WHY an environment action and not `\.dismiss`: `dismiss` would take the cover down
/// with the system's slide, downward, which is the wrong direction for a screen that
/// came from the top. Inside `ProHubDropContainer` this runs the upward exit instead;
/// everywhere else it is nil and `PaywallView` falls back on `dismiss`.
struct ProHubCloseAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

private struct ProHubCloseKey: EnvironmentKey {
    static let defaultValue: ProHubCloseAction? = nil
}

extension EnvironmentValues {
    var proHubClose: ProHubCloseAction? {
        get { self[ProHubCloseKey.self] }
        set { self[ProHubCloseKey.self] = newValue }
    }
}

/// The hub's feel, in one place. These are the numbers the device round is expected
/// to move (#216 comment of 2026-09-30: the mock-up fixed the idea, not the spring).
enum ProHubMotion {
    /// The drop and the return. Slightly under-damped so the hub settles with the
    /// small give of something pulled down, without a visible bounce.
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)

    /// Under Reduce Motion the hub cross-fades instead of travelling (decision 9).
    static let crossFade = Animation.easeInOut(duration: 0.25)

    /// How dark the screen behind gets once the hub is down. The hub is opaque, so
    /// this only shows while it travels, and it is what makes the travel read as
    /// something arriving over the screen rather than the screen scrolling.
    static let backdropOpacity = 0.35

    /// How far up the hub must be pushed, in points, before letting go closes it.
    static let dismissDistance: CGFloat = 90

    /// Pull on the Home header: the finger's travel (actual or predicted, so a flick
    /// counts) past which letting go opens the hub.
    static let headerPullThreshold: CGFloat = 70

    /// Pull on the Home header: how much of the finger's travel the header follows.
    /// Under 1 so it reads as elastic rather than dragged.
    static let headerRubberBand: CGFloat = 0.5

    /// Pull on the Home header: the most the header moves, whatever the finger does.
    static let headerMaxTravel: CGFloat = 90

    /// Pull on the Home header: how much Home dims at full travel, announcing the
    /// hub before it arrives.
    static let headerDimming = 0.3

    /// The resisted travel for a finger that moved `translation` points.
    static func rubberBand(_ translation: CGFloat) -> CGFloat {
        guard translation > 0 else { return 0 }
        return min(translation * headerRubberBand, headerMaxTravel)
    }
}

/// Presents the hub from the top.
///
/// WHY a cover shown without animation, then moved by hand: SwiftUI's covers only
/// know one direction, and the hub has to keep being a cover (see `paywallCover`).
/// So the cover itself appears instantly, transparent, and its content travels down
/// inside it; leaving is the same in reverse, and the cover goes away once the
/// content is off screen.
private struct ProHubCover: ViewModifier {
    @Binding var isPresented: Bool

    /// Whether the cover is on screen. Separate from `isPresented` because the cover
    /// has to outlive the caller's `false` for as long as the exit animation runs.
    @State private var coverShown = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, wantsHub in
                // Only the opening goes through here: closing is driven from inside
                // the container, which sets `isPresented` back once it has finished.
                if wantsHub && !coverShown { setCover(true) }
                if !wantsHub && coverShown { setCover(false) }
            }
            .fullScreenCover(isPresented: $coverShown) {
                ProHubDropContainer {
                    setCover(false)
                    isPresented = false
                }
                .presentationBackground(.clear)
            }
    }

    private func setCover(_ shown: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { coverShown = shown }
    }
}

/// The hub, travelling down from the top edge and pushed back up to leave.
///
/// **Leaving by pushing up.** The hub scrolls, so a drag anywhere on it belongs to
/// the scroll view; the push lives on a grabber at the bottom edge, the way the
/// Notification Center it borrows its motion from does. The close button stays, and
/// is the path for VoiceOver.
private struct ProHubDropContainer: View {
    /// Called once the hub is off screen.
    let onClosed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 while the hub is off screen, 1 once it is down. Drives the offset, or the
    /// opacity under Reduce Motion, and the backdrop in both.
    @State private var progress: CGFloat = 0

    /// The finger's upward travel on the grabber, in points (negative is up).
    @State private var push: CGFloat = 0

    @State private var isClosing = false

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            ZStack(alignment: .top) {
                Color.black
                    .opacity(ProHubMotion.backdropOpacity * Double(progress))
                    .ignoresSafeArea()

                NavigationStack {
                    PaywallView()
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    grabber
                }
                .environment(\.proHubClose, ProHubCloseAction { close() })
                .offset(y: reduceMotion ? 0 : offset(height: height))
                .opacity(reduceMotion ? Double(progress) : 1)
            }
        }
        // The grabber sits right above the home indicator; without this the system
        // takes an upward swipe there as "go home" before the grabber sees it.
        .defersSystemGestures(on: .bottom)
        .onAppear {
            withAnimation(reduceMotion ? ProHubMotion.crossFade : ProHubMotion.spring) {
                progress = 1
            }
        }
    }

    /// Where the hub sits: a full height above the screen at progress 0, home at 1,
    /// plus the push while the grabber is held.
    private func offset(height: CGFloat) -> CGFloat {
        -height * (1 - progress) + push
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.6))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(Color.dictusBackground)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        guard !isClosing else { return }
                        // Up follows the finger; down only gives a little, the hub is
                        // already as far down as it goes.
                        let dy = value.translation.height
                        push = dy < 0 || reduceMotion ? min(dy, 0) : dy * 0.15
                    }
                    .onEnded { value in
                        let travelled = min(value.translation.height, value.predictedEndTranslation.height)
                        if travelled < -ProHubMotion.dismissDistance {
                            close()
                        } else {
                            withAnimation(ProHubMotion.spring) { push = 0 }
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(reduceMotion ? ProHubMotion.crossFade : ProHubMotion.spring) {
            progress = 0
            push = 0
        } completion: {
            onClosed()
        }
    }
}
