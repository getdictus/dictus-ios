# Keyboard languages and layouts

- **ID:** `keyboard.languages`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.panel`, `kbd.numbers`, `kbd.symbols`, `app.settings` — see [screens.md](screens.md)

## Sub-features

- `keyboard.language-switch`: Français, English, Español, Deutsch, switched from the keyboard panel (☰ held).
- `keyboard.layout`: AZERTY / QWERTY / QWERTZ per language.
- `keyboard.number-row`: « Rangée de chiffres » above the letters.
- `keyboard.default-page`: Default page ABC or 123.
- `keyboard.transcription-language`: Transcription language: « Suivre la langue du clavier » or fixed.
- `keyboard.open-app`: The panel's gear opens Dictus.

## How to get to it (user POV)

1. In the Dictus keyboard, hold ☰ (top left).
2. Choose a language and a layout in the panel, close with ✕.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd menu-hold
.claude/skills/verify-dictus-ios/scripts/evidence.sh panel
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd menu                                   # ✕ sits where ☰ was
```

The 123 and `#+=` pages: `drive.sh kbd abc` on the letters page presses the bottom-left key, which reads 123 there (`kbd.numbers`); `#+=` is the first key of the third row, at (+30, +187) pt from `inputView`'s origin (`kbd.symbols`); `kbd abc` goes back to the letters.

App side: `.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages`, `axe swipe --start-x 201 --start-y 600 --end-x 201 --end-y 350 --duration 0.4 --udid <udid>` (at rest the row sits under the floating tab bar, and a tap there switches to Modèles), then `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Disposition, AZERTY"`.

## Gotchas

- Panel rows are inside the keyboard: tap them by coordinate from the screenshot (`kbd.panel`), then check the log (`presentAreaMode`).
- The gear's `intent=settings` URL has no route in the app: it only brings Dictus forward, and raises the openurl confirmation in the simulator.
