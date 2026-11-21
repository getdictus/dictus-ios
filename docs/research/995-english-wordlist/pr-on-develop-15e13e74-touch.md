# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: `15e13e74f`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 9 | 5.9% | 1.5% | 0.5% | 0 |
| en | 20 | 157 | 9 | 5.7% | 2.2% | 2.2% | 0 |
| es | 20 | 141 | 29 | 20.6% | 4.4% | 1.5% | 0 |
| de | 20 | 141 | 7 | 5.0% | 1.1% | 1.1% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 21 (3.3%) | 1 | 157 | 2 (1.3%) | `none` 1, `v` 1 |
| es | 608 | 23 (3.8%) | 1 | 141 | 1 (0.7%) | `none` 1 |
| de | 634 | 21 (3.3%) | 1 | 141 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.11 | 0.49 | 9.26 |
| fr | space | 152 | 0.09 | 0.43 | 2.06 |
| en | letter | 626 | 0.94 | 1.82 | 22.71 |
| en | space | 156 | 0.05 | 0.63 | 0.74 |
| es | letter | 605 | 0.10 | 0.71 | 10.47 |
| es | space | 141 | 0.09 | 1.10 | 1.83 |
| de | letter | 630 | 0.10 | 0.69 | 9.48 |
| de | space | 142 | 0.10 | 0.59 | 1.35 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 22 | **0** | 5 | 5 | **4** | 0 | 0 |
| en | 153 | 135 | 11 | **0** | 3 | 0 | **4** | 2 | 1 |
| es | 140 | 99 | 15 | **0** | 23 | 18 | **3** | 1 | 0 |
| de | 142 | 118 | 17 | **0** | 5 | 0 | **2** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| de | miscorrected | bestellt | vestellt | gestellt |
| de | miscorrected | heiß | heisa | geist |
| de | missed | wann | Wa | Wa |
| de | missed | wann | n | n |
| de | missed | für | fr | fr |
| de | missed | tasse | gasse | gasse |
| de | missed | wetter | wettet | wettet |
| en | miscorrected | morning | irning | irving |
| en | miscorrected | my | finishy | finish |
| en | miscorrected | hour | boue | bone |
| en | miscorrected | need | meef | meet |
| en | missed | been | een | een |
| en | missed | is | s | s |
| en | missed | been | bern | bern |
| en | glued | hour late | hourvlate | hourglass |
| es | miscorrected | minutos | deinutos | dei unos |
| es | miscorrected | película | peljcula | pelicula |
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
| fr | miscorrected | réunion | reùion | région |
| fr | miscorrected | décalée | decalee | dévaler |
| fr | miscorrected | réservé | reserve | réserve |
| fr | miscorrected | déchargé | decharge | décharge |
| fr | missed | à | a | a |
| fr | missed | arrivé | arrive | arrive |
| fr | missed | trouvé | trouve | trouve |
| fr | missed | couchés | couches | couches |
| fr | missed | oublié | oublie | oublie |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| fr | 132 | 16 (12.1%) | 22 (16.7%) | 0 (0.0%) |
| en | 135 | 16 (11.9%) | 27 (20.0%) | 0 (0.0%) |
| es | 120 | 15 (12.5%) | 26 (21.7%) | 0 (0.0%) |
| de | 122 | 13 (10.7%) | 22 (18.0%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

