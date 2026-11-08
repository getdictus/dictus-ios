# Onboarding and What's new

- **ID:** `onboarding`
- **Tier:** Gratuit (Free) — Pro scenes shown to all eligible devices
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.onboarding.*` (14 steps), `app.whats-new` — see [screens.md](screens.md)

## Sub-features

- `onboarding.welcome`: Intro carousel, « Commencer ».
- `onboarding.language`: Language and keyboard layout.
- `onboarding.keyboard-setup`: Add the keyboard and turn on Full Access, with an explainer.
- `onboarding.apple-intelligence`: Wait for Apple Intelligence to be ready.
- `onboarding.pro-scenes`: Scenes for Smart Modes, voice notes, vocabulary and history.
- `onboarding.smart-mode-pick`: Pick three Smart Modes.
- `onboarding.model-download`: Download and prepare the recommended model.
- `onboarding.microphone`: Microphone permission.
- `onboarding.first-dictation`: A first dictation in a practice field. The field focuses itself and the keyboard opens with no tap; the globe animation, in the bottom of the onboarding's drawn iPhone (`onboarding.firstDictation.animation`), shows only once Apple's keyboard is up, between the field and the keyboard; Dictus's keyboard shows the mic banner (`onboarding.firstDictation.banner`). No focus within 1 s: « Touchez le champ pour ouvrir votre clavier », no animation. After 15 s on another keyboard without Dictus: « Continuer » (`onboarding.firstDictation.continue`) next to Skip. Three characters typed or dictated once Dictus has been up complete the step (#845).
- `onboarding.stop-standby`: How to stop Dictus from the Dynamic Island.
- `onboarding.completion`: « C'est prêt ».
- `onboarding.resume`: An interrupted onboarding resumes at the same step.
- `onboarding.whats-new`: An existing user sees the new Pro scenes once.

## How to get to it (user POV)

1. Install and open Dictus.
2. Follow « Commencer » → language → keyboard setup → … → « C'est prêt ».

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh          # READY … screen=onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id onboarding.primary
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-id onboarding.back 10                             # language step
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id onboarding.back
# jump to any step without walking through the ones before it:
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.onboardingStep -string smartModePick
# What's new:
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.hasCompletedOnboarding -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.lastVersionSeen -string 1.8.0
```

## Gotchas

- **Never tap `onboarding.primary` on the language step** unless a download is wanted: it starts the model download. Jump past it with `set-default dictus.onboardingStep`.
- `modelPreparation` downloads; `microphonePrompt` raises the system mic prompt; `firstDictation` records. Show them, do not complete them.
- `firstDictation` reopens on the keyboard the device used last. To see the animation, long-press the globe (`Clavier suivant`) and pick an Apple keyboard; to see the banner, pick `Dictus, multilingue`. Typing three letters with the Dictus keyboard completes the step without a recording (Dictus keys are not in the accessibility tree: tap by coordinate).
- On a fresh simulator, iOS's own keyboard tips (« Type français et anglais », swipe typing) cover the keyboard the first time it opens. Their `Continue` buttons come in pairs, so tap them by coordinate.
- The 1 s fallback (« Touchez le champ… ») only shows when the focus fails, which a normal simulator run does not produce: neither Apple's nor Dictus's iPhone keyboard has a key that closes it.
- The step is resumed only while `dictus.hasCompletedOnboarding` is false.
