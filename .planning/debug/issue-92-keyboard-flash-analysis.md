# Issue #92 — Keyboard load flash : analyse approfondie (2026-04-29)

## TL;DR

À chaque apparition du clavier Dictus, `inputView.bounds` est forcé à **504pt** par iOS pendant ~500ms avant de retomber à 276pt. Cause : iOS impose `UIView-Encapsulated-Layout-Height` à priorité **1000** sur tout view assigné à `self.inputView` pendant l'animation d'entrée. Aucune contrainte 999 ne peut gagner contre 1000.

L'upstream giellakbd-ios n'a PAS ce bug parce qu'il :
1. N'assigne **jamais** `self.inputView` (utilise `self.view` directement, qui n'est pas décoré par cette contrainte 1000)
2. Bottom-anchor son `keyboardContainer` (top yield, bottom required, height=999) → pendant le transient le clavier reste 276pt collé en bas, pas de flash visible

## Reproduction confirmée

- iPhone 17 Pro / iOS 26.3.1
- TestFlight build 13 (commit `49e23d7@develop`)
- Captures et logs : `/Users/pierreviviere/Downloads/dictus-logs 12.txt`, `dictus-logs 13.txt`, screenshots du 2026-04-29 09:03 et 09:53
- Reproduction la plus dramatique : pull-down Spotlight depuis l'écran d'accueil

## Logs caractéristiques (build 14, après tentative self-sizing)

```
viewWillAppear_entry:    inputBounds=430x932 hostingConst=52 preferredH=276
viewDidAppear_settled:   inputBounds=430x504 viewBounds=430x504 keyboardFrame=430x224 hostingFrame=430x52
layoutSnapshot_500ms:    inputBounds=430x276 viewBounds=430x276 keyboardFrame=430x224 hostingFrame=430x52
```

Pattern identique sur 7 sessions consécutives. Self-sizing (`allowsSelfSizing=true` + `intrinsicContentSize`) **n'a pas** réduit le transient.

## Synthèse des 6 + 4 agents lancés

### Agents 1-6 (analyse initiale, 2026-04-29 matin)

