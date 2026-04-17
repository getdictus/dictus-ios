# Optimiser un clavier iOS custom ou une extension clavier pour une expérience proche du clavier de l’app Téléphone

## Résumé exécutif

Reproduire « la sensation Téléphone » (app clavier du pavé numérique) n’est pas seulement une question d’apparence : c’est un budget de latence (visuel + haptique + audio), une gestion stricte du thread principal, et une intégration correcte avec les APIs de saisie (traits, proxy, gestion du focus/chaîne de responders, sélection) — tout en acceptant des limites structurelles des extensions clavier. citeturn10search0turn9search0turn9search3

Si votre objectif est “comme Téléphone” **dans votre propre app**, la voie la plus réaliste est : **utiliser autant que possible le clavier système** (ex. `UIKeyboardType.phonePad`) et ne customiser que ce qui apporte une vraie valeur, car Apple a déjà optimisé à l’extrême le pipeline d’événements/animation/rendu. citeturn14search0turn1search6

Si votre objectif est “comme Téléphone” **avec une extension clavier système**, il faut savoir qu’Apple documente des restrictions qui impactent directement l’équivalence : notamment, une extension clavier **ne peut pas s’afficher dans les champs “phone pad”** (ex. champs téléphone de Contacts) et elle est remplacée temporairement par le clavier système, et la sélection de texte reste sous le contrôle de l’app hôte. citeturn10search0turn9search5  
En conséquence, une extension clavier ne peut **pas** “remplacer le clavier Téléphone” dans les contextes `.phonePad` d’autres apps ; l’approche “clavier Téléphone-like” via extension vise plutôt les champs standard, pas les champs phone pad. citeturn10search0turn9search5

Pour obtenir une réactivité perçue proche de Téléphone, visez un contrat simple : sur `touchDown` vous devez **(1)** afficher un highlight de touche au prochain frame, **(2)** déclencher haptique/audio sans bloquer, **(3)** insérer/supprimer via `textDocumentProxy` (extension) ou via le contrôle texte (in‑app) avec un minimum de travail synchrone. Les traitements “carburant” (suggestions, formatage, analytics, mise en page lourde) doivent être **décorrélés** et “coalescés”. citeturn5search15turn5search21turn5search10turn3search35

Enfin, pour converger vers l’expérience Téléphone, vous devez instrumenter et mesurer : **latence input→highlight**, **input→haptique**, **input→insert**, **taux de frames ratées** (hitches/hangs), mémoire, énergie. Apple recommande l’instrumentation via signposts/OSSignposter + Instruments (Points of Interest) et l’analyse des hangs via Instruments. citeturn5search10turn5search1turn5search21turn5search14turn5search22

## “Comme Téléphone” : critères observables et limites structurelles

Une expérience “Téléphone‑like” peut être spécifiée en critères **mesurables** (ceux-ci vous servent de SLA interne) :

- **Latence visuelle** (touchDown → highlight/popup) : idéalement **≤ 1 frame**. À 60 fps, un frame = 16,67 ms ; Apple rappelle ce budget (60 FPS ≈ 16,67 ms) dans ses bonnes pratiques de framerate. citeturn11search1  
- **Latence haptique** : haptique déclenchée sans “ratés”, et préparée pour minimiser la latence (via `prepare()` sur les feedback generators). citeturn12search9turn1search2  
- **Latence insertion** (touchUpInside dans votre clavier → texte réellement inséré dans le document cible) : typiquement non déterministe en extension (car dépend de l’app hôte), mais vous pouvez mesurer votre part (temps jusqu’à l’appel `insertText`/`deleteBackward`, et la cadence). citeturn10search0  
- **Transitions clavier** (apparition/disparition/resize) : doivent utiliser les mêmes timings/curves que le système, via les userInfo keys de notifications clavier ou, mieux, via `keyboardLayoutGuide` introduit pour simplifier l’adaptation. citeturn0search33turn0search37turn3search3turn3search35

### Limites spécifiques aux extensions clavier (impact direct sur “Téléphone‑like”)

Apple documente plusieurs limites :

