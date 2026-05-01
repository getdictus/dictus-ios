# Issue #92 — Approche B handoff (refactor self.inputView)

**Branche** : `fix/92-approach-b` (depuis `develop`)
**Date du handoff** : 2026-04-29
**Auteur du handoff** : conversation précédente, Claude Opus 4.7
**Mission** : éliminer DEFINITIVEMENT le flash visuel de chargement du clavier

---

## TL;DR pour la prochaine IA

Le bug #92 : à chaque apparition du clavier Dictus, un rectangle gris de 228pt apparaît visuellement pendant ~500ms. La cause racine est **structurelle** : `self.inputView = kbInputView` déclenche `UIView-Encapsulated-Layout-Height = ~504pt @ priorité 1000` par iOS pendant l'animation d'entrée. Aucune contrainte priorité ≤ 999 ne peut gagner contre 1000.

**Toutes les approches non-invasives ont été épuisées** sur la branche `fix/92-keyboard-load-flash` (déjà commit). L'approche B est le seul vrai fix structurel : retirer `self.inputView = kbInputView` et migrer le layout sur `self.view`, pattern upstream giellakbd-ios. Régression audio à gérer : créer un `KeyboardInputView` 1×1pt invisible juste pour conformer à `UIInputViewAudioFeedback`.

**Effort estimé** : ~80-150 LOC, refactor focalisé dans `DictusKeyboard/KeyboardViewController.swift`. 1-2h de travail + tests device.

---

## Contexte complet

### Le bug

