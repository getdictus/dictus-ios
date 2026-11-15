# Keyboard measurement: Dictus, real keyboard on the simulator (iOS 26.5, iPhone 17)

commit: `3fa26bf11f726fdd6bdf7756a8d7b6e7c71aed3f`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 9 | 5.9% | 1.5% | 0.5% | 0 |
| en | 20 | 157 | 17 | 10.8% | 6.9% | 6.9% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

