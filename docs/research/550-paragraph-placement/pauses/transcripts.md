# The five fixtures, raw and polished

Source: `dictus-polish-debug-20260912-001017.json`, events 209 to 213. Parakeet
`parakeet-tdt-0.6b-v3`, Normal polish, French, 2026-09-11 between 21:59 and 22:06 UTC.
Fixture A was dictated twice; the first attempt was cut short and is event 208.

Reference breaks were collected on 2026-09-12 from the numbered polished text, before
any silence measurement was shown to the speaker.

---

## A — read aloud, 19,7 s, reference: after sentence 2

**Raw and polished are identical.**

> Ce matin, j'ai commencé ma journée assez tranquillement. J'ai pris un café, puis j'ai regardé rapidement mes messages. Ensuite, je me suis mis au travail. Rien de vraiment particulier aujourd'hui, mais finalement la matinée est passée assez vite.

## B — read aloud, 17,4 s, reference: after sentence 1

**Raw**

> Je trouve qu'on passe beaucoup de temps à vouloir aller vite, faire les choses rapidement, répondre immédiatement, passer à la suivante alors que parfois prendre quelques minutes pour réfléchir permettre simplement de mieux faire les choses. Ce n'est pas forcément plus long, c'est juste une autre manière de travailler.

**Polished** — one grammar repair, `permettre` to `permet`.

> Je trouve qu'on passe beaucoup de temps à vouloir aller vite, faire les choses rapidement, répondre immédiatement, passer à la suivante alors que parfois prendre quelques minutes pour réfléchir permet simplement de mieux faire les choses. Ce n'est pas forcément plus long, c'est juste une autre manière de travailler.

## C — spontaneous, 25,6 s, reference: after sentence 2

**Raw**

> Ok, donc là bah écoute, je vais faire ce que tu m'as demandé, je vais faire des audios un peu plus naturels pour qu'on puisse essayer d'avancer sur cette issue. C'est vrai que ça m'embête. Je voudrais vraiment qu'on arrive à essayer de trouver un compromis force. paragraphes de taille.

**Polished** — the dangling `paragraphes de taille.` is dropped.

> Ok, donc là, bah écoute, je vais faire ce que tu m'as demandé. Je vais faire des audios un peu plus naturels pour qu'on puisse essayer d'avancer sur cette issue. C'est vrai que ça m'embête. Je voudrais vraiment qu'on arrive à essayer de trouver un compromis force.

The last five seconds of the audio are lost to a physical noise during the recording,
confirmed by the speaker. Transcription, not paragraphing.

## D — spontaneous, 60,0 s, reference: after sentences 1 and 5

**Raw** — Parakeet switches to English mid-dictation.

> Dans le cas où on n'arriverait vraiment pas à gérer ça de manière efficace, il faudra quand même qu'on réfléchisse à se soit laisser le mode normal comme ça. Et dans tous les cas, je pense que là où on peut essayer de se rattraper, c'est sur les sport modes. Parce que comme tu l'as dit, on peut... Enfin, on va pouvoir. And we'll unless the LLM, just enjoying the coherence of text. But that would permettrait peut-être de faire des trucs un petit peu plus poussés qui donneront quand même envie aux utilisateurs de payer en fait pour les smart modes parce que tout l'enjeu est là. Sans smart mode, il n'y a aucun intérêt d'acheter Dictus Pro.

**Polished**

> Dans le cas où on n'arriverait vraiment pas à gérer ça de manière efficace, il faudra quand même qu'on réfléchisse à se laisser le mode normal comme ça. Et dans tous les cas, je pense que là où on peut essayer de se rattraper, c'est sur les modes sportifs. Parce que comme tu l'as dit, on peut. Enfin, on va pouvoir. Et nous allons, sauf si le modèle, juste en profitant de la cohérence du texte. Mais cela permettrait peut-être de faire des trucs un peu plus poussés qui donneront quand même envie aux utilisateurs de payer en fait pour les modes intelligents parce que tout l'enjeu est là. Sans mode intelligent, il n'y a aucun intérêt d'acheter Dictus Pro.

Two observations that belong to other issues, not to this one. The raw output mixes
English into French, which is the #456 family. And the polish translates the product
terms the speaker used in English: `sport modes` becomes `modes sportifs` and
`smart modes` becomes `modes intelligents`. That is a word change, not whitespace.

## E — spontaneous, 48,1 s, reference: after sentence 1

**Raw**

> Parce que concrètement, dans les fonctionnalités premium actuellement, à part les smart modes, on a le vocabulaire perso, mais honnêtement, c'est sympa, mais je trouve que c'est encore un petit peu archaïque c'est à dire que l'utilisateur doit saisir manuellement les textes qu'il veut qui soient remplacés donc ça veut dire qu'il faut qu'il puisse les identifier en amont parce qu'en plus le c'est assez strict, sinon le llm ne touche pas ça. And on a l'historique de transcription, which honnêtement aurait pu être dans la version gratuite. But c'était histoire de faire une différence par rapport au payant quoi donc voilà à réfléchir moi je mettais vraiment beaucoup d'espoir dans les sport mode donc j'espère vraiment qu'on va arriver à faire quelque chose de correct

**Polished**

> Parce que concrètement, dans les fonctionnalités premium actuellement, à part les smart modes, on a le vocabulaire personnel, mais honnêtement, c'est sympa, mais je trouve que c'est encore un petit peu archaïque, c'est à dire que l'utilisateur doit saisir manuellement les textes qu'il veut qui soient remplacés, donc ça veut dire qu'il faut qu'il puisse les identifier en amont, parce qu'en plus, c'est assez strict, sinon le LLM ne touche pas ça. Et on a l'historique de transcription, qui honnêtement aurait pu être dans la version gratuite. Mais c'était histoire de faire une différence par rapport au payant, donc voilà à réfléchir. Moi, je mettais vraiment beaucoup d'espoir dans les sport modes, donc j'espère vraiment qu'on va arriver à faire quelque chose de correct.
