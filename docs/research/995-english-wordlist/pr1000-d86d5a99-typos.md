# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: `d86d5a99`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 20 | 129 | 14 | 10.9% | 3.2% | 3.2% | 0 |
| es-typos | 20 | 119 | 19 | 16.0% | 3.9% | 0.6% | 0 |
| de-typos | 20 | 131 | 5 | 3.8% | 0.8% | 0.3% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |
| es-typos | 441 | 0 (0.0%) | 0 | 119 | 0 (0.0%) | - |
| de-typos | 559 | 0 (0.0%) | 0 | 131 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| en-typos | letter | 491 | 1.08 | 2.18 | 31.21 |
| en-typos | space | 129 | 0.07 | 0.83 | 2.38 |
| es-typos | letter | 441 | 0.10 | 0.72 | 11.39 |
| es-typos | space | 119 | 0.09 | 0.26 | 3.84 |
| de-typos | letter | 559 | 0.11 | 0.70 | 9.24 |
| de-typos | space | 131 | 0.10 | 0.32 | 2.55 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 129 | 92 | 23 | **0** | 13 | 0 | **1** | 0 | 0 |
| es-typos | 119 | 73 | 27 | **0** | 17 | 17 | **2** | 0 | 0 |
| de-typos | 131 | 103 | 23 | **0** | 5 | 3 | **0** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| de-typos | missed | dass | das | das |
| de-typos | missed | vielleicht | Vieleicht | Vieleicht |
| de-typos | missed | hätte | hatte | hatte |
| de-typos | missed | würde | wurde | wurde |
| de-typos | missed | schön | schon | schon |
| en-typos | miscorrected | will | wll | all |
| en-typos | missed | believe | beleive | beleive |
| en-typos | missed | because | becuase | becuase |
| en-typos | missed | i'll | Ill | Ill |
| en-typos | missed | and | adn | adn |
| en-typos | missed | it's | Its | Its |
| en-typos | missed | receive | recieve | recieve |
| en-typos | missed | definitely | definately | definately |
| en-typos | missed | the | teh | teh |
| en-typos | missed | i'll | Ill | Ill |
| en-typos | missed | i'll | Ill | Ill |
| en-typos | missed | i'll | ill | ill |
| en-typos | missed | we're | were | were |
| en-typos | missed | it's | Its | Its |
| es-typos | miscorrected | que | qe | de |
| es-typos | miscorrected | año | ano | uno |
| es-typos | missed | él | El | El |
| es-typos | missed | sé | se | se |
| es-typos | missed | dónde | donde | donde |
| es-typos | missed | está | esta | esta |
| es-typos | missed | qué | que | que |
| es-typos | missed | mí | mi | mi |
| es-typos | missed | sí | Si | Si |
| es-typos | missed | cómo | Como | Como |
| es-typos | missed | mí | mi | mi |
| es-typos | missed | sé | se | se |
| es-typos | missed | sé | se | se |
| es-typos | missed | él | el | el |
| es-typos | missed | qué | que | que |
| es-typos | missed | está | esta | esta |
| es-typos | missed | dónde | Donde | Donde |
| es-typos | missed | está | esta | esta |
| es-typos | missed | él | el | el |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| en-typos | 109 | 19 (17.4%) | 28 (25.7%) | 0 (0.0%) |
| es-typos | 99 | 7 (7.1%) | 14 (14.1%) | 0 (0.0%) |
| de-typos | 111 | 7 (6.3%) | 18 (16.2%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

