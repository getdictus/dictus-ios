// DictusApp/Onboarding/GlobeKeyTutorialPage.swift
// Onboarding step: the first dictation through the globe key (#678, #845).
import SwiftUI
import UIKit
import DictusCore

/// The first dictation: the page opens the keyboard on a real text field, the user switches
/// to the Dictus keyboard with the globe long-press, and dictates. The text landing in the
/// field ends the step.
///
/// THE STATES (#649 decision 1.8, #678, #845), from `FirstDictationStage`:
/// 1. Opening: the field takes focus by itself and the keyboard slides in. No hint, since
///    there is no globe to press yet.
/// 2. No keyboard (the focus did not come within a second, or the user closed the keyboard):
///    the subtitle asks for a tap on the field. Still no animation.
/// 3. Apple's keyboard is up: the drawn globe animation, between the field and the keyboard.
/// 4. Dictus's keyboard is up: a banner points at the blue mic.
///
/// WHY EVERY HINT SITS ABOVE THE KEYBOARD: the app cannot draw over a system keyboard. The
/// hint is the last view before Skip, and the page ends at the keyboard's top edge (the
/// keyboard safe area), so it can only ever be above it. Nothing is overlaid.
///
/// WHY THE PAGE FOCUSES THE FIELD (#845, decided by Pierre on 2026-10-28): #678 made tapping
/// the field the first gesture, and showed the globe animation before any keyboard was up.
/// Users read it as "do this now", found no globe, and got stuck. The keyboard now opens on
/// its own, as before #678, and the animation waits for it.
struct GlobeKeyTutorialPage: View {
    /// Called once the field holds a dictation (or typed words), or on "Continue".
    /// `OnboardingView` resets the dictation coordinator and moves on to the completion step
    /// (#675); the shell's Skip, at the bottom of the page, does the same without a dictation.
    let onComplete: () -> Void

    @State private var isFieldFocused = false
    @State private var isDictusKeyboard = false
    @State private var textFieldContent = ""

    /// True from the page's appear until the field takes focus, the focus is given up on
    /// (`FirstDictationStage.autoFocusHasFailed`), or the keyboard is closed.
    @State private var isAwaitingAutoFocus = true

    /// Bumped to ask the field for focus: once on appear, then on each return to the
    /// foreground while the field has no keyboard and the user did not close it.
    @State private var focusRequest = 1

    /// Set when the user closes the keyboard on the page: from then on, only a tap on the
    /// field opens it again (#845).
    @State private var userClosedKeyboard = false

    /// The first time another keyboard than Dictus came up, and the clock the "Continue"
    /// fallback reads (`FirstDictationStage.showsContinue`).
    @State private var otherKeyboardSince: Date?
    @State private var now = Date()

    /// Latched the first time the Dictus keyboard is up: the completion rule counts text
    /// only from then on (`FirstDictationStage.completes`), as the page did before #678.
    @State private var hasSeenDictusKeyboard = false

    /// Guard against multiple auto-advance triggers.
    @State private var hasAutoAdvanced = false

    /// Set when enough text has landed: drives `successCue` until the page moves on.
    @State private var showSuccessCue = false

    /// The stage shown once the page is leaving, so the keyboard closing on the way out
    /// does not bring back the "tap the field" state for the last fraction of a second.
    @State private var frozenStage: FirstDictationStage?

    @Environment(\.scenePhase) private var scenePhase

    /// Whether the keyboard can dictate on this device (#635). False on a pre-A14
    /// chip, where the Dictus keyboard draws its mic disabled everywhere, this page's
    /// text field included: the keyboard cannot tell that its host is DictusApp in
    /// the foreground, so it has no safe way to make an exception here. The page then
    /// asks for typing instead, and the same 3-character rule advances it.
    private let keyboardCanDictate = DeviceCapabilities.current().supportsKeyboardDictation

    private var stage: FirstDictationStage {
        frozenStage ?? FirstDictationStage(
            isFieldFocused: isFieldFocused,
            isDictusKeyboard: isDictusKeyboard,
            isAwaitingAutoFocus: isAwaitingAutoFocus
        )
    }

    private var showsContinue: Bool {
        frozenStage == nil && FirstDictationStage.showsContinue(
            secondsSinceOtherKeyboard: otherKeyboardSince.map { now.timeIntervalSince($0) },
            hasSeenDictusKeyboard: hasSeenDictusKeyboard
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: Text("Try it now"), subtitle: instruction)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.top, OnboardingMetrics.titleTopPadding)
                .padding(.bottom, 20)

