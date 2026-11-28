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
- `keyboard.return-key-type`: the return key follows the field's `returnKeyType`, as Apple's keyboard draws it (#1023): blue → in Safari's address bar (Go), blue magnifier in a search field, blue ↑ for Send, ✓ for Done, › for Next and Continue, plain ↵ elsewhere. Greyed, and a tap does nothing, while the field is empty and the host sets `enablesReturnKeyAutomatically` (Safari's address bar does). The words (« accéder », « rechercher »…) are VoiceOver labels in the keyboard's language, as on Apple's keyboard.

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

The bottom row is the same on the letters, 123 and `#+=` pages, in units of a 10-unit row: 123/ABC 1.25, emoji 1.25, space 5.5, return 2.0 (#877). On a 402 pt wide keyboard held upright the keys are laid out on Apple's key plane (`KeyPlaneGeometry`): the keycaps start 6.5 pt in from each side with 6 pt between them, and the outer keys' touch targets run to the screen edges, so the targets are 123/ABC 0 to 52.9 pt, emoji 52.9 to 102.25, space 102.25 to 319.5, return 319.5 to 402; `kbd abc` (+22), `kbd emoji` (+90) and `space` (+220) tap inside those cells. Rows sit where Apple's do: the letters' keycaps start 8 pt below the toolbar on a 54 pt pitch (iPhone 17), and turned, the keys are Apple's smaller ones (27.3 pt on a 35.3 pt pitch) at the bottom of the same grid. With the globe key (home-button iPhones) the row is globe 1.0, 123/ABC 1.5, emoji 1.5, space 4.0, return 2.0.

On the AZERTY letters page the apostrophe key sits over the left end of return, and their targets meet halfway down the gap between the rows, as Apple's do. One exception (#1080, `ApostropheReturnBorder` in DictusCore): a tap in the top quarter row pitch of return's target (its half of the gap and the top 8 pt of its keycap), under the apostrophe's column, types the apostrophe when the word before the cursor is one French elides (c, d, j, l, m, n, s, t, qu, and the words ending in qu such as jusqu), in any case. Anywhere else, and after any other word, return stays return. To check it in a search field (iPhone 17, grid top 583.2 pt): tap c (161.5, 720.7), then (320.7, 752.0) or (331.4, 749.9), Pierre's two device taps. Expect `C'` in the field; after `bonjour` the same points run the search. Apple's French AZERTY on the iOS 26.5 simulator types return at both points in both contexts.

A space typed on either page after a digit or symbol also goes back to the letters, as Apple's keyboard does (#504). A space typed before any character stays on the page, and so does Return. To check it: `kbd abc`, tap `2` (second key of the first row), tap the space bar, and expect the letters page, its bottom-left key reading 123 again.

Reopen on letters (#889): `kbd abc` (123 page), then hide the keyboard with Safari's ✕ next to the address bar (`drive.sh tap-id CancelBarItemButton`, label « Fermer »), then tap the address bar again (`drive.sh tap-id TabBarItemTitle`). Expect the letters page, bottom-left key reading 123, and `<KBD> … action=registeredAppearance` in the log after the reopen. Same with `#+=`. On iOS the reset runs on each appearance only: moving to another field with the keyboard up does not trigger it (Android resets there too).

App side: `.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages`, `axe swipe --start-x 201 --start-y 600 --end-x 201 --end-y 350 --duration 0.4 --udid <udid>` (at rest the row sits under the floating tab bar, and a tap there switches to Modèles), then `.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Disposition, AZERTY"`.

Return key type (#1023): `drive.sh tap-id TabBarItemTitle` in Safari, select the Dictus keyboard, screenshot: the return key (bottom right) is grey with a faint →. Type one letter by coordinate: it turns blue with a white →. A field with the default type (Rappels, a new reminder's title) shows the plain grey ↵. The glyphs are drawn inside the keyboard's remote view, so `describe-ui` does not list them: the screenshot is the evidence.

## Gotchas

- `keyboard.return-key-type` in third-party apps (WhatsApp, Telegram, Google search, a bank's form) is checked on the iPhone: the simulator has only Apple's apps. Messages uses the default type and sends from its own button, so its return key stays ↵ with Apple's keyboard too.

- `keyboard.reopen-letters` cannot be told apart from the old behaviour in the simulator: there, iOS creates a new `KeyboardViewController` for every appearance (new `instanceID` at each `registeredAppearance`, measured on iOS 26.5 for a Safari hide/show and a Home round trip, #889), and a new controller starts on the letters anyway. The kept-controller case, where the page used to survive, is checked on the iPhone.
- Panel rows are inside the keyboard: tap them by coordinate from the screenshot (`kbd.panel`), then check the log (`presentAreaMode`).
- The gear's `intent=settings` URL has no route in the app: it only brings Dictus forward, and raises the openurl confirmation in the simulator.
