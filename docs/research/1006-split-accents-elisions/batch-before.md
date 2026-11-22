# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

sources: the batch chain without #1008 (#992 `cc5ee518`, #997 `82ff08e5`, #1000 `6541e79c`, #999 `c70ce2bf`, #1002 `7a2d967f`, #998 `9b4a6ed0`, #1005 `bfe600ea`), rebuilt locally

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 15 | 10.6% | 2.3% | 1.5% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 21 (3.3%) | 1 | 157 | 2 (1.3%) | `none` 1, `v` 1 |
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |
| es | 608 | 23 (3.8%) | 1 | 141 | 1 (0.7%) | `none` 1 |
| de | 634 | 21 (3.3%) | 1 | 141 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.11 | 0.52 | 44.32 |
| fr | space | 152 | 0.10 | 0.44 | 2.85 |
| en | letter | 626 | 0.96 | 1.85 | 410.64 |
| en | space | 156 | 0.05 | 0.69 | 1.54 |
| en-typos | letter | 491 | 0.90 | 1.75 | 4.88 |
| en-typos | space | 129 | 0.05 | 0.23 | 3.15 |
| es | letter | 605 | 0.10 | 0.71 | 16.71 |
| es | space | 141 | 0.10 | 0.61 | 3.66 |
| de | letter | 630 | 0.10 | 0.67 | 11.34 |
| de | space | 142 | 0.08 | 0.61 | 1.61 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 29 | **0** | 9 | 5 | **3** | 1 | 0 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| de | miscorrected | bestellt | vestellt | gestellt |
| de | missed | wann | Wa | Wa |
| de | missed | wann | n | n |
| de | missed | für | fr | fr |
| de | missed | tasse | gasse | gasse |
| de | missed | heiß | heisa | heisa |
| de | missed | wetter | wettet | wettet |
| de | missed | montag | montg | montg |
| en | miscorrected | my | finishy | finish |
| en | missed | been | een | een |
| en | missed | morning | irning | irning |
| en | missed | is | s | s |
| en | missed | been | bern | bern |
| en | glued | hour late | hourvlate | hourglass |
| en-typos | miscorrected | will | wll | all |
| es | miscorrected | minutos | deinutos | dei unos |
| es | miscorrected | médico | mexico | méxico |
| es | miscorrected | está | ests | esta |
| es | missed | mañana | ma | ma |
| es | missed | mañana | ana | ana |
| es | missed | está | esta | esta |
| es | missed | llegué | llegue | llegue |
| es | missed | sé | se | se |
| es | missed | qué | que | que |
| es | missed | venir | venid | venid |
| es | missed | qué | Que | Que |
| es | missed | de | fe | fe |
| es | glued | tengo que | Tengoque | Enfoque |
| fr | missed | réunion | reùion | reùion |
| fr | missed | décalée | decalee | decalee |
| fr | missed | à | a | a |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| fr | 132 | 16 (12.1%) | 23 (17.4%) | 0 (0.0%) |
| en | 135 | 17 (12.6%) | 28 (20.7%) | 0 (0.0%) |
| en-typos | 109 | 20 (18.3%) | 30 (27.5%) | 0 (0.0%) |
| es | 120 | 16 (13.3%) | 27 (22.5%) | 0 (0.0%) |
| de | 122 | 13 (10.7%) | 22 (18.0%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

