# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, spatial decoder)

commit: `a5ef8a71f15bd1946e80f69b2f0fa518a4f9b252`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en | 20 | 157 | 2 | 1.3% | 0.9% | 0.9% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.2% | 0.2% | 0 |
| en-us | 58 | 417 | 20 | 4.8% | 1.2% | 1.2% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| en | 629 | 20 (3.2%) | 1 | 157 | 3 (1.9%) | `none` 2, `v` 1 |
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |
| en-us | 1616 | 0 (0.0%) | 0 | 417 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| en | letter | 627 | 1.47 | 2.61 | 112.84 |
| en | space | 155 | 0.34 | 1.36 | 1.46 |
| en-typos | letter | 491 | 1.37 | 2.50 | 4.02 |
| en-typos | space | 129 | 0.28 | 0.68 | 3.72 |
| en-us | letter | 1616 | 1.42 | 2.45 | 4.26 |
| en-us | space | 417 | 0.34 | 1.45 | 3.71 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en | 151 | 135 | 14 | **0** | 0 | 0 | **2** | 3 | 3 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| en-us | 417 | 337 | 61 | **7** | 11 | 0 | **1** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| en | miscorrected | morning | irning | ironing |
| en | miscorrected | my | finishy | finish |
| en-typos | miscorrected | will | wll | well |
| en-us | broken | venmo | venmo | venom |
| en-us | broken | coworker | coworker | coworkers |
| en-us | broken | jaxon | jaxon | jax on |
| en-us | broken | idk | Idk | Idl |
| en-us | broken | hulu | hulu | july |
| en-us | broken | texted | texted | tested |
| en-us | broken | priya | priya | prima |
| en-us | miscorrected | wants | wnats | whats |
| en-us | missed | we're | were | were |
| en-us | missed | start | strat | strat |
| en-us | missed | let's | Lets | Lets |
| en-us | missed | won't | wont | wont |
| en-us | missed | i'd | Id | Id |
| en-us | missed | we'll | Well | Well |
| en-us | missed | it's | its | its |
| en-us | missed | it's | its | its |
| en-us | missed | why | Hwy | Hwy |
| en-us | missed | we're | Were | Were |
| en-us | missed | doing | doidn | doidn |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| en | 134 | 16 (11.9%) | 27 (20.1%) | 0 (0.0%) |
| en-typos | 109 | 20 (18.3%) | 30 (27.5%) | 0 (0.0%) |
| en-us | 359 | 29 (8.1%) | 52 (14.5%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

## Register of real cases (#500)

11 of 11 come out as the person meant. Each case is committed by the space bar in a field holding the text typed before it (`register.tsv`).

| lang | before | typed | expected | reported | lexicon | final | |
|---|---|---|---|---|---|---|---|
| en | send it on | whatsap | WhatsApp | whats | - | WhatsApp | right |
| en | - | Whatsap | WhatsApp | Whats | - | WhatsApp | right |
| en | my | iphon | iPhone | upon | - | iPhone | right |
| en | watch it on | youtub | YouTube | youth | - | YouTube | right |
| en | - | Youtub | YouTube | Youth | - | YouTube | right |
| en | he sent a | telegram | telegram | - | - | telegram | right |
| en | once | upon | upon | upon | - | upon | right |
| en | the | youth | youth | youth | - | youth | right |
| en | call my | phone | phone | phone | - | phone | right |
| en | call my | ihone | phone | phone | - | phone | right |
| en | - | Iphon | iPhone | Upon | - | iPhone | right |

