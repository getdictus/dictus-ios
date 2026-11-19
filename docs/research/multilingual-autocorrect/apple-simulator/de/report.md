# Keyboard measurement: Apple, simulator, German (key choice only: no German language data in the simulator runtime)

commit: `unknown`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| de | 20 | 141 | 30 | 21.3% | 4.4% | 4.4% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

