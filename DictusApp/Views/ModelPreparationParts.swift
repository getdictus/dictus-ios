// DictusApp/Views/ModelPreparationParts.swift
// The pieces of the model preparation screen: the ring around the logo and a row of the
// two-step card. Issue #708.
import SwiftUI
import DictusCore

/// Sizes of the preparation screen, from the validated mock-up (#708).
///
/// WHY EVERY BLOCK HAS A FIXED HEIGHT: a phase change swaps the content of a block and
/// never its size, so nothing on the screen moves vertically between the download, the
/// optimization and the ready state. The screen it replaces moved three times: the bar
/// under the download disappeared at the compile (#533), and the completion state was a
/// third layout swapped in with a scale.
enum ModelPreparationMetrics {
    static let ringDiameter: CGFloat = 168
    /// Inner radius at about 90 % of the outer one.
    static let ringLineWidth: CGFloat = 8.5
    static let discDiameter: CGFloat = 100
    static let logoHeight: CGFloat = 40

    static let ringToTitle: CGFloat = 32
    /// Two lines of the title, bottom-aligned, so a one-line title sits where the second
    /// line of a two-line one would.
    static let titleHeight: CGFloat = 72
    static let titleToSubtitle: CGFloat = 10
    /// Three lines of the subtitle, top-aligned.
    static let subtitleHeight: CGFloat = 72
    static let subtitleToCard: CGFloat = 20
    static let rowHeight: CGFloat = 22
    static let rowSpacing: CGFloat = 12
    static let cardVerticalPadding: CGFloat = 16
    static let cardHorizontalPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 18
    static let cardToCaption: CGFloat = 14
    /// Two caption lines.
    static let captionHeight: CGFloat = 42

    /// Side margins of the text and the card (32 pt in the mock-up).
    static let horizontalPadding: CGFloat = 32

    /// One full turn of the spinning arc. The brief asks for a continuous linear turn and
    /// names no speed; this is the pace of the system's own activity indicators.
    static let spinPeriod: TimeInterval = 1.2

    /// The grey track under the arc: the mock-up's `surface-2`.
    static let track = Color(light: Color(hex: 0xE5E5EA), dark: Color(hex: 0x232B3B))
}

// MARK: - Ring

/// The ring around the Dictus logo (#708).
///
/// - downloading: the real fraction, from 12 o'clock clockwise, eased between ticks like
///   the onboarding's download pill.
/// - optimizing or loading: a short arc that turns continuously. No percentage, because
///   Core ML reports none for a compile (#432, #533): the ring says the app is working and
///   claims nothing about how far along it is.
/// - ready: the arc closes to a full circle, then turns green.
///
/// WHY A TIMELINE AND NOT `repeatForever`: a repeating animation keeps running, or jumps,
/// when the state it was started from changes under it, and this ring changes state twice.
/// An angle computed from the clock is exact at every frame and stops where it is told.
struct ModelPreparationRingView: View {
    let ring: ModelPreparationRing

    /// When the current turn started, so a new spin starts at 12 o'clock, where the
    /// download's arc started.
    @State private var spinStart = Date()

    /// Where the arc stood when it stopped turning, so the closing arc grows from there
    /// instead of jumping back to 12 o'clock.
    @State private var frozenAngle: Double = 0

    /// Set a beat after the ring closes: first the circle completes, then it turns green.
    @State private var isGreen = false

    private typealias Metrics = ModelPreparationMetrics

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: ring != .spinning)) { context in
            ZStack {
                Circle()
                    .inset(by: Metrics.ringLineWidth / 2)
                    .stroke(Metrics.track, lineWidth: Metrics.ringLineWidth)

                Circle()
                    .inset(by: Metrics.ringLineWidth / 2)
                    .trim(from: 0, to: ring.arcEnd)
                    .stroke(
                        isGreen ? Color.dictusSuccess : Color.dictusAccent,
                        style: StrokeStyle(lineWidth: Metrics.ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90 + angle(at: context.date)))

                Circle()
                    .fill(Color.dictusSurface)
                    .frame(width: Metrics.discDiameter, height: Metrics.discDiameter)

                DictusLogo(height: Metrics.logoHeight)
            }
        }
        .frame(width: Metrics.ringDiameter, height: Metrics.ringDiameter)
        .animation(.easeInOut(duration: 0.35), value: ring.arcEnd)
        .onChange(of: ring) { oldValue, newValue in
            switch newValue {
            case .spinning where oldValue != .spinning:
                spinStart = Date()
            case .closed:
                frozenAngle = oldValue == .spinning ? spinAngle(at: Date()) : 0
                // The brief: closes to 360°, then turns green in about 200 ms, ease-out.
                // The close is the 0.35 s above; the colour waits for it.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.easeOut(duration: 0.2)) {
                        isGreen = true
                    }
                }
            default:
                break
            }
        }
        .onAppear {
            // A screen that opens already closed (a model loaded before it appeared) is
            // green from the first frame: there is no close to watch.
            if ring == .closed { isGreen = true }
        }
        // The steps card says the same thing in words, so VoiceOver reads it there.
        .accessibilityHidden(true)
    }

    private func angle(at date: Date) -> Double {
        switch ring {
        case .spinning: return spinAngle(at: date)
        case .closed: return frozenAngle
        case .fraction: return 0
        }
    }

    private func spinAngle(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(spinStart)
        return (elapsed / Metrics.spinPeriod).truncatingRemainder(dividingBy: 1) * 360
    }
}

// MARK: - Step row

/// One row of the two-step card: an icon, a label and an optional value on the right.
///
/// - pending: empty circle, tertiary label
/// - running: spinner in the accent colour, semibold primary label
/// - done: green check, secondary label
struct ModelPreparationStepRow: View {
    let state: ModelPreparationStepState
    let label: Text
    /// The download's percentage while it runs. nil otherwise.
    var value: Text?

    private typealias Metrics = ModelPreparationMetrics

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: Metrics.rowHeight, height: Metrics.rowHeight)

            label
                .font(.system(size: 17, weight: state == .running ? .semibold : .regular))
                .foregroundStyle(labelStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            if let value {
                value
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.dictusAccent)
                    .lineLimit(1)
            }
        }
        .frame(height: Metrics.rowHeight)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.tertiary)
        case .running:
            ProgressView()
                .controlSize(.small)
                .tint(Color.dictusAccent)
        case .done:
            Image(systemName: "checkmark.circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.dictusSuccess)
        }
    }

    private var labelStyle: HierarchicalShapeStyle {
        switch state {
        case .pending: return .tertiary
        case .running: return .primary
        case .done: return .secondary
        }
    }
}
