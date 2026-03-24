# Éliminer les “dead zones” et reproduire la sélection de lettres façon clavier Apple

## Synthèse exécutive

Ce que vous appelez “pas de dead zone” sur le clavier Apple correspond à deux idées techniques complémentaires :  
- **La surface du clavier est traitée comme une zone continue** : un tap entre deux (ou quatre) touches est **quand même** interprété comme l’intention d’une touche “la plus probable”, au lieu d’être “dans le vide”. Cette philosophie est explicitement décrite dans la littérature sur les *soft keyboards* : combiner un **modèle spatial du tap** (où tombe le doigt) et un **modèle de langage** (ce qui est probable d’être tapé) permet de choisir une touche même si le tap n’est pas strictement “dans la touche”. citeturn5search0turn5search3turn5search4  
- **Les touches ont des “zones d’impact” invisibles et dynamiques** (hit regions cachées), qui peuvent **se chevaucher** et dont la taille peut varier selon une probabilité (ex. lettre suivante probable). Apple a breveté ce principe : des “hit regions” non affichées, ajustées dynamiquement, et une sélection basée sur la **plus grande / plus probable zone** au moment du relâchement. citeturn2search0  

Côté Android open-source, on retrouve la même famille d’approches sous le nom **proximity correction** : on limite le calcul à un petit ensemble de touches “proches” grâce à une **grille** (accélération spatiale), puis on score des candidats à partir de la distance et d’heuristiques (et éventuellement d’un correcteur). AOSP LatinIME (la base de nombreux claviers) illustre cette approche avec `ProximityInfo`, un seuil de recherche (ex. `SEARCH_DISTANCE = 1.2f` en “largeur de touche”), une liste de voisins par cellule, et un plafond de candidats (ex. 16). citeturn1search1turn1search4turn1search7turn1search9  

Pour reproduire fidèlement ce comportement sur iOS (clavier in‑app ou extension), le meilleur pattern est de **ne pas laisser les touches gérer le hit‑testing individuellement**. À la place, vous construisez un **routeur de touches** (un “touch surface” unique) qui :  
1) capte tous les contacts dans la zone clavier,  
2) calcule la touche “gagnante” via une carte de proximité + scoring (distance + biais + éventuellement modèle de langage),  
3) applique un peu d’**hystérésis** (anti‑flicker) pour stabiliser le survol près des frontières,  
4) commit au relâchement (comme décrit par le brevet Apple : “touch point determined at lift off”, avec un feedback visuel avant lift‑off). citeturn2search0  

## Ce que laisse entrevoir l’approche Apple

### Hit regions invisibles, chevauchement et sélection probabiliste

Le brevet **US8232973B2** décrit un clavier où chaque touche a une zone visible (ce que vous dessinez) et une **zone de hit invisible** (“hidden/undisplayed hit region”), dont la taille est **dynamiquement ajustée** en fonction d’une probabilité de caractère/continuation. citeturn2search0  
Ce brevet va plus loin que “prendre la touche la plus proche” :  
- Les zones invisibles peuvent **déborder au-delà** des limites visuelles. citeturn2search0  
- Si plusieurs zones se chevauchent là où le doigt touche, la méthode décrit un mécanisme de sélection lié à la “plus grande” zone / la plus probable. citeturn2search0  
- La taille des zones peut être modulée par une formule dépendant d’une **probabilité P(i)** (probabilité de la prochaine lettre i). citeturn2search0  

Ce mécanisme explique très bien l’impression “entre quatre lettres il y en a forcément une” : la surface clavier n’est pas un patchwork de rectangles disjoints, mais un **espace couvert** par des régions (souvent chevauchantes) qui garantissent une décision.

### Décision au relâchement et feedback “avant relâchement”