- Une extension clavier est **ineligible** dans les champs “phone pad” (traits `UIKeyboardTypePhonePad` / `UIKeyboardTypeNamePhonePad`) : le système remplace votre clavier par le clavier standard. citeturn10search0turn9search5  
- Le clavier custom (extension) **ne peut pas sélectionner le texte** ; la sélection et le menu d’édition appartiennent à l’app hôte. citeturn10search0turn9search5  
- Pas d’accès micro (dictée impossible) en extension (au moins dans les contraintes historiques documentées). citeturn10search0turn9search5  
- Les capacités “Open Access” étendent la sandbox (réseau, conteneur partagé, etc.) mais augmentent fortement les exigences de confiance/privacité, et Apple encadre ces extensions via règles App Store + contrat développeur. citeturn13view1turn9search3turn9search1turn9search0

Point clé : viser l’UX Téléphone avec une extension, c’est viser la **qualité de votre rendu et pipeline**, pas l’accès total aux fonctions “texte riche/IME/sélection” du système.

## Choix d’architecture et APIs UIKit à utiliser

### Trois architectures (et ce qu’elles permettent réellement)

1) **Clavier système dans votre app** (préférable si votre app ressemble à un “composeur” ou une saisie téléphone)  
Vous configurez un `UITextField`/`UITextView` avec `keyboardType = .phonePad` ou `asciiCapableNumberPad` selon le besoin. `UIKeyboardType.phonePad` est explicitement un pavé pour numéros de téléphone (0–9, * #) et ne supporte pas l’auto-capitalisation. citeturn1search6turn14search0  
Avantages : latence/animations/haptique “système”, IME géré, accessibilité largement “gratuite”. citeturn4search1turn6search20  
Inconvénient : vous ne contrôlez pas la forme exacte des touches (Téléphone a son design propre).

2) **Clavier custom in‑app via `inputView` / `UIInputView`** (compromis “Téléphone‑like” très réaliste dans votre app)  
`UIResponder` expose `inputView` et `inputAccessoryView`, et Apple décrit que tout responder peut fournir son propre input view ; `UITextField`/`UITextView` l’exposent aussi. citeturn21search16turn21search0  
`UIInputView` est “designed to match the appearance of the standard system keyboard when used as an input view”. citeturn2search27  
Avantages : vous contrôlez l’UI et la réactivité, tout en restant dans votre app (donc pas les contraintes d’extension).  
Inconvénients : vous devez re‑implémenter beaucoup de détails (gestes, touches, accessibilité, etc.).

3) **Extension clavier (`UIInputViewController`)** (clavier systèmewide)  
Apple décrit la structure : subclass de `UIInputViewController`, UI ajoutée dans `inputView`, insertion via proxy, gestion d’un bouton “next keyboard” (`advanceToNextInputMode`) et détection via `needsInputModeSwitchKey`. citeturn12search0turn13view1turn9search3  
Avantages : disponible dans la plupart des apps (sauf champs sécurisés/passcode et restrictions phone pad). citeturn9search0turn10search0  
Inconvénients : limites fortes (sélection, phone pad, dictée, sandbox), et obligations App Store/contrat. citeturn10search0turn9search3turn9search1turn9search0

### Tableau de comparaison des techniques

| Technique | Bénéfice principal “Téléphone‑like” | Complexité | Risque (Store/UX) | Points d’attention |
|---|---:|---:|---:|---|
| Clavier système (`keyboardType = .phonePad`) | Latence/animation/IME identiques au système | Faible | Faible | Peu de contrôle UI ; dépend du style Apple citeturn14search0turn1search6 |
| Clavier in‑app via `inputView` / `UIInputView` | UI 100% contrôlée + intégration UIKit | Moyenne | Moyenne | Accessibilité/gestes/IME à soigner citeturn21search16turn2search27turn6search20 |
| Extension clavier (`UIInputViewController`) | Disponible cross‑apps | Élevée | Élevé | Pas dans champs phone pad, sélection limitée, contraintes Open Access citeturn10search0turn9search5turn9search3turn13view1 |

### APIs UIKit/Swift à maîtriser (et pourquoi)

