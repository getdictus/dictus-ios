# Trackpad de la barre d'espace : Hex, Dictus et Apple

Étude du 22 novembre 2026, pour #950. Sources : Hex (github.com/anomalyco/hex, branche `dev`, MIT), commits 667f771 (#2219) et 50e3464 (#2233), fichiers `TrackpadCursor.swift`, `FullKeyboardEngine+Trackpad.swift` et `FullKeyboardTouch.swift`, plus #2265 (sélection à deux pouces) ; Dictus `develop` 4ebcf0d4 ; trois vidéos du simulateur (iPhone 17, iOS 26.5, Safari, un `<textarea>` de quatre lignes), où le même script de gestes est joué sur le clavier d'Apple, sur Dictus `develop` et sur Dictus avec la PR.

Captures : `docs/study-captures/trackpad/` sur la branche `study/trackpad`.

## En bref

- Hex ne fait rien de magique. Il utilise la seule API qu'a un clavier, `adjustTextPosition(byCharacterOffset:)`, mais il ne compte plus « N points par caractère ». Il **reconstruit la mise en page du texte** que l'hôte partage : la police du corps de texte, des lignes coupées à la largeur du clavier moins 40 pt, et une hauteur de ligne. Le doigt traîne un point dans cette mise en page, et le curseur va à la frontière de caractère la plus proche. C'est ce qui donne le glissé fluide, le haut et le bas entre les lignes, et une vitesse proche de celle d'Apple.
- Dictus aujourd'hui : horizontal seulement, 12 pt par caractère quel que soit le texte, une accélération qui ne se déclenche jamais, 0,5 s d'appui, une vibration à chaque pas.
- Avec la PR, sur le même script joué dans Safari, Dictus finit aux mêmes endroits qu'Apple sur 4 gestes sur 6, et à quelques caractères près sur les 2 autres. Avant, il ratait 5 gestes sur 6.
- #950 avait **tort pour le mouvement**, qui est atteignable par approximation, et **raison pour la sélection** : aucune API publique ne permet à un clavier de sélectionner du texte dans l'hôte.

## 1. Comment Hex fait

### L'API

- **Déplacer** : `UITextDocumentProxy.adjustTextPosition(byCharacterOffset:)` et rien d'autre. Les décalages sont en **unités UTF-16**, celles du proxy : un 👍🏽 vaut 4. Avant #2219, Hex avançait par caractère et restait bloqué trois pas à l'intérieur d'un emoji.
- **Lire** : `documentContextBeforeInput` et `documentContextAfterInput`, à chaque mouvement proche du bord du texte connu, et sur les rappels `textDidChange` / `selectionDidChange` de l'hôte (`trackpadFieldChanged`).
- **Sélection** : aucune. Le commit #2219 le dit : « UITextDocumentProxy can't set one ». La sélection à deux pouces de #2265 est une expérience désactivée par défaut. Le clavier y garde **sa propre** plage, l'affiche dans sa barre, et propose Supprimer, Couper, Copier, Dicter et Annuler. Ces actions passent par les mêmes déplacements et suppressions du proxy. Rien n'est sélectionné dans l'hôte.

### Le modèle (`TrackpadCursor.State`)

- Le texte partagé est mis en page avec les largeurs de `UIFont.preferredFont(forTextStyle: .body)` (17 pt, Dynamic Type compris), mesurées une fois par caractère. Un « i » passe donc plus vite qu'un « m », comme chez Apple.
- Largeur de ligne : celle du clavier moins 40 pt, au moins 120 pt (`wrapWidth`). Coupure après la dernière espace qui tient, en plein mot seulement pour un mot plus large qu'une rangée. Hauteur de ligne : `lineHeight` de la police (environ 20 pt).
- Le point part du curseur. Chaque mouvement du doigt, multiplié par le gain, le déplace. Le curseur va à la frontière la plus proche sur la rangée du point.
- **Horizontal** : il s'arrête au début d'une ligne (revenir le fait repartir aussitôt) ; après la fin d'une ligne, le point continue jusqu'au bord du champ (revenir demande de refaire ce trajet), comme chez Apple. Sur une ligne coupée par le champ, il passe à la rangée suivante.
- **Vertical** : une ligne par hauteur de ligne, la première après une demi-ligne. Le x est gardé à travers les lignes courtes. Il s'arrête à la première et à la dernière ligne.
- **Bord du texte connu** : un hôte ne partage qu'un morceau. Selon Hex, le UITextView d'iOS 27.2 partage la phrase ou la ligne ; d'après mes logs, Safari partage environ 60 caractères coupés n'importe où. Au-delà, le curseur fait **un pas juste après le texte connu**, que l'hôte n'exécute que s'il y a du texte. Puis il relit le contexte (`catchUp`). Sans réponse en 100 ms (`edgeTimeout`), c'était le début ou la fin du texte.