Le même brevet précise que chaque touch point est “determined at lift off” et qu’une **prévisualisation du caractère** (type “popup”) peut être affichée **avant** lift off, la prévisualisation étant choisie selon les hit regions. citeturn2search0  
Traduction design (utile pour votre implémentation) :  
- Pendant `touchesMoved`, on peut changer la touche “cible” (highlight).  
- À `touchesEnded`, on commit la touche actuellement gagnante.  
C’est cohérent avec la sensation iOS (le survol bouge, la frappe se valide au relâchement). citeturn2search0  

### Convergence avec la littérature HCI (soft keyboard decoding)

La publication classique de Goodman et al. explique exactement le principe “pas de rigidité des frontières” : en combinant un **modèle de placement** (où tombe le stylet/doigt) et un **modèle de langage**, on peut réduire significativement l’erreur de saisie, notamment quand l’utilisateur tape près des frontières ou même en dehors d’une limite stricte. citeturn5search0turn5search3turn5search4  
Des travaux plus récents (ex. CHI’14 *Uncertain Text Entry*) reprennent le même schéma “modèle spatial + modèle de langage”, et explorent des modèles spatiaux probabilistes plus modernes. citeturn5search6turn5search8  

**Conclusion pragmatique** : reproduire l’absence de dead zones “façon Apple” ne se limite pas à agrandir des rectangles ; il faut penser en **décodeur** : “quel caractère est le plus probable étant donné (x,y) + contexte”.

## Comment les claviers open source Android gèrent la proximité

### AOSP LatinIME : grille de proximité et limitation des candidats

Dans AOSP LatinIME, `ProximityInfo` utilise une approche typique “rapide et robuste” :  
- Une **grille** (grid) couvre la zone du clavier. Chaque cellule stocke la liste des touches “voisines” de cette cellule. citeturn1search7turn1search9  
- Un seuil de recherche exprime la zone d’influence en “largeur de touche” (ex. `SEARCH_DISTANCE = 1.2f`). citeturn1search1turn1search4  
- `getNearestKeys(x,y)` renvoie les touches proches pour la cellule correspondant à (x,y), ce qui évite de scorer *toutes* les touches à chaque tap. citeturn1search1turn1search4turn1search7  
- La taille max des candidats est bornée (constante `MAX_PROXIMITY_CHARS_SIZE = 16`). citeturn1search1turn1search4  

Ce design correspond à votre besoin iOS : **réponse instantanée**, pas d’allocations, scoring sur un petit `k` (≈ 8–16), donc faible latence.

### Touch position correction et “sweet spots”

Le code AOSP mentionne explicitement des mécanismes de correction : `TouchPositionCorrection` et des données de “sweet spots” (centres et rayons), transmises au natif via `setProximityInfoNative(...)` avec des tableaux `sweetSpotCenterXs`, `sweetSpotCenterYs`, `sweetSpotRadii`. citeturn1search7turn1search1  
Même sans entrer dans les détails internes exacts, ces indices confirment un pattern important : **ne prenez pas le centre géométrique de la touche comme unique vérité**, mais autorisez un centre “préféré” (sweet spot) + un rayon (tolérance) — typiquement différent selon la rangée (thumb reach, occlusion, etc.). citeturn1search7turn1search1  

### AnySoftKeyboard : KeyDetector + proximity correction + tracking

La documentation (DeepWiki) d’AnySoftKeyboard décrit une pipeline courante :  
- `AnyKeyboardViewBase` reçoit l’événement touch,  
- `KeyDetector` détermine la touche en fonction des coordonnées (avec support de *proximity correction*),  
- `PointerTracker` gère l’état touch et le multi-touch,  
- puis l’action est traitée par le listener (IME). citeturn1search0  

C’est exactement la structure que vous voulez reproduire sur iOS : séparer **détection** (géométrie + scoring) et **tracking** (hystérésis, glissés, répétition backspace).

## Stratégie iOS pour éliminer les dead zones dans votre clavier

### Pourquoi vous avez des dead zones aujourd’hui

