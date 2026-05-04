# Issue #92 — Fresh start handoff (2026-04-30)

**Branche actuelle** : `fix/92-approach-b`
**Repartir de** : commit `9437ff0` (HEAD de develop)
**État au moment du handoff** : 4 itérations testées sur cette branche, aucune n'a résolu le bug visuel. Toutes en WIP non commitées (peuvent être reset proprement).

---

## Le bug, sans interpretation

À chaque apparition du clavier Dictus, pendant ~500ms après `viewDidAppear`, l'utilisateur perçoit une transition visible : **le clavier semble "grandir" / s'ajuster en taille avant d'arriver à sa position finale**. Une zone d'environ **228pt de hauteur** apparaît AU-DESSUS de la zone clavier utile (au-dessus de la barre toolbar Dictus FR+mic), et disparaît après ~500ms.

**Reproduction la plus dramatique** :
1. iPhone 17 Pro / iOS 26.3.1
2. Spotlight pull-down depuis l'écran d'accueil → tap dans la barre de recherche
3. Le clavier apparaît avec ~228pt de zone supplémentaire au-dessus pendant ~500ms

Reproductible aussi : tap dans Notes, retour d'app après dictation, cold start.

---

## Diagnostic structurel confirmé (logs)

iOS impose `UIView-Encapsulated-Layout-Height ≈ 504pt @ priorité 1000` sur `self.inputView` (ou `self.view` si pas d'inputView assigné) pendant l'animation d'entrée. Notre clavier utile fait 276pt (toolbar 52pt + key grid 224pt). Différence = 228pt exposés.

Logs caractéristiques (toutes itérations) :
```
viewDidAppear_settled:  viewBounds=430x504  containerFrame=430x276@y=228  status=ready
layoutSnapshot_500ms:   viewBounds=430x276  containerFrame=430x276@y=0    status=ready
```

Notre `keyboardContainer` est correctement positionné (276pt collé en bas pendant le transient, puis 276pt au top après settlement). C'est la zone des **228pt qui restent au-dessus** qui pose problème — elle est visible (gris translucide), pas transparente.

---

## Architecture actuelle (état après les 4 itérations WIP)

```
UIInputViewController (KeyboardViewController)
└── self.view (UIView vanille, backgroundColor=.clear)  ← itération 4
    └── keyboardContainer: UIView (subview de self.view)
        ├── hosting.view (UIHostingController<KeyboardRootView>) — toolbar + recording overlay
        └── giellaKeyboard: GiellaKeyboardView (UICollectionView) — touches AZERTY
```

**Contraintes container** (pattern upstream giellakbd-ios) :
- `top = self.view.top` @ `.defaultHigh` (yields)
- `leading/trailing/bottom = self.view` @ `.required`
- `height = 276pt` @ `999` — installé en `viewDidLayoutSubviews` first-run via `DispatchQueue.main.async`

**Audio click** : géré dans `DictusKeyboardBridge.swift` via `AudioServicesPlaySystemSound(1104)` etc. (3 sons distincts via `KeySound.letter/delete/modifier`). **Aucune dépendance à `UIInputViewAudioFeedback`** ou `playInputClick()`.

---

## Les 4 hypothèses testées et leur résultat

| # | Hypothèse | Modif | Résultat | Pourquoi |
|---|-----------|-------|----------|----------|
| 1 | "Self.view + 1×1 audio inputView fonctionne" | `keyboardContainer` subview de `self.view` + `self.inputView = KeyboardInputView(1×1, alpha=0)` | ❌ KO total — clavier invisible, écran blanc | Setting `self.inputView` détache `self.view` de la window. Container width=0, hors hiérarchie. |
| 2 | "Override loadView pour faire de self.view un UIInputView" | `loadView()` → `self.view = KeyboardInputView` | ⚠️ Partiel — le clavier marche, container correctement positionné, mais flash gris persiste | UIInputView a un visual-effect chrome interne (frosted-glass system blur) non-désactivable via API publique |
| 3 | "Setter `.clear` sur l'UIInputView neutralise son chrome" | `inputView.backgroundColor = .clear` dans loadView | ❌ KO — chrome blur reste visible | Le visual effect interne n'est pas affecté par backgroundColor |
| 4 | "Drop UIInputView entièrement, UIView vanille .clear" | Drop `loadView()`, `self.view.backgroundColor = .clear` dans viewDidLoad, supprime `InputView.swift` (code mort, bridge utilise déjà AudioServicesPlaySystemSound) | ❌ KO — flash gris toujours présent | self.view est bien transparent, mais une vue PARENTE système iOS (`UIInputSetHostView` ou `UIInputSetContainerView`) reste grise et est visible à travers |

---

## Conclusion sur ce qui n'a pas marché

Toutes les hypothèses tournaient autour de "neutraliser self.view ou son équivalent". La conclusion forte de la 4e itération est que **le gris ne vient PAS de self.view** (qui est maintenant transparent confirmé). Il vient probablement d'une vue système iOS au-dessus de self.view dans la hiérarchie de la keyboard window :
- `UITextEffectsWindow` (la keyboard window)
- `UIInputSetContainerView` (vue parente système)
- `UIInputSetHostView` (vue parente système)
- `self.view` (notre UIView, transparent maintenant)

Aucune API publique ne permet de modifier ces vues système. C'est probablement pour ça qu'il faudrait inspecter via Xcode View Debugger / Reveal sur device pendant le transient pour comprendre quelle vue précise est grise.

---

## Pourquoi giellakbd-ios upstream n'a pas le bug (mystère non résolu)

L'agent de recherche a confirmé :
- Upstream n'override pas `loadView` → self.view est UIView vanille
- Upstream a `self.view.backgroundColor = .clear` (theme.backgroundColor en mode light)
- Upstream a la même structure container : top=defaultHigh, bottom=required, height=999

**On a fait exactement la même chose maintenant**. Et notre flash persiste. Donc soit :
- (a) Upstream a aussi le flash mais c'est moins visible/perceptible (différence subtile de timing, animation, ou couleur)
- (b) Il y a un trick quelque part qu'on n'a pas trouvé (build settings, plist key, deployment target différent)
- (c) iOS 26 traite différemment les keyboard extensions selon un facteur qu'on n'a pas identifié

**Cette question reste ouverte et est probablement la clé.**

---

## Pistes non explorées (pour le fresh start)

1. **Xcode View Debugger / Reveal sur device pendant le transient** : la SEULE façon fiable de voir QUELLE vue est grise dans la hiérarchie. Probablement nécessite de pause au bon moment (breakpoint dans viewDidAppear).
2. **Comparer les Info.plist** : Dictus vs giellakbd-ios. Y a-t-il une clé qui change le comportement de l'inputView ? `RequestsOpenAccess`, `IsASCIICapable`, `PrefersRightToLeft`, `KeyboardName`, etc.
3. **`UIInputViewController.preferredContentSize`** : pas testé. Peut signaler à iOS la taille préférée.
4. **`self.view.window.rootViewController?.view.backgroundColor = .clear`** : remonter la hiérarchie et clear toutes les parentes possibles.
5. **Override `viewWillAppear` pour chercher les superviews** : remonter la chaîne `view.superview?.superview?...` et logger leur backgroundColor + class. Peut-être qu'on peut neutraliser un parent.
6. **Tester sur simulator vs device** : si comportement différent, ça peut indiquer une animation iOS spécifique au hardware.
7. **`disablesAutomaticKeyboardDismissal`** : explorer toutes les properties de UIInputViewController pour voir s'il y a un toggle qu'on a raté.
8. **Recording d'écran 60fps + analyse frame par frame** : voir EXACTEMENT à quel moment le gris apparaît et disparaît, et si la couleur évolue (animation alpha ?).
9. **Récupérer/installer giellakbd-ios sur un device et comparer côte à côte avec un screen recording** : confirmer que upstream n'a vraiment PAS le bug, ou qu'il l'a aussi mais différemment.
10. **Tenter un nouvel angle : ne pas faire un container 276pt, mais un container 504pt avec contenu rendered uniquement dans les 276pt du bas** (sorte de "mask" ou clip). Le slot reste 504pt visuellement mais transparent au-dessus de notre contenu.

---

## Outils / skills suggérés pour le fresh start

- **Xcode View Debugger** : indispensable. Lancer Dictus sur device, déclencher le bug, capture la hiérarchie pendant le transient.
- **Reveal app** : alternative pro pour debug de view hierarchy live.
- **Screen recording 60fps** sur device (`xcrun simctl io booted recordVideo` pour simulator, ou Voice Memos + screen recording iOS pour device) puis analyse frame par frame.
- **`po self.view.recursiveDescription()`** dans LLDB pendant le transient pour dump la hiérarchie.
- **Agent de recherche dédié à la doc Apple privée / OpenRadar / forums Apple Dev** : chercher "third-party keyboard 504pt transient flash" ou "UIInputSetHostView background".
- **MCP Serena** : si disponible, pour explorer plus efficacement le codebase et naviguer.

---

## Pour repartir proprement

### Option recommandée : reset hard à develop

```bash
git reset --hard 9437ff0
```

Garde les 2 commits de doc (`615edd9` et `1ca9a79`), supprime toutes les modifs WIP des 4 itérations. Branche reste `fix/92-approach-b`. Repart de zéro côté code.

### Option : garder la suppression code mort uniquement

```bash
# Reset code mais garde la suppression InputView.swift et la simplification audio mention
git reset --hard 9437ff0
# Puis re-supprimer InputView.swift proprement dans une nouvelle commit
```

### Option : garder l'architecture container mais reset le reste

Pas recommandé — l'architecture container ne résout pas le bug et ajoute de la complexité sans bénéfice clair.

---

## Fichiers de référence à consulter avant de commencer

- `.planning/debug/issue-92-keyboard-flash-analysis.md` — analyse 10-agents originale (synthèse causes/régressions)
- `.planning/debug/issue-92-approach-b-handoff.md` — handoff de l'approche B (à considérer comme historique maintenant)
- `DictusKeyboard/KeyboardViewController.swift` — état actuel WIP (à reset)
- `DictusKeyboard/DictusKeyboardBridge.swift` — bridge avec audio implémentation (12 call sites `AudioServicesPlaySystemSound`)
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Controllers/KeyboardViewController.swift` — référence upstream
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Utility/Audio.swift` — référence audio upstream

---

## Prompt suggéré pour la nouvelle session

```
Je travaille sur l'issue #92 du repo Dictus (clavier iOS) : à chaque apparition
du clavier, pendant ~500ms, une zone de 228pt apparaît au-dessus de la zone
utile, donnant la sensation que le clavier "grandit". Cause structurelle :
iOS impose UIView-Encapsulated-Layout-Height = 504pt @ priorité 1000 sur
self.view pendant l'animation d'entrée, notre keyboard utile = 276pt.

Une session précédente a tenté 4 approches (refactor self.inputView, pattern
upstream giellakbd-ios, etc.). AUCUNE n'a résolu le bug. Tout le contexte
exhaustif est dans .planning/debug/issue-92-fresh-start-handoff.md — LIS-LE
EN ENTIER avant toute action.

Le travail WIP a été reset à develop, on repart de zéro côté code, mais on
garde la branche fix/92-approach-b active pour ne pas perdre le contexte.

Mission : tenter une NOUVELLE approche. Le handoff liste 10 pistes non explorées
(section "Pistes non explorées"). Le plus prometteur selon moi : utiliser le
Xcode View Debugger ou faire un dump LLDB de view.recursiveDescription pendant
le transient pour identifier QUI est gris. Sans cette info, on continue à tirer
à l'aveugle.

Mode plan obligatoire (shift+tab) avant toute action. Lis le handoff,
analyse les pistes, propose-moi un plan détaillé qui commence par DIAGNOSTIC
PRÉCIS (pas par code).

Pas de commit ni push avant retour positif de Pierre sur device.
```