### Seuils, vitesse, inertie

| Quoi | Valeur Hex | Mesure d'Apple selon Hex (iOS 27.2) |
| --- | --- | --- |
| Appui qui démarre le trackpad | 0,35 s, immobile | 330 à 365 ms |
| Glissé avant l'appui | ne compte pas ; avec 2 langues ou plus, 24 pt = changement de langue | idem, le trajet avant l'appui ne compte pas |
| Seuil `trackpadActivationDistance` | 10 pt, ne sert plus qu'au changement de langue depuis #2233 | — |
| Gain jusqu'à 1 000 pt/s | `1 + max(0, v − 40) / 960` | ×1,05 lent, ×1,4 à 400 pt/s, ×2 à 1 000 |
| Gain au-delà | `2 + (v − 1000) / 1690`, plafonné à ×4 | ×2,6 à 2 000 pt/s |
| Vitesse | distance sur les ≤ 30 ms les plus récents des 8 derniers échantillons, pas de temps ≥ 1/120 s | même gain dans toutes les directions |
| Inertie | **aucune** : le curseur s'arrête avec le doigt | « un coup rapide puis un glissé lent vont aussi loin que chacun seul » |
| Résultat | 80 pt à droite à 150/400/1 000/2 000 pt/s : 11/13/20/26 caractères | 11/13/21/26 |

### Les vibrations

Aucune. Ni au démarrage, ni par caractère. Hex cite le log d'iOS 27.2 : le clavier d'Apple ne demande aucun retour après celui de la touche espace elle-même. Un second doigt ne tape rien et ne vibre pas (test `testASecondFingerOnTheTrackpadTypesNothingAndItNeverTicks`). À vérifier sur iPhone : le simulateur n'a pas de moteur haptique, et Hex l'a lu dans un log, pas senti.

### Un tap rapide qui glisse reste une espace (#2233)

Avant #2233, avec une seule langue, un toucher de la barre d'espace qui glissait de 10 pt démarrait aussitôt le trackpad, et le lâcher ne tapait pas d'espace. Le TestFlight 56 perdait ainsi 15 espaces sur 15 sur des taps de 60 à 150 ms qui glissaient de 12 à 24 pt. Apple tape une espace dans tous ces cas, et même pour des glissés de 40 pt en 150 ms. **Seul l'appui immobile démarre le trackpad.** Le même commit corrige l'ordre dans un « rollover » : une espace encore tenue pendant qu'une lettre part en premier est tapée à sa place, et « a espace b » ne donne plus « ab ».

### Haut et bas entre les lignes

Ils sont dans le modèle (voir plus haut). Sur la boîte noire de Hex, 140 pt vers le bas depuis la ligne 1 atteignent la ligne 5, chez Apple comme chez Hex. Et 40 pt vers le haut en 40 ms montent de 4 lignes des deux côtés.

### Apparence

Les touches deviennent des touches vierges, à 60 % du chemin vers le fond : Apple dessine 242,242,247 sur 226,227,232 en clair, 54 sur 32 en sombre.

## 2. Ce que fait Dictus aujourd'hui (`develop` 4ebcf0d4)

`LongPressCursorMovementController` (`DictusKeyboard/Vendored/Controllers/LongPressController.swift`), démarré par `GiellaKeyboardView.touchesFoundLongpress` (`KeyboardView.swift`). Le déplacement passe par `DictusKeyboardBridge.didMoveCursor`.