            field
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                // Takes what the rest leaves (#700): the animation is sized first, and only
                // shrinks once the field is down to its minimum.
                .layoutPriority(-1)

            switch stage {
            case .opening, .beforeTap:
                EmptyView()
            case .otherKeyboard:
                // Apple's keyboard is up: the globe animation, right above it.
                KeyboardSwitchAnimation()
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.top, 12)
                    .transition(.opacity)
            case .dictusKeyboard:
                // Dictus is up: the banner, right above the keyboard.
                FirstDictationBanner(content: bannerContent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom)))
            }

            // Skip, the step's only way out without a dictation (#700). The page has no
            // button, so it sits alone in the row other steps keep under theirs, at the
            // same place. With a keyboard up it follows the page's bottom edge, between the
            // hint and the keyboard: it never goes under the keyboard. "Continue" joins it
            // when the Dictus keyboard is not detected (#845).
            OnboardingSkipRow()
                .overlay(alignment: .trailing) {
                    if showsContinue {
                        continueButton
                            .padding(.trailing, OnboardingMetrics.horizontalPadding)
                            .transition(.opacity)
                    }
                }
                .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .animation(.easeInOut(duration: 0.3), value: showsContinue)
        .task {
            // The auto-focus fallback (#845): no focus a second after the request, ask for
            // a tap.
            let requestedAt = Date()
            try? await Task.sleep(for: .seconds(FirstDictationStage.autoFocusTimeout))
            if FirstDictationStage.autoFocusHasFailed(
                secondsSinceRequest: Date().timeIntervalSince(requestedAt),
                isFieldFocused: isFieldFocused
            ) {
                isAwaitingAutoFocus = false
            }
        }
        .task(id: otherKeyboardSince) {
            // The "Continue" fallback (#845): wake once the delay has run, and let the rule
            // decide.
            guard let since = otherKeyboardSince else { return }
            let remaining = FirstDictationStage.continueDelay - Date().timeIntervalSince(since)
            if remaining > 0 {
                do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
            }
            now = Date()
        }
        .onChange(of: stage) { _, newStage in
            if newStage == .otherKeyboard && otherKeyboardSince == nil {
                otherKeyboardSince = Date()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings or the app switcher with no keyboard: ask again, unless
            // the user closed it here (#845).
            guard phase == .active, !isFieldFocused, !userClosedKeyboard, frozenStage == nil else { return }
            focusRequest += 1
        }
        .onChange(of: textFieldContent) { newValue in
            // Auto-advance when the user has dictated or typed enough text with Dictus
            // (`FirstDictationStage`: 3 characters, once the Dictus keyboard has been up).
            guard !hasAutoAdvanced,
                  FirstDictationStage.completes(text: newValue, hasSeenDictusKeyboard: hasSeenDictusKeyboard)
            else { return }
            hasAutoAdvanced = true
            frozenStage = stage
            PersistentLog.log(.onboardingGlobeTutorialTextDetected)
            // WHY 0.6 s AND A CUE (decided 2026-10-09): the fixed 1.5 s wait read as
            // "something is loading" on device. The field now turns green with a check
            // the moment the text lands, and the page leaves about 0.6 s later
            // (0.4 s here, then the 0.2 s keyboard dismissal in `advanceToSuccess`).
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                showSuccessCue = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                advanceToSuccess()
            }
        }
    }

    // MARK: - Field

    /// The real text field, on a card, outlined in blue while it has the keyboard.
    ///
    /// WHY frame minHeight + maxHeight .infinity: the field takes the height the hint
    /// leaves it, which is everything above the keyboard once one is up. The UITextView
    /// scrolls internally if the dictation is longer than that.
    ///
    /// WHY 60 PT AT LEAST (#700), AND ONE LINE UNDER THE ANIMATION (#845): on a 667 pt
    /// screen (iPhone SE) with the keyboard up, the room between the title and the keyboard
    /// is about 200 pt. While the animation shows, the field holds no text yet, so it gives
    /// up its height to it, down to one line.
    private var field: some View {
        KeyboardDetectingTextField(
            text: $textFieldContent,
            placeholder: placeholder,
            focusRequest: focusRequest,
            onFocusChange: { focused in
                guard frozenStage == nil else { return }
                isFieldFocused = focused
                if !focused {
                    isAwaitingAutoFocus = false
                    // A keyboard closed while the app is in the foreground is the user's
                    // doing; one closed on the way to the background is not.
                    if UIApplication.shared.applicationState == .active {
                        userClosedKeyboard = true
                    }
                }
            },
            onKeyboardChange: { isDictus in
                guard frozenStage == nil else { return }
                isDictusKeyboard = isDictus
                if isDictus && !hasSeenDictusKeyboard {
                    hasSeenDictusKeyboard = true
                    PersistentLog.log(.onboardingDictusKeyboardActivated)
                }
            }
        )
        .accessibilityIdentifier("onboarding.firstDictation.field")
        .frame(minHeight: stage == .otherKeyboard ? 22 : 60, maxHeight: .infinity)
        .padding(16)
        .onboardingCard(cornerRadius: 20)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isFieldFocused ? Color.dictusAccent : Color.primary.opacity(0.08),
                    lineWidth: isFieldFocused ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .overlay { successCue }
        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
    }

    /// The "it worked" cue on the text field, shown between the text landing and the page
    /// moving on: a green outline and a check in its corner, in the app's success colour,
    /// the same check the keyboard and microphone steps use for "detected" and "authorized".
    private var successCue: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.dictusSuccess, lineWidth: 2)
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white, Color.dictusSuccess)
                .padding(10)
                .scaleEffect(showSuccessCue ? 1 : 0.4)
        }
        .opacity(showSuccessCue ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// "Continue", next to Skip after 15 s on another keyboard without Dictus detected
    /// (#845). It ends the step like a dictation would, keyboard dismissal included.
    private var continueButton: some View {
        Button {
            guard !hasAutoAdvanced else { return }
            hasAutoAdvanced = true
            frozenStage = stage
            // Logged as the Skip it stands in for: no `onboardingDictusKeyboardActivated`
            // line before it is what tells the two apart from a dictation.
            PersistentLog.log(.onboardingGlobeTutorialSkipped)
            advanceToSuccess()
        } label: {
            Text("Continue")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(Color.dictusAccent)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.firstDictation.continue")
    }

    // MARK: - Copy

    /// What to do now, under the title. Changes with the stage and, on a pre-A14 chip, asks
    /// for typing instead of dictating (#635).
    private var instruction: Text {
        switch stage {
        case .opening:
            return Text("Your keyboard opens below.")
        case .beforeTap:
            return Text("Tap the field to open your keyboard")
        case .otherKeyboard:
            return Text("Long-press the globe, then choose Dictus.")
        case .dictusKeyboard:
            return keyboardCanDictate
                ? Text("Tap the blue mic and speak. The text lands here.")
                : Text("Type a few words to try the keyboard")
        }
    }

    /// The field's placeholder: an invitation to tap it, then what to put in it.
    private var placeholder: String {
        if stage == .opening || stage == .beforeTap {
            return String(localized: "Tap here to write")
        }
        return keyboardCanDictate
            ? String(localized: "Say something…")
            : String(localized: "Type something…")
    }

    /// The banner once Dictus is up.
    private var bannerContent: FirstDictationBanner.Content {
        keyboardCanDictate
            ? .init(leadingSymbol: "mic", text: Text("Tap the blue mic, then speak"), trailingSymbol: "arrow.down.right")
            : .init(leadingSymbol: "keyboard", text: Text("Type a few words"), trailingSymbol: "arrow.down")
    }

    // MARK: - Navigation

    private func advanceToSuccess() {
        // Dismiss the keyboard before the completion step slides in.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onComplete()
        }
    }
}

