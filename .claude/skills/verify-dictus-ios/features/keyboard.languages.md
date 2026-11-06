# Keyboard languages and layouts

- **ID:** `keyboard.languages`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.panel`, `kbd.numbers`, `kbd.symbols`, `app.settings` — see [screens.md](screens.md)

## Sub-features

- `keyboard.language-switch`: Français, English, Español, Deutsch, switched from the keyboard panel (☰ held).
- `keyboard.layout`: AZERTY / QWERTY / QWERTZ per language.
- `keyboard.number-row`: « Rangée de chiffres » above the letters.
- `keyboard.default-page`: **retired (#888).** Was the « Page par défaut » ABC / 123 choice in Réglages; the setting is gone and the keyboard always opens on the letters. The ID stays retired, never reused.
- `keyboard.reopen-letters`: the keyboard always opens on the letters, even when it was hidden on 123 or `#+=` (#889; Android uses the same ID, #291).
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

The bottom row is the same on the letters, 123 and `#+=` pages, in units of a 10-unit row: 123/ABC 1.25, emoji 1.25, space 5.5, return 2.0 (#877). On a 402 pt wide keyboard that is 123/ABC 0 to 50.1 pt, emoji 50.1 to 100.25, space 100.25 to 320.8, return 320.8 to 401; `kbd abc` (+22), `kbd emoji` (+90) and `space` (+220) tap inside those cells. With the globe key (home-button iPhones) the row is globe 1.0, 123/ABC 1.5, emoji 1.5, space 4.0, return 2.0.

A space typed on either page after a digit or symbol also goes back to the letters, as Apple's keyboard does (#504). A space typed before any character stays on the page, and so does Return. To check it: `kbd abc`, tap `2` (second key of the first row), tap the space bar, and expect the letters page, its bottom-left key reading 123 again.

Reopen on letters (#889): `kbd abc` (123 page), then hide the keyboard with Safari's ✕ next to the address bar (`drive.sh tap-id CancelBarItemButton`, label « Fermer »), then tap the address bar again (`drive.sh tap-id TabBarItemTitle`). Expect the letters page, bottom-left key reading 123, and `<KBD> … action=registeredAppearance` in the log after the reopen. Same with `#+=`. On iOS the reset runs on each appearance only: moving to another field with the keyboard up does not trigger it (Android resets there too).

App side: `.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages`, `axe swipe --start-x 201 --start-y 600 --end-x 201 --end-y 350 --duration 0.4 --udid <udid>` (at rest the row sits under the floating tab bar, and a tap there switches to Modèles), then `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Disposition, AZERTY"`.

## Gotchas

- `keyboard.reopen-letters` cannot be told apart from the old behaviour in the simulator: there, iOS creates a new `KeyboardViewController` for every appearance (new `instanceID` at each `registeredAppearance`, measured on iOS 26.5 for a Safari hide/show and a Home round trip, #889), and a new controller starts on the letters anyway. The kept-controller case, where the page used to survive, is checked on the iPhone.
- Panel rows are inside the keyboard: tap them by coordinate from the screenshot (`kbd.panel`), then check the log (`presentAreaMode`).
- The gear's `intent=settings` URL has no route in the app: it only brings Dictus forward, and raises the openurl confirmation in the simulator.
