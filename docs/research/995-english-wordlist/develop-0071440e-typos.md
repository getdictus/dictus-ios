# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: `0071440ec`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 20 | 129 | 16 | 12.4% | 3.7% | 3.7% | 0 |
| es-typos | 20 | 119 | 44 | 37.0% | 8.7% | 0.7% | 0 |
| de-typos | 20 | 131 | 6 | 4.6% | 1.1% | 0.6% | 0 |

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
| en-typos | letter | 491 | 0.89 | 1.79 | 38.08 |
| en-typos | space | 129 | 0.06 | 0.93 | 5.97 |
| es-typos | letter | 441 | 0.09 | 0.67 | 14.89 |
| es-typos | space | 119 | 0.07 | 0.95 | 1.16 |
| de-typos | letter | 559 | 0.10 | 0.58 | 5.95 |
| de-typos | space | 131 | 0.09 | 0.12 | 1.04 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| en-typos | 129 | 92 | 21 | **0** | 13 | 0 | **3** | 0 | 0 |
| es-typos | 119 | 73 | 2 | **0** | 42 | 42 | **2** | 0 | 0 |
| de-typos | 131 | 103 | 22 | **0** | 5 | 3 | **1** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| de-typos | miscorrected | und | udn | in |
| de-typos | missed | dass | das | das |
| de-typos | missed | vielleicht | Vieleicht | Vieleicht |
| de-typos | missed | hätte | hatte | hatte |
| de-typos | missed | würde | wurde | wurde |
| de-typos | missed | schön | schon | schon |
| en-typos | miscorrected | people | Poeple | Purple |
| en-typos | miscorrected | being | Beeing | Bering |
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
| es-typos | miscorrected | quiero | Queiro | Quebró |
| es-typos | missed | él | El | El |
| es-typos | missed | años | anos | anos |
| es-typos | missed | más | mas | mas |
| es-typos | missed | papá | papa | papa |
| es-typos | missed | sé | se | se |
| es-typos | missed | dónde | donde | donde |
| es-typos | missed | está | esta | esta |
| es-typos | missed | mamá | mama | mama |
| es-typos | missed | qué | que | que |
| es-typos | missed | así | asi | asi |
| es-typos | missed | será | Sera | Sera |
| es-typos | missed | día | dia | dia |
| es-typos | missed | difícil | dificil | dificil |
| es-typos | missed | mí | mi | mi |
| es-typos | missed | también | tambien | tambien |
| es-typos | missed | aquí | aqui | aqui |
| es-typos | missed | ahí | ahi | ahi |
| es-typos | missed | año | ano | ano |
| es-typos | missed | sí | Si | Si |
| es-typos | missed | café | cafe | cafe |
| es-typos | missed | cómo | Como | Como |
| es-typos | missed | están | estan | estan |
| es-typos | missed | mamá | mama | mama |
| es-typos | missed | papá | papa | papa |
| es-typos | missed | película | pelicula | pelicula |
| es-typos | missed | niños | ninos | ninos |
| es-typos | missed | había | habia | habia |
| es-typos | missed | después | despues | despues |
| es-typos | missed | mí | mi | mi |
| es-typos | missed | teléfono | telefono | telefono |
| es-typos | missed | sé | se | se |
| es-typos | missed | sé | se | se |
| es-typos | missed | él | el | el |
| es-typos | missed | podrías | podrias | podrias |
| es-typos | missed | más | mas | mas |
| es-typos | missed | qué | que | que |
| es-typos | missed | está | esta | esta |
| es-typos | missed | después | despues | despues |
| es-typos | missed | dónde | Donde | Donde |
| es-typos | missed | está | esta | esta |
| es-typos | missed | aquí | aqui | aqui |
| es-typos | missed | él | el | el |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| en-typos | 109 | 18 (16.5%) | 27 (24.8%) | 0 (0.0%) |
| es-typos | 99 | 8 (8.1%) | 13 (13.1%) | 0 (0.0%) |
| de-typos | 111 | 7 (6.3%) | 18 (16.2%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