Dans un clavier custom “à la UIKit classique”, chaque touche est souvent un `UIButton`/`UIControl` avec un `frame` rectangulaire. Si vous laissez UIKit faire le hit‑testing, un tap dans l’espace entre deux boutons n’appartient à aucun bouton, donc **aucun événement** (dead zone). Ce comportement est normal : vous avez créé une surface interactive disjointe.

Apple, d’après son brevet, raisonne plutôt en “hit regions invisibles” chevauchantes et sélection au relâchement. citeturn2search0  
La littérature “soft keyboard” propose le même contournement : ne pas imposer des frontières strictes, et inférer la touche voulue. citeturn5search0turn5search4  

### Pattern recommandé : une “surface tactile” unique + routeur vers touches

Au lieu de laisser chaque touche gérer les touches, créez un composant unique (par ex. `KeyboardTouchSurfaceView`) qui capte **tous** les touches dans un rectangle englobant, puis décide de la touche.

Un flow typique (inspiré du comportement Apple “preview puis lift‑off”) : citeturn2search0  

```mermaid
flowchart TD
  A[Touch Down] --> B[Calcul touche gagnante (score)]
  B --> C[Highlight/popup sur cette touche]
  A --> D[Touch Move]
  D --> E[Recalcul + hystérésis anti-flicker]
  E --> C
  A --> F[Touch End]
  F --> G[Commit: insertion caractère de la touche gagnante]
```

### Algorithme minimal “zéro dead zone” (Voronoï au centre)

Le niveau 1 le plus simple est : pour tout point (x,y) dans la zone clavier, rendre **la touche dont le centre est le plus proche**. C’est une partition de type Voronoï (même si vous ne la calculez pas explicitement).  
Ça supprime 100% des dead zones **à condition** que votre surface capture tous les touches.

Mais pour être “Apple-like”, vous allez vouloir :  
- utiliser distance à la **bordure** (pas seulement au centre) pour mieux coller à la forme visuelle,  
- ajouter un biais (“sweet spot”),  
- stabiliser près des frontières (hystérésis),  
- éventuellement injecter une probabilité de continuation (modèle de langage / lexique), comme décrit par l’approche Apple brevetée et la littérature. citeturn2search0turn5search0turn5search6  

## Implémentation Swift actionnable : grille de proximité + scoring + hystérésis

### Modèle de données clé

Vous voulez séparer “rendu” et “détection” :

- **Rendu** : vos vues de touches (ou un rendu custom dessiné).  
- **Détection** : une structure prête pour le scoring (frames, centres, sweet spots, index spatial).

Un design proche d’AOSP LatinIME est particulièrement efficace : une **grille** qui renvoie rapidement une liste de candidats (k faible). AOSP fait exactement ça avec `getNearestKeys` et un seuil fondé sur la largeur de touche (`SEARCH_DISTANCE`) et un max de 16 candidats. citeturn1search1turn1search4turn1search9  

### Code Swift (cœur) : index spatial par grille + distance à la bordure