// MARK: - Banner

/// The coach banner above the Dictus keyboard (#678, mock-up `10c`): a capsule in the
/// Dictus blue with white text and symbols, in light and dark alike (decided by Pierre on
/// 2026-10-10 after testing on device: the first version, navy on light and white on dark,
/// read as foreign to the app). Same pairing as the onboarding's primary button: the accent
/// with white on top, and its accent-tinted shadow (a black shadow under blue reads muddy).
private struct FirstDictationBanner: View {
    struct Content {
        let leadingSymbol: String
        let text: Text
        let trailingSymbol: String
    }

    let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: content.leadingSymbol)
                .font(.body.weight(.medium))
            content.text
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
            Image(systemName: content.trailingSymbol)
                .font(.body.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.dictusAccent))
        .shadow(color: .dictusAccent.opacity(0.3), radius: 12, y: 4)
        // A new banner per state, so the page's stage animation cross-fades them.
        .id(content.leadingSymbol)
        .transition(.opacity)
        // One sentence for VoiceOver; the symbols only decorate it.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.text)
        .accessibilityIdentifier("onboarding.firstDictation.banner")
    }
}

// MARK: - KeyboardSwitchAnimation

/// The globe long-press, drawn in four frames above the open keyboard (#845, the animation
/// the page had before #678): the keyboard with its globe at the bottom of the phone, the
/// globe held and the keyboard menu open on the current keyboard, Dictus highlighted, then
/// the Dictus keyboard.
///
/// WHY THIS ONE (decided by Pierre on 2026-10-28): it presses the globe where it sits on a
/// Face ID iPhone, under the keys, as Wispr Flow shows it.
///
/// WHY SCALED, NOT CUT (#845): it sits between the field and the open keyboard, which on a
/// 667 pt screen (iPhone SE) leaves far less than its drawn height. The drawing is laid out
/// at one size and scaled down to the height the page gives it, so the whole of it, globe
/// and menu included, stays visible.
///
/// WHY A `.task` LOOP AND NOT A TIMER: the loop belongs to the view's lifetime. SwiftUI
/// cancels the task when the animation leaves (Dictus comes up), so no timer is left firing
/// into a view that is gone. With Reduce Motion on, it holds the frame that says it all:
/// the menu open, Dictus highlighted. The animation is a picture, so it is one element for
/// VoiceOver, read as its caption.
private struct KeyboardSwitchAnimation: View {
    /// One moment of the loop, in order: the drawn frame, whether the globe is held, and
    /// for how long.
    private struct Step {
        let frame: Int
        let globePressed: Bool
        let duration: Duration
    }

