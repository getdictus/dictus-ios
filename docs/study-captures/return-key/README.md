# Return key redraw and #1026's cap insets (#1025)

`before` is `a1a34bb8` (#1025 merged with `develop` `93a639fc`, without the fix);
`after` is `07dcc77a` (the same plus `capInsets: capInsets(at: indexPath)` in
`GiellaKeyboardView.updateReturnKey`). Debug builds, iOS 26.5 simulators
`iPhone 17` and `iPhone 17 Pro Max` created for this study (French, Dictus keyboard,
no Full Access), driven with `axe` 2.1.1. Measured 2026-11-23.

| Capture | Field | What runs |
| --- | --- | --- |
| `*-messages-*` | Messages, a conversation's compose box, keyboard just shown | first layout |
| `*-safari-*` | Safari, address bar focused (blue `→` key) | first layout |
| `*-settings-search-*` | Réglages search bar, after one letter typed | `updateReturnKey`: the key turns from off (grey) to on (blue) with the keyboard up, the path the fix changes |

Result: `bmpdiff.py` finds no difference in the keyboard between `before` and `after`,
in any of the six pairs, on either device. What differs is outside the keyboard (the
text caret, Safari's page behind the address bar, Messages' own microphones). On these
two devices, the theme's even margins and the `KeyPlaneGeometry` insets put the return
key's cap at the same place, so the missing argument had no visible effect here. The fix
keeps the redrawn key on the same code path as the first layout; a device or layout
where the two differ is not covered by this study.

Scripts: `apps-seq.sh` (Messages, Safari) and `settings-seq.sh` (Réglages), then
`sips -s format bmp` on both PNGs and `python3 -I bmpdiff.py before.bmp after.bmp`.
Messages needs a stock simulator: a slimmed one (`simslim on`) does not draw its compose box.
