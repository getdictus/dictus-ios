# Device cross-check: Apple's French keyboard on `a` / `à` (about 15 minutes)

The simulator run in this folder uses an Apple French language asset that had to be
installed by hand (see `README.md`, "Can Apple's French autocorrect run on the
simulator?"). It is the February 2026 build of that asset, relabelled. This protocol
checks, on a real iPhone, that Apple's keyboard behaves the same way. It takes one pass
and no tooling on the phone.

## Before you start

- iPhone, **Apple's French keyboard** (not Dictus), Settings › General › Keyboard:
  **Auto-Correction on**, **Predictive Text on**.
- Open **Notes**, new note.

## How to type

- Type each line **in lowercase, without accents and without apostrophe corrections**:
  type `a` for `à`, and type the apostrophe where the sentence has one.
- **Put a space after every word, the last one included**, then press return.
- Do not tap a suggestion, do not backspace. If you mistype a letter, leave it.
- While typing, **watch the `a`**: note whether it changed when you pressed the space
  after it (`S`), only after you typed the next word and its space (`N`), never but
  the bar offered `à` (`B`), or never (`-`). A pen and paper is enough; one letter per
  line.

## The 25 lines

| # | Case | Type this | The right form |
|---|---|---|---|
| 1 | start | `a demain ` | à demain |
| 2 | start | `a quelle heure tu arrives ` | à quelle heure |
| 3 | cap-start | `a deux on ira plus vite ` | À deux |
| 4 | noun-a | `le probleme a ete regle ` | a été |
| 5 | noun-a | `ma voiture a cale ce matin ` | a calé |
| 6 | noun-à | `une machine a laver ` | à laver |
| 7 | noun-à | `il reste du travail a faire ` | à faire |
| 8 | adj-à | `c'est facile a faire ` | à faire |
| 9 | verb-à | `je pense a toi ` | à toi |
| 10 | verb-à | `jouer a deux mains ` | à deux |
| 11 | verb-à | `je vais a paris demain ` | à Paris |
| 12 | phrase | `je rentre a pied ` | à pied |
| 13 | phrase | `c'est a cause de la pluie ` | à cause |
| 14 | phrase | `j'ai a peine dormi ` | à peine |
| 15 | il-a | `il a faim ` | a faim |
| 16 | il-a | `il a beaucoup mange ` | a beaucoup |
| 17 | pronoun-a | `ca a marche du premier coup ` | a marché |
| 18 | relative | `ce que tu as fait a marche ` | a marché |
| 19 | relative | `l'homme qui parle a raison ` | a raison |
| 20 | name | `marie a appele ce matin ` | a appelé |
| 21 | name | `j'ai ecrit a marie ` | à Marie |
| 22 | elision | `jusqu'a demain ` | jusqu'à |
| 23 | elision | `il n'y a qu'a demander ` | a, qu'à |
| 24 | y-a | `y a pas de souci ` | y a |
| 25 | question | `a qui tu parles ` | À qui |

## Sending the result back

1. Select all the note's text, copy it, and paste it as a comment on the doc PR (or in
   a message), one line per sentence as it ended up on screen.
2. Under it, paste your 25 letters (`S`, `N`, `B` or `-`), one per line, in order.

Nothing else is needed: the comparison with the simulator table is done from those two
lists.
