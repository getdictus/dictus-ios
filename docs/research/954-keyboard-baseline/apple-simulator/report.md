# Keyboard measurement: Apple, real keyboard on the simulator (iOS 26.5, iPhone 17)

commit: `unknown`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 33 | 21.7% | 5.4% | 2.1% | 0 |
| en | 20 | 157 | 0 | 0.0% | 0.0% | 0.0% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

