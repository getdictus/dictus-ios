# `Structuré`, `List` and the Typeless reference, side by side (#523)

The sixth acceptance line of #523: *the six outputs presented side by side with the
`List` output and the Typeless reference on the same fixture, for Pierre to judge on
sight.* **Reported, never barred** — Typeless is one acceptable answer, not the truth.

- **Structured** — `swift run polish-harness show Sources/polish-harness/fixtures/longform-fr.json --mode structured --runs 5`, shipping prompt, capture in `raw/round6-structured-shipping-5runs.txt`. The run shown per fixture is the one carrying the most paragraph breaks of the five, so what is below is this mode **at its best on that fixture**, not its median. The run number says which; where it is 0 breaks, every run was one block.
- **List** — same command with `--mode notes`, one run, capture in `raw/round2-list-show-1run.txt`.
- **Typeless** — the 2026-08-27 reference, verbatim from #437's comment of 14:39.

Read `findings.md` first: it says what these six do and do not show.


---

## 1-free-form

### Dictation (raw, Parakeet)

```
Bon alors je pensais à un truc ce matin en marchant, c'est que finalement quand on lance un produit tout seul, le plus dur ce n'est pas de le coder, c'est de décider quoi ne pas faire en fait. Parce qu'il y a toujours une idée qui a l'air meilleure que celle sur laquelle on est en train de bosser. Et du coup on saute dessus et au bout de 6 mois en fait on a 15 trucs commencés et rien de fini.
```

### `Structuré` — run 1 of 5

```
Bon alors je pensais à un truc ce matin en marchant, c'est que finalement quand on lance un produit tout seul, le plus dur ce n'est pas de le coder, c'est de décider quoi ne pas faire en fait. Parce qu'il y a toujours une idée qui a l'air meilleure que celle sur laquelle on est en train de bosser. Et du coup on saute dessus et au bout de 6 mois en fait on a 15 trucs commencés et rien de fini.
```

### `List`

```
- Le plus dur de lancer un produit est de décider quoi ne pas faire.
- Il y a toujours une idée meilleure que celle sur laquelle on travaille.
- On saute dessus et finit par avoir 15 trucs commencés et rien de fini en 6 mois.
```

### Typeless (reference)

```
Bon alors, je pensais à un truc ce matin en marchant.

C'est que finalement, quand on lance un produit tout seul, le plus dur, ce n'est pas de le coder : c'est de décider quoi ne pas faire. Parce qu'il y a toujours une idée qui a l'air meilleure que celle sur laquelle on est en train de bosser. Du coup, on saute dessus et au bout de six mois, on a quinze trucs commencés et rien de fini.
```


---

## 2-project-update

### Dictation (raw, Parakeet)

```
Alors point rapide sur le projet, on a basculé la partie abonnement lundi dernier, Thomas a fini l'intégration StoreKit et ça passe en sandbox. Il reste deux trucs. Le premier c'est l'historique des transcriptions qui n'est pas commencé du tout. Et le deuxième c'est le vocabulaire personnalisé. Et là dessus on a une spec mais pas de code. Côté chiffres, on est à 412 téléchargements depuis le lancement, avec un taux de rétention à 7 jours de 19%, ce qui est faible, mais pas catastrophique pour une première version. L'objectif, c'est de passer la barre des 1000 avant fin octobre. Je vois Sarah jeudi à 14h pour caler la partie Apple Store. Et si tout se passe bien, on soumet la semaine du 12.
```

### `Structuré` — run 3 of 5

```
Alors point rapide sur le projet.
On a basculé la partie abonnement lundi dernier, Thomas a fini l'intégration StoreKit et ça passe en sandbox. Il reste deux trucs. Le premier c'est l'historique des transcriptions qui n'est pas commencé du tout. Et le deuxième c'est le vocabulaire personnalisé. Et là dessus on a une spec mais pas de code.
Côté chiffres, on est à 412 téléchargements depuis le lancement, avec un taux de rétention à 7 jours de 19%, ce qui est faible, mais pas catastrophique pour une première version. L'objectif, c'est de passer la barre des 1000 avant fin octobre. Je vois Sarah jeudi à 14h pour caler la partie Apple Store. Et si tout se passe bien, on soumet la semaine du 12.
```

### `List`

```
- Basculé abonnement lundi dernier
- Thomas a fini intégration StoreKit, passe sandbox
- Historique transcriptions non commencé
- Vocabulaire personnalisé: spec, pas de code
- 412 téléchargements depuis lancement
- Taux rétention 7 jours: 19%
- Objectif: dépasser 1000 téléchargements avant fin octobre
- Visite Sarah jeudi à 14h
- Soumission semaine 12 si tout se passe bien
```