    private static let steps = [
        Step(frame: 0, globePressed: false, duration: .seconds(1.2)),
        Step(frame: 0, globePressed: true, duration: .seconds(0.3)),
        Step(frame: 1, globePressed: true, duration: .seconds(1.5)),
        Step(frame: 2, globePressed: true, duration: .seconds(1.5)),
        Step(frame: 3, globePressed: false, duration: .seconds(2.0))
    ]

    /// The size the drawing is laid out at, before it is scaled to the room it gets.
    private static let drawnSize = CGSize(width: 340, height: 214)

    @State private var animationFrame = 0
    @State private var globePressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the iOS system language is French (drives AZERTY vs QWERTY layout).
    /// WHY read from Locale.preferredLanguages, NOT SharedKeys.language:
    /// SharedKeys.language is the Dictus *transcription* preference — it's independent
    /// from the iOS keyboard layout the user actually sees when they press the globe.
    private let isFrench = (Locale.preferredLanguages.first ?? "en").hasPrefix("fr")

    private var row0: [String] {
        isFrench
            ? ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"]
            : ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]
    }
    private var row1: [String] {
        isFrench
            ? ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"]
            : ["A", "S", "D", "F", "G", "H", "J", "K", "L"]
    }
    private var row2: [String] {
        isFrench
            ? ["W", "X", "C", "V", "B", "N", "'"]
            : ["Z", "X", "C", "V", "B", "N", "M"]
    }

    /// The current keyboard's row in the menu. The real menu names each keyboard in its
    /// own language, so the catalog spells both names the same in every locale.
    private var systemKeyboardName: String {
        isFrench
            ? String(localized: "Français", comment: "Drawn globe menu row: the French keyboard, named in French (#678).")
            : String(localized: "English", comment: "Drawn globe menu row: the English keyboard, named in English (#678).")
    }

    /// The space bar's label in the non-Dictus frames.
    private var spaceLabel: String {
        isFrench ? "espace" : "space"
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                1,
                proxy.size.width / Self.drawnSize.width,
                proxy.size.height / Self.drawnSize.height
            )
            drawing
                .frame(width: Self.drawnSize.width, height: Self.drawnSize.height, alignment: .bottom)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Never taller than drawn; shorter when the page has less room (iPhone SE).
        .frame(maxWidth: .infinity, maxHeight: Self.drawnSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Long-press the globe, then Dictus"))
        .accessibilityIdentifier("onboarding.firstDictation.animation")
        .task(id: reduceMotion) { await run() }
    }

    private var drawing: some View {
        ZStack(alignment: .bottomLeading) {
            fakeKeyboard(isDictus: animationFrame == 3)

            // The menu, for frames 1 and 2.
            if animationFrame == 1 || animationFrame == 2 {
                fakeKeyboardPicker(dictusHighlighted: animationFrame == 2)
                    .padding(.leading, 8)
                    .padding(.bottom, 44)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomLeading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: animationFrame)
        .animation(.easeInOut(duration: 0.15), value: globePressed)
        .allowsHitTesting(false)
    }

    // MARK: Loop

    private func run() async {
        if reduceMotion {
            animationFrame = 2
            globePressed = true
            return
        }
        while !Task.isCancelled {
            for step in Self.steps {
                animationFrame = step.frame
                globePressed = step.globePressed
                do {
                    try await Task.sleep(for: step.duration)
                } catch {
                    return
                }
            }
        }
    }

    // MARK: Drawn keyboard

    /// The keyboard, with real key labels.
    /// WHY isDictus branches the layout:
    /// - isDictus == false: iOS's keyboard, with the globe and mic under the keys
    /// - isDictus == true: the Dictus keyboard, with its toolbar (language + blue mic pill)
    private func fakeKeyboard(isDictus: Bool) -> some View {
        VStack(spacing: 5) {
            if isDictus {
                dictusToolbar
                    .padding(.bottom, 2)
            }

            HStack(spacing: 4) {
                ForEach(row0, id: \.self) { keyCell($0) }
            }

            HStack(spacing: 4) {
                ForEach(row1, id: \.self) { keyCell($0) }
            }

            HStack(spacing: 4) {
                Image(systemName: "shift")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                ForEach(row2, id: \.self) { keyCell($0) }

                Image(systemName: "delete.left")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))
            }

            HStack(spacing: 4) {
                Text(verbatim: "123")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                Text(verbatim: "😊")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(keyCapsule(dark: true))

                Text(verbatim: spaceLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(keyCapsule(dark: false))

                Image(systemName: "return")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .frame(width: 64, height: 36)
                    .background(keyCapsule(dark: true))
            }

            // Globe and mic under the keys, on iOS's keyboard only: Dictus has its mic in
            // its toolbar.
            if !isDictus {
                HStack {
                    // The globe, lit while it is held.
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundStyle(globePressed ? Color.primary : Color.secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.dictusAccent.opacity(globePressed ? 0.22 : 0))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.dictusAccent, lineWidth: 1.5)
                                .opacity(globePressed ? 1 : 0)
                        )

                    Spacer()

                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }

    /// The Dictus keyboard's toolbar: the language on the left, the blue mic pill on the right.
    private var dictusToolbar: some View {
        HStack {
            Text(verbatim: isFrench ? "FR" : "EN")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.dictusAccent))
        }
        .padding(.horizontal, 8)
    }

    private func keyCell(_ letter: String) -> some View {
        Text(verbatim: letter)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(keyCapsule(dark: false))
    }

    /// Key background: light for letter keys, darker for function keys.
    private func keyCapsule(dark: Bool) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.primary.opacity(dark ? 0.08 : 0.05))
            .shadow(color: .black.opacity(0.08), radius: 0.5, y: 1)
    }

    // MARK: Drawn menu

    /// The globe's keyboard menu: the current keyboard, Emoji, Dictus.
    private func fakeKeyboardPicker(dictusHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerRow(systemKeyboardName, highlighted: !dictusHighlighted)
            Divider().opacity(0.2)
            pickerRow(String(localized: "Emoji"))
            Divider().opacity(0.2)
            pickerRow("Dictus", highlighted: dictusHighlighted, accent: dictusHighlighted)
        }
        .padding(.vertical, 4)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 2)
        )
    }

    /// Takes a `String`, so it is shown verbatim: callers localize with `String(localized:)`
    /// (#661).
    private func pickerRow(_ text: String, highlighted: Bool = false, accent: Bool = false) -> some View {
        Text(verbatim: text)
            .font(.callout)
            .foregroundColor(accent ? .dictusAccent : .primary)
            .fontWeight(highlighted || accent ? .medium : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(highlighted ? Color.primary.opacity(0.1) : (accent ? Color.dictusAccent.opacity(0.12) : Color.clear))
                    .padding(.horizontal, 4)
            )
    }
}