- `UITextInput` / `UITextInputTraits` : le contrat complet texte (sélection, marked text, etc.). Essentiel si vous implémentez un contrôle texte custom (in‑app). citeturn4search0turn4search23turn1search4  
- `UITextField` / `UITextView` + delegates : la voie la plus stable pour hériter du système texte (sélection, loupe, etc.). citeturn4search1turn4search5turn4search34  
- `UITextInteraction` : Apple recommande de l’utiliser pour donner à des text views custom les “same text selection gestures and UI”. citeturn1search1turn1search30  
- `UIResponder` : input views (`inputView`, `inputAccessoryView`), responder chain. citeturn4search10turn21search0turn21search16  
- `UIInputViewController` + `textDocumentProxy` (extension) : insertion/suppression/ajustement du curseur via proxy + gestion “next keyboard”. citeturn13view1turn10search0turn9search3  
- Notifications clavier + `keyboardLayoutGuide` (in‑app) : timing exact d’animation et adaptation layout. citeturn0search33turn0search37turn3search3turn3search35

## Implémentation ultra‑réactive : pipeline tactile, rendu, haptique, audio, transitions

Cette section se concentre sur le “comment faire” pour approcher la sensation Téléphone.

### Diagramme de pipeline de frappe (objectif : un highlight au prochain frame)

```mermaid
flowchart LR
  A[Touch Down] --> B[Maj UI highlight immédiate]
  B --> C[prepare() haptique]
  A --> D[Touch Up Inside]
  D --> E[impactOccurred / playInputClick]
  D --> F[insertText/deleteBackward]
  D --> G[Planifier async: suggestions, formatage]
  G --> H[Coalescer résultats -> update UI barre prédictive]
```

Ce pipeline découple volontairement le “feedback immédiat” (B/C/E) et le “travail lourd” (G/H). Les recommandations Apple sur la réduction de travail sur le main thread et l’usage de la mesure via logging/signposts soutiennent ce type d’approche. citeturn3search0turn5search21turn5search10

### Code : squelette d’extension clavier “phone‑like” (UIInputViewController)

```swift
import UIKit
import os

final class KeyboardViewController: UIInputViewController {

    // Signposter pour mesures locales (latence key press -> insertText, etc.)
    private let log = OSLog(subsystem: "com.example.keyboard", category: "latency")
    private let signposter = OSSignposter()

    // Haptique
    private lazy var impact = UIImpactFeedbackGenerator(style: .light)
    private lazy var selection = UISelectionFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI minimaliste: éviter la hiérarchie profonde & Auto Layout “churn” en boucle.
        // Construisez un grid simple (frames ou contraintes statiques initialisées 1 fois).

        setupKeyGrid()

        // Pré‑chauffage haptique (réduit la latence perçue)
        impact.prepare()
        selection.prepare()
    }

    private func setupKeyGrid() {
        // Exemple minimal: boutons 0-9, *, # + backspace + next keyboard
        // (À remplacer par votre layout réel)
    }

    @objc private func keyTouchDown(_ sender: UIButton) {
        // 1) feedback visuel immédiat (highlight)
        sender.isHighlighted = true

        // 2) préparer haptique pour le touchUp
        impact.prepare()
    }

    @objc private func keyTouchUpInside(_ sender: UIButton) {
        sender.isHighlighted = false

        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("keyPress", id: signpostID)

        defer { signposter.endInterval("keyPress", state) }

        // Haptique
        impact.impactOccurred()
        impact.prepare()

        // Audio “click” (si vous choisissez de l’activer; voir section trade‑off Open Access)
        UIDevice.current.playInputClick()

        // Insertion via proxy
        if let value = sender.titleLabel?.text {
            textDocumentProxy.insertText(value)
        }
    }

    @objc private func backspaceTapped(_ sender: UIButton) {
        impact.impactOccurred()
        textDocumentProxy.deleteBackward()
    }

    @objc private func nextKeyboardTapped(_ sender: UIButton) {
        advanceToNextInputMode()
    }
}
```

