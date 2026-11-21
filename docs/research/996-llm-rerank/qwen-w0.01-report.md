# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf)

commit: `c3cdf63515a275f1969d82d6540667aae2057227`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 13 | 9.2% | 1.9% | 1.1% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 18 | 45.0% | 15.9% | 13.1% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 21 (3.3%) | 1 | 157 | 2 (1.3%) | `none` 1, `v` 1 |
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |
| es | 608 | 23 (3.8%) | 1 | 141 | 1 (0.7%) | `none` 1 |
| de | 634 | 21 (3.3%) | 1 | 141 | 0 (0.0%) | - |
| fr-pierre-device | 201 | 8 (4.0%) | 0 | 36 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.14 | 50.01 | 111.73 |
| fr | space | 152 | 14.06 | 36.60 | 47.36 |
| en | letter | 626 | 1.08 | 26.78 | 105.79 |
| en | space | 156 | 13.78 | 25.40 | 27.36 |
| en-typos | letter | 491 | 1.01 | 15.51 | 85.77 |
| en-typos | space | 129 | 13.76 | 26.01 | 47.15 |
| es | letter | 605 | 0.13 | 61.58 | 125.59 |
| es | space | 141 | 13.97 | 36.48 | 47.69 |
| de | letter | 630 | 0.11 | 38.25 | 160.16 |
| de | space | 142 | 13.93 | 36.56 | 47.66 |
| fr-pierre-device | letter | 201 | 0.43 | 97.25 | 181.72 |
| fr-pierre-device | space | 36 | 25.95 | 59.66 | 59.97 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 29 | **0** | 9 | 5 | **3** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 11 | **1** | 4 | 0 | **11** | 0 | 0 |

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
| fr | missed | réunion | reùion | reùion |
| fr | missed | décalée | decalee | decalee |
| fr | missed | à | a | a |
| fr-pierre-device | broken | we | we | de |
| fr-pierre-device | miscorrected | trouve | trouce | trouvé |
| fr-pierre-device | miscorrected | trouve | triuce | trouvé |
| fr-pierre-device | miscorrected | j'ai | J'aa | J'as |
| fr-pierre-device | miscorrected | la | Lz | L'z |
| fr-pierre-device | miscorrected | fonction | Lnction | Onction |
| fr-pierre-device | miscorrected | parce | Pasqueil | Pasque |
| fr-pierre-device | miscorrected | manque | Ma'qje | Ma'que |
| fr-pierre-device | miscorrected | discord | Dizcitd | Discute |
| fr-pierre-device | miscorrected | honnête | Honetre | Contre |
| fr-pierre-device | miscorrected | donne | Donnequoi | Donne quoi |
| fr-pierre-device | miscorrected | que | qur | sur |
| fr-pierre-device | missed | j'ai | J'ainhate | J'ainhate |
| fr-pierre-device | missed | j'ai | J'aintrouve | J'aintrouve |
| fr-pierre-device | missed | intégré | Integté | Integté |
| fr-pierre-device | missed | franchement | Fràvhelent | Fràvhelent |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| fr | 132 | 16 (12.1%) | 44 (33.3%) | 0 (0.0%) |
| en | 135 | 31 (23.0%) | 62 (45.9%) | 0 (0.0%) |
| en-typos | 109 | 25 (22.9%) | 52 (47.7%) | 0 (0.0%) |
| es | 120 | 28 (23.3%) | 44 (36.7%) | 0 (0.0%) |
| de | 122 | 13 (10.7%) | 24 (19.7%) | 0 (0.0%) |
| fr-pierre-device | 13 | 2 (15.4%) | 2 (15.4%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