### Typeless (reference)

```
Point rapide sur le projet :

La partie abonnement a été basculée lundi dernier. Thomas a fini l'intégration StoreKit, et ça passe en sandbox.

Il reste deux trucs :

1. L'historique des transcriptions, qui n'est pas commencé du tout.
2. Le vocabulaire personnalisé (on a une spec, mais pas de code).

Côté chiffres :
• 412 téléchargements depuis le lancement.
• Taux de rétention à 7 jours de 19 % (ce qui est faible, mais pas catastrophique pour une première version).
• L'objectif est de passer la barre des 1 000 avant fin octobre.

Je vois Sarah jeudi à 14h pour caler la partie Apple Store et, si tout se passe bien, on soumet la semaine du 12.
```


---

## 3-message-draft

### Dictation (raw, Parakeet)

```
Je voulais juste te dire pour demain que je ne pourrais pas venir au bureau. J'ai un rendez-vous chez le dentiste à 11h and I think that it will déborder. Du coup, si tu peux décaler le point d'équipe à l'après-midi, ça m'arrangerait. Sinon je me débrouillerai pour suivre une visio depuis la salle à tante. Mais ce sera moyen. Dis-moi ce qui t'arrange.
```

### `Structuré` — run 2 of 5

```
Je voulais juste te dire pour demain que je ne pourrais pas venir au bureau.
J'ai un rendez-vous chez le dentiste à 11h, et je pense que ça va déborder.
Du coup, si tu peux décaler le point d'équipe à l'après-midi, ça me ferait plaisir.
Sinon, je me débrouillerai pour suivre une visio depuis la salle à tante.
Mais ce sera moyen.
Dis-moi ce qui t'arrange.
```

### `List`

```
- Ne peux pas venir au bureau demain
- Rendez-vous chez le dentiste à 11h
- Réunion décaler à l'après-midi
- Suivre visio depuis la salle à tante
- Dis-moi ce qui t'arrange
```

### Typeless (reference)

```
Je voulais juste te dire pour demain que je ne pourrai pas venir au bureau. J'ai un rendez-vous chez le dentiste à 11h et je pense que ça va déborder.

Du coup, si tu peux décaler le point d'équipe à l'après-midi, ça m'arrangerait. Sinon, je me débrouillerai pour suivre une visio depuis la salle d'attente, mais ce sera moyen.

Dis-moi ce qui t'arrange.
```


---

## 4-explanation

### Dictation (raw, Parakeet)

```
Alors je t'explique comment fonctionne la reconnaissance vocale sur le téléphone. En gros il y a trois étapes. La première c'est la capture. Le micro enregistre le son et le système le découpe en petits morceaux de quelques millisecondes. La deuxième étape c'est le modèle. Il prend ses morceaux et il essaye de deviner quels sons ont été prononcés, puis quels mots ces sons forment. Et pour ça, il utilise à la fois ce qu'il entend et ce qu'il a déjà écrit avant. Parce que le contexte aide énormément à lever les ambiguïtés. Et la troisième étape, c'est la mise en forme. Là on prend le texte brut qui sort du modèle et on ajoute la ponctuation les majuscules éventuellement on découpe en paragraphes le truc important à comprendre c'est que ces trois étapes ne coûtent pas du tout le même prix en calcul le deuxième c'est 90% du temps.
```

### `Structuré` — run 3 of 5

```
Alors je t'explique comment fonctionne la reconnaissance vocale sur le téléphone. En gros, il y a trois étapes.
La première étape est la capture. Le micro enregistre le son et le système le découpe en petits morceaux de quelques millisecondes.
La deuxième étape est le modèle. Il prend ses morceaux et essaie de deviner quels sons ont été prononcés, puis quels mots ces sons forment. Et pour ça, il utilise à la fois ce qu'il entend et ce qu'il a déjà écrit avant. Parce que le contexte aide énormément à lever les ambiguïtés.
La troisième étape est la mise en forme. Là, on prend le texte brut qui sort du modèle et on ajoute la ponctuation, les majuscules éventuellement, et on découpe en paragraphes le truc important à comprendre, c'est que ces trois étapes ne coûtent pas du tout le même prix. Le deuxième, c'est 90% du temps.
```

### `List`