Ce code s’appuie sur : `UIInputViewController` (extension), `advanceToNextInputMode`, `needsInputModeSwitchKey` (à traiter dans votre layout), et la présence d’un bouton “next keyboard” est exigée par les règles App Store pour les extensions clavier. citeturn13view1turn9search3  
Pour les mesures, `OSSignposter` est documenté comme outil de mesure de performance via le système de logging unifié et exploitable dans Instruments. citeturn5search1turn5search10

**Attention importante (audio, Open Access)** : dans le guide Apple des extensions clavier, la capacité à “play audio, including keyboard clicks using playInputClick” est listée comme une capacité obtenue quand `RequestsOpenAccess` est activé (avec responsabilités). citeturn13view1turn9search3turn9search1  
Donc, si vous visez un clavier “clic sonore” **en extension**, planifiez explicitement votre stratégie Open Access, et assurez-vous que le clavier reste fonctionnel sans accès réseau ni “full access” (règles App Store). citeturn9search3turn9search1

### Code : clavier in‑app via `inputView` + accessory pour “barre Téléphone‑like”

Dans votre app, vous pouvez fournir un clavier custom en assignant un `inputView` à un `UITextField`/`UITextView`. Apple documente ce mécanisme et le fait que UIKit animera l’input view quand le responder devient first responder. citeturn21search16turn21search0

```swift
import UIKit

final class DialerTextField: UITextField {

    private let dialerView = DialerInputView()        // UIView/ UIInputView custom
    private let accessories = DialerAccessoryView()   // inputAccessoryView custom

    override var inputView: UIView? { dialerView }
    override var inputAccessoryView: UIView? { accessories }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Important: garder des références fortes aux vues.
    }
}

final class DialerInputView: UIInputView {

    // Callback vers le champ actif
    weak var target: (UIKeyInput & UIResponder)?

    override init(frame: CGRect, inputViewStyle: UIInputView.Style) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)
        setupGrid()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    private func setupGrid() {
        // Construire votre pavé (0-9, *, #, backspace) avec une hiérarchie courte.
    }

    @objc private func didTapDigit(_ sender: UIButton) {
        guard let s = sender.titleLabel?.text else { return }
        target?.insertText(s)
    }

    @objc private func didTapBackspace(_ sender: UIButton) {
        target?.deleteBackward()
    }
}
```

`inputAccessoryView` est documenté comme une manière standard d’attacher des contrôles au‑dessus du clavier (système ou custom). citeturn21search0  
`UIInputView` vise à s’intégrer visuellement comme un clavier standard quand il est utilisé comme input view. citeturn2search27

### Transitions clavier : caler exactement timing/curve (in‑app)

Deux approches complémentaires :

- **Approche moderne** : `keyboardLayoutGuide` (iOS 15+) et la session “Keep up with the keyboard” recommande cette voie, déjà utilisée par des apps Apple (ex. Messages/Spotlight) selon la session. citeturn3search35turn3search3turn3search11  
- **Approche notifications** : `UIResponder.keyboardWillChangeFrameNotification` et les userInfo keys de durée/curve (ex. `UIKeyboardAnimationCurveUserInfoKey`, `UIKeyboardFrameBeginUserInfoKey`). citeturn0search33turn0search37

Exemple (notifications) pour animer une view avec les mêmes paramètres que le clavier :

```swift
import UIKit

final class KeyboardFollower {

    private weak var view: UIView?
    private var bottomConstraint: NSLayoutConstraint

    init(view: UIView, bottomConstraint: NSLayoutConstraint) {
        self.view = view
        self.bottomConstraint = bottomConstraint

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kbChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func kbChange(_ note: Notification) {
        guard let view = view,
              let userInfo = note.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt,
              let frameEnd = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }

        let frameInView = view.convert(frameEnd, from: nil)
        let overlap = max(0, view.bounds.maxY - frameInView.minY)

        bottomConstraint.constant = overlap

        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            view.layoutIfNeeded()
        }
    }
}
```

Les clés `keyboardAnimationDurationUserInfoKey` et `keyboardAnimationCurveUserInfoKey` sont documentées pour récupérer la durée et la curve d’animation du clavier. citeturn0search33turn0search37  
`layoutIfNeeded()` force une mise en page immédiate : utile pour synchroniser l’animation, mais potentiellement coûteux si vous déclenchez trop de re‑layout. citeturn3search1turn26search0