// MARK: - KeyboardDetectingTextField

/// UIKit text view wrapper that reports its focus and which keyboard is up.
///
/// WHY UITextView (not UITextField):
/// UITextField is single-line only — long dictated text overflows horizontally
/// and gets clipped. UITextView supports multi-line editing with automatic
/// wrapping, which matches user expectations for dictation output.
///
/// WHY UIViewRepresentable instead of SwiftUI TextEditor:
/// We need access to the UITextView's `textInputMode` property to detect when
/// the user switches to the Dictus keyboard (via long-press globe). SwiftUI's
/// TextEditor doesn't expose this. This wrapper:
/// 1. Reports focus from `textViewDidBeginEditing` / `textViewDidEndEditing`: a focused
///    field is a keyboard on screen (#678, #845)
/// 2. Observes UITextInputMode.currentInputModeDidChangeNotification
/// 3. Reads the UITextView's textInputMode.identifier
/// 4. Calls onKeyboardChange(isDictus:) when the active keyboard changes
/// 5. Takes focus each time `focusRequest` changes (#845)
private struct KeyboardDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequest: Int
    let onFocusChange: (Bool) -> Void
    let onKeyboardChange: (Bool) -> Void

    func makeUIView(context: Context) -> PlaceholderTextView {
        let textView = PlaceholderTextView()
        textView.placeholder = placeholder
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.tintColor = UIColor(Color.dictusAccent)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        // Remove default inner padding so text aligns to the top-left
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences

        // Listen for keyboard switches
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.inputModeDidChange(_:)),
            name: UITextInputMode.currentInputModeDidChangeNotification,
            object: nil
        )

        return textView
    }

    func updateUIView(_ textView: PlaceholderTextView, context: Context) {
        context.coordinator.parent = self
        if textView.text != text {
            textView.text = text
            textView.refreshPlaceholder()
        }
        if textView.placeholder != placeholder {
            textView.placeholder = placeholder
        }
        if context.coordinator.handledFocusRequest != focusRequest {
            context.coordinator.handledFocusRequest = focusRequest
            textView.requestFocus()
        }
    }

    static func dismantleUIView(_ textView: PlaceholderTextView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardDetectingTextField
        weak var textView: PlaceholderTextView?
        /// The last `focusRequest` acted on: 0, so the first one (1) focuses on appear.
        var handledFocusRequest = 0

        init(_ parent: KeyboardDetectingTextField) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView as? PlaceholderTextView
            DispatchQueue.main.async {
                self.parent.onFocusChange(true)
            }
            checkInputMode(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.onFocusChange(false)
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
        }

        @objc func inputModeDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            checkInputMode(for: textView)
        }

        /// WHY KVC ON "identifier": `UITextInputMode` exposes no public identifier, and the
        /// KVC key is the one `KeyboardSetupPage` already reads to detect the installed
        /// keyboard. Guarded, so an unreadable key reads as "not Dictus" rather than
        /// crashing (`FirstDictationStage.isDictusInputMode`).
        private func checkInputMode(for textView: UITextView) {
            guard let inputMode = textView.textInputMode else { return }
            let identifier = inputMode.value(forKey: "identifier") as? String
            let isDictus = FirstDictationStage.isDictusInputMode(identifier: identifier)
            DispatchQueue.main.async {
                self.parent.onKeyboardChange(isDictus)
            }
        }
    }
}