| Quoi | Valeur |
| --- | --- |
| Appui | `UILongPressGestureRecognizer` par défaut : **0,5 s**, `allowableMovement` 10 pt (le même pour les popups d'accents) |
| Zone morte après l'appui | 8 pt **horizontaux**, puis une vibration moyenne (`HapticFeedback.trackpadActivated`) |
| Vitesse | **12 pt par caractère**, quel que soit le caractère |
| Accélération | prévue de ×1 à ×3 sur 120 pt depuis la ligne de base. Mais la ligne de base est remise à zéro après chaque pas, donc la distance ne dépasse jamais ~12 pt et le multiplicateur reste vers ×1,2 : **l'accélération ne joue pas** |
| Cadence | au plus 60 déplacements par seconde (16 ms) ; un mouvement plus rapproché est ignoré et rattrapé au suivant |
| Direction | **horizontale seulement** : `y` est gardé puis jamais lu |
| Vibration | un « tick » `UISelectionFeedbackGenerator` à **chaque** déplacement (`HapticFeedback.cursorMoved`) |
| Apparence | touches à 40 % d'opacité, **lettres visibles** |
| Second doigt | ignoré au toucher. Mais `touchesMoved` lit `touches.first`, qui peut être l'autre doigt, et le lever de **n'importe quel** doigt arrête le trackpad |
| Annulation système | `touchesCancelled` oublie le contrôleur sans remettre l'opacité : les touches peuvent rester à 40 % |
| Emoji | décalages en « caractères » envoyés comme unités UTF-16 : un emoji composé demande plusieurs pas |
| Tap qui glisse | reste une espace, sauf si le doigt sort de la barre d'espace (la touche active suit le doigt) |

## 3. Le même script, trois claviers (simulateur)

Le script (`demo.sh`) part de la fin du texte. Chaque geste tient la barre d'espace 0,7 s immobile, puis glisse. Les positions sont lues sur les vidéos (planches `strip-*.png`).

| Geste | Apple | Dictus avant | Dictus avec la PR |
| --- | --- | --- | --- |
| 100 pt à gauche, lent (1,2 s) | « du c\|hamp » | « derni\|ère », trop loin | « du c\|hamp » |
| 45 pt vers le haut | « première.\| » | ne bouge pas | « première.\| » |
| 25 pt vers le haut | « Deuxième\| » | ne bouge pas | « Deuxième\| » |
| 120 pt à droite en 0,15 s | « plu\|s » | « de \|test », sur sa ligne | « long\|ue », environ 5 caractères plus loin qu'Apple |
| 70 pt vers le bas | « dernièr\|e » | ne bouge pas | « du\| champ », environ 10 caractères avant celui d'Apple |
| diagonale haut-gauche | « Troisième ligne.\| » | « derni\|ère », seule la part horizontale | « Troisième ligne.\| » |

Une première version de la PR (Hex tel quel) finissait le 2e geste en **début** de « première » au lieu de sa fin. Les logs du clavier montrent pourquoi. Safari partage environ 60 caractères coupés en pleine ligne (« ligne, un peu plus longue que la première. »). La ligne partielle est donc posée comme si elle commençait au bord gauche. Quand Safari montre ensuite son début (« Deuxième »), Hex recale le point sur le curseur, dont la place était devinée, et le point retombe à x≈0. La PR garde le x du doigt quand le geste est vertical (`catchUp(keepingX:)`), avec un test qui échoue sans le correctif. Le reste est Hex tel quel.

## 4. Écarts avec le trackpad d'Apple, et ce qu'un clavier tiers peut faire

| Comportement | Apple | Dictus avant | Atteignable par une extension | Avec la PR |
| --- | --- | --- | --- | --- |
| Glissé fluide à l'échelle du texte | oui | 12 pt/car. fixes | **oui, par approximation** : on connaît le texte partagé, pas la police ni la largeur réelles du champ | modèle de Hex : police du corps de texte, largeur du clavier − 40 pt |
| Courbe de vitesse | ×1 à ×2,6 selon la vitesse | ×1,2 en pratique | **oui** : les horodatages `UITouch.timestamp` et les touches coalescées sont disponibles | gain de Hex, échantillons coalescés |
| Inertie | aucune | aucune | — | aucune |
| Délai d'appui | ~0,35 s | 0,5 s | **oui** | 0,35 s sur la barre d'espace ; les autres touches gardent 0,5 s |
| Tap qui glisse = espace | oui | oui | oui | oui (10 pt avant l'appui = tap) |
| Haut / bas entre les lignes | oui | non | **approximatif** : il faut deviner les coupures de ligne, et le texte n'est connu que par morceaux | oui, avec le pas au-delà du texte connu |
| Touches vierges | oui | lettres visibles à 40 % | **oui** | touches vierges à 40 % de leur couleur, lettres masquées |
| Vibrations | aucune après celle de l'espace (log iOS 27.2, via Hex) | moyenne au démarrage + un tick par pas | oui | aucune propre au trackpad : **à valider sur iPhone** |
| Second doigt | démarre une sélection | peut faire sauter ou arrêter le trackpad | ignorer : oui ; sélectionner : non | ignoré : ne tape rien, ne l'arrête pas |
| Sélection au second doigt | oui | non | **non** : `UITextDocumentProxy` n'a aucun moyen de poser une sélection ; `adjustTextPosition` la referme | non (voir plus bas) |
| Sélection par appui ferme | oui sur les iPhone 3D Touch | non | **non en pratique** : le 3D Touch a disparu après l'iPhone XS, et iOS 26 ne tourne sur aucun iPhone qui l'a ; l'appui ferme ne donnerait de toute façon pas de sélection | non |
| Démarrer par appui ferme n'importe où | iPhone 3D Touch seulement | non | possible sur un iPhone XS sous iOS 17/18 (`UITouch.force`), soit une poignée d'appareils | non (hors périmètre) |

**Ce que la sélection pourrait devenir.** Hex montre la seule voie : une sélection tenue par le clavier (#2265), avec sa propre barre et ses actions (supprimer, couper, copier, dicter), sans sélection visible dans l'hôte. Copier et couper demandent l'Accès complet (presse-papiers). C'est une fonctionnalité à part, avec de l'interface dans la barre du haut. Elle toucherait `KeyboardState`, que cette PR ne doit pas toucher (#992). À ouvrir en issue séparée si Pierre la veut.

## 5. #950 avait-il raison ?

L'issue rapportait la remarque de Christian Selig : un clavier tiers ne pourrait pas faire un trackpad au niveau d'Apple.

- **Tort pour le mouvement.** Le glissé fluide, l'accélération et le passage d'une ligne à l'autre sont atteignables avec la seule API `adjustTextPosition`, à condition de modéliser la mise en page au lieu de compter des points par caractère. Hex mesure des distances quasi identiques à celles d'Apple. Ici, sur Safari, la PR finit là où Apple finit sur 4 gestes sur 6, et à quelques caractères près sur les autres. FluidVoice (« presque au niveau d'Apple », selon Pierre) fait sans doute la même chose.
- **Raison pour la sélection.** Aucune API publique ne permet à une extension de sélectionner du texte dans l'hôte. Ni le second doigt ni l'appui ferme ne peuvent donc être reproduits. Seule une imitation tenue par le clavier est possible.
- **À moitié raison sur la précision.** Le modèle devine la police (corps de texte 17 pt) et la largeur (clavier − 40 pt). Dans un champ à une autre police (titre de Notes, bulles de Messages, page web stylée) ou d'une autre largeur, une montée d'une ligne peut tomber quelques caractères à côté. L'hôte ne partage d'ailleurs que des morceaux (Safari : ~60 caractères), si bien qu'une ligne dont le début n'a pas été montré est posée au jugé jusqu'à ce qu'il le soit. Apple, lui, connaît la vraie géométrie.

## 6. Ce que le simulateur ne montre pas

La sensation d'un vrai pouce (le script `axe` glisse à vitesse constante), les vibrations, et la précision dans Notes, Messages, Mail et les apps tierces. C'est la liste « À tester à la main » de la PR.

## Fichiers (`docs/study-captures/trackpad/`, branche `study/trackpad`)

- `trackpad-apple-reference.mp4`, `trackpad-avant-develop.mp4`, `trackpad-apres-pr.mp4` : le même script sur le clavier d'Apple, sur Dictus `develop` (4ebcf0d4) et sur Dictus avec la PR, enregistré par `xcrun simctl io recordVideo` (iPhone 17, iOS 26.5, Safari).
- `strip-apple.png`, `strip-avant.png`, `strip-apres.png` : une image par seconde de chaque vidéo (le texte et la première rangée de touches), faites par `strip.swift`.
- `apple-trackpad-blank.png`, `dictus-trackpad-blank.png` : les touches vierges en plein geste, chez Apple et chez Dictus avec la PR.
- `demo.sh` (le script de gestes, `axe drag --hold 0.7`), `page-de-test.html` (le champ, servi par `python3 -m http.server` sur 127.0.0.1, car `simctl openurl` refuse les URL `data:`).