1. **Apple official APIs** — Identifie `UIView-Encapsulated-Layout-Height` priorité 1000 comme contrainte gagnante. Recommande `allowsSelfSizing` + `intrinsicContentSize`. **Tenté → n'a pas marché.**
2. **Constraint priority forensics** — Confirme l'asymétrie hosting@999 OK / giellaKeyboard@999 KO via topologie : hosting top-anchored converge instantanément, giellaKeyboard bottom-anchored sur build 13 stretchait à 452pt.
3. **Open-source keyboards reference** — giellakbd upstream n'a pas le bug. Leur fix : installer heightConstraint dans `viewDidLayoutSubviews` first-run via `DispatchQueue.main.async`. Commentaire upstream explicite : *"If this is removed, iPhone 5s glitches before finding the correct height"*.
4. **Visual masking strategies** — Background opaque sur `kbInputView`. **Tenté → a aggravé le visuel** (rectangle gris très visible au lieu d'un fond système moins distinct).
5. **Git history regression hunt** — Confirme que ba12a69 (déjà sur develop) corrige la stretch des touches. Commit 6add300 (sondes mémoire) a rendu le transient visible en chargeant le main thread.
6. **View hierarchy analysis** — Mécanisme : `GiellaKeyboardView.bounds.didSet` → `reloadData()` → cellules à `bounds.height/4`. Sur build 13 (avec bottomAnchor), bounds=452 → cellules 113pt = touches doublées. Sur build avec ba12a69 : cellules restent 56pt mais 228pt vide visible.

### Agents 7-10 (comparaison upstream, 2026-04-29 fin)

7. **KeyboardViewController structural diff** — Diff complet. 3 différences cumulées causent le bug : (a) `self.inputView = kbInputView`, (b) absence de bottom-pin sur enfants de kbInputView, (c) UIHostingController ajouté.
8. **UIInputView lifecycle deep dive** — Confirme H1+H2+H3 TRUE. `self.inputView` opt-in dans pathway "self-sizing UIInputView" qui n'est honoré qu'**après** l'animation. Recommande retrait de `self.inputView`.
9. **Build settings/plist diff** — `IPHONEOS_DEPLOYMENT_TARGET 17.0` (nous) vs `13.0` (upstream). Plausible que iOS 14+ ait introduit la pathway "système → autolayout" en 2 temps. Test diagnostique secondaire.
10. **UIHostingController analysis** — INCONCLUSIVE leaning FALSE. Hosting est neutralisé par `compressionResistance=.defaultLow` + heightAnchor 999. Cause réelle = `UIView-Encapsulated-Layout-Height`. Hosting est incidental.

## Cause racine définitive

`self.inputView = kbInputView` (KeyboardViewController.swift, ligne ~213) déclenche l'application par iOS de `UIView-Encapsulated-Layout-Height = ~504pt` priorité 1000 pendant l'animation d'entrée. Combiné avec une absence de bottom-pin, le 228pt vide est exposé au-dessous des touches avec le fond gris par défaut de UIInputView.

## Approches recommandées (du moins invasif au plus complet)

### Approche A — Bottom-anchor minimal (recommandée pour tester)

**Modification** : 4 lignes dans `KeyboardViewController.swift` (et le miroir dans `reloadKeyboardLayout`).

```swift
// Lignes ~187-191 : ajouter bottomAnchor à priorité defaultHigh
keyboard.topAnchor.constraint(equalTo: hosting.view.bottomAnchor),  // garder
keyboard.leadingAnchor.constraint(equalTo: kbInputView.leadingAnchor),
keyboard.trailingAnchor.constraint(equalTo: kbInputView.trailingAnchor),
keyboard.bottomAnchor.constraint(equalTo: kbInputView.bottomAnchor),  // NOUVEAU, priorité par défaut required
keyboardHeight,  // garder priorité 999
```

Wait — il faut baisser la priorité du topAnchor pour que ça yield :

```swift
let topPin = keyboard.topAnchor.constraint(equalTo: hosting.view.bottomAnchor)
topPin.priority = .defaultHigh  // 750 — yield au transient
let bottomPin = keyboard.bottomAnchor.constraint(equalTo: kbInputView.bottomAnchor)
// bottomPin priority = .required par défaut
NSLayoutConstraint.activate([topPin, bottomPin, /* leading, trailing, heightAnchor 999 */])
```

**Pendant le transient 504pt** : top yield, bottom required gagne, height=999 fixe à 224pt → keyboard collé en bas du kbInputView, 228pt vide AU-DESSUS du toolbar (zone host app, transparente).

**Préserve** :
- `self.inputView = kbInputView` (audio feedback Apple intact)
- ba12a69 (heightAnchor=224 priorité 999)
- Toute la logique recording overlay / emoji picker / language switch

**Risque** : faible. C'est exactement le pattern upstream.

**Test diagnostique** : si l'utilisateur ne voit plus le rectangle gris au-dessus du clavier après cette modif, la cause structurelle est confirmée et on peut s'arrêter là.

### Approche B — Alignement complet upstream (refactor)

À tenter UNIQUEMENT si A laisse un visuel résiduel.

1. Retirer `self.inputView = kbInputView`
2. Renommer `kbInputView` en `keyboardContainer` et l'ajouter comme subview de `self.view`
3. Pinner `keyboardContainer` : `top=.defaultHigh`, `leading/trailing/bottom=.required`
4. Installer `heightAnchor=computeKeyboardHeight() priority 999` dans `viewDidLayoutSubviews` first-run via `DispatchQueue.main.async` (pattern upstream lignes 98-105 + 361-368)
5. **Régression audio à gérer** : `playInputClick()` ne marche que si `self.inputView` est un `UIInputView`. Workaround : créer un tiny `KeyboardInputView` (1x1pt, alpha=0) assigné à `self.inputView` juste pour conformer au protocole audio, et router le layout via `keyboardContainer` sur `self.view`.

## Régressions à éviter (mémoire institutionnelle de l'enquête)

| Tentative | Régression | Source |
|---|---|---|
| Désactiver autoresizing masks sur `kbInputView` | Clavier collapse à zéro largeur | commit `a2d847d` |
| Re-pinner `keyboard.bottomAnchor` SANS bottom-pin priorité required | Recrée stretch des touches | commit `ba12a69` |
| Contrainte sur `self.view.heightAnchor` | No-op | commits `d2b9024`/`2ccc528` |
| `alpha=0` sur tout `kbInputView` | Expose le gris système | tentative pré-2026-04-09 |
| `clipsToBounds=true` sur kbInputView | Casse popups top-row | issue #69 |
| `window.layer.speed = 0` | App Review rejection | hypothèse rejetée |
| Override `layoutSubviews` clamping bounds | Risque de freeze layout | hypothèse rejetée |
| `allowsSelfSizing=true` + `intrinsicContentSize` | Honoré post-animation seulement, ne supprime pas le 504pt transient | tentative 2026-04-29 build 14 |
| `self.preferredContentSize` | Pas la bonne API pour keyboards (Apple docs : popovers/sheets) | tentative 2026-04-29 build 14 |
| Background opaque sur `KeyboardInputView` | Aggrave visuel — rectangle gris très visible au lieu d'un fond système discret | tentative 2026-04-29 build 14 |

## Critères de validation

Sur device, après modif :

**Visuel** :
- [ ] Plus de touches doublées en taille pendant l'apparition
- [ ] Plus de rectangle gris au-dessus du clavier
- [ ] Apparition fluide en dark + light mode
- [ ] Cas Spotlight pull-down OK
- [ ] Cas tap dans Notes OK
- [ ] Cas retour d'app OK

**Logs** :
- [ ] `viewDidAppear_settled keyboardFrame=430x224` à toutes les sessions
- [ ] `keyboard.frame.minY` = `kbInputView.bounds.height - 224` pendant le transient (clavier en bas)
- [ ] `inputBounds=430x504` peut persister à viewDidAppear (acceptable si le visuel est OK)

## Tests de non-régression

- [ ] #69 — popups top-row pas clippés
- [ ] #99 — pas de toolbar déplacé en cold start
- [ ] #116 — pas de stretched keys au switch d'app
- [ ] #128 — pas de zombies controller
- [ ] #134 — pas de retain cycle ni de gris non-cliquable après 10 switches rapides
- [ ] Audio feedback Apple `playInputClick()` toujours actif
- [ ] Recording overlay s'étire et se contracte sans flash
- [ ] Emoji picker bascule sans flash
- [ ] Language switch (globe) sans flash

## Fichiers de référence

### Côté Dictus (à modifier)
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardViewController.swift`
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/InputView.swift`

### Côté upstream (référence)
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Controllers/KeyboardViewController.swift` (lignes 98-110, 262-274, 361-368)
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Utility/Utils.swift:217-226` (helper `enable(priority:)`)

## Historique des modifications déjà revertées

Sur la branche `fix/92-keyboard-load-flash`, j'avais tenté avant ce reset :
- `InputView.swift` : ajout `allowsSelfSizing`, `intrinsicContentSize`, `preferredHeight`, `applyChromeBackground` (background opaque), `layoutSubviews` probe
- `KeyboardViewController.swift` : suppression `heightConstraint`, ajout `preferredContentSize`, helpers `preferredHeightOfInput()`/`setInputPreferredHeight()`, sondes diagnostiques `preferredH=`

**Toutes ces modifs ont été revertées** au reset (`git checkout develop -- ...`), seul le bump build 13→14 est conservé. La branche est maintenant prête pour appliquer l'approche A.