/// UITextView subclass that shows a placeholder when empty.
///
/// WHY a subclass: UITextView has no built-in placeholder (unlike UITextField).
/// We overlay a UILabel that shows/hides based on whether the text view is empty.
private class PlaceholderTextView: UITextView {
    var placeholder: String = "" {
        didSet { placeholderLabel.text = placeholder; refreshPlaceholder() }
    }

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .placeholderText
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupPlaceholder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }

    private func setupPlaceholder() {
        addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func refreshPlaceholder() {
        placeholderLabel.isHidden = !text.isEmpty
    }

    /// Set while a focus request waits for the view to be in a window.
    private var wantsFocus = false

    /// Opens the keyboard on this view, now if it is in a window, or as soon as it is.
    ///
    /// WHY WAIT FOR THE WINDOW (#845): `becomeFirstResponder()` returns false on a view
    /// outside a window. Before #678 the page called it from `makeUIView`, one run-loop tick
    /// after creating the view, with no guarantee the view was in a window yet and no
    /// retry. `didMoveToWindow` is the moment it is.
    func requestFocus() {
        guard window != nil else {
            wantsFocus = true
            return
        }
        wantsFocus = false
        // Next run-loop tick: SwiftUI calls this from `updateUIView`, mid-update.
        DispatchQueue.main.async { [weak self] in
            _ = self?.becomeFirstResponder()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if wantsFocus && window != nil {
            requestFocus()
        }
    }
}
