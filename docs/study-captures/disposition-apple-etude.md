# Disposition du clavier : Dictus face au clavier d'Apple (iOS 26.5)

Étude du 2026-11-22. Commande de Pierre (via Titus) : rapprocher au plus près la disposition du clavier Dictus de celle d'Apple, en mesurant d'abord et en ne corrigeant que les écarts mesurés.

- Dictus mesuré : `origin/develop` à `4ebcf0d4` (« avant »), puis la branche `fix/layout-apple-geometry` (« après »).
- Captures : `docs/study-captures/` sur la branche `study/disposition-apple-captures` (jamais fusionnée), et `/Users/pierre/dev/swipe-artifacts/disposition-captures/` sur le Mac.

## Résumé

1. **Debout (portrait), les rangées de Dictus étaient 2 à 2,5 pt trop hautes** sur l'iPhone SE et l'iPhone 17 : Dictus laissait 5,5 pt sous la rangée 4, Apple 4 pt (SE) et 3 pt (17) par rapport au bas de la grille que Dictus déclare. Sur le SE, les touches de Dictus faisaient aussi 43 pt contre 42. Le Pro Max était déjà aligné verticalement (réglé en #117).
2. **Debout, les touches de Dictus partaient à 3 pt du bord, celles d'Apple à 6,5 pt** sur les trois tailles, avec le même écart de 6 pt entre touches. Les centres des touches A…P étaient décalés jusqu'à 3,3 pt vers les bords.
3. **Couché (paysage), Dictus dessinait d'autres touches qu'Apple** : 36,7 pt sur un pas de 43,8 pt contre 27,3 pt sur 35,3 pt (17, Pro Max) et 37 pt sur 43,8 contre 32 pt sur 40 (SE). Sur le SE couché, Apple rentre ses touches de 72 pt de chaque côté, Dictus les étalait sur toute la largeur (−62 pt sur les centres extrêmes). Sur le 17 et le Pro Max couchés, la rangée 1 de Dictus était 34 pt au-dessus de celle d'Apple.
4. **Le clavier Dictus est plus haut que celui d'Apple** : +25 pt debout (SE, 17), +23 pt (Pro Max), +21 pt (SE couché), +40 pt (17 et Pro Max couchés). Debout, 17 pt de cet écart sont la bande qu'iOS dessine au-dessus de tout clavier tiers (la « bande de 17 pt » de Hex) : **elle apparaît bien, sur les trois iPhone, en portrait seulement**. Le reste vient de la barre d'outils de 52 pt (contre ~44 pt de barre de suggestions chez Apple) et, couché, de la grille de 175 pt. **Cette hauteur est la contrainte de hauteur déclarée (#166), zone interdite : elle n'est pas touchée.**
5. **Après correction**, sur les six configurations, chaque rangée, hauteur de touche, pas, bord, écart et centre de touche est à moins de 0,5 pt d'Apple (centres A…P : 0,25 pt au plus). Restent la hauteur du clavier et la barre du haut (contrainte déclarée), la largeur de maj/effacer et la composition de la rangée du bas (jeu de touches, pas géométrie).

## Méthode

### Simulateurs

Trois simulateurs créés pour l'étude, iOS 26.5 (23F77), Xcode 27.2, allégés avec `simslim on <udid> --keep com.apple.remindd` :

| Nom | Modèle | Écran (pt) | Échelle |
|---|---|---|---|
| `fix/layout-apple-geometry SE` | iPhone SE (3e génération) | 375 × 667 | 2x |
| `fix/layout-apple-geometry 17` | iPhone 17 | 402 × 874 | 3x |
| `fix/layout-apple-geometry ProMax` | iPhone 17 Pro Max | 440 × 956 | 3x |

Appareils en français (`fr-FR`), apparence claire, barre d'état figée (`simctl status_bar … override`).

### Hôte et champ

Une petite app hôte (`KBHost`, compilée avec `swiftc`, hors dépôt) : un seul `UITextField` en haut d'un écran blanc, qui prend le focus une seconde après l'apparition. L'orientation est forcée par l'app elle-même (`requestGeometryUpdate(.landscapeRight)` quand on la lance avec `-orientation landscape`), ce qui évite toute rotation pilotée par Simulator.app. Elle journalise `UIResponder.keyboardDidChangeFrameNotification` (cadre final du clavier) dans ses Documents : c'est la colonne « Hauteur du clavier » des tableaux. Le même champ, au même endroit, sert aux deux claviers.

Pourquoi pas Notes : il faut un tap pour créer une note et une rotation pilotée, et `axe` n'est pas installé sur ce Mac.

### Changer de clavier sans tap

`axe` absent, le clavier se choisit par la liste `AppleKeyboards` du `.GlobalPreferences.plist` de l'appareil, écrite avec `plistlib` appareil éteint (méthode de `docs/agents/simulator.md` §6 et §8) :

- clavier Apple : `['fr_FR@sw=AZERTY-French;hw=Automatic', 'emoji@sw=Emoji']` ;
- Dictus : `['com.pivi.dictus.keyboard', 'fr_FR@sw=AZERTY-French;hw=Automatic', 'emoji@sw=Emoji']` — iOS ouvre le premier clavier de la liste ;
- avec `AppleKeyboardsExpanded = 1` dans les deux cas.

Le clavier d'Apple affiche d'abord l'écran de présentation du « glisser pour écrire » : la clé `DidShowContinuousPathIntroduction = true` (dans `com.apple.Preferences.plist` et `.GlobalPreferences.plist`) le supprime. Aucune invite de permission n'a été déclenchée. Dictus tourne sans Accès complet (sa barre affiche « Accès complet requis ») : la grille de touches est la même.

### Mesure

`xcrun simctl io <udid> screenshot`, puis un outil Swift (CoreGraphics, hors dépôt) qui lit les pixels :

- **haut du panneau** : premier pixel non blanc en descendant à 30 % de la largeur ;
- **touches** : pixels dont la composante la plus faible dépasse le milieu entre le gris du panneau (226) et le blanc des touches (255) ; une colonne appartient à une touche quand au moins un quart des lignes de la rangée sont des pixels de touche (insensible aux lettres et aux coins arrondis) ;
- **haut et bas d'une touche** : le pixel de touche le plus haut et le plus bas sur les colonnes de la première touche de la rangée.

Les valeurs sont en points (pixels ÷ échelle), à ±0,5 pixel près : ±0,25 pt sur le SE, ±0,17 pt sur les deux autres. Deux points de méthode vérifiés au pixel :

- la barre d'espace (sans libellé), mesurée colonne par colonne, va de 621 à 663 pt chez Apple et chez Dictus « après » sur le SE, au même pixel ;
- Dictus arrondit ses touches à 10 pt, Apple à environ 8 pt : un pixel de bord peut être à moitié couvert chez l'un et plein chez l'autre (écart d'un demi-pixel, sous le seuil).

Les rangées et les bords mesurés ne dépendent pas de la grille supposée de Dictus : ce sont des positions à l'écran, comparées à l'écran.

### Références Hex

[Hex](https://github.com/anomalyco/hex), branche `dev`, MIT (Copyright (c) 2026 Christopher Langton) :

- `ios/HEXMobileTests/KeyboardLayoutTests.swift` : modèle des tests (valeurs d'Apple épinglées, cibles qui pavent le clavier sans zone morte ni recouvrement, touches dans leurs cibles) ;
- #2201, #2202, #2280 (`KeyboardLayout.swift`) : disposer les rangées depuis la hauteur réelle et le bas du clavier ;
- #2256, #2302 : barre du haut de 38 pt, bande de 17 pt dessinée par iOS au-dessus d'un clavier tiers.

**Hex a mesuré iOS 27.2, pas iOS 26.5.** Les chiffres diffèrent : sur iOS 27.2, Hex relève des touches de 43 pt sur 54 pt (17), 42 sur 54 (SE), 45 sur 56 (Pro Max) — identiques à iOS 26.5 debout — mais 32 pt sur 40 pt couché sur tous les iPhone, là où iOS 26.5 dessine 27,3 pt sur 35,3 pt sur le 17 et le Pro Max (32 sur 40 seulement sur le SE). Hex relève aussi la rangée 4 d'Apple 4 pt sous la fin de la vue d'un clavier tiers sur le 17 ; sur iOS 26.5 elle finit 3 pt au-dessus. Les valeurs de Dictus sont donc mesurées ici, et seule la démarche vient de Hex.

## La bande de 17 pt

Debout, sur les trois iPhone, le cadre que rapporte iOS pour Dictus fait 17 pt de plus que ce que Dictus demande, en haut : `kbFrame` = 285 pt sur le SE pour 268 pt demandés (52 pt de barre + 216 pt de grille), et le panneau visible commence 17 pt au-dessus de la vue de Dictus. Sur le 17 et le Pro Max s'y ajoutent les 75 pt de la rangée globe/micro qu'iOS dessine sous tout clavier (Apple compris). Couché, il n'y a pas de bande au-dessus ; il y a 21 pt de rangée globe sous le clavier sur le 17 et le Pro Max, rien sur le SE.

Un clavier tiers ne peut pas dessiner dans cette bande (Hex #2201 : iOS la découpe). Elle explique 17 des 25 pt d'écart de hauteur debout ; les 8 restants viennent de la barre d'outils de Dictus (52 pt) face à la barre de suggestions d'Apple (51,3 pt du haut du panneau à la rangée 1, barre comprise).

## Tableaux — avant (develop 4ebcf0d4)

Écart = Dictus − Apple, en points. En gras : plus de 0,5 pt. « Haut de la rangée » : position à l'écran depuis le haut de l'écran. « Sous la rangée 4 » : jusqu'au bas de l'écran (sur le 17 et le Pro Max, il inclut la rangée globe/micro d'iOS).

### iPhone SE (3e gén.) — portrait

Captures : `se-portrait-apple.png`, `se-portrait-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 260 | 285 | **+25** |
| Haut du panneau visible (depuis le haut de l'écran) | 407.5 | 382.5 | **-25** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.5 | 74 | **+22.5** |
| Haut de la rangée 1 (écran) | 459 | 456.5 | **-2.5** |
| Haut de la rangée 2 | 513 | 510.5 | **-2.5** |
| Haut de la rangée 3 | 567 | 564.5 | **-2.5** |
| Haut de la rangée 4 (rangée du bas) | 621 | 618.5 | **-2.5** |
| Pas vertical des rangées | 54 | 54 | +0 |
| Hauteur d'une touche (rangée 1) | 42 | 43 | **+1** |
| Hauteur de la rangée du bas | 42 | 43 | **+1** |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 4 | 5.5 | **+1.5** |
| Bord gauche (1re touche) | 6.5 | 3 | **-3.5** |
| Bord droit (dernière touche) | 6.5 | 3 | **-3.5** |
| Écart entre touches (rangée 1) | 6 | 6 | +0 |
| Largeur d'une lettre (rangée 1) | 30.8 | 31.5 | **+0.7** |
| Pas horizontal (rangée 1) | 36.78 | 37.5 | **+0.72** |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 17 | — |
| Centres des touches A…P, écart min / max | — | — | -3.25 / +3.25 |

### iPhone SE (3e gén.) — paysage

Captures : `se-landscape-apple.png`, `se-landscape-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 206 | 227 | **+21** |
| Haut du panneau visible (depuis le haut de l'écran) | 169.5 | 148.5 | **-21** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.5 | 55 | **+5.5** |
| Haut de la rangée 1 (écran) | 219 | 203.5 | **-15.5** |
| Haut de la rangée 2 | 259 | 247.5 | **-11.5** |
| Haut de la rangée 3 | 299 | 291 | **-8** |
| Haut de la rangée 4 (rangée du bas) | 339 | 335 | **-4** |
| Pas vertical des rangées | 40 | 43.83 | **+3.83** |
| Hauteur d'une touche (rangée 1) | 32 | 37 | **+5** |
| Hauteur de la rangée du bas | 32 | 37 | **+5** |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 4 | 3 | **-1** |
| Bord gauche (1re touche) | 72 | 3 | **-69** |
| Bord droit (dernière touche) | 72 | 3 | **-69** |
| Écart entre touches (rangée 1) | 6 | 6.22 | +0.22 |
| Largeur d'une lettre (rangée 1) | 46.9 | 60.5 | **+13.6** |
| Pas horizontal (rangée 1) | 52.89 | 66.72 | **+13.83** |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 0 | — |
| Centres des touches A…P, écart min / max | — | — | -62.25 / +62.25 |

### iPhone 17 — portrait

Captures : `iphone17-portrait-apple.png`, `iphone17-portrait-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 335 | 360 | **+25** |
| Haut du panneau visible (depuis le haut de l'écran) | 539.67 | 514.67 | **-25** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.33 | 74 | **+22.67** |
| Haut de la rangée 1 (écran) | 591 | 588.67 | **-2.33** |
| Haut de la rangée 2 | 645 | 642.67 | **-2.33** |
| Haut de la rangée 3 | 699 | 696.67 | **-2.33** |
| Haut de la rangée 4 (rangée du bas) | 753 | 750.67 | **-2.33** |
| Pas vertical des rangées | 54 | 54 | +0 |
| Hauteur d'une touche (rangée 1) | 43 | 43 | +0 |
| Hauteur de la rangée du bas | 43 | 43 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 78 | 80.33 | **+2.33** |
| Bord gauche (1re touche) | 6.67 | 3 | **-3.67** |
| Bord droit (dernière touche) | 6.33 | 3 | **-3.33** |
| Écart entre touches (rangée 1) | 6 | 6.22 | +0.22 |
| Largeur d'une lettre (rangée 1) | 33.5 | 34 | +0.5 |
| Pas horizontal (rangée 1) | 39.48 | 40.22 | **+0.74** |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 92 | — |
| Centres des touches A…P, écart min / max | — | — | -3.34 / +3.16 |

### iPhone 17 — paysage

Captures : `iphone17-landscape-apple.png`, `iphone17-landscape-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 208 | 248 | **+40** |
| Haut du panneau visible (depuis le haut de l'écran) | 194.67 | 154.67 | **-40** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.33 | 55 | **+5.67** |
| Haut de la rangée 1 (écran) | 244 | 209.67 | **-34.33** |
| Haut de la rangée 2 | 279.33 | 253.33 | **-26** |
| Haut de la rangée 3 | 314.67 | 297.33 | **-17.34** |
| Haut de la rangée 4 (rangée du bas) | 349.67 | 341 | **-8.67** |
| Pas vertical des rangées | 35.22 | 43.78 | **+8.56** |
| Hauteur d'une touche (rangée 1) | 27.33 | 36.67 | **+9.34** |
| Hauteur de la rangée du bas | 27.33 | 36.67 | **+9.34** |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 25 | 24.33 | **-0.67** |
| Bord gauche (1re touche) | 79 | 78 | **-1** |
| Bord droit (dernière touche) | 79 | 78 | **-1** |
| Écart entre touches (rangée 1) | 6 | 6.07 | +0.07 |
| Largeur d'une lettre (rangée 1) | 66.2 | 66.33 | +0.13 |
| Pas horizontal (rangée 1) | 72.19 | 72.41 | +0.22 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 21 | — |
| Centres des touches A…P, écart min / max | — | — | -1 / +1 |

### iPhone 17 Pro Max — portrait

Captures : `promax-portrait-apple.png`, `promax-portrait-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 345 | 368 | **+23** |
| Haut du panneau visible (depuis le haut de l'écran) | 611.67 | 588.67 | **-23** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.33 | 74 | **+22.67** |
| Haut de la rangée 1 (écran) | 663 | 662.67 | -0.33 |
| Haut de la rangée 2 | 719 | 718.67 | -0.33 |
| Haut de la rangée 3 | 775 | 774.67 | -0.33 |
| Haut de la rangée 4 (rangée du bas) | 831 | 830.67 | -0.33 |
| Pas vertical des rangées | 56 | 56 | +0 |
| Hauteur d'une touche (rangée 1) | 45 | 45 | +0 |
| Hauteur de la rangée du bas | 45 | 45 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 80 | 80.33 | +0.33 |
| Bord gauche (1re touche) | 6.67 | 3 | **-3.67** |
| Bord droit (dernière touche) | 6.33 | 3 | **-3.33** |
| Écart entre touches (rangée 1) | 6 | 6 | +0 |
| Largeur d'une lettre (rangée 1) | 37.3 | 38 | **+0.7** |
| Pas horizontal (rangée 1) | 43.3 | 44 | **+0.7** |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 92 | — |
| Centres des touches A…P, écart min / max | — | — | -3.17 / +3 |

### iPhone 17 Pro Max — paysage

Captures : `promax-landscape-apple.png`, `promax-landscape-dictus-avant.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 208 | 248 | **+40** |
| Haut du panneau visible (depuis le haut de l'écran) | 232.67 | 192.67 | **-40** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.33 | 55 | **+5.67** |
| Haut de la rangée 1 (écran) | 282 | 247.67 | **-34.33** |
| Haut de la rangée 2 | 317.33 | 291.33 | **-26** |
| Haut de la rangée 3 | 352.67 | 335.33 | **-17.34** |
| Haut de la rangée 4 (rangée du bas) | 387.67 | 379 | **-8.67** |
| Pas vertical des rangées | 35.22 | 43.78 | **+8.56** |
| Hauteur d'une touche (rangée 1) | 27.33 | 36.67 | **+9.34** |
| Hauteur de la rangée du bas | 27.33 | 36.67 | **+9.34** |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 25 | 24.33 | **-0.67** |
| Bord gauche (1re touche) | 121 | 120 | **-1** |
| Bord droit (dernière touche) | 121 | 120 | **-1** |
| Écart entre touches (rangée 1) | 6 | 6.22 | +0.22 |
| Largeur d'une lettre (rangée 1) | 66 | 66 | +0 |
| Pas horizontal (rangée 1) | 72 | 72.22 | +0.22 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 21 | — |
| Centres des touches A…P, écart min / max | — | — | -1 / +1 |

## Ce que la correction change

Une table par taille × orientation (`KeyPlaneGeometry`, DictusCore), en points dans la grille que Dictus déclare déjà (hauteur inchangée) :

| Taille | Orientation | Touche | Pas des rangées | Sous la rangée 4 | Bord | Écart |
|---|---|---|---|---|---|---|
| SE (écran < 700 pt) | portrait | 42 | 54 | 4 | 6,5 | 6 |
| 17 (700–899 pt) | portrait | 43 | 54 | 3 | 6,5 | 6 |
| Pro Max (≥ 900 pt) | portrait | 45 | 56 | 5,5 (inchangé) | 6,5 | 6 |
| SE | paysage | 32 | 40 | 4 | 72 | 6 |
| 17 | paysage | 27,33 | 35,33 | 4 | 4 (depuis la zone sûre) | 6 |
| Pro Max | paysage | 27,33 | 35,33 | 4 | 4 (depuis la zone sûre) | 6 |

Les touches sont posées depuis le bas de la grille, comme chez Apple. Les cibles tactiles pavent toute la grille : la rangée 1 monte jusqu'à la barre d'outils, la rangée 4 descend jusqu'en bas, la première et la dernière touche de chaque rangée vont jusqu'aux bords de l'écran (comme celles d'Apple et de Hex). Une page qui n'a pas quatre rangées (rangée de chiffres, #331) garde la grille régulière.

## Tableaux — après (fix/layout-apple-geometry)

Mêmes captures Apple, Dictus reconstruit avec la table.

### iPhone SE (3e gén.) — portrait

Captures : `se-portrait-apple.png`, `se-portrait-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 260 | 285 | **+25** |
| Haut du panneau visible (depuis le haut de l'écran) | 407.5 | 382.5 | **-25** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.5 | 76.5 | **+25** |
| Haut de la rangée 1 (écran) | 459 | 459 | +0 |
| Haut de la rangée 2 | 513 | 513 | +0 |
| Haut de la rangée 3 | 567 | 567 | +0 |
| Haut de la rangée 4 (rangée du bas) | 621 | 621 | +0 |
| Pas vertical des rangées | 54 | 54 | +0 |
| Hauteur d'une touche (rangée 1) | 42 | 42 | +0 |
| Hauteur de la rangée du bas | 42 | 42 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 4 | 4 | +0 |
| Bord gauche (1re touche) | 6.5 | 6.5 | +0 |
| Bord droit (dernière touche) | 6.5 | 6.5 | +0 |
| Écart entre touches (rangée 1) | 6 | 5.78 | -0.22 |
| Largeur d'une lettre (rangée 1) | 30.8 | 31 | +0.2 |
| Pas horizontal (rangée 1) | 36.78 | 36.78 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 17 | — |
| Centres des touches A…P, écart min / max | — | — | +0 / +0.25 |

### iPhone SE (3e gén.) — paysage

Captures : `se-landscape-apple.png`, `se-landscape-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 206 | 227 | **+21** |
| Haut du panneau visible (depuis le haut de l'écran) | 169.5 | 148.5 | **-21** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.5 | 70.5 | **+21** |
| Haut de la rangée 1 (écran) | 219 | 219 | +0 |
| Haut de la rangée 2 | 259 | 259 | +0 |
| Haut de la rangée 3 | 299 | 299 | +0 |
| Haut de la rangée 4 (rangée du bas) | 339 | 339 | +0 |
| Pas vertical des rangées | 40 | 40 | +0 |
| Hauteur d'une touche (rangée 1) | 32 | 32 | +0 |
| Hauteur de la rangée du bas | 32 | 32 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 4 | 4 | +0 |
| Bord gauche (1re touche) | 72 | 72 | +0 |
| Bord droit (dernière touche) | 72 | 72 | +0 |
| Écart entre touches (rangée 1) | 6 | 5.89 | -0.11 |
| Largeur d'une lettre (rangée 1) | 46.9 | 47 | +0.1 |
| Pas horizontal (rangée 1) | 52.89 | 52.89 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 0 | — |
| Centres des touches A…P, écart min / max | — | — | +0 / +0.25 |

### iPhone 17 — portrait

Captures : `iphone17-portrait-apple.png`, `iphone17-portrait-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 335 | 360 | **+25** |
| Haut du panneau visible (depuis le haut de l'écran) | 539.67 | 514.67 | **-25** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.33 | 76.33 | **+25** |
| Haut de la rangée 1 (écran) | 591 | 591 | +0 |
| Haut de la rangée 2 | 645 | 645.33 | +0.33 |
| Haut de la rangée 3 | 699 | 699.33 | +0.33 |
| Haut de la rangée 4 (rangée du bas) | 753 | 753.33 | +0.33 |
| Pas vertical des rangées | 54 | 54.11 | +0.11 |
| Hauteur d'une touche (rangée 1) | 43 | 43 | +0 |
| Hauteur de la rangée du bas | 43 | 43 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 78 | 77.67 | -0.33 |
| Bord gauche (1re touche) | 6.67 | 6.67 | +0 |
| Bord droit (dernière touche) | 6.33 | 6.67 | +0.34 |
| Écart entre touches (rangée 1) | 6 | 5.85 | -0.15 |
| Largeur d'une lettre (rangée 1) | 33.5 | 33.6 | +0.1 |
| Pas horizontal (rangée 1) | 39.48 | 39.48 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 92 | — |
| Centres des touches A…P, écart min / max | — | — | -0.18 / +0.17 |

### iPhone 17 — paysage

Captures : `iphone17-landscape-apple.png`, `iphone17-landscape-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 208 | 248 | **+40** |
| Haut du panneau visible (depuis le haut de l'écran) | 194.67 | 154.67 | **-40** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.33 | 89 | **+39.67** |
| Haut de la rangée 1 (écran) | 244 | 243.67 | -0.33 |
| Haut de la rangée 2 | 279.33 | 279 | -0.33 |
| Haut de la rangée 3 | 314.67 | 314.33 | -0.34 |
| Haut de la rangée 4 (rangée du bas) | 349.67 | 349.67 | +0 |
| Pas vertical des rangées | 35.22 | 35.33 | +0.11 |
| Hauteur d'une touche (rangée 1) | 27.33 | 27.33 | +0 |
| Hauteur de la rangée du bas | 27.33 | 27.33 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 25 | 25 | +0 |
| Bord gauche (1re touche) | 79 | 79 | +0 |
| Bord droit (dernière touche) | 79 | 79 | +0 |
| Écart entre touches (rangée 1) | 6 | 5.85 | -0.15 |
| Largeur d'une lettre (rangée 1) | 66.2 | 66.33 | +0.13 |
| Pas horizontal (rangée 1) | 72.19 | 72.19 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 21 | — |
| Centres des touches A…P, écart min / max | — | — | +0 / +0.17 |

### iPhone 17 Pro Max — portrait

Captures : `promax-portrait-apple.png`, `promax-portrait-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 345 | 368 | **+23** |
| Haut du panneau visible (depuis le haut de l'écran) | 611.67 | 588.67 | **-23** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 51.33 | 74 | **+22.67** |
| Haut de la rangée 1 (écran) | 663 | 662.67 | -0.33 |
| Haut de la rangée 2 | 719 | 718.67 | -0.33 |
| Haut de la rangée 3 | 775 | 774.67 | -0.33 |
| Haut de la rangée 4 (rangée du bas) | 831 | 830.67 | -0.33 |
| Pas vertical des rangées | 56 | 56 | +0 |
| Hauteur d'une touche (rangée 1) | 45 | 45 | +0 |
| Hauteur de la rangée du bas | 45 | 45 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 80 | 80.33 | +0.33 |
| Bord gauche (1re touche) | 6.67 | 6.67 | +0 |
| Bord droit (dernière touche) | 6.33 | 6.33 | +0 |
| Écart entre touches (rangée 1) | 6 | 6 | +0 |
| Largeur d'une lettre (rangée 1) | 37.3 | 37.3 | +0 |
| Pas horizontal (rangée 1) | 43.3 | 43.3 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 92 | — |
| Centres des touches A…P, écart min / max | — | — | +0 / +0 |

### iPhone 17 Pro Max — paysage

Captures : `promax-landscape-apple.png`, `promax-landscape-dictus-apres.png`

| Mesure (pt) | Apple | Dictus | Écart (Dictus − Apple) |
|---|---|---|---|
| Hauteur du clavier (cadre `keyboardFrameEnd`) | 208 | 248 | **+40** |
| Haut du panneau visible (depuis le haut de l'écran) | 232.67 | 192.67 | **-40** |
| Barre du haut (haut du panneau → haut de la rangée 1) | 49.33 | 89 | **+39.67** |
| Haut de la rangée 1 (écran) | 282 | 281.67 | -0.33 |
| Haut de la rangée 2 | 317.33 | 317 | -0.33 |
| Haut de la rangée 3 | 352.67 | 352.33 | -0.34 |
| Haut de la rangée 4 (rangée du bas) | 387.67 | 387.67 | +0 |
| Pas vertical des rangées | 35.22 | 35.33 | +0.11 |
| Hauteur d'une touche (rangée 1) | 27.33 | 27.33 | +0 |
| Hauteur de la rangée du bas | 27.33 | 27.33 | +0 |
| Sous la rangée 4 (jusqu'au bas de l'écran) | 25 | 25 | +0 |
| Bord gauche (1re touche) | 121 | 121 | +0 |
| Bord droit (dernière touche) | 121 | 121 | +0 |
| Écart entre touches (rangée 1) | 6 | 6 | +0 |
| Largeur d'une lettre (rangée 1) | 66 | 66 | +0 |
| Pas horizontal (rangée 1) | 72 | 72 | +0 |
| Bande iOS hors du clavier tiers (cadre − hauteur demandée par Dictus) | — | 21 | — |
| Centres des touches A…P, écart min / max | — | — | +0 / +0 |

## Écarts corrigés

| Écart (avant) | Où | Correction |
|---|---|---|
| Rangées 2 à 2,5 pt trop hautes | SE et 17, portrait | rangée 4 à 4 pt (SE) / 3 pt (17) du bas de la grille au lieu de 5,5 |
| Touches de 43 pt au lieu de 42 | SE, portrait | touche 42 pt sur un pas de 54 |
| Touches à 3 pt du bord au lieu de 6,5 (centres jusqu'à ±3,3 pt) | portrait, les trois tailles | bord 6,5 pt, écart 6 pt |
| Touches couchées de 37 pt sur 43,8 au lieu de 32 sur 40, toute la largeur au lieu de 72 pt de retrait | SE, paysage | touches 32 pt, pas 40, retrait 72 pt |
| Touches couchées de 36,7 pt sur 43,8 au lieu de 27,3 sur 35,3, rangée 1 34 pt trop haute | 17 et Pro Max, paysage | touches 27,33 pt, pas 35,33, 4 pt sous la rangée 4 |
| Bord couché 1 pt trop près | 17 et Pro Max, paysage | bord 4 pt depuis la zone sûre au lieu de 3 |

## Écarts laissés, et pourquoi

| Écart | Valeur | Raison |
|---|---|---|
| Hauteur du clavier | +25 (SE, 17), +23 (Pro Max) debout ; +21 (SE), +40 (17, Pro Max) couché | C'est la contrainte de hauteur déclarée (`KeyboardHeightProvider`), zone interdite (#166, CLAUDE.md). Debout, 17 pt sont la bande d'iOS, hors d'atteinte de tout clavier tiers. |
| Barre du haut (haut du panneau → rangée 1) | +25 / +23 debout ; +21 (SE), +39,7 (17, Pro Max) couché | Conséquence de la ligne précédente : les touches sont maintenant sur celles d'Apple, donc tout le surplus de hauteur est au-dessus de la rangée 1. **Couché sur le 17 et le Pro Max, cela laisse une bande vide d'environ 38 pt entre la barre d'outils et la rangée 1** (19 pt sur le SE). La cible tactile de la rangée 1 la couvre. La supprimer demande de baisser la hauteur déclarée couchée (175 pt de grille), donc une décision sur #166. |
| Barre d'outils 52 pt contre ~44 pt chez Apple (38 pt chez Hex) | +8 pt | Sa hauteur entre dans la hauteur déclarée ; même raison. |
| Largeur de maj et d'effacer (rangée 3) | maj 6,5–55,5 contre 6,5–48,5 pt (SE) ; 79–181 contre 79–167 pt (17 couché) | Apple dessine ces touches plus étroites avec un espace plus large avant W ; chez Dictus c'est la largeur en unités de la touche (`KeyboardLayouts`, 1,5 unité), donc le jeu de touches et ses cibles tactiles, pas la géométrie du plan. Les lettres de la rangée 3 sont, elles, au pixel près sur celles d'Apple. |
| Composition de la rangée du bas | Apple : 123, emoji, micro, espace, retour (SE) ; 123, espace, retour (17, Pro Max, emoji et micro hors clavier). Dictus : globe, 123, emoji, espace, retour (SE) ; 123, emoji, espace, retour | Jeu de touches décidé en #877 (unités 1,25 / 1,25 / 5,5 / 2). Hors du périmètre « géométrie ». Les bords et la hauteur de la rangée sont alignés. |
| Tailles de police en paysage | non mesuré | Les libellés gardent la taille du thème ; les touches couchées étant plus basses, ils paraissent plus gros que chez Apple. À regarder sur iPhone. |

## Fichiers de capture

Dans `docs/study-captures/` (branche `study/disposition-apple-captures`) et `/Users/pierre/dev/swipe-artifacts/disposition-captures/`. Chaque `.png` a son `.log` (le cadre du clavier rapporté par iOS à l'hôte).

| Appareil | Orientation | Apple | Dictus avant | Dictus après |
|---|---|---|---|---|
| iPhone SE (3e gén.) | portrait | `se-portrait-apple.png` | `se-portrait-dictus-avant.png` | `se-portrait-dictus-apres.png` |
| iPhone SE (3e gén.) | paysage | `se-landscape-apple.png` | `se-landscape-dictus-avant.png` | `se-landscape-dictus-apres.png` |
| iPhone 17 | portrait | `iphone17-portrait-apple.png` | `iphone17-portrait-dictus-avant.png` | `iphone17-portrait-dictus-apres.png` |
| iPhone 17 | paysage | `iphone17-landscape-apple.png` | `iphone17-landscape-dictus-avant.png` | `iphone17-landscape-dictus-apres.png` |
| iPhone 17 Pro Max | portrait | `promax-portrait-apple.png` | `promax-portrait-dictus-avant.png` | `promax-portrait-dictus-apres.png` |
| iPhone 17 Pro Max | paysage | `promax-landscape-apple.png` | `promax-landscape-dictus-avant.png` | `promax-landscape-dictus-apres.png` |

## Limites

- Simulateur seulement. Un iPhone peut donner à un clavier tiers une hauteur différente selon l'app (Hex #2280 : Spotlight sur iOS 27.3) ; la table ne s'applique que si la grille est assez haute pour les rangées d'Apple, sinon Dictus garde sa grille régulière.
- Un seul champ (un `UITextField` sans barre d'accessoires). Hex note que la bande de 17 pt dépend du champ sur iOS 27.2 ; ici elle est apparue dans ce champ, sur les trois iPhone, en portrait.
- Clavier français AZERTY, apparence claire, sans Accès complet. Les pages 123 et `#+=` (quatre rangées) suivent la même table ; elles n'ont pas été capturées.

## Banc #954 (fr, en, en-typos), avant et après

`tools/keyboard-bench/run.sh --langs fr,en,en-typos`, grille 402 × 216 pt (iPhone 17 debout), même simulateur, `develop` 4ebcf0d4 puis la branche (`bench-avant.md`, `bench-apres.md` à côté de cette étude).

| Langue | Mots faux avant → après | Lettres fausses | Espaces manqués | Autocorrection cassée / mal corrigée |
|---|---|---|---|---|
| fr | 3 → 3 | 13 → 13 | 0 → 0 | 0 / 0 → 0 / 0 |
| en | 7 → 8 | 21 → 20 | 2 → 3 | 0 / 1 → 0 / 1 |
| en-typos | 1 → 1 | 0 → 0 | 0 → 0 | 0 / 1 → 0 / 1 |

Seuls deux appuis changent de résultat, tous deux en anglais : un « i » visé 1 pt au-dessus de la grille (dans la barre d'outils) ne tapait rien et tape « i » (la rangée 1 est descendue de 2,5 pt) ; une espace visée 0,49 rangée sous le centre de la barre d'espace tombe 2 pt sous la grille et ne tape plus rien (la barre d'espace finit maintenant 3 pt au-dessus du bas de la grille, comme celle d'Apple), ce qui colle « still have ». Le banc vise le centre de la touche dessinée : les appuis suivent les touches là où elles sont.
