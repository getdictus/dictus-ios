# Keyboard languages and layouts

- **ID:** `keyboard.languages`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.panel`, `app.settings` — see [screens.md](screens.md)

## Sub-features

- Four keyboard languages: Français, English, Español, Deutsch, each with AZERTY / QWERTY / QWERTZ.
- Keyboard panel (☰ held): language rows, layout pills, gear « Ouvrir Dictus ».
- Réglages → Clavier: « Langue du clavier », default page ABC / 123, « Disposition », « Rangée de chiffres».
- Transcription language: « Suivre la langue du clavier » or fixed.
- Files: `DictusKeyboard/Views/KeyboardPanelView.swift`, `DictusKeyboard/KeyboardLayouts.swift`, `DictusCore/Sources/DictusCore/SupportedLanguage.swift`, `DictusApp/Views/KeyboardModePicker.swift`.

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

App side: `.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages`, then `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Disposition, AZERTY"`.

## Gotchas

- Panel rows are inside the keyboard: tap them by coordinate from the screenshot (`kbd.panel`), then check the log (`presentAreaMode`).
- The gear's `intent=settings` URL has no route in the app: it only brings Dictus forward, and raises the openurl confirmation in the simulator.