```
- Capture: Micro enregistre et découpe en petits morceaux.
- Modèle: Analyse morceaux pour deviner sons et mots.
- Mise en forme: Ajoute ponctuation, majuscules, découpe en paragraphes.
```

### Typeless (reference)

```
Alors, je t'explique comment fonctionne la reconnaissance vocale sur téléphone. En gros, il y a trois étapes :

1. La capture : le micro enregistre le son et le système le découpe en petits morceaux de quelques millisecondes.
2. Le modèle : il prend ces morceaux et il essaie de deviner quels sons ont été prononcés, puis quels mots ces sons forment. Pour ça, il utilise à la fois ce qu'il entend et ce qu'il a déjà écrit avant, parce que le contexte aide énormément à lever les ambiguïtés.
3. La mise en forme : on prend le texte brut qui sort du modèle, on ajoute la ponctuation, les majuscules, et éventuellement on découpe en paragraphes.

Le truc important à comprendre, c'est que ces trois étapes ne coûtent pas du tout le même prix en calcul : la deuxième, c'est 90 % du temps.
```


---

## 5-rambling

### Dictation (raw, Parakeet)

```
Bon alors je me lance. Je voulais faire le point sur plein de choses en fait. Déjà, il faut que je répète le comptable le comptable je l'ai eu vendredi c'est l'assurance qu'il faut que je rappelle pour le truc de la voiture bon ensuite alors ça c'est important il faut absolument que je réponde à julien parce que ça fait je ne sais pas ça fait peut-être une semaine et demie qu'il attend. Je crois qu'il commence un peu à se demander si je les zappais. Ce qui est un peu le cas honnête. Quoi d'autre? Ah oui, le site, le site, il faut le refaire. Enfin, pas le refaire, je changeais la page d'accueil parce que là, elle ne dit pas du tout ce qu'on fait. Les gens arrivent, ils lisent trois lignes, ils partent. Donc changer la page d'accueil, mais avant ça, il faut que je sache ce qu'on fait, ce qui est bon. Ça c'est vraiment le sujet en fait. Enfin bref. Ah, j'ai aussi... Il faut que je pense à annuler l'abonnement machin. Celui à 19 euros par mois qu'on n'utilise plus depuis février. Ça fait donc 6 mois qu'on paye pour rien. Super quoi. Et puis la dernière chose, et là je note vraiment parce que sinon je vais oublier c'est de préparer les questions pour l'entretien de mardi voilà je crois que c'est tout ah non il y avait un dernier truc ça m'échappe mais ça me reviendra
```

### `Structuré` — run 2 of 5

```
Je me lance. Je voulais faire le point sur plein de choses.
Déjà, il faut que je répète le comptable. Je l'ai eu vendredi, c'est l'assurance qu'il faut que je rappelle pour le truc de la voiture.
Bon ensuite, ça c'est important. Il faut absolument que je réponde à Julien parce que ça fait peut-être une semaine et demie qu'il attend. Je crois qu'il commence un peu à se demander si je les zappais. Ce qui est un peu le cas honnête.
Quoi d'autre? Ah oui, le site. Le site, il faut le refaire. Enfin, pas le refaire, je changeais la page d'accueil parce que là, elle ne dit pas du tout ce qu'on fait. Les gens arrivent, ils lisent trois lignes, ils partent. Donc changer la page d'accueil, mais avant ça, il faut que je sache ce qu'on fait, ce qui est bon. Ça c'est vraiment le sujet en fait. Enfin bref.
Ah, j'ai aussi. Il faut que je pense à annuler l'abonnement machin. Celui à 19 euros par mois qu'on n'utilise plus depuis février. Ça fait donc 6 mois qu'on paye pour rien. Super quoi.
Et puis la dernière chose, et là je note vraiment parce que sinon je vais oublier, c'est de préparer les questions pour l'entretien de mardi.
Voilà, je crois que c'est tout. Ah non, il y avait un dernier truc, ça m'échappe, mais ça me reviendra.
```

### `List`

```
- Répéter le comptable, vendredi, assurance voiture
- Répondre à Julien, attendu depuis une semaine et demie
- Changer la page d'accueil, rendre claire l'activité
- Annuler l'abonnement machine, 19 euros/mois, non utilisé depuis février
- Préparer les questions pour l'entretien de mardi
```

### Typeless (reference)