## Autocorrection, prédiction, curseur/sélection, TextKit2, IME, accessibilité

### Autocorrection et prédiction : ce que vous pouvez faire en extension

Apple documente que chaque clavier custom (même sans Open Access) peut demander un lexique d’autocorrection via `UILexicon`, contenant notamment des noms (Contacts), des raccourcis clavier iOS et un dictionnaire de mots communs. citeturn10search0turn13view1  
Mais Apple précise aussi qu’il n’y a pas “d’API dédiée” qui vous donne la barre de correction “inline” du système ; en extension, vous devez construire votre propre UI de suggestions, et vous n’avez pas accès aux contrôles inline près du point d’insertion. citeturn10search2turn9search5turn10search0

**Implication pratique** : pour une extension, visez une autocorrection **discrète** (ex. correction de casse, expansion de raccourcis) et une prédiction simple, plutôt qu’une copie de QuickType.

Exemple de récupération de lexique (extension) :

```swift
import UIKit

final class LexiconProvider {

    private(set) var entries: [UILexiconEntry] = []

    func refresh(in controller: UIInputViewController, completion: @escaping () -> Void) {
        controller.requestSupplementaryLexiconWithCompletion { lexicon in
            self.entries = lexicon.entries
            completion()
        }
    }
}
```

Le guide Apple met explicitement en avant `UILexicon` comme base de suggestions/autocorrections pour claviers custom. citeturn10search0turn13view1

#### Petits modèles de langage : options réalistes et sources “papiers”

Pour aller au‑delà du lexique, la prédiction texte s’appuie classiquement sur des modèles de langage :

- Les modèles n‑gram et leurs techniques de smoothing (étude comparative de Chen & Goodman, et Kneser‑Ney) sont des références pour des prédictions légères/embarquées. citeturn20search0turn20search11  
- Les approches neurales (Bengio 2003) ont introduit l’idée de représentations distribuées pour mieux généraliser sur des séquences non vues. citeturn20search1turn20search38  
- Les vecteurs de mots type word2vec (Mikolov et al.) sont une base historique de représentations continues efficaces. citeturn19search5turn19search2  

**Actionnable** (dans le cadre iOS extension) : si vous voulez rester “Phone‑like” (rapide), privilégiez :
- un modèle **très léger** (n‑gram + Kneser‑Ney) ou un ranking heuristique,
- calculé hors main thread,
- avec coalescing, et
- fallback vers `UILexicon` + dictionnaire embarqué lorsque la batterie/CPU est contrainte. citeturn5search15turn3search0turn10search0turn20search11

### Traits recommandés (config flags) pour réduire complexité et surprises UX

Pour un pavé type Téléphone, les traits doivent réduire les fonctionnalités texte inutiles :

- `keyboardType = .phonePad` si vous restez sur le clavier système ; Apple décrit ce type comme un pavé numéros incluant `*` et `#`. citeturn1search6turn14search0  
- `autocorrectionType = .no` (désactive autocorrection) si saisie numérique / identifiants ; Apple décrit cette propriété comme déterminant si l’autocorrection est activée/désactivée pendant la frappe. citeturn1search0  
- `spellCheckingType = .no` (désactive soulignement orthographique) si non pertinent. citeturn1search7  
- `smartQuotesType`, `smartDashesType`, `smartInsertDeleteType` : à désactiver sur des champs stricts (codes, numéros) pour éviter substitutions. citeturn1search10turn14search0  

Exemple :

```swift
textField.keyboardType = .phonePad
textField.autocorrectionType = .no
textField.spellCheckingType = .no
textField.smartQuotesType = .no
textField.smartDashesType = .no
textField.smartInsertDeleteType = .no
```

Ces propriétés font partie de `UITextInputTraits` (contrat de configuration du clavier). citeturn1search4turn14search0

### Curseur, sélection, loupe : in‑app vs extension