À chaque apparition du clavier Dictus (tap dans Notes, Spotlight pull-down, retour d'app, etc.), pendant ~500ms :
- iOS impose `UIView-Encapsulated-Layout-Height = 504pt @ priorité 1000` sur `self.inputView`
- Pendant ce transient, kbInputView est 504pt mais le contenu utile (toolbar 52pt + clavier 224pt = 276pt) ne fait que 276pt
- Les 228pt restants exposent le chrome gris de UIInputView, créant un flash visuel jarrant

### Architecture actuelle (sur develop)

```
UIInputViewController (KeyboardViewController)
└── self.inputView = kbInputView: KeyboardInputView (UIInputView)  ← ICI le bug
    ├── hosting.view: UIView (UIHostingController contenu SwiftUI)
    │   └── KeyboardRootView (toolbar FR/mic + recording overlay + emoji picker)
    └── giellaKeyboard: GiellaKeyboardView (UICollectionView)
        └── 224pt key grid
```

Contraintes actuelles sur develop (avant approche B) :
- `kbInputView.heightAnchor = 276 @ 999` (cassé pendant transient car 1000 > 999)
- `hosting.top = kbInputView.top @ required`, `hosting.height = 52 @ 999`
- `keyboard.top = hosting.bottom @ required`, `keyboard.height = 224 @ 999`
- Pas de `keyboard.bottom`, pas de `hosting.bottom`

### Pattern upstream giellakbd-ios (référence pour approche B)

**Fichier** : `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Controllers/KeyboardViewController.swift`

Lignes 262-274 (`setupKeyboardContainer`) :
```swift
keyboardContainer = UIView()
keyboardContainer.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(keyboardContainer)
keyboardContainer.topAnchor.constraint(equalTo: view.topAnchor).enable(priority: .defaultHigh)
keyboardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor).enable(priority: .required)
keyboardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor).enable(priority: .required)
keyboardContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor).enable(priority: .required)
```

Lignes 98-105 (`initHeightConstraint`) :
```swift
private func initHeightConstraint() {
    // If this is removed, iPhone 5s glitches before finding the correct height.
    DispatchQueue.main.async {
        self.heightConstraint = self.keyboardContainer.heightAnchor
            .constraint(equalToConstant: self.preferredHeight)
            .enable(priority: UILayoutPriority(999))
    }
}
```

Lignes 360-368 (`viewDidLayoutSubviews`) :
```swift
private var isFirstRun = true
open override func viewDidLayoutSubviews() {
    if isFirstRun {
        isFirstRun = false
        initHeightConstraint()
    }
    super.viewDidLayoutSubviews()
}
```

**Pourquoi upstream n'a pas le bug** :
1. `self.inputView` n'est jamais assigné. iOS ne décore pas `self.view` avec la contrainte 1000.
2. `keyboardContainer` est subview directe de `self.view` avec `top=.defaultHigh`, `bottom=.required`, `leading/trailing=.required`. Pendant le transient, `self.view` est 504pt mais `keyboardContainer` reste 224pt collé en bas.
3. `heightConstraint` installé en `viewDidLayoutSubviews` first-run via `DispatchQueue.main.async` (commentaire upstream : "If this is removed, iPhone 5s glitches before finding the correct height").

### Régression audio à gérer

`UIDevice.current.playInputClick()` (clic des touches Apple natif) ne marche QUE si `self.inputView` est un `UIView` conforme à `UIInputViewAudioFeedback`. Si on supprime `self.inputView = kbInputView`, le clic des touches devient silencieux.

**Solution proposée** : créer un mini `KeyboardInputView` de 1×1pt, alpha=0 ou hidden=true, assigné à `self.inputView` UNIQUEMENT pour conformer au protocole audio. Tout le layout réel se fait sur `self.view` via `keyboardContainer`. Ce pattern est documenté dans le doc d'analyse comme alternative valide.

`KeyboardInputView` (DictusKeyboard/InputView.swift) est déjà conforme :
```swift
class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
    convenience init() { self.init(frame: .zero, inputViewStyle: .keyboard) }
}
```

### États du clavier à préserver

L'architecture actuelle gère **5 états** via `hostingHeightConstraint` et `giellaKeyboard.isHidden` :

1. **Toolbar mode (idle)** : `hostingHeight = 52pt`, `giellaKeyboard` visible. UI = toolbar(52) + keys(224) = 276pt
2. **Recording mode** : `hostingHeight = 276pt` (full keyboard area), `giellaKeyboard` visible derrière (recording overlay opaque le couvre)
3. **Emoji picker mode** : `hostingHeight = 276pt`, `giellaKeyboard.isHidden = true`
4. **Language switch** : reload du `giellaKeyboard` (destroy + recreate avec nouveau layout/locale)
5. **Cold start** : `hosting.view.isHidden = true` initialement, dévoilé après `viewWillAppear`

**Tous ces états doivent continuer à fonctionner après l'approche B**.

### Tests de non-régression critiques

Issues à ne PAS régresser (mémoire institutionnelle) :

| Issue | Description | Fichier de test |
|---|---|---|
| #56 | Dead zones edge keys | Pas de touches mortes sur les bords |
| #69 | Top-row key popups clipping | Popups au-dessus du clavier visibles |
| #99 | Toolbar displacement cold start | Toolbar pas déplacée au démarrage |
| #116 | Stretched keys on app switch | Pas de touches étirées au retour d'app |
| #128 | Stale controllers / memory leak | activeControllerID gating |
| #134 | Retain cycle / grey overlay freeze | Pas de gris non-cliquable après 10 switches |
| audio | `playInputClick()` actif | Clic Apple sur appui touches |
| recording overlay | Stretches/contracts smoothly | Pas de flash, transition fluide |
| emoji picker | Toggle smooth | Pas de flash |
| language switch | Globe key behavior | Pas de flash, layout correct |

---

## Spec d'implémentation approche B

### Étape 1 — restructurer le layout sur `self.view`

Dans `viewDidLoad` de `KeyboardViewController.swift` :

1. **Créer `kbInputView` minuscule** pour audio uniquement :
   ```swift
   let audioInputView = KeyboardInputView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
   audioInputView.alpha = 0
   self.inputView = audioInputView
   ```

2. **Créer `keyboardContainer = UIView()`** comme subview directe de `self.view` :
   ```swift
   let container = UIView()
   container.translatesAutoresizingMaskIntoConstraints = false
   container.backgroundColor = .clear
   self.view.addSubview(container)
   self.keyboardContainer = container
   ```

3. **Pinner keyboardContainer au pattern upstream** :
   ```swift
   let containerTop = container.topAnchor.constraint(equalTo: self.view.topAnchor)
   containerTop.priority = .defaultHigh  // yields under transient
   NSLayoutConstraint.activate([
       containerTop,
       container.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
       container.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
       container.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
   ])
   ```

4. **Ajouter hosting.view + giellaKeyboard à `keyboardContainer`** (pas à `kbInputView`) :
   ```swift
   container.addSubview(hosting.view)
   container.addSubview(keyboard)
   ```

5. **Pinner hosting + keyboard à `keyboardContainer`** (logique actuelle adaptée) :
   ```swift
   // hosting top, leading, trailing pinned to container; height as before
   hosting.view.topAnchor.constraint(equalTo: container.topAnchor)
   hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor)
   hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor)
   hostingHeight  // 52 @ 999
   // keyboard top to hosting bottom; bottom to container bottom; height 224 @ 999
   keyboard.topAnchor.constraint(equalTo: hosting.view.bottomAnchor)
   keyboard.leadingAnchor.constraint(equalTo: container.leadingAnchor)
   keyboard.trailingAnchor.constraint(equalTo: container.trailingAnchor)
   keyboard.bottomAnchor.constraint(equalTo: container.bottomAnchor)
   keyboardHeight  // 224 @ 999
   ```

### Étape 2 — installer la heightConstraint via `viewDidLayoutSubviews` first-run

Pattern upstream :
```swift
private var hasInstalledHeightConstraint = false
override func viewDidLayoutSubviews() {
    if !hasInstalledHeightConstraint {
        hasInstalledHeightConstraint = true
        installContainerHeight()
    }
    super.viewDidLayoutSubviews()
}

private func installContainerHeight() {
    DispatchQueue.main.async {
        guard let container = self.keyboardContainer else { return }
        let constraint = container.heightAnchor.constraint(equalToConstant: self.computeKeyboardHeight())
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        self.containerHeightConstraint = constraint
    }
}
```

### Étape 3 — migrer toutes les références `kbInputView` vers `keyboardContainer`

Sites concernés (sur la branche develop actuelle) :
- `viewDidLoad` : addSubview, constraint setup, heightConstraint sur kbInputView
- `viewWillAppear` : `disableWindowGestureDelay()`, snapshots
- `viewDidAppear` : `logLayoutSnapshot()`
- `handleDictationStatusChange` : `inputView?.setNeedsLayout(); inputView?.layoutIfNeeded()` → utiliser `self.view` ou `keyboardContainer`
- `reloadKeyboardLayout` : guard `inputView` → guard sur `keyboardContainer`, addSubview/constraint, setNeedsLayout
- `toggleEmojiPicker` : `inputView?.setNeedsLayout()` → `self.view` ou `keyboardContainer`

### Étape 4 — gestion `hostingHeightConstraint`

Le toggle entre 52pt (toolbar) et 276pt (recording/emoji) reste identique, juste sur `keyboardContainer` au lieu de `kbInputView`. **Important** : pendant recording overlay, hosting.height = container.height (276pt). Hosting overlay couvre le keyboard. Pas besoin de toggle bottom anchor (la solution option E sur fix/92-keyboard-load-flash devient obsolète car le 504pt transient n'existe plus).

### Étape 5 — tests sur device

Build et tester chaque état :
1. Apparition normale (tap Notes) → flash supprimé ?
2. Spotlight pull-down → flash supprimé ?
3. Retour d'app → flash supprimé ?
4. Cold start → toolbar bien positionnée, pas de displacement ?
5. Recording overlay → s'étire/contracte sans flash ?
6. Emoji picker → toggle sans flash ?
7. Language switch (globe) → reload sans flash ?
8. Audio click → `playInputClick()` toujours actif sur tap touches ?
9. Top-row popups → pas clippés ?
10. Edge keys → réactifs (pas de dead zones bord écran) ?
11. Switch rapide d'apps (10x) → pas de gris non-cliquable, pas de leak ?

### Étape 6 — bumper le build

Build 14 → 15 dans 3 plists :
- `DictusApp/Info.plist`
- `DictusKeyboard/Info.plist`
- `DictusWidgets/Info.plist`

---

## Risques et gotchas

### Risque 1 : Audio feedback ne marche pas

`playInputClick()` exige que `self.inputView` soit le UIInputView **visible** (selon Apple docs informels). Notre 1×1pt invisible pourrait ne pas suffire.

**Mitigation** : tester en priorité. Si ça ne marche pas, alternatives :
- `UIDevice.current.playInputClick()` peut être remplacé par `AudioServicesPlaySystemSound(1104)` (clic Apple ID 1104) en fallback
- Ou rendre l'input view de 1pt mais visible (alpha=1) hors écran (e.g., y=-10)

### Risque 2 : `disableWindowGestureDelay()` ne marche plus

Méthode lit `view.window?.gestureRecognizers` — elle dépend de la window de l'inputView/view. Vérifier que `self.view.window` est toujours accessible avec self.inputView en 1×1pt invisible.

### Risque 3 : `viewDidLayoutSubviews` se déclenche trop souvent

Le first-run guard est important. Sans lui, on réinstalle la heightConstraint à chaque layout pass → fuite de constraints.

### Risque 4 : Recording overlay positionnement vertical

Hosting.view a actuellement `top = kbInputView.top`. Avec keyboardContainer, hosting.view sera `top = keyboardContainer.top`. Comportement identique attendu, mais à vérifier en device : pendant recording, le waveform doit s'afficher centré dans les 276pt du container, pas plus haut que prévu.

### Risque 5 : compute `preferredHeight` / `computeKeyboardHeight()`

La fonction existe déjà dans le code (dans `KeyboardViewController.swift` ou un helper). Elle retourne 276pt. Vérifier qu'elle est appelée au bon moment (après que `traitCollection` est initialisé). Pattern upstream l'appelle dans `installContainerHeight` via `DispatchQueue.main.async` pour différer après la première passe layout.

### Risque 6 : Cold start regression #99

`hosting.view.isHidden = true` initialement, dévoilé en `viewWillAppear`. À préserver tel quel. Aucune raison que keyboardContainer change ça.

### Risque 7 : self.view background color

`self.view` (UIInputViewController.view) a un background par défaut clear. Pendant le transient 504pt (avant que keyboardContainer ne se cale en bas), le top de self.view sera visible si transparent → on voit ce qui est derrière (host app). C'est le comportement upstream et c'est OK. À vérifier que self.view.backgroundColor est bien `.clear`.

---

## Fichiers à modifier

### Modifs principales
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/KeyboardViewController.swift` — refactor layout

### Modifs build version
- `/Users/pierreviviere/dev/dictus/DictusApp/Info.plist` — build 14 → 15
- `/Users/pierreviviere/dev/dictus/DictusKeyboard/Info.plist` — build 14 → 15
- `/Users/pierreviviere/dev/dictus/DictusWidgets/Info.plist` — build 14 → 15

### Fichiers de référence (lecture seule)
- `/Users/pierreviviere/dev/dictus/.planning/debug/issue-92-keyboard-flash-analysis.md` — analyse 10-agents, régressions
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Controllers/KeyboardViewController.swift` — pattern upstream
  - Lignes 98-110 : `initHeightConstraint`
  - Lignes 262-274 : `setupKeyboardContainer`
  - Lignes 360-368 : `viewDidLayoutSubviews` first-run
- `/Users/pierreviviere/dev/giellakbd-ios/Keyboard/Utility/Utils.swift:217-226` — helper `enable(priority:)`

---

## État actuel des branches au moment du handoff

```
develop                          ← branche stable, target des PRs
  └── fix/92-approach-b           ← TU ES ICI, branche de travail
      (depuis 9437ff0 = dernier commit de develop)

fix/92-keyboard-load-flash       ← approche A + option E commitées
                                    (a27a980, partial fix)
                                    Build 14 testé, flash résiduel 228pt
```

**Ne PAS merger fix/92-keyboard-load-flash dans la nouvelle branche** — l'approche B remplace complètement ces tentatives. Si l'approche B échoue, on pourra toujours revenir à approche A via cherry-pick ou merge.

---

## Critères de succès

L'approche B sera considérée comme un succès si, sur device :

1. ✅ **Le flash 228pt gris a disparu** lors de l'apparition du clavier (Spotlight, Notes, retour d'app)
2. ✅ Audio click `playInputClick()` toujours actif
3. ✅ Recording overlay s'étire et se contracte sans flash
4. ✅ Emoji picker bascule sans flash
5. ✅ Language switch (globe) sans flash
6. ✅ Toutes les non-régressions (#56, #69, #99, #116, #128, #134) tiennent

Si tout est OK : commit + push + ouvrir PR vers develop pour merge.

Si flash résiduel inattendu : logger les frame.minY de keyboardContainer, hosting, keyboard via `logLayoutSnapshot` (sonde déjà étendue sur fix/92-keyboard-load-flash) et adapter.

Si régression audio : voir Risque 1, fallback `AudioServicesPlaySystemSound(1104)`.

---

## Mode de travail recommandé

1. **Démarrer en mode plan** (`shift+tab` au début) pour proposer le plan détaillé avant d'écrire du code
2. **Lire les fichiers de référence** avant de planifier (analysis doc + upstream)
3. **Build après chaque étape majeure** (`xcodebuild -project Dictus.xcodeproj -scheme DictusKeyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`)
4. **Demander à Pierre de tester sur device** avant de commit. Pierre teste sur iPhone 17 Pro / iOS 26.3.1 via TestFlight ou run direct
5. **Ne PAS push avant retour positif de Pierre**
6. **Commit message** : `fix(#92): refactor self.inputView to eliminate 504pt transient flash` + body détaillé

---

## Glossaire

- **Transient** : la fenêtre de ~500ms pendant laquelle iOS impose `UIView-Encapsulated-Layout-Height = 504pt @ priority 1000` sur `self.inputView`
- **kbInputView** : l'instance actuelle de `KeyboardInputView` assignée à `self.inputView` (à RETIRER ou réduire à 1×1pt)
- **keyboardContainer** : nouveau UIView, subview directe de `self.view`, qui hébergera hosting + giellaKeyboard
- **giellaKeyboard** : la `GiellaKeyboardView` qui contient les touches AZERTY (UICollectionView)
- **hosting** : le `UIHostingController<KeyboardRootView>` qui contient toolbar SwiftUI + recording overlay + emoji picker
- **bridge** : `DictusKeyboardBridge`, adaptateur giellakbd-ios delegate → Dictus actions

---

Bonne chance. La doc d'analyse `.planning/debug/issue-92-keyboard-flash-analysis.md` est ta meilleure amie pour les régressions à éviter et les hypothèses déjà testées.
