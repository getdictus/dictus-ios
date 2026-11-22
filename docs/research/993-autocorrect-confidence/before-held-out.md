# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: ``

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr-learned | 8 | 59 | 7 | 11.9% | 4.4% | 3.7% | 0 |
| en-learned | 8 | 52 | 5 | 9.6% | 1.3% | 1.3% | 1 |
| es | 20 | 141 | 29 | 20.6% | 4.4% | 1.5% | 0 |
| de | 20 | 141 | 7 | 5.0% | 1.1% | 1.1% | 0 |
| es-typos | 20 | 119 | 44 | 37.0% | 8.7% | 0.7% | 0 |
| de-typos | 20 | 131 | 6 | 4.6% | 1.1% | 0.6% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr-learned | 270 | 11 (4.1%) | 1 | 59 | 1 (1.7%) | `none` 1 |
| en-learned | 259 | 8 (3.1%) | 1 | 52 | 1 (1.9%) | `none` 1 |
| es | 608 | 23 (3.8%) | 1 | 141 | 1 (0.7%) | `none` 1 |
| de | 634 | 21 (3.3%) | 1 | 141 | 0 (0.0%) | - |
| es-typos | 441 | 0 (0.0%) | 0 | 119 | 0 (0.0%) | - |
| de-typos | 559 | 0 (0.0%) | 0 | 131 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr-learned | letter | 268 | 0.10 | 0.52 | 11.95 |
| fr-learned | space | 59 | 0.10 | 1.30 | 1.58 |
| en-learned | letter | 258 | 0.99 | 1.85 | 29.77 |
| en-learned | space | 52 | 0.08 | 1.11 | 1.46 |
| es | letter | 605 | 0.09 | 0.66 | 31.29 |
| es | space | 141 | 0.07 | 0.99 | 4.58 |
| de | letter | 630 | 0.09 | 0.70 | 27.60 |
| de | space | 142 | 0.08 | 0.55 | 1.05 |
| es-typos | letter | 441 | 0.09 | 0.68 | 1.31 |
| es-typos | space | 119 | 0.07 | 0.91 | 1.15 |
| de-typos | letter | 559 | 0.10 | 0.69 | 1.77 |
| de-typos | space | 131 | 0.08 | 0.23 | 1.48 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr-learned | 58 | 47 | 5 | **0** | 1 | 1 | **5** | 1 | 0 |
| en-learned | 50 | 43 | 4 | **0** | 3 | 0 | **0** | 1 | 0 |
| es | 140 | 99 | 15 | **0** | 23 | 18 | **3** | 1 | 0 |
| de | 142 | 118 | 17 | **0** | 5 | 0 | **2** | 0 | 0 |
| es-typos | 119 | 73 | 2 | **0** | 42 | 42 | **2** | 0 | 0 |
| de-typos | 131 | 103 | 22 | **0** | 5 | 3 | **1** | 0 | 0 |

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
| de-typos | miscorrected | und | udn | in |
| de-typos | missed | dass | das | das |
| de-typos | missed | vielleicht | Vieleicht | Vieleicht |
| de-typos | missed | hätte | hatte | hatte |
| de-typos | missed | würde | wurde | wurde |
| de-typos | missed | schön | schon | schon |
| en-learned | missed | fix | tix | tix |
| en-learned | missed | on | o | o |
| en-learned | missed | for | foe | foe |
| en-learned | glued | before friday | beforefriday | beforefriday |
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
| fr-learned | miscorrected | je | Jz | J'z |
| fr-learned | miscorrected | migré | mugrd | murs |
| fr-learned | miscorrected | compile | compime | comprimé |
| fr-learned | miscorrected | relancer | relan | relax |
| fr-learned | miscorrected | relancer | er | et |
| fr-learned | missed | dîne | dine | dine |
| fr-learned | glued | demande à | Demande | Demande |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| fr-learned | 51 | 2 (3.9%) | 5 (9.8%) | 0 (0.0%) |
| en-learned | 43 | 3 (7.0%) | 5 (11.6%) | 0 (0.0%) |
| es | 120 | 15 (12.5%) | 26 (21.7%) | 0 (0.0%) |
| de | 122 | 13 (10.7%) | 22 (18.0%) | 0 (0.0%) |
| es-typos | 99 | 8 (8.1%) | 13 (13.1%) | 0 (0.0%) |
| de-typos | 111 | 7 (6.3%) | 18 (16.2%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