- **In‑app** : si vous utilisez `UITextField`/`UITextView`, vous bénéficiez de la sélection système. Si vous implémentez une vue texte custom (rare), Apple recommande `UITextInteraction` pour obtenir gestes/UI de sélection. citeturn1search1turn1search30turn4search1  
- **Extension** : Apple indique explicitement que la sélection est sous contrôle de l’app hôte, et que le clavier custom ne peut pas sélectionner du texte. citeturn9search5turn10search0

### IME et “marked text” : compatibilité et attentes

`markedTextRange` et `setMarkedText(_:selectedRange:)` sont au cœur des méthodes d’entrée multi‑étapes (japonais/chinois, composition) ; Apple définit le “marked text” comme un texte provisionnel nécessitant confirmation et apparaissant dans les entrées multi‑stades. citeturn4search4turn4search23

- **In‑app** : rester sur `UITextField`/`UITextView` est la manière la plus sûre d’obtenir une compatibilité IME. citeturn4search1turn4search34  
- **Extension** : vous êtes dans un modèle “proxy” ; vous pouvez insérer/supprimer/ajuster la position, mais une IME complète est coûteuse et se heurte souvent aux limites d’intégration/UX et au fait que l’app hôte contrôle la sélection. citeturn10search0turn9search5

### Text rendering et TextKit2 : où optimiser vraiment

Pour un clavier type Téléphone, les textes affichés (digits, labels) sont courts. Les gains viennent surtout de :
- **hiérarchie de vues minimale**,  
- **éviter Auto Layout churn**,  
- **éviter recalculs d’attributed strings en boucle**,  
- **limiter les invalidations de layout**.

Si votre app (pas le clavier) affiche/édite de gros blocs de texte, TextKit 2 et les améliorations de TextKit (WWDC) apportent des gains de performance et une meilleure architecture, mais ce n’est généralement pas le goulot d’un pavé numérique. citeturn0search10turn1search26

### Accessibilité : VoiceOver, Switch Control, Full Keyboard Access

Un clavier custom (in‑app ou extension) doit rester utilisable au lecteur d’écran :

- UIKit fournit des mécanismes standard via le protocole `UIAccessibility` et les traits (`UIAccessibilityTraits`). citeturn6search0turn6search15  
- Vous pouvez adapter le comportement selon l’état de VoiceOver (`isVoiceOverRunning`) et écouter les changements (`voiceOverStatusDidChangeNotification`). citeturn6search2turn6search6  
- Apple fournit des critères d’évaluation VoiceOver côté App Store Connect : navigation, activation des contrôles, labels concis. citeturn6search8  
- Pour réduire le nombre de gestes, `UIAccessibilityCustomAction` est un outil recommandé (WWDC sur custom actions). citeturn6search3turn6search14  

**Actionnable pour un pavé Téléphone-like** :
- Chaque touche = un élément accessible, label localisé (“1”, “2”, “Étoile”, “Dièse”, “Supprimer”, “Appeler”, etc.).  
- Traits adaptés (`.button`), hints (“Double‑tapez pour saisir 1”). citeturn6search18turn6search15  
- Zones tactiles ≥ 44×44 pt (référence HIG accessibilité) et support “Réduire les animations” si vous avez des animations non essentielles. citeturn6search1turn3search22

## Mesure, plan de test, métriques, checklist priorisée, sources recommandées

### Mesurer la latence : méthode, métriques, outils Apple

#### Métriques à collecter (P50/P90/P99)

- **T1** : `touchDown → highlight visible` (ms)  
- **T2** : `touchUpInside → impactOccurred appelé` (ms) et stabilité (taux de “haptic drop”)  
- **T3** : `touchUpInside → insertText/deleteBackward appelé` (ms)  
- **T4** : `insertText appelé → UI prédictive mise à jour` (ms) (si vous avez une barre)  
- **Frames** : hitches/hangs lors de la frappe rapide (cadence 6–10 taps/s typique pavé)  
- **Ressources** : mémoire (pics), CPU, énergie (sur device réel)

