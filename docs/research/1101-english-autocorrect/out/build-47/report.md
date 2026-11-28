# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: `9bfa9203ecea0ecaaae125972725a48ab9bdc26e`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en-us | 58 | 417 | 27 | 6.5% | 1.6% | 1.6% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| en-us | 1616 | 0 (0.0%) | 0 | 417 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| en-us | letter | 1616 | 1.40 | 2.41 | 55.63 |
| en-us | space | 417 | 0.07 | 0.97 | 3.30 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en-us | 417 | 337 | 54 | **7** | 17 | 0 | **2** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| en-us | broken | venmo | venmo | venom |
| en-us | broken | coworker | coworker | coworkers |
| en-us | broken | jaxon | jaxon | jax on |
| en-us | broken | idk | Idk | Idl |
| en-us | broken | hulu | hulu | july |
| en-us | broken | texted | texted | tested |
| en-us | broken | priya | priya | prima |
| en-us | miscorrected | expected | expectd | expects |
| en-us | miscorrected | wants | wnats | whats |
| en-us | missed | we're | were | were |
| en-us | missed | to | ro | ro |
| en-us | missed | start | strat | strat |
| en-us | missed | let's | Lets | Lets |
| en-us | missed | won't | wont | wont |
| en-us | missed | i'd | Id | Id |
| en-us | missed | we'll | Well | Well |
| en-us | missed | mom | mon | mon |
| en-us | missed | where | Wher | Wher |
| en-us | missed | it's | its | its |
| en-us | missed | at | st | st |
| en-us | missed | it's | its | its |
| en-us | missed | in | jn | jn |
| en-us | missed | good | goood | goood |
| en-us | missed | why | Hwy | Hwy |
| en-us | missed | we're | Were | Were |
| en-us | missed | doing | doidn | doidn |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| en-us | 359 | 28 (7.8%) | 52 (14.5%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

