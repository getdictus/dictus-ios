# Keyboard measurement: Dictus (replay, 402x216 pt grid)

commit: `920db323cc61fee59ba91b4c42ae6273c6c4647a`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 8 | 5.3% | 1.4% | 0.5% | 0 |
| en | 20 | 157 | 9 | 5.7% | 2.2% | 2.2% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 21 (3.3%) | 1 | 157 | 2 (1.3%) | `none` 1, `v` 1 |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.11 | 0.53 | 28.45 |
| fr | space | 152 | 0.10 | 0.47 | 2.35 |
| en | letter | 626 | 0.98 | 1.86 | 87.11 |
| en | space | 156 | 0.06 | 0.64 | 1.45 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 23 | **0** | 4 | 4 | **4** | 0 | 0 |
| en | 153 | 135 | 11 | **0** | 3 | 0 | **4** | 2 | 1 |

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
| fr | miscorrected | réunion | reùion | région |
| fr | miscorrected | décalée | decalee | dévaler |
| fr | miscorrected | réservé | reserve | réserve |
| fr | miscorrected | déchargé | decharge | décharge |
| fr | missed | arrivé | arrive | arrive |
| fr | missed | trouvé | trouve | trouve |
| fr | missed | couchés | couches | couches |
| fr | missed | oublié | oublie | oublie |