Apple fournit :
- `OSSignposter` + guide “Recording Performance Data” (signposts → Instruments). citeturn5search1turn5search10  
- WWDC “Measuring Performance Using Logging” (Points of Interest). citeturn5search21  
- WWDC “Analyze hangs with Instruments” + tutoriels Instruments sur hang analysis. citeturn5search14turn5search22  
- MetricKit (`MXMetricManager`) pour métriques agrégées sur appareils utilisateurs (CPU/mémoire/énergie/diagnostics). citeturn5search2turn5search5turn5search31  
- Des clocks monotones (`mach_continuous_time`) et des APIs de temps (`CACurrentMediaTime`) pour timestamps fiables. citeturn5search6turn5search28

#### Exemple : instrumentation fine d’une frappe (OSSignposter)

```swift
import os

final class KeyLatencyTracer {
    private let signposter = OSSignposter()
    private var state: OSSignpostIntervalState?

    func beginKeyPress() {
        let id = signposter.makeSignpostID()
        state = signposter.beginInterval("keyPress", id: id)
    }

    func endKeyPress() {
        if let state { signposter.endInterval("keyPress", state) }
        state = nil
    }
}
```

Apple documente `OSSignposter` comme un objet de mesure de performance via le logging unifié et exploitable dans Instruments. citeturn5search1turn5search10

#### XCTest / XCUITest

- Dans **votre app**, utilisez `XCTest` + `XCTMeasure` et/ou des métriques orientées signposts (quand disponibles) pour benchmarker la latence de vos handlers et la stabilité du rendu (en mode “stress typing”). Les “hangs” doivent être diagnostiqués par Instruments. citeturn5search14turn5search15  
- Pour une **extension clavier**, les tests automatisés sont plus délicats (UI test cross‑app) : construisez plutôt une “harness app” interne avec un champ texte instrumenté et des scripts de frappe (ou un mode debug). (Recommandation pratique ; la doc Apple insiste surtout sur Instruments / signposts pour mesurer en conditions réelles.) citeturn5search21turn5search10

### Minimiser la latence d’entrée : plan d’optimisation concret

Les points suivants sont hiérarchisés pour un clavier “Téléphone‑like” :

1) **Zéro travail lourd sur le main thread dans l’événement de touche**  
Votre handler ne fait que : update highlight, déclenche haptique/audio, appelle `insertText/deleteBackward`, et envoie un message async pour le reste. Apple met en avant la réduction de travail sur le main thread comme axe majeur de perf. citeturn3search0turn5search15  

2) **Éviter les passes Auto Layout inutiles / “constraint churn”**  
Le render loop (update constraints → layout → display) se déclenche très souvent (jusqu’à 120 fois/s sur certains appareils) ; tout churn de contraintes peut se refléter en hitches. Le transcript WWDC Auto Layout explique explicitement le lien entre render loop et updateConstraints/layout/display. citeturn26search0turn11search1  

3) **Pré‑chauffer haptique**  
`prepare()` est explicitement indiqué comme partie du setup des feedback generators. citeturn12search9turn1search2  

4) **Couper/Coalescer prédiction et formatage**  
Pour ne pas “jitter”, coalescer (ex. max 10–20 Hz d’update suggestions) et abandonner les calculs obsolètes si une nouvelle touche arrive.

5) **Transitions clavier**  
Utiliser `keyboardLayoutGuide` lorsque possible, sinon animer avec la curve/duration du système via userInfo keys. citeturn3search35turn0search37turn0search33  

6) **Surveiller mémoire/énergie**  
Adopter MetricKit pour détecter des régressions sur appareils réels. citeturn5search5turn5search2turn5search31  

### Checklist priorisée d’implémentation

**Niveau indispensable (MVP “Phone‑like”)**
- Implémenter un pipeline `touchDown` (highlight) / `touchUp` (insert/delete + haptique/audio) minimal et instrumenté (signposts). citeturn5search10turn5search21turn12search9  
- UI très simple (grille), pas de recalcul Auto Layout à chaque frappe (contraintes fixes, ou frames). citeturn26search0turn3search1  
- Accessibilité : labels, traits, focus, support VoiceOver on/off. citeturn6search8turn6search2turn6search15  

