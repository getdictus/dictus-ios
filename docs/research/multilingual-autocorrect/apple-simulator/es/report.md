# Keyboard measurement: Apple, simulator, Spanish (key choice only: no Spanish language data in the simulator runtime)

commit: `unknown`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| es | 20 | 141 | 48 | 34.0% | 7.5% | 4.0% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

