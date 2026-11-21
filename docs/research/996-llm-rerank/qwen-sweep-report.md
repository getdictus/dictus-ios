# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.0)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 13 | 9.2% | 1.9% | 1.1% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 19 | 47.5% | 16.8% | 14.0% | 0 |

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
| fr | letter | 669 | 0.12 | 0.58 | 1.27 |
| fr | space | 152 | 0.11 | 0.54 | 2.09 |
| en | letter | 626 | 0.92 | 1.78 | 3.64 |
| en | space | 156 | 0.07 | 0.72 | 1.70 |
| en-typos | letter | 491 | 0.89 | 1.74 | 5.16 |
| en-typos | space | 129 | 0.06 | 0.12 | 2.35 |
| es | letter | 605 | 0.11 | 0.79 | 2.17 |
| es | space | 141 | 0.11 | 0.66 | 1.62 |
| de | letter | 630 | 0.10 | 0.82 | 1.58 |
| de | space | 142 | 0.10 | 0.63 | 1.59 |
| fr-pierre-device | letter | 201 | 0.38 | 0.57 | 1.30 |
| fr-pierre-device | space | 36 | 0.50 | 26.03 | 40.49 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 29 | **0** | 9 | 5 | **3** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 10 | **1** | 4 | 0 | **12** | 0 | 0 |

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
| fr-pierre-device | miscorrected | j'ai | J'aa | J'la |
| fr-pierre-device | miscorrected | j'ai | J'ak | J'au |
| fr-pierre-device | miscorrected | la | Lz | L'z |
| fr-pierre-device | miscorrected | fonction | Lnction | Onction |
| fr-pierre-device | miscorrected | parce | Pasqueil | Pasque |
| fr-pierre-device | miscorrected | manque | Ma'qje | Ma'que |
| fr-pierre-device | miscorrected | discord | Dizcitd | Discute |
| fr-pierre-device | miscorrected | honnête | Honetre | Monstre |
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

# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.01)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

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
| fr | letter | 669 | 0.15 | 50.26 | 111.61 |
| fr | space | 152 | 14.01 | 36.35 | 47.15 |
| en | letter | 626 | 1.09 | 27.03 | 82.88 |
| en | space | 156 | 13.86 | 25.63 | 27.35 |
| en-typos | letter | 491 | 1.02 | 15.63 | 86.73 |
| en-typos | space | 129 | 13.79 | 25.93 | 49.29 |
| es | letter | 605 | 0.13 | 62.14 | 125.47 |
| es | space | 141 | 14.02 | 36.39 | 47.65 |
| de | letter | 630 | 0.11 | 38.51 | 158.70 |
| de | space | 142 | 14.00 | 36.84 | 51.07 |
| fr-pierre-device | letter | 201 | 0.44 | 97.29 | 183.83 |
| fr-pierre-device | space | 36 | 26.00 | 60.23 | 60.65 |

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

# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.0125)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 13 | 9.2% | 1.9% | 1.1% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 19 | 47.5% | 16.4% | 13.6% | 0 |

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
| fr | letter | 669 | 0.12 | 0.59 | 1.20 |
| fr | space | 152 | 0.11 | 0.46 | 2.19 |
| en | letter | 626 | 0.95 | 1.81 | 5.23 |
| en | space | 156 | 0.07 | 0.69 | 1.61 |
| en-typos | letter | 491 | 0.91 | 1.82 | 6.68 |
| en-typos | space | 129 | 0.06 | 0.14 | 2.37 |
| es | letter | 605 | 0.11 | 0.78 | 2.10 |
| es | space | 141 | 0.11 | 0.66 | 2.03 |
| de | letter | 630 | 0.10 | 0.79 | 1.58 |
| de | space | 142 | 0.10 | 0.65 | 1.62 |
| fr-pierre-device | letter | 201 | 0.39 | 0.68 | 1.20 |
| fr-pierre-device | space | 36 | 0.46 | 1.99 | 14.36 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 29 | **0** | 9 | 5 | **3** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 10 | **1** | 4 | 0 | **12** | 0 | 0 |

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
| fr-pierre-device | miscorrected | sais | Sats | Sans |
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

# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.015)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 13 | 9.2% | 1.9% | 1.1% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 17 | 42.5% | 15.9% | 14.0% | 0 |

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
| fr | letter | 669 | 0.12 | 0.57 | 1.20 |
| fr | space | 152 | 0.11 | 0.46 | 2.19 |
| en | letter | 626 | 0.94 | 1.85 | 6.48 |
| en | space | 156 | 0.07 | 0.68 | 1.61 |
| en-typos | letter | 491 | 0.91 | 1.95 | 5.00 |
| en-typos | space | 129 | 0.06 | 0.14 | 2.38 |
| es | letter | 605 | 0.11 | 0.79 | 2.13 |
| es | space | 141 | 0.10 | 0.64 | 2.05 |
| de | letter | 630 | 0.10 | 0.68 | 1.55 |
| de | space | 142 | 0.10 | 0.62 | 1.64 |
| fr-pierre-device | letter | 201 | 0.38 | 0.79 | 1.51 |
| fr-pierre-device | space | 36 | 0.49 | 2.12 | 14.33 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 29 | **0** | 9 | 5 | **3** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 12 | **1** | 4 | 0 | **10** | 0 | 0 |

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
| fr-pierre-device | miscorrected | j'ai | J'aa | J'as |
| fr-pierre-device | miscorrected | la | Lz | L'z |
| fr-pierre-device | miscorrected | fonction | Lnction | Onction |
| fr-pierre-device | miscorrected | parce | Pasqueil | Pasque |
| fr-pierre-device | miscorrected | manque | Ma'qje | Ma'que |
| fr-pierre-device | miscorrected | discord | Dizcitd | Discute |
| fr-pierre-device | miscorrected | honnête | Honetre | Contre |
| fr-pierre-device | miscorrected | donne | Donnequoi | Donne quoi |
| fr-pierre-device | miscorrected | sais | Sats | Dans |
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

# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.0175)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 14 | 9.9% | 2.2% | 1.2% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 17 | 42.5% | 15.9% | 14.0% | 0 |

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
| fr | letter | 669 | 0.12 | 0.56 | 1.23 |
| fr | space | 152 | 0.11 | 0.47 | 2.12 |
| en | letter | 626 | 0.95 | 1.80 | 4.75 |
| en | space | 156 | 0.07 | 0.69 | 1.52 |
| en-typos | letter | 491 | 0.91 | 1.93 | 6.41 |
| en-typos | space | 129 | 0.06 | 0.17 | 2.31 |
| es | letter | 605 | 0.11 | 0.87 | 37.68 |
| es | space | 141 | 0.11 | 1.03 | 47.91 |
| de | letter | 630 | 0.10 | 0.84 | 1.74 |
| de | space | 142 | 0.10 | 0.61 | 1.66 |
| fr-pierre-device | letter | 201 | 0.38 | 0.58 | 1.09 |
| fr-pierre-device | space | 36 | 0.45 | 1.63 | 1.86 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 28 | **0** | 9 | 5 | **4** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 12 | **1** | 4 | 0 | **10** | 0 | 0 |

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
| es | miscorrected | estará | estaea | estaba |
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
| fr-pierre-device | miscorrected | j'ai | J'aa | J'as |
| fr-pierre-device | miscorrected | la | Lz | L'z |
| fr-pierre-device | miscorrected | fonction | Lnction | Onction |
| fr-pierre-device | miscorrected | parce | Pasqueil | Pasque |
| fr-pierre-device | miscorrected | manque | Ma'qje | Ma'que |
| fr-pierre-device | miscorrected | discord | Dizcitd | Discute |
| fr-pierre-device | miscorrected | honnête | Honetre | Contre |
| fr-pierre-device | miscorrected | donne | Donnequoi | Donne quoi |
| fr-pierre-device | miscorrected | sais | Sats | Dans |
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

# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain, language model qwen2.5-0.5b-instruct-q4_k_m.gguf w0.02)

commit: `b6c4edb172fee9b5b2d1aec0b7aa47ff27065556`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 3 | 2.0% | 0.7% | 0.1% | 0 |
| en | 20 | 157 | 7 | 4.5% | 1.4% | 1.4% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |
| es | 20 | 141 | 14 | 9.9% | 2.2% | 1.2% | 0 |
| de | 20 | 141 | 8 | 5.7% | 1.1% | 1.1% | 0 |
| fr-pierre-device | 27 | 40 | 17 | 42.5% | 15.9% | 14.0% | 0 |

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
| fr | letter | 669 | 0.12 | 0.58 | 1.37 |
| fr | space | 152 | 0.11 | 0.47 | 2.18 |
| en | letter | 626 | 0.93 | 1.79 | 6.70 |
| en | space | 156 | 0.07 | 0.70 | 1.58 |
| en-typos | letter | 491 | 0.90 | 1.94 | 7.66 |
| en-typos | space | 129 | 0.06 | 0.18 | 2.34 |
| es | letter | 605 | 0.11 | 0.78 | 2.17 |
| es | space | 141 | 0.11 | 0.66 | 1.63 |
| de | letter | 630 | 0.10 | 0.80 | 1.76 |
| de | space | 142 | 0.10 | 0.63 | 1.56 |
| fr-pierre-device | letter | 201 | 0.37 | 0.74 | 1.40 |
| fr-pierre-device | space | 36 | 0.48 | 1.68 | 1.80 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 28 | **0** | 3 | 2 | **0** | 0 | 0 |
| en | 153 | 135 | 13 | **0** | 4 | 0 | **1** | 2 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |
| es | 140 | 99 | 28 | **0** | 9 | 5 | **4** | 1 | 1 |
| de | 142 | 118 | 16 | **0** | 7 | 0 | **1** | 0 | 0 |
| fr-pierre-device | 36 | 9 | 12 | **1** | 4 | 0 | **10** | 0 | 0 |

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
| es | miscorrected | estará | estaea | estaba |
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
| fr-pierre-device | miscorrected | j'ai | J'aa | J'as |
| fr-pierre-device | miscorrected | la | Lz | L'z |
| fr-pierre-device | miscorrected | fonction | Lnction | Onction |
| fr-pierre-device | miscorrected | parce | Pasqueil | Pasque |
| fr-pierre-device | miscorrected | manque | Ma'qje | Ma'que |
| fr-pierre-device | miscorrected | discord | Dizcitd | Discute |
| fr-pierre-device | miscorrected | honnête | Honetre | Contre |
| fr-pierre-device | miscorrected | donne | Donnequoi | Donne quoi |
| fr-pierre-device | miscorrected | sais | Sats | Dans |
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

