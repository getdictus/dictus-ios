# Evidence for #1097 (refs #1089)

Releasing a held letter without picking an accent types it, as on Apple's keyboard.

Simulator: iPhone 17, iOS 26.5, French UI, status bar 09:41, Dictus French AZERTY, Settings
search field. AXe 2.2.0 (official release binary). Branch build `06e4687f`, develop build
`eb129bbb`.

- `longpress-release.mp4`: « l », then « e » held 0.7 s and released: « Le »; space, « d »,
  then « e » held and slid onto « é »: « Le dé ».
- `held-e-highlighted.png`: the popup with « e » highlighted under the still finger.
- `slid-onto-e-acute.png`: the finger slid onto « é ».
- `bench-develop.txt`, `bench-branch.txt`: 20 taps over e s r d t f y g u h i j o k per case.
  A held press is an `axe swipe` drifting 0.5 pt for the duration (`axe touch --delay` and
  `axe tap --hold` overshoot the popup's 0.5 s); a slide moves 2, 5 or 10 pt over 100 ms.
- `directions-develop.txt`, `directions-branch.txt`: « e » held 1 s, `axe drag` to the
  point, released. Key centre y 612.
- `scripts/`: the bench as run (`bench.sh <udid> <label>`, `directions.sh <udid> <label>`).