```swift
import CoreGraphics

struct KeySpec: Sendable {
    let id: Int
    let label: String
    let frame: CGRect

    // Optionnel: sweet spot (biais)
    let sweetSpot: CGPoint   // en coords clavier
    let sigma: CGFloat       // largeur de pénalité distance (px)
}

@inline(__always)
private func squaredDistancePointToRectEdge(_ p: CGPoint, _ r: CGRect) -> CGFloat {
    // Distance 0 si inside.
    let dx: CGFloat
    if p.x < r.minX { dx = r.minX - p.x }
    else if p.x > r.maxX { dx = p.x - r.maxX }
    else { dx = 0 }

    let dy: CGFloat
    if p.y < r.minY { dy = r.minY - p.y }
    else if p.y > r.maxY { dy = p.y - r.maxY }
    else { dy = 0 }

    return dx*dx + dy*dy
}

/// Index spatial “à la LatinIME”: grille -> liste de keys candidates.
final class ProximityGrid {
    private let bounds: CGRect
    private let cellW: CGFloat
    private let cellH: CGFloat
    private let gridW: Int
    private let gridH: Int

    // Par cellule: indices des keys candidates
    private var neighbors: [[Int]] = []

    init(bounds: CGRect, cellSize: CGSize, keys: [KeySpec], searchDistanceMultiplier: CGFloat = 1.2) {
        self.bounds = bounds
        self.cellW = max(8, cellSize.width)
        self.cellH = max(8, cellSize.height)
        self.gridW = Int(ceil(bounds.width / self.cellW))
        self.gridH = Int(ceil(bounds.height / self.cellH))
        self.neighbors = Array(repeating: [], count: gridW * gridH)

        // Heuristique: seuil basé sur “largeur de touche la plus commune”
        let commonW = keys.map(\.frame.width).sorted().dropFirst(keys.count/4).first ?? 40
        let threshold = (commonW * searchDistanceMultiplier)
        let threshold2 = threshold * threshold

        // Remplir chaque cellule avec les keys dont la distance à la cellule est < seuil
        for cy in 0..<gridH {
            for cx in 0..<gridW {
                let cellIndex = cy * gridW + cx
                let cellCenter = CGPoint(
                    x: bounds.minX + (CGFloat(cx) + 0.5) * cellW,
                    y: bounds.minY + (CGFloat(cy) + 0.5) * cellH
                )

                var list: [Int] = []
                list.reserveCapacity(16)

                for (i, k) in keys.enumerated() {
                    // Distance du centre de cellule à la bordure de touche
                    let d2 = squaredDistancePointToRectEdge(cellCenter, k.frame)
                    if d2 <= threshold2 { list.append(i) }
                }

                neighbors[cellIndex] = list
            }
        }
    }

    @inline(__always)
    func candidates(at p: CGPoint) -> [Int] {
        guard bounds.contains(p) else { return [] }

        let cx = Int((p.x - bounds.minX) / cellW)
        let cy = Int((p.y - bounds.minY) / cellH)
        guard cx >= 0, cx < gridW, cy >= 0, cy < gridH else { return [] }

        return neighbors[cy * gridW + cx]
    }
}
```

Ce pattern copie l’idée fondamentale vue dans LatinIME : limiter le calcul à une liste de voisins par cellule, avec un seuil lié à la taille des touches, et un plafond de candidats (typiquement ~16). citeturn1search1turn1search4turn1search9  

### Scoring “Apple-like” (distance + sweet spot + prior) et élimination des dead zones

```swift
import Foundation

struct KeyContext {
    // Optionnel: distribution de probabilité des prochaines lettres
    // Ex: issu d’un modèle n-gram/lexique/prediction
    var logPriorByKeyID: [Int: Double] = [:]  // log(P(key|context))
}

final class KeyDecoder {
    private let keys: [KeySpec]
    private let grid: ProximityGrid

    // Hystérésis: stabilise la touche survolée près des frontières
    private var currentKeyIndex: Int? = nil
    private let hysteresisMargin: Double = 0.15 // 15% de marge

    init(keys: [KeySpec], grid: ProximityGrid) {
        self.keys = keys
        self.grid = grid
    }

    func pickKey(at p: CGPoint, context: KeyContext?) -> Int? {
        let candidateIdxs = grid.candidates(at: p)
        if candidateIdxs.isEmpty { return nil } // hors zone active

        func score(for i: Int) -> Double {
            let k = keys[i]

            // 1) Distance: à la bordure (plus robuste qu’au centre)
            let d2 = Double(squaredDistancePointToRectEdge(p, k.frame))

            // 2) Biais sweet spot (ex: centre préféré)
            let sx = Double(p.x - k.sweetSpot.x)
            let sy = Double(p.y - k.sweetSpot.y)
            let sd2 = sx*sx + sy*sy

            // 3) Transformations en log-proba (gaussienne)
            let sigma2 = Double(max(8, k.sigma) * max(8, k.sigma))
            let logTouch = -0.5 * (d2 / sigma2) - 0.35 * (sd2 / sigma2)

            // 4) Prior (langage/contexte) optionnel
            let logPrior = context?.logPriorByKeyID[k.id] ?? 0.0

            // Poids du prior: à calibrer. Apple décrit que la probabilité peut
            // influencer les hit regions, donc la décision. (idée comparable)
            return logTouch + 0.6 * logPrior
        }

        // Trouver le meilleur candidat
        var best = candidateIdxs[0]
        var bestScore = score(for: best)

        for i in candidateIdxs.dropFirst() {
            let s = score(for: i)
            if s > bestScore {
                bestScore = s
                best = i
            }
        }

        // Hystérésis: si on a déjà une touche active, exiger une marge pour changer
        if let current = currentKeyIndex, candidateIdxs.contains(current) {
            let currentScore = score(for: current)
            if currentScore >= bestScore * (1.0 - hysteresisMargin) {
                return current
            }
        }

        return best
    }

    func updateCurrentKey(_ idx: Int?) {
        currentKeyIndex = idx
    }
}
```