**Niveau recommandé (qualité perçue)**
- Haptique calibrée (`UIImpactFeedbackGenerator` + `prepare()`), cohérente avec HIG haptics. citeturn3search22turn12search9  
- Stratégie audio : clicks (et décision Open Access si extension). citeturn13view1turn9search3turn9search1  
- Gestion “next keyboard” (extension) via `needsInputModeSwitchKey` + `advanceToNextInputMode`. citeturn13view1turn9search3  
- Adaptation layout aux variations clavier (in‑app) via `keyboardLayoutGuide`. citeturn3search3turn3search35  

**Niveau avancé (proche du système)**
- Barre de suggestions propre (extension) basée sur `UILexicon` + modèle léger + coalescing. citeturn10search0turn20search11turn5search15  
- Support multi‑langue : `primaryLanguage` + `PrefersRightToLeft` + layouts. citeturn13view1turn2search22  
- Analyse continue (MetricKit) et budgets perf (P50/P90/P99). citeturn5search5turn5search2  

### Sources recommandées (présentées en français)

**Documentation et guidelines Apple (prioritaires)**
- Sécurité & sandbox des extensions clavier (guide sécurité Apple, version FR) : restrictions réseau par défaut, Open Access, champs sécurisés. citeturn9search0  
- Règles App Store pour extensions clavier (exigence “next keyboard”, fonctionnement sans full access, restrictions collecte). citeturn9search3  
- Contrat développeur : exigences sur extensions, collecte de données, “keyboard functionality must operate independent of network access”, logging. citeturn9search1  
- Guide Apple (archive) sur claviers custom : limitations (phone pad ineligible, pas de sélection, lexique `UILexicon`, clés Info.plist). citeturn13view1turn10search0  
- `UIKeyboardType` (dont `phonePad`, `asciiCapableNumberPad`). citeturn14search0turn1search6  
- `autocorrectionType`, `spellCheckingType`, `smartQuotesType` (traits). citeturn1search0turn1search7turn1search10  
- Guides clavier & interaction : “Keep up with the keyboard” / `keyboardLayoutGuide`. citeturn3search35turn3search3  
- Mesure performance : WWDC “Measuring Performance Using Logging”, docs “Recording Performance Data”, `OSSignposter`. citeturn5search21turn5search10turn5search1  
- Analyse de hangs : WWDC “Analyze hangs with Instruments” + tutoriels hang analysis. citeturn5search14turn5search22  
- Accessibilité : HIG Accessibility/VoiceOver, `UIAccessibility`, critères VoiceOver (App Store Connect). citeturn6search1turn6search12turn6search0turn6search8  
- Haptics : HIG “Playing haptics”, WWDC Core Haptics (si vous faites des patterns avancés). citeturn3search22turn3search10  

**Papiers “originaux” utiles pour la prédiction**
- Bengio et al., “A Neural Probabilistic Language Model” (JMLR, 2003). citeturn20search1turn20search38  
- Chen & Goodman, “An Empirical Study of Smoothing Techniques for Language Modeling” (ACL, 1996). citeturn20search0  
- Kneser & Ney, “Improved Backing-off for M-gram Language Modeling” (ICASSP, 1995) — référence Kneser‑Ney. citeturn20search11  
- Mikolov et al., “Efficient Estimation of Word Representations in Vector Space” (ICLR/arXiv, 2013). citeturn19search5turn19search2  

**Référence pratique sur AutoFill OTP (utile pour champs codes)**
- “Securing logins with iCloud Keychain verification codes” (AuthenticationServices) : `textContentType = oneTimeCode` pour AutoFill dans UIKit/SwiftUI/AppKit/Web. citeturn16search0  

---

**Note de cadrage finale** : l’UX “Téléphone” est un excellent objectif, mais la stratégie la plus efficace est de **définir un budget de latence**, instrumenter via signposts + Instruments, et optimiser itérativement le pipeline tactile/rendu. Pour une extension clavier, acceptez les limites documentées (phone pad ineligible, sélection sous contrôle host) et concentrez-vous sur la réactivité perçue, pas sur une copie exacte du système. citeturn10search0turn9search5turn5search10turn5search21turn9search3