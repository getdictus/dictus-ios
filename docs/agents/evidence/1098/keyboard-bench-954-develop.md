# Keyboard measurement: Dictus (replay, 402x216 pt grid, hit test: plain)

commit: `6d57b268aca772c3129e68e0977763619f3f2d06`

## Final text

| lang | sentences | words | wrong words | word error rate | char error rate | char error rate, accents ignored | glued words |
|---|---:|---:|---:|---:|---:|---:|---:|
| fr | 20 | 152 | 2 | 1.3% | 0.6% | 0.1% | 0 |
| en | 20 | 157 | 8 | 5.1% | 1.6% | 1.6% | 0 |
| en-typos | 20 | 129 | 1 | 0.8% | 0.3% | 0.3% | 0 |

Word errors are a word-level edit distance against the intended sentence; a glued word is a final token that is two consecutive intended words without the space. Ignoring accents leaves the errors that are not a missing accent: with no autocorrect at work, they are the keyboard's wrong keys.

## Taps

| lang | letter taps | wrong letter | of which a stray space | space taps | missed space | missed space landed on |
|---|---:|---:|---:|---:|---:|---|
| fr | 669 | 13 (1.9%) | 0 | 152 | 0 (0.0%) | - |
| en | 629 | 20 (3.2%) | 1 | 157 | 3 (1.9%) | `none` 2, `v` 1 |
| en-typos | 491 | 0 (0.0%) | 0 | 129 | 0 (0.0%) | - |

## Engine time per keystroke (ms)

The suggestion work a letter triggers and the autocorrect a space triggers, run one after the other on the replay's thread. Simulator on a Mac: compare runs with each other, never with a device.

| lang | key | taps | p50 | p95 | max |
|---|---|---:|---:|---:|---:|
| fr | letter | 669 | 0.17 | 0.79 | 55.45 |
| fr | space | 152 | 0.15 | 0.72 | 4.11 |
| en | letter | 627 | 1.48 | 2.65 | 125.27 |
| en | space | 155 | 0.08 | 1.00 | 2.21 |
| en-typos | letter | 491 | 1.47 | 2.76 | 4.45 |
| en-typos | space | 129 | 0.08 | 0.20 | 3.46 |

## Autocorrect, per word the space bar committed

| lang | words | typed right, kept | typed wrong, fixed | **broken** (typed right, changed) | missed (typed wrong, kept) | of which accent only | **miscorrected** | glued | glued, split back |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| fr | 152 | 121 | 29 | **0** | 2 | 1 | **0** | 0 | 0 |
| en | 151 | 135 | 12 | **0** | 3 | 0 | **1** | 3 | 1 |
| en-typos | 129 | 92 | 36 | **0** | 0 | 0 | **1** | 0 | 0 |

Wrong autocorrections are the two bold columns. A stray space splits one intended word over two commits; those halves count as typed wrong.

## Every word that did not come out right

| lang | outcome | intended | typed | final |
|---|---|---|---|---|
| en | miscorrected | my | finishy | finish |
| en | missed | been | een | een |
| en | missed | morning | irning | irning |
| en | missed | been | bern | bern |
| en | glued | hour late | hourvlate | hourglass |
| en | glued | still have | atillhave | atillhave |
| en-typos | miscorrected | will | wll | all |
| fr | missed | réunion | reùion | reùion |
| fr | missed | décalée | decalee | decalee |

## Next-word prediction, after each space

| lang | spaces with a next word | next word first | next word in the bar (top 3) | bar empty |
|---|---:|---:|---:|---:|
| fr | 132 | 16 (12.1%) | 23 (17.4%) | 0 (0.0%) |
| en | 134 | 16 (11.9%) | 27 (20.1%) | 0 (0.0%) |
| en-typos | 109 | 20 (18.3%) | 30 (27.5%) | 0 (0.0%) |

The bar is what `predictNextWords` returns after the space, from the text the field holds then (autocorrections included). A hit saves the typist the whole next word.

## Register of real cases (#500)

50 of 57 come out as the person meant. Each case is committed by the space bar in a field holding the text typed before it (`register.tsv`).