- La partie “prior” somme une proba contextuelle (log prior) à un score spatial. Cela reflète la même intuition que : “le modèle de langage + modèle de placement permettent de choisir la touche voulue près des frontières”. citeturn5search0turn5search4  
- Et ça s’aligne avec le brevet Apple, qui décrit des hit regions ajustées selon des probabilités et une sélection liée à ces régions. citeturn2search0  

### Touch tracking (anti-dead zone) : le composant UIView/UIControl qui capte tout

Sur iOS, implémentez un `UIControl` plein écran clavier : `beginTracking/continueTracking/endTracking`. Pendant le tracking, vous mettez à jour le highlight/popup. Au relâchement, vous “commit”.

Le rôle de “PointerTracker” dans AnySoftKeyboard (gestion de l’état touch, multi-touch) illustre l’intérêt de séparer tracking vs détection. citeturn1search0  

## Tableau des techniques pour supprimer les dead zones (et se rapprocher d’Apple)

| Technique | Résultat sur dead zones | Proximité du “feeling Apple” | Complexité | Risques/points faibles |
|---|---|---:|---:|---|
| Hit-test UIKit classique (UIButtons disjoints) | Dead zones présentes | Faible | Faible | Comportement “trous” inévitable |
| Agrandir `point(inside:)` de chaque touche | Dead zones réduites | Moyen | Moyenne | Chevauchements ambigus (z-order), difficile à stabiliser |
| Surface tactile unique + “closest center” (Voronoï implicite) | Dead zones éliminées dans la zone active | Moyen+ | Moyenne | Comportement parfois instable au croisement de 4 touches (sans hystérésis) |
| Surface unique + distance à la bordure + hystérésis | Dead zones éliminées + highlight stable | Élevée | Moyenne+ | Besoin de tuning (marges, zones actives) |
| Ajout “sweet spots” + correction position (row bias) | Dead zones éliminées + meilleure précision | Très élevée | Élevée | Nécessite calibration/mesure (biais selon rangées/appareil) |
| Ajout prior/langage (n-gram/lexique) au score | Dead zones éliminées + comportement proche Apple (probabiliste) | Très élevée | Élevée | Effet “sur-correction” si poids trop grand (risque UX) |

Les deux dernières lignes reflètent la logique “spatial model + language model”, documentée par la recherche, et le principe de régions de touche dynamiques décrit par le brevet Apple. citeturn5search0turn5search6turn2search0  

## Validation, tuning et métriques

### Ce que vous devez mesurer (sinon vous allez “tuner à l’aveugle”)