```
Faire le point sur les choses à faire :

1. Rappeler l'assurance pour le truc de la voiture (j'ai déjà eu le comptable vendredi).
2. Répondre absolument à Julien : ça fait peut-être une semaine et demie qu'il attend et il commence un peu à se demander si je l'ai zappé (ce qui est honnêtement un peu le cas).
3. Changer la page d'accueil du site : pas besoin de tout refaire, mais là elle ne dit pas du tout ce qu'on fait, les gens arrivent, lisent trois lignes et partent. Mais avant ça, il faut vraiment clarifier ce qu'on fait.
4. Annuler l'abonnement à 19 € par mois : on ne l'utilise plus depuis février, ça fait six mois qu'on paye pour rien.
5. Préparer les questions pour l'entretien de mardi (à noter pour ne pas oublier).
```


---

## 6-unscripted

### Dictation (raw, Parakeet)

```
Alors je vais quand même faire un sixième test parce que les autres c'est pas vraiment ma voix, c'est pas naturel. L'idée c'est vraiment de voir encore une fois comment se comporte type less vs mon application dictus l'idée ça va être vraiment de repérer déjà la qualité de la transcription éventuellement et aussi de voir comment Type Laiss arrive à découper les différents paragraphes, les organiser, s'il met éventuellement des listes, s'il met des espaces entre les lignes. Et voilà, tout simplement l,'idée ça va être de voir tout ça. Et ensuite, on va analyser tout ça. Comme ça, ça va nous permettre d'essayer de créer par la suite soit un mode différent, soit améliorer notre polish et je pense que ça ça peut être vraiment très intéressant parce que ça va vraiment améliorer l'expérience des utilisateurs et même les utilisateurs qui sont gratuits parce que c'est vrai que là pour l'instant quand tu lances un grand un grand audio comme je peux le faire là tout de suite ça fait un gros pavé sur dictus alors quand je fais du développement c'est pas dérangeant mais c'est vrai que si tu veux l'utiliser pour discuter avec quelqu'un c'est un peu moyen
```

### `Structuré` — run 1 of 5

```
Je vais quand même faire un sixième test parce que les autres c'est pas vraiment ma voix, c'est pas naturel. L'idée c'est vraiment de voir encore une fois comment se comporte type less vs mon application dictus. L'idée ça va être vraiment de repérer déjà la qualité de la transcription éventuellement et aussi de voir comment Type Laiss arrive à découper les différents paragraphes, les organiser, s'il met éventuellement des listes, s'il met des espaces entre les lignes. Et voilà, tout simplement, l'idée ça va être de voir tout ça. Et ensuite, on va analyser tout ça. Comme ça, ça va nous permettre d'essayer de créer par la suite soit un mode différent, soit améliorer notre polish et je pense que ça ça peut être vraiment très intéressant parce que ça va vraiment améliorer l'expérience des utilisateurs et même les utilisateurs qui sont gratuits parce que c'est vrai que là pour l'instant quand tu lances un grand un grand audio comme je peux le faire là tout de suite ça fait un gros pavé sur dictus. Alors quand je fais du développement c'est pas dérangeant mais c'est vrai que si tu veux l'utiliser pour discuter avec quelqu'un c'est un peu moyen.
```

### `List`

```
- Faire un sixième test
- Vérifier la qualité de la transcription
- Analyser la découpe des paragraphes
- Vérifier l'organisation et l'utilisation de listes
- Vérifier l'utilisation d'espaces entre les lignes
- Analyser pour créer un mode différent
- Analyser pour améliorer le polish
- Améliorer l'expérience des utilisateurs
- Améliorer l'expérience des utilisateurs gratuits
- Réduire les problèmes de pavé lors de l'utilisation
```

### Typeless (reference)

```
Alors, je vais quand même faire un sixième test parce que les autres, c'est pas vraiment ma voix, c'est pas naturel.

L'idée, c'est vraiment de voir encore une fois comment se comporte Typeless vis-à-vis de mon application Dictus. Ça va être de repérer la qualité de la transcription et de voir comment Typeless arrive à :
• Découper les différents paragraphes et les organiser
• Mettre éventuellement des listes
• Mettre des espaces entre les lignes

Ensuite, on va analyser tout ça. Ça va nous permettre d'essayer de créer par la suite soit un mode différent, soit d'améliorer notre polish. Je pense que ça peut être vraiment très intéressant parce que ça va améliorer l'expérience des utilisateurs, et même celle des utilisateurs gratuits.

C'est vrai que pour l'instant, quand tu lances un long audio comme je le fais là tout de suite, ça fait un gros pavé sur Dictus. Quand je fais du développement, ce n'est pas dérangeant, mais si tu veux l'utiliser pour discuter avec quelqu'un, c'est un peu moyen.
```
