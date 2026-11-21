# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: ``

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 20 | 129 | 14 | 10.9% | 3.2% | 3.2% | 0 |
| es | 20 | 141 | 28 | 19.9% | 4.3% | 1.5% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |
| es | 608 | 23 (3.8%) | 1 | 141 | 1 (0.7%) | `none` 1 |
| de | 634 | 21 (3.3%) | 1 | 141 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| en-typos | letter | 491 | 1.44 | 3.45 | 148.60 |
| en-typos | space | 129 | 0.09 | 1.14 | 3.58 |
| es | letter | 605 | 0.12 | 1.54 | 23.79 |
| es | space | 141 | 0.10 | 1.53 | 3.64 |
| de | letter | 630 | 0.14 | 1.74 | 20.24 |
| de | space | 142 | 0.12 | 1.72 | 3.52 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 129 | 92 | 23 | **0** | 13 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 16 | **0** | 23 | 18 | **2** | 1 | 0 |
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
| es | miscorrected | minutos | deinutos | dei unos |
| es | miscorrected | está | ests | esta |
| es | missed | llamaré | llamare | llamare |
| es | missed | mañana | manana | manana |
| es | missed | mañana | ma | ma |
| es | missed | mañana | ana | ana |
| es | missed | está | esta | esta |
| es | missed | había | habia | habia |
| es | missed | llegué | llegue | llegue |
| es | missed | estación | estacion | estacion |
| es | missed | están | estan | estan |
| es | missed | médico | mexico | mexico |
| es | missed | todavía | Todavia | Todavia |
| es | missed | sé | se | se |
| es | missed | qué | que | que |
| es | missed | estaré | estare | estare |
| es | missed | venir | venid | venid |
| es | missed | mañana | manana | manana |
| es | missed | qué | Que | Que |
| es | missed | mañana | Manana | Manana |
| es | missed | gustaría | gustaria | gustaria |
| es | missed | café | cafe | cafe |
| es | missed | número | numero | numero |
| es | missed | de | fe | fe |
| es | missed | teléfono | telefono | telefono |
| es | glued | tengo que | Tengoque | Enfoque |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| en-typos | 109 | 19 (17.4%) | 28 (25.7%) | 0 (0.0%) |
| es | 120 | 15 (12.5%) | 26 (21.7%) | 0 (0.0%) |
| de | 122 | 13 (10.7%) | 22 (18.0%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