Même si l’objectif est ici la précision de sélection, surveillez aussi la réactivité :  
- **Taux de “no key”** dans la zone active : doit être 0 (c’est votre définition “no dead zones”).  
- **Stabilité du highlight** : nombre de changements de touche pendant un tap (touchDown→touchUp). Un nombre trop élevé = jitter.  
- **CER/TER** (Character Error Rate / Total Error Rate) sur des phrases de test. L’intérêt de combiner modèle spatial + modèle de langage est justement la réduction des erreurs, mesurée dans la littérature. citeturn5search0turn5search6  
- **Backspace rate** et “immediate delete” (touche puis backspace dans les 500 ms) : signal d’erreurs de décodage. (Interprétation plausible, à valider dans vos données). citeturn5search6  

### Plan de test concret “dead zones”

1) **Test déterministe par balayage**  
Échantillonnez la zone active du clavier (par ex. un point tous les 2 px). Vérifiez qu’il y a toujours une touche renvoyée (non-nil).  
Puis visualisez la “carte d’activation” (id touche) en heatmap de debug (dans un build interne).

2) **Test humain contrôlé**  
- Phrase set standard (FR) + mesures CER/Backspace.  
- A/B : Voronoï simple vs bordure+hystérésis vs bordure+hystérésis+prior.

3) **Test “quatre touches”** (votre cas critique)  
Créez des scripts où l’utilisateur tape volontairement au croisement de 4 touches et mesurez :  
- quelle touche est choisie,  
- si le highlight flicker,  
- si un prior (ex. “qu” → “e” probable) infléchit correctement la décision.  
Cette idée d’influencer la décision via probabilité contextuelle correspond au principe de hit regions ajustées par P(i) dans le brevet. citeturn2search0  

### Réglages clés (tuning) recommandés

- **Zone active** : définissez clairement où votre surface tactile répond. Apple parle d’objets avec hit regions et d’overlap ; dans votre cas, vous pouvez décider “tout l’intérieur du rectangle clavier” ou un polygone englobant. citeturn2search0  
- **SEARCH_DISTANCE** style AOSP (≈ 1.2× largeur de touche) : bon point de départ pour limiter les candidats. citeturn1search1turn1search4turn1search9  
- **Hystérésis** : indispensable pour éviter le flicker au croisement de 4 touches (sinon vos frontières Voronoï deviennent des lignes “trop sensibles”). L’idée de tracking séparé (PointerTracker) dans AnySoftKeyboard reflète exactement ce besoin. citeturn1search0  
- **Poids du prior** : commencez faible (ex. 0.3–0.6 en log-space dans l’exemple) et testez surtout les mots fréquents + les prénoms + les mots hors vocabulaire (sinon “sur-correction”). La littérature sur claviers probabilistes montre que trop d’agressivité peut être contre-productive, d’où l’importance de tests. citeturn5search6turn5search0  

## Sources et lectures recommandées

- Brevet décrivant **hit regions invisibles ajustables** et sélection au relâchement avec probas : **US8232973B2**. citeturn2search0  
- Fondations “modèle spatial + modèle de langage” pour accepter des taps près/en dehors des frontières : Goodman et al., *Language Modeling for Soft Keyboards* (publication MSR / rapport technique). citeturn5search3turn5search4turn5search48  
- Décodeurs probabilistes modernes (incertitude, modèles spatiaux) : Weir et al., *Uncertain Text Entry on Mobile Devices*. citeturn5search6turn5search8  
- Implémentations open-source Android :  
  - AOSP LatinIME `ProximityInfo` (grille, seuil, voisins, max candidats, sweet spots). citeturn1search1turn1search4turn1search7turn1search9  
  - AnySoftKeyboard (KeyDetector + PointerTracker + proximity correction). citeturn1search0  

Si vous me donnez : (a) votre layout exact (tailles/offsets), (b) si c’est AZERTY FR uniquement ou multi-langues, et (c) si vous committez au touchUp ou touchDown aujourd’hui, je peux vous proposer une config “tuning de départ” (valeurs sigma, hystérésis, cellSize, zone active) et un protocole de mesures A/B spécifiquement adapté à votre clavier iOS.