# Keyboard measurement: Dictus (replay, 402x216 pt grid)

commit: `3f74a5c0232617f05571d0defd34c9ada4a1022f`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 9 | 5.9% | 1.5% | 0.5% | 0 |
| en | 20 | 157 | 9 | 5.7% | 2.2% | 2.2% | 0 |
| fr-learned | 8 | 59 | 10 | 16.9% | 5.3% | 4.7% | 0 |
| en-learned | 8 | 52 | 6 | 11.5% | 1.7% | 1.7% | 1 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 21 (3.3%) | 1 | 157 | 2 (1.3%) | `none` 1, `v` 1 |
| fr-learned | 270 | 11 (4.1%) | 1 | 59 | 1 (1.7%) | `none` 1 |
| en-learned | 259 | 8 (3.1%) | 1 | 52 | 1 (1.9%) | `none` 1 |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.12 | 0.57 | 11.03 |
| fr | space | 152 | 0.10 | 0.48 | 2.02 |
| en | letter | 626 | 1.17 | 2.10 | 50.08 |
| en | space | 156 | 0.08 | 0.66 | 0.79 |
| fr-learned | letter | 268 | 0.11 | 0.55 | 0.67 |
| fr-learned | space | 59 | 0.09 | 1.35 | 1.39 |
| en-learned | letter | 258 | 1.17 | 1.94 | 4.88 |
| en-learned | space | 52 | 0.10 | 1.38 | 1.73 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 22 | **0** | 5 | 5 | **4** | 0 | 0 |
| en | 153 | 135 | 11 | **0** | 3 | 0 | **4** | 2 | 1 |
| fr-learned | 58 | 47 | 2 | **0** | 2 | 1 | **7** | 1 | 0 |
| en-learned | 50 | 43 | 3 | **0** | 4 | 0 | **0** | 1 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| en | miscorrected | morning | irning | irving |
| en | miscorrected | my | finishy | finish |
| en | miscorrected | hour | boue | bone |
| en | miscorrected | need | meef | meet |
| en | missed | been | een | een |
| en | missed | is | s | s |
| en | missed | been | bern | bern |
| en | glued | hour late | hourvlate | hourglass |
| en-learned | missed | fix | tix | tix |
| en-learned | missed | on | o | o |
| en-learned | missed | kubernetes | kuberneted | kuberneted |
| en-learned | missed | for | foe | foe |
| en-learned | glued | before friday | beforefriday | beforefriday |
| fr | miscorrected | réunion | reùion | région |
| fr | miscorrected | décalée | decalee | dévaler |
| fr | miscorrected | réservé | reserve | réserve |
| fr | miscorrected | déchargé | decharge | décharge |
| fr | missed | à | a | a |
| fr | missed | arrivé | arrive | arrive |
| fr | missed | trouvé | trouve | trouve |
| fr | missed | couchés | couches | couches |
| fr | missed | oublié | oublie | oublie |
| fr-learned | miscorrected | je | Jz | J'z |
| fr-learned | miscorrected | dictus | dictuq | rictus |
| fr-learned | miscorrected | migré | mugrd | murs |
| fr-learned | miscorrected | compile | compime | comprimé |
| fr-learned | miscorrected | dictus | dicrus | rictus |
| fr-learned | miscorrected | relancer | relan | relax |
| fr-learned | miscorrected | relancer | er | et |
| fr-learned | missed | testflight | testflifht | testflifht |
| fr-learned | missed | dîne | dine | dine |
| fr-learned | glued | demande à | Demande | Demande |