| lang | before | typed | expected | reported | lexicon | final | |
|---|---|---|---|---|---|---|---|
| fr | il | ma | m'a | ma | - | m'a | right |
| fr | comment as tu | troubz | trouvé | trouve | - | trouve | wrong |
| fr | ce que tu as | dais | fait | dais | - | dais | wrong |
| fr | - | vocaux | vocaux | bocaux | - | vocaux | right |
| fr | - | styke | stylé | style | - | style | wrong |
| fr | - | styké | stylé | style | - | style | wrong |
| fr | bien | arruves | arrivés | arrives | - | arrivés | right |
| fr | - | stylé | stylé | style | - | stylé | right |
| fr | - | mok | moi | m'ok | - | m'ok | wrong |
| fr | il | ma | m'a | ma | ma | m'a | right |
| fr | il | zofiak | Zofiak | - | Zofiak | Zofiak | right |
| fr | une | pierre | pierre | - | Pierre | pierre | right |
| fr | je veux | qqc | quelque chose | - | qqc=quelque chose | quelque chose | right |
| fr | le a ne marche pas les | voczux | vocaux | bocaux | - | bocaux | wrong |
| fr | quand on saisit | voczux | vocaux | bocaux | - | bocaux | wrong |
| fr | - | cœur | cœur | cour | - | cœur | right |
| fr | le | cœur | cœur | cour | - | cœur | right |
| fr | ma | sœur | sœur |  | - | sœur | right |
| fr | une | œuvre | œuvre |  | - | œuvre | right |
| fr | un | œil | œil |  | - | œil | right |
| fr | un | nœud | nœud |  | - | nœud | right |
| fr | un | vœu | vœu |  | - | vœu | right |
| fr | du | bœuf | bœuf |  | - | bœuf | right |
| fr | - | Œuvre | Œuvre |  | - | Œuvre | right |
| fr | - | Œil | Œil |  | - | Œil | right |
| fr | - | Cœur | Cœur |  | - | Cœur | right |
| fr | un curriculum | vitæ | vitæ |  | - | vitæ | right |
| fr | ex | æquo | æquo |  | - | æquo | right |
| fr | le | coeur | coeur |  | - | coeur | right |
| fr | vas avoir des problème | z | a | z | - | a | right |
| fr | on passe au plan | B | B | - | - | B | right |
| fr | le mot commence par | l'h | l'h | - | - | l'h | right |
| fr | la lettre | b | b | - | - | b | right |
| fr | il | t | y | t | T | y | right |
| fr | il | t | y | - | - | y | right |
| fr | il y | a | a | - | a | a | right |
| fr | j'ai envoyé sur | whatsap | WhatsApp | whatsapp | - | WhatsApp | right |
| fr | - | Whatsap | WhatsApp | Whatsapp | - | WhatsApp | right |
| fr | mon | iphon | iPhone | siphon | - | iPhone | right |
| fr | une vidéo sur | youtub | YouTube | foutu | - | YouTube | right |
| fr | un | telegram | telegram | - | - | telegram | right |
| fr | le | siphon | siphon | siphon | - | siphon | right |
| fr | c'est | foutu | foutu | foutu | - | foutu | right |
| fr | le | clou | clou | clou | - | clou | right |
| fr | j'ai cassé | l'iphon | l'iPhone | l'iphon | - | l'iPhone | right |
| fr | - | Iphon | iPhone | Siphon | - | iPhone | right |
| en | send it on | whatsap | WhatsApp | whats | - | WhatsApp | right |
| en | - | Whatsap | WhatsApp | Whats | - | WhatsApp | right |
| en | my | iphon | iPhone | upon | - | iPhone | right |
| en | watch it on | youtub | YouTube | youth | - | YouTube | right |
| en | - | Youtub | YouTube | Youth | - | YouTube | right |
| en | he sent a | telegram | telegram | - | - | telegram | right |
| en | once | upon | upon | upon | - | upon | right |
| en | the | youth | youth | youth | - | youth | right |
| en | call my | phone | phone | phone | - | phone | right |
| en | call my | ihone | phone | phone | - | phone | right |
| en | - | Iphon | iPhone | Upon | - | iPhone | right |

