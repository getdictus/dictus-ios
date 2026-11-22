# Recette : ajouter des dispositions de clavier à Dictus

Étude en lecture seule, 2026-11-22, demandée par Pierre via Titus. Aucun code modifié, aucune PR.
Base lue : `develop` à `4ebcf0d4`, plus les branches des PR ouvertes #1013 (`feature/spatial-decoder`, `00c665ff`) et #1026 (`fix/layout-apple-geometry`, `ae777165`).
Concurrents : Hex (`anomalyco/hex`, branche `dev`, commit `492d8c28`, 2026-11-22) et FluidVoice (`altic-dev/FluidVoice`, et la page publique fluidvoice.com/fluid/ios).

Limite de lecture : le projet « Dictus 2.1 » n'a pas pu être lu (`gh` n'a pas le scope `read:project`). L'ordre proposé ici ne tient donc pas compte des items `À faire` du projet : il faut le recaler dessus.

---

## 0. En une minute

- **Ce qu'on a** : 3 dispositions (AZERTY, QWERTY, QWERTZ allemand) et 4 langues de dictionnaire (fr, en, es, de). Depuis #272, la disposition est stockée par langue.
- **Ce qui coûte quand on ajoute une disposition** :
  - les lignes d'AZERTY sont recopiées à 4 endroits ;
  - les pastilles de choix affichent *toutes* les dispositions pour *toutes* les langues ;
  - les tests de géométrie de #1026 ne couvrent que l'AZERTY et le QWERTY.

  Un « lot 0 » de remise en ordre rend chaque disposition suivante quasi mécanique.
- **Disposition et langue sont deux recettes distinctes** :
  - une variante régionale du français (Suisse, Canada, Belgique) est une *disposition*, sans nouveau dictionnaire : taille S ;
  - une nouvelle langue (italien, portugais…) demande dictionnaire, n-grammes, modèle `.hextm`, prompts de polish et un relecteur natif : taille M à L.
- **Le goulot d'étranglement pour le `.hextm`** : Google Books Ngram v3 ne couvre que 8 langues (anglais, chinois, français, allemand, hébreu, italien, russe, espagnol). Pas de portugais, de néerlandais, de langues nordiques ni de polonais. Pour ces langues, il faut une autre source, comme Hex l'a fait pour le polonais avec le NKJP.
- **Prémisse à corriger** : Hex n'est **pas** dépourvu d'AZERTY. Sa branche `dev` a un clavier iOS en 18 langues, dont le français de France en AZERTY, celui du Canada et celui de Suisse. L'avantage de Dictus doit donc être la *qualité mesurée* par disposition et les variantes qu'Apple et Hex n'ont pas (le QWERTZ suisse à touches è/é/à de #608), pas la simple présence de l'AZERTY. Pour FluidVoice, rien n'est vérifiable : son app iPhone est en TestFlight, sans code public.

---

## 1. L'état actuel

### 1.1 Dispositions et langues présentes dans le dépôt

**Langues de dictionnaire** : `SupportedLanguage` (`DictusCore/Sources/DictusCore/SupportedLanguage.swift`)

| Code | Nom | Disposition par défaut | `spaceName` / `returnName` | Profil |
|---|---|---|---|---|
| `fr` | Français | AZERTY | espace / retour | `Languages/French.swift` |
| `en` | English | QWERTY | space / return | `Languages/English.swift` |
| `es` | Español | QWERTY (sans touche ñ) | espacio / intro | `Languages/Spanish.swift` |
| `de` | Deutsch | QWERTZ | Leertaste / Eingabe | `Languages/German.swift` |

**Dispositions** : `LayoutType` (`DictusCore/Sources/DictusCore/KeyboardLayoutData.swift:15`). Les valeurs brutes sont figées, parce qu'elles sont écrites dans l'App Group.

| Cas | Lignes de lettres | Où sont écrites les lignes |
|---|---|---|
| `.azerty` | `azertyuiop` / `qsdfghjklm` / `wxcvbn` + touche `'` adaptative | **4 copies** : `DictusKeyboard/KeyboardLayouts.swift:161`, `DictusCore/.../TextCorrection/KeyboardProximity.swift:107`, `DictusApp/Onboarding/LanguageSetupPage.swift:396` (aperçu d'onboarding), `DictusKeyboard/Views/EmojiPickerView.swift:374` (mini-clavier de recherche d'emoji) |
| `.qwerty` | `qwertyuiop` / `asdfghjkl` (demi-espaceurs) / `zxcvbnm` | `QWERTYLayout` dans DictusCore, plus une copie dans `EmojiPickerView` |
| `.qwertz` | `qwertzuiopü` / `asdfghjklöä` / `yxcvbnm` (11 / 11 / 7) | `QWERTZLayout` dans DictusCore, source unique (#151) |

**Les fichiers qu'une disposition touche aujourd'hui** (tous les `switch` sur `LayoutType`) :

- `KeyboardLayoutData.swift` : le cas, `displayName`, les lignes (sauf pour l'AZERTY).
- `KeyboardLayouts.swift` : les pages normale et majuscule, et `current(needsGlobe:)`. Les pages 123 et `#+=` sont communes à toutes les dispositions, avec `€` en dur.
- `KeyboardProximity.swift:100` : les lignes et les décalages de la table de coûts de proximité, qui servent aux fautes de frappe.
- `TextPredictionEngine.swift:885` et `:936` : les voisins de la barre d'espace. Il y a deux ensembles, et tout ce qui n'est pas AZERTY prend celui du QWERTY.
- `LanguageSetupPage.swift:393` et `EmojiPickerView.swift:373` : les lignes de l'aperçu et du mini-clavier.
- `KeyboardPanelView.swift:148`, `SettingsView.swift:372` et `LanguageSetupPage.swift:71` : les pastilles, générées depuis `LayoutType.allCases`, donc **toutes les dispositions pour chaque langue**.
- `TypingJournalEvent.swift:21` : l'étiquette `fr-azerty` du journal de frappe. Elle est générique, rien à faire.
- `DictusKeyboard/Models/KeyboardLayout.swift` : **fichier mort**. Il a une entrée `PBXBuildFile`, mais aucune phase Sources ne le référence. Son `switch` n'a même pas `.qwertz`. À supprimer : il trompe quiconque cherche « où sont les dispositions ».

**Appuis longs** : `AccentedCharacters.mappings` (`DictusCore/.../AccentedCharacters.swift`). C'est une **union plate, commune à toutes les langues**, que #157 a délibérément gardée (fermée *not planned* : « gérable jusqu'à 5-6 langues »). Elle contient :

- `e` : é è ê ë ; `a` : à â ä á ; `u` : ù û ü ú ; `i` : î ï í ; `o` : ô ö ó ;
- `c` : ç ; `y` : ÿ ; `n` : ñ ; `s` : ß.

Elle n'a ni `œ`, ni `æ`, ni `ì`, ni `ò`, ni `ã`, ni `õ`, ni `å`, ni `ø`. La touche adaptative française (`FrenchAdaptiveKey`) est liée à la touche `'` de la 3ᵉ ligne AZERTY, et protégée par `language == .french` depuis #272.

**Ressources par langue** (`DictusKeyboard/Resources/`) :

- `<code>_frequency.json` : 0,6 à 0,85 Mo ;
- `<code>_spellcheck.dict` (trie) : 0,4 à 0,5 Mo ;
- `<code>_ngrams.dict` : 6 à 7 Mo.

La PR #1013 ajoute `fr.hextm` et `en.hextm` (3,6 Mo chacun, lus en mmap). Une seule langue est chargée à la fois (`TextPredictionEngine.setLanguage`).

**Outillage existant pour une langue** : `docs/agents/language-onboarding.md` et `tools/onboard_language.py`. Ses étapes sont `scaffold`, `build-dicts`, `wire-xcode` et `verify`. L'allemand (#109) est l'exemple résolu. Règle de l'ADR 0001 : `overrides` et `SEED_BIGRAMS_BY_LANG` restent **vides** à la première sortie d'une langue dont le mainteneur n'est pas natif.

### 1.2 Les 4 axes de #272 (lus avec `gh issue view 272`)

L'issue nomme quatre axes indépendants. Ce ne sont pas tout à fait « disposition, dictionnaire, autocorrection, dictée » : l'autocorrection fait partie de l'axe dictionnaire, et le quatrième axe est la cible de traduction.

| Axe (#272) | Ce qu'il contrôle | Où il vit | État |
|---|---|---|---|
| **Disposition** | la position des touches : AZERTY, QWERTY, QWERTZ | `LayoutType`, stockée par langue (`KeyboardLayoutPreference`, `SharedKeys.keyboardLayoutsByLanguage`) | découplé par #325 (fermé, validé sur device le 2026-08-07) |
| **Langue de dictionnaire** | l'autocorrection, les suggestions, les appuis longs, les libellés espace et retour | `SupportedLanguage` et `LanguageProfile` | c'est l'axe que demandent les nouvelles langues |
| **Langue de transcription** | ce que transcrit le modèle de dictée | Réglages, découplée en #226 | Parakeet (DictusApp seulement) et Whisper |
| **Cible de traduction** | la langue de sortie du Smart Mode « traduire » | #79 ; #622 dit qu'elle se limite encore aux 4 langues du clavier | hors sujet ici |

Décisions de #272 utiles pour la recette :

- la disposition est **par langue**, avec un défaut hérité tant que l'utilisateur ne choisit pas ;
- une nouvelle valeur par défaut atteint ceux qui n'ont jamais choisi ;
- aucun clavier ne change de forme à une mise à jour ;
- les pastilles du panneau sont générées depuis `LayoutType.allCases` ; c'est précisément ce qui cesse de tenir au-delà de 4 ou 5 dispositions (voir le lot 0).

Depuis #1013, il y a un **cinquième couplage** à garder en tête : le décodeur spatial dépend de la **langue**, pour le `.hextm`, et de la **disposition**, pour les centres des touches. Le code le permet déjà : `SpatialDecoder.Keys(centres: [Character: CGPoint], …)` prend les centres de n'importe quelle grille. Une touche `é` directe reçoit son propre centre, et le décodeur garde le minimum entre ce coût et celui de la lettre de base plus `accentCost`.

---

## 2. La recette pas à pas

Il y a deux recettes, à ne pas confondre :

- **Recette A, nouvelle disposition pour une langue existante** (QWERTZ suisse pour `fr`, QWERTY canadien pour `fr`, QWERTY espagnol avec ñ…) : étapes 1, 2, 4 et 5. Aucun dictionnaire.
- **Recette B, nouvelle langue** (italien, portugais…) : toutes les étapes, *en plus de* `docs/agents/language-onboarding.md` (profil, prompts de polish Natural et Repair, curate script). Souvent, elle réutilise une disposition existante, le QWERTY.

Légende : 🤖 = un agent peut le générer ou le vérifier seul · 👤 = il faut un humain (natif, licence, choix de Pierre, iPhone).

### Étape 1 : définir les touches, les accents et l'appui long

1. **Choisir la référence** 👤. Il y a souvent trois références qui divergent : le clavier iPhone d'Apple, le clavier physique du pays, et HeliBoard/Gboard. Exemple pour la Suisse romande :
   - Apple (« QWERTZ – French », relevé par Hex) : `qwertzuiop` / `asdfghjkl'` / `yxcvbnm` ;
   - HeliBoard, et le clavier physique suisse : `…p è` / `…l é à` ;
   - #608 demande la version HeliBoard.

   **C'est le choix de Pierre**, et c'est là que se joue la différenciation.
2. **Relever les lignes de la référence** 🤖. Hex (MIT) a déjà relevé en boîte noire les lignes et les appuis longs du clavier iPhone pour 18 langues (`ios/HEXShared/FullKeyboard/KeyboardLanguage.swift` : `ownLetterRows`, `letterHolds`, `letterLayouts`). On peut les porter avec attribution, comme #1013 et #1026 l'ont fait. Le relevé lui-même se refait sur simulateur avec `axe` (arbre d'accessibilité de la bulle d'appui long).
3. **Écrire les lignes dans DictusCore** 🤖 : un `enum <Nom>Layout { lettersRows, lowercasedLettersRows, rowUnitWidths }`, sur le modèle de `QWERTZLayout`. Le clavier construit ses `KeyDefinition` depuis ces tableaux, ce qui permet à `swift test` de les épingler (l'extension n'a pas de cible de test).
4. **Ajouter le cas `LayoutType`** 🤖 et son `displayName` 👤 (le libellé : « QWERTZ (Suisse) » ? « Suisse romande » ?). Ajouter ensuite chaque bras de `switch` listé au §1.1 ; le compilateur les exige.
5. **Les appuis longs** :
   - 🤖 ajouter à `AccentedCharacters.mappings` les variantes manquantes (`œ`, `æ`, `ì`, `ò`, `ã`, `õ`, `å`, `ø`…) ;
   - 👤 décider s'il faut rouvrir #157. L'union atteint vite 30 variantes avec l'italien, le portugais et le nordique, alors que le seuil de #157 était « 5-6 langues ».
6. **La touche adaptative** 👤 : faut-il que la touche `'` du QWERTY canadien et du QWERTZ suisse (Apple) se comporte comme la touche AZERTY (é après e, etc.) ? Le pont la déclenche sur la *présence* de la touche `alternate: "accent"`. C'est donc un réglage de données, mais un choix de produit.
7. **La page 123** 👤 : `€` est codé en dur. Apple met la monnaie locale sur sa page 123 (CHF ? $ ?). Non vérifié pour chaque région, à relever au simulateur.
8. **La ligne du bas** 👤 : #608 demande virgule et point sur la page principale. La composition de la ligne du bas a été décidée en #877. Hex a une option pour ça (`KeyboardLayout+CommaPeriod.swift`). C'est à trancher par Pierre, pas dans une PR de disposition.

### Étape 2 : la géométrie (PR #1026, `KeyPlaneGeometry`)

- `KeyPlaneGeometry` (DictusCore, #1026) est **indépendant de la disposition** à la verticale : hauteur de touche, pas de ligne, marge sous la dernière ligne, marge latérale et écart, par classe de taille (SE, standard, grand) × orientation.
- Horizontalement, `layout(rows:width:height:)` répartit chaque ligne selon ses **unités** (`KeyDefinition.size.width`). Une ligne de 11 touches (QWERTZ, nordique) ou de 12 (ukrainien) se dessine donc sans code nouveau.
- 🤖 À faire pour chaque disposition :
  - ajouter ses unités de ligne aux tests de pavage de `KeyPlaneGeometryTests` (500 points aléatoires : ni zone morte, ni recouvrement ; touches dans leur cible) ;
  - aujourd'hui seuls `azerty` et `qwerty` y figurent, alors que le QWERTZ à 11 touches n'a jamais été mesuré contre Apple (`tools/keyboard-bench/README.md:71`) ;
  - le mieux est de paramétrer le test sur `LayoutType.allCases` (lot 0).
- 🤖 `KeyboardProximity` : ajouter les lignes et le décalage horizontal de chaque ligne. `keyWidth(forKeyCount:)` gère déjà plus de 10 touches.
- 🤖 Les voisins de la barre d'espace (`TextPredictionEngine`) : les dériver des 3 touches centrales de la dernière ligne de lettres, au lieu de deux ensembles écrits à la main.
- 👤📱 Les zones mortes réelles et la hauteur ne se voient que sur iPhone (liste « iPhone » du skill `verify-dictus-ios`, ligne `kbd.keys`). La hauteur **déclarée** reste interdite (#166).
- Petits iPhone : 12 touches sur la ligne du haut d'un SE (cyrillique) donnent des touches de moins de 27 pt. 🤖 À calculer avec `KeyPlaneGeometry`, 👤 à valider au doigt.

### Étape 3 : le dictionnaire et le modèle `.hextm` (recette B seulement)

Une langue embarque quatre fichiers :

| Fichier | Construit par | Source actuelle | 🤖 / 👤 |
|---|---|---|---|
| `<code>_frequency.json` | `scripts/curate_<code>_dictionary.py` (à écrire par langue) | Norvig (en), Lexique 3.83 (fr), HermitDave/OpenSubtitles (de) | 🤖 script ; 👤 choix de la source et de sa licence |
| `<code>_spellcheck.dict` | `tools/dict_builder.py` | le JSON ci-dessus | 🤖 |
| `<code>_ngrams.dict` | `tools/ngram_builder.py --lang <code>` | Google Books (orgtre), OpenSubtitles top sentences (orgtre), Wikipedia CirrusSearch | 🤖 ; ajouter `LANG_MAP` et `choices` |
| `<code>.hextm` (décodeur spatial, #1013) | `tools/typing-model/build-typing-model.py` | Google Books Ngram v3 + une liste de mots Hunspell | 🤖 build ; 👤 licence de la liste |

**Comment `fr.hextm` a été construit (PR #1013)** :

- point de départ : le script de Hex (`ios/scripts/build-typing-model.py`, MIT), étendu au français ;
- comptes de mots et de paires de Google Books Ngram v3 français (2020-02-17, CC BY 3.0), sommés sur 1980-2019 ;
- les mots gardés sont filtrés par le dictionnaire Grammalecte « Classique » 7.7 (le `fr_FR` de LibreOffice, MPL 2.0, lu par `spylls`) ;
- s'y ajoutent les clitiques élidés `c' d' j' l' m' n' s' t' qu' jusqu' lorsqu' puisqu' quoiqu'`, que Hunspell ne liste pas ;
- résultat : 110 000 mots et 322 885 paires, 3,60 Mo ;
- construction : 1 h 35 sur un M1 avec 5 workers, environ 95 Go téléchargés (fichier par fichier, supprimés après comptage), déterministe ;
- la MPL étant une licence par fichier, `fr.hextm` est lui-même sous MPL 2.0 et le reste de Dictus reste MIT ; les crédits sont dans Réglages → Licences.

**Pour une nouvelle langue**, ajouter au script :

- `FILES[lang]` (le code Google Books et le nombre de fichiers 1-gram et 2-gram) ;
- `MAX_WORDS[lang]` ;
- `LETTERS[lang]` (l'alphabet complet, accents compris) ;
- une branche dans `word_list()` pour sa liste Hunspell.

**La contrainte qui ordonne tout** : Google Books v3 n'a que `eng`, `chi_sim`, `fre`, `ger`, `heb`, `ita`, `rus` et `spa` (listing du bucket `storage.googleapis.com/books/ngrams/books/20200217/`, lu le 2026-11-22). Le dépôt orgtre, qui alimente `ngram_builder.py`, a les mêmes 8 langues. Conséquences :

- **l'allemand, l'italien et le russe** ont un `.hextm` constructible tel quel ;
- **le portugais, le néerlandais, le suédois, le danois, le norvégien, le finnois et le polonais** n'en ont pas. Il faut un autre corpus :
  - Hex a construit `pl.hextm` à partir du NKJP (corpus national polonais) et de ParlaMint, filtrés par PoliMorf, avec des sommes de contrôle sur les entrées (voir son script) ;
  - OpenSubtitles (orgtre) couvre ces langues pour les n-grammes, mais c'est un registre de sous-titres ;
  - 👤 il faut décider de la source et de sa licence, langue par langue.
- Hex a aussi un `nb.hextm` et un `it.hextm`, côté Android. Leur source n'a pas été lue : **non vérifié**.
- **Les licences des listes Hunspell varient** (MPL, LGPL, GPL selon la langue) ; 👤 à vérifier une par une. Une liste uniquement GPL poserait la question de l'App Store, et seul Pierre peut la trancher. **Non vérifié ici.**

**Le reste de la recette B** (`language-onboarding.md`) :

- 🤖 le scaffold du profil, `wire-xcode` et `verify` ;
- 🤖 écrire les prompts `PolishNaturalPrompt<XX>` et `PolishRepairPrompt<XX>` ;
- 👤 les faire valider par un natif ;
- 👤 vérifier sur device que la langue figure dans `SystemLanguageModel.default.supportedLanguages`. Sans Apple FM, c'est une sortie « clavier + dictée sans polish », dont #631 dit qu'elle n'est pas encore une forme de sortie supportée ;
- `overrides` et graines de bigrammes restent vides (ADR 0001).

Budget de l'extension : environ 11 Mo de bundle par langue (0,5 trie + 6-7 n-grammes + 3,6 `.hextm`). La mémoire résidente ne change pas, puisqu'une seule langue est chargée et que le `.hextm` est fait de pages propres lues en mmap (mesuré dans #1013 : `phys_footprint` inchangé). 👤 À reconfirmer sur device à chaque langue (limite d'environ 50 Mo).

### Étape 4 : mesurer sur le banc #954 et les runs multilingues de #978

`tools/keyboard-bench/` (#962, livré pour #954) et ses corpus multilingues (#978, fusionné) :

1. 🤖 **Corpus** : 20 phrases par langue. Pour es et de, elles viennent de Tatoeba (CC BY 2.0 FR), écrites par des natifs déclarés (`docs/research/multilingual-autocorrect/corpus.md`). Même procédure pour une nouvelle langue. 👤 Un natif relit les 20 phrases.
2. 🤖 **Run de fautes** : des paires `typos-<lang>.tsv` tirées de corpus publics de fautes (`typo-sources.md`), puis `make_typos.py` et `make_runs.py`. 👤 Licence de chaque corpus de fautes.
3. 🤖 **Rejouer** :
   - `run.sh --langs <lang>,<lang>-typos` pour la disposition par défaut ;
   - `run.sh --layout <x>` (ajouté par #1013) pour une langue sur une autre disposition, par exemple le français sur QWERTZ suisse ;
   - avec #1013 fusionné, `--spatial` mesure le décodeur.
4. **Métriques** à reporter dans la PR, avant et après : mots faux dans le texte final, lettres fausses (géométrie), *broken* (doit rester à 0), corrigés, ratés, mal corrigés, mots collés, et temps moteur p50/p95.
5. **La référence Apple** : sur simulateur, l'autocorrection d'Apple ne tourne qu'en anglais (les runtimes 26.5, 27.0 et 27.2 livrent des bundles es, de et fr vides), comme le documente `docs/research/multilingual-autocorrect/README.md`. Pour les autres langues, Apple ne fournit que son *choix de touche* (`sim_replay.py --keyboard apple`). 👤 La vraie comparaison passe par une session tapée sur iPhone, puis rejouée avec `journal_to_run.py`.
6. 👤 **La session réelle** : Pierre, ou un natif, tape une minute avec le journal de frappe actif, et la session se rejoue sur le banc. C'est elle qui a trouvé `sais → sauts` dans #1013.

### Étape 5 : tests et captures

- 🤖 `cd DictusCore && swift test` :
  - les lignes exactes (normale et majuscule) et les totaux d'unités, sur le modèle de `QWERTZLayoutTests` ;
  - la table de proximité de la disposition, sur le modèle de `KeyboardProximityTests` ;
  - le pavage `KeyPlaneGeometryTests` ;
  - la migration : un choix stocké survit (`KeyboardLayoutPreferenceTests`), le défaut de la langue ne change pas ;
  - pour la recette B : `<Lang>LanguageTests`, et les tests du décodeur sur le `.hextm` livré.
- 🤖 `swiftlint lint --strict`.
- 🤖 `scripts/simulator-smoke-test.sh` (SMOKE PASS).
- 🤖 **Captures** avec le skill `verify-dictus-ios` :
  - mettre à jour `features/keyboard.languages.md` (`keyboard.layout`) et `screens.md`, de façon **obligatoire dans la même PR** (CLAUDE.md) ;
  - capturer la page normale, la page majuscule et une bulle d'appui long, en portrait et en paysage, sur SE, 17 et Pro Max (les six configurations de #1026).
- 👤📱 Le label `needs-physical-test` et un test sur device, via `batch-device-test` : toutes les touches de bord, shift, effacer, appuis longs et frappe rapide.
- 👤 Une relecture indépendante, puis un merge (jamais en squash), et `refs #N` avec fermeture à la main.

---

## 3. Les prochaines dispositions, par priorité

Tailles :

- **S** : moins d'une semaine d'agent, aucun dictionnaire, un test device ;
- **M** : environ 1 à 2 semaines, une langue à corpus Google Books ou un gros chantier de disposition ;
- **L** : plusieurs semaines, une source de corpus nouvelle, plusieurs langues ou un nouvel alphabet, et un natif indispensable.

La colonne « Marché » est qualitative, non chiffrée ici.

| # | Disposition / langue | Type | Marché cible | Taille | Demande | Remarques |
|---|---|---|---|---|---|---|
| 1 | **QWERTZ suisse romand (fr-CH)** | A (disposition de `fr`) | Suisse romande ; utilisateurs venus de HeliBoard/Android | **S** (M si la ligne du bas change) | **#608**, demandé par un utilisateur, `priority:high` | 👤 choisir la version HeliBoard (è é à, comme le clavier physique suisse) ou Apple (`'` en fin de ligne 2). Ni Apple ni Hex n'ont les touches è/é/à : c'est un vrai différenciateur. La virgule et le point sur la page principale sont une décision #877 à part. |
| 2 | **Touche ñ pour l'espagnol** (QWERTY espagnol) | A | Espagne, Amérique latine | **S** | mesure #978 : es à **20,6 %** de mots faux, dont 18 ratés sur accent seul | Apple met `ñ` en fin de ligne 2 (10 touches). Le banc dit déjà que la ligne 2 à 9 touches pèse sur la largeur. Meilleur rapport gain/coût de la liste. |
| 3 | **QWERTY canadien français (fr-CA)** | A | Québec | **S** | aucune issue | Apple et Hex : `'` en fin de ligne 2. Réutilise le dictionnaire `fr`. Les régionalismes québécois sont hors périmètre (comme `fr-CH` dans #608). |
| 4 | **AZERTY belge** | A, en pratique un alias | Wallonie, Bruxelles | **XS** | aucune issue | Sur iPhone, Apple dessine le même AZERTY qu'en France (relevé de Hex, **non vérifié par nous**). Rien à coder, à part le dire dans la communication. Le vrai travail belge, c'est le néerlandais sur AZERTY : une ligne n° 7 + #272, gratuit une fois le néerlandais là. |
| 5 | **Italien** | B, QWERTY existant | Italie | **M** | #631, tier 1 | Google Books `ita` disponible : `.hextm` constructible avec le script actuel. Parakeet le couvre. Apple FM : 👤 à vérifier sur device. Appuis longs : ajouter `ì` et `ò`. 👤 Un natif. |
| 6 | **Portugais (BR d'abord, puis PT)** | B, QWERTY existant | Brésil, Portugal | **L** | #631, tier 1 | **Pas de Google Books** : `.hextm` à construire sur un autre corpus. 👤 Choisir entre BR et PT, ou faire les deux. Appuis longs : `ã õ`. Parakeet le couvre. |
| 7 | **Néerlandais** | B, QWERTY existant (et AZERTY pour la Belgique) | Pays-Bas, Flandre | **M-L** | #631, tier 3 | Pas de Google Books. Liste OpenTaal (licence à vérifier). Parakeet le couvre. |
| 8 | **Allemand QWERTZ** | déjà là | Allemagne, Autriche, Suisse alémanique | — | #151 (fermé) | Il reste à mesurer la grille à 11 touches contre Apple (pavage #1026). Suisse alémanique et Autriche : même grille sur iPhone ? **Non vérifié.** |
| 9 | **Nordique** (sv, fi : `å ä ö` ; da : `å æ ø` ; nb : `å ø æ`) | B ×4, une famille de dispositions à 11/11/7 | Suède, Danemark, Norvège, Finlande | **L** | aucune issue | Une seule famille de grilles, réutilise le modèle QWERTZ à 11 touches. Pas de Google Books. Parakeet faible en sv, da, fi selon les mesures FLEURS de Hex (`docs/plans/language-recommendations.md`) : Whisper est conseillé. Hex a `nb`. |
| 10 | **Russe ЙЦУКЕН, puis ukrainien** | B, nouvel alphabet | Russie, Ukraine, diaspora | **L** | **#632** (TestFlight), #631 tier 2 | Google Books `rus` disponible. 11/11/9 touches (12 en ukrainien sous iOS 27, selon Hex). Pipeline jamais lancé sur du cyrillique. 👤 Un natif obligatoire (« sans validateur, ne pas livrer »). |
| 11 | **Polonais** | B, QWERTY existant | Pologne | **M-L** | #631, tier 2 | Hex a déjà un `pl.hextm` (NKJP + ParlaMint) : piste à évaluer, avec sa licence. Appuis longs : `ą ć ę ł ń ś ź ż`. |
| 12 | **Persan** | hors périmètre | Iran, diaspora | **XL** | **#633** (Someday) | RTL, ZWNJ, shift sans majuscules, pas de Parakeet ni d'Apple FM. C'est un autre projet, comme le CJK. |

Les issues ouvertes qui demandent une disposition sont **#608** (fr-CH), **#632** (russe) et **#633** (persan). #631 fixe la stratégie ; #632, #633, #631 et #52 sont au milestone `Someday`. Je les cite parce que la demande le fait, pas pour les remonter. En dehors de #151 (le QWERTZ allemand, livré), aucune autre issue, ouverte ou fermée, ne demande de disposition (italien, portugais, belge, canadien, nordique, Dvorak ou BÉPO). La recherche a porté sur les titres des 552 issues.

---

## 4. Le lien avec la stratégie #631, et les concurrents

**Ce que dit #631** (milestone `Someday`) :

- le différenciateur, c'est « la dictée d'un Wispr Flow, avec un vrai clavier dans votre langue » ;
- il vaut contre les apps de dictée, **pas** contre le clavier d'Apple ;
- une langue vaut la peine quand trois facteurs sont élevés ensemble : le nombre d'utilisateurs d'iPhone qui la parlent, la couverture STT, et le coût du clavier ;
- tier 1 : portugais et italien ; tier 2 : russe, ukrainien et polonais ; tier 3 : néerlandais et turc ; hors périmètre : CJK, arabe, hébreu.

Cette note précise #631 sur trois points :

1. **Un quatrième facteur : la disponibilité d'un corpus pour le `.hextm`.** L'italien et le russe l'ont via Google Books ; le portugais, le néerlandais et le polonais non. L'italien devient la langue la moins chère du tier 1.
2. **Les variantes régionales du français sont moins chères que n'importe quelle langue**, et elles parlent au cœur de cible (francophone, AZERTY). Elles passent avant le tier 1.
3. **L'argument « les concurrents n'ont pas d'AZERTY » ne tient plus pour Hex.** Il faut le reformuler.

| | Hex (`anomalyco/hex`, `dev`, `492d8c28`) | FluidVoice |
|---|---|---|
| Source lue | le dépôt public, MIT | le dépôt public `altic-dev/FluidVoice` (GPL-3.0), uniquement macOS ; le README et fluidvoice.com/fluid/ios |
| Clavier iOS | **oui, dans le dépôt** (`ios/HEXKeyboard`, `ios/HEXShared/FullKeyboard`). Publié sur l'App Store ? **Non vérifié** : le README parle du desktop. | une app iPhone en **TestFlight** (« iPhone beta »). Le code n'est pas dans le dépôt public. Clavier tiers ou non, et lesquelles des dispositions : **non vérifié**. Le formulaire bêta propose « Typing experience » parmi les critères, ce qui ne prouve rien. |
| Langues de clavier | **18** : en, nb, es, de, it, fr (France), fr-CA, fr-CH, pt, pl, cs, hu, ro, ru, uk, el, sr-Latn, ko (expérimental) | non vérifié |
| AZERTY | **oui**, celui d'Apple (« AZERTY – French », touche `'` en fin de ligne 3), et offert aussi pour en, es, de, it, pt… | non vérifié |
| Suisse romande | QWERTZ d'Apple avec `'` en fin de ligne 2, **sans è/é/à directs** | non vérifié |
| Choix de disposition par langue | oui : `letterLayouts` (la sienne, plus QWERTY, AZERTY, QWERTZ, et Dvorak pour l'anglais) | non vérifié |
| Autocorrection | décodeur spatial avec `.hextm` pour en, es, de, fr, pl sur iOS ; d'après les commentaires du code, les autres langues reposent sur `UITextChecker`, le dictionnaire du système | non vérifié |
| Dictée | Parakeet v3, Apple Speech et d'autres ; reco par langue mesurée sur FLEURS | Fluid Speech Pro/Mini/Pico et Parakeet (25 langues), Qwen3 ASR (30), Nemotron, Whisper… (README, côté Mac) |

**Ce que ça change pour Dictus** :

- Hex avance vite (18 langues, push le jour même) et sous MIT. C'est à la fois un concurrent et une **source réutilisable** : ses relevés des lignes et appuis longs d'Apple, son script `.hextm`, sa source polonaise.
- Le positionnement défendable n'est donc pas « nous avons l'AZERTY ». Ce serait plutôt :
  - (a) **chaque disposition mesurée** sur le banc #954 contre Apple, chiffres publiés ;
  - (b) **les variantes que ni Apple ni Hex ne dessinent**, à commencer par le QWERTZ romand à è/é/à de #608 ;
  - (c) **le bilingue sur une même grille** (#272 + #1009/#1015) : par exemple de l'anglais tapé sur AZERTY, avec l'autocorrection anglaise.
- Contre Wispr Flow et Superwhisper, l'argument de #631 tient tel quel : le premier ouvre sur une page numérique avec un QWERTY optionnel, et le second n'a pas de clavier de frappe (sources dans #631, non relues ici).

---

## 5. Le plan par lots

Précondition commune : l'autocorrection fr/en est jugée stable par Pierre, et #1013 (décodeur spatial) et #1026 (géométrie Apple) sont fusionnés, puisque la recette s'appuie sur les deux. À recaler sur l'ordre du projet « Dictus 2.1 », que je n'ai pas pu lire.

**Lot 0, remise en ordre (M, une PR, aucun changement visible)**. Il rend chaque disposition suivante mécanique :

1. Déplacer les lignes de l'AZERTY dans DictusCore (`AZERTYLayout`), et faire lire une source unique par `KeyboardLayouts`, `KeyboardProximity`, `LanguageSetupPage` et `EmojiPickerView`. Aujourd'hui, il y a 4 copies.
2. Donner à chaque `LayoutType` ses lignes, ses unités et ses voisins d'espace dans un seul type DictusCore (par exemple `LayoutType.letterRows`). Les `switch` dispersés deviennent des lectures.
3. Ajouter une liste des dispositions **offertes par langue** (à la Hex : `SupportedLanguage.offeredLayouts`, la sienne en premier), lue par le panneau, les Réglages et l'onboarding à la place de `LayoutType.allCases`. 👤 Pierre valide l'ordre et le libellé des pastilles.
4. Paramétrer `KeyPlaneGeometryTests`, ainsi que les tests de lignes et de proximité, sur `LayoutType.allCases`. Le QWERTZ à 11 touches entre enfin dans le pavage.
5. Supprimer le fichier mort `DictusKeyboard/Models/KeyboardLayout.swift`.
6. Mettre à jour `docs/agents/language-onboarding.md`, qui dit encore « `.azerty` (French only) or `.qwerty` (everything else) », et y ajouter la recette A et l'étape `.hextm`.

**Lot 1, les variantes francophones et ñ (S chacun, 4 PR indépendantes)**, sans dictionnaire :

- QWERTZ romand, #608 (👤 HeliBoard ou Apple) ;
- QWERTY canadien français ;
- AZERTY belge (un libellé ou un alias, si Pierre veut qu'il apparaisse) ;
- touche `ñ` pour l'espagnol, en mesurant le run `es` de #978 avant et après.

Chaque PR passe par `run.sh --layout`, les captures et un test device.

**Lot 2, l'italien (M)** : la première nouvelle langue avec le script `.hextm` tel quel (Google Books `ita`). C'est le test grandeur nature de la recette B, sur une disposition existante. 👤 Un natif, et la vérification d'Apple FM sur device.

**Lot 3, le portugais (BR), puis le néerlandais (L)** : ce lot ouvre la **voie hors Google Books** pour le `.hextm` (corpus, licence, porte de qualité). C'est le vrai chantier d'outillage. 👤 Le choix de la source et sa licence, un natif par langue.

**Lot 4, la famille nordique (L)** : une famille de grilles à 11 touches et 4 langues, avec dictée Whisper conseillée (Parakeet faible en sv, da, fi). À ne lancer qu'avec la voie du lot 3 en place.

**Lot 5, cyrillique et polonais (L)** : le russe (#632), puis l'ukrainien sur la même grille, et le polonais (en évaluant la source NKJP de Hex). C'est le premier alphabet non latin dans le pipeline. 👤 Un natif obligatoire.

**Hors plan** : le persan (#633), le CJK et le coréen. Il faut un moteur de saisie ou du RTL : un autre projet, comme le dit #631.

### Ce qui reste à décider par Pierre, en résumé

1. #608 : la version HeliBoard (è/é/à) ou Apple (`'`) ? Les deux ?
2. Virgule et point sur la page principale (#608 contre #877) ?
3. Rouvrir #157 (appuis longs par langue) au-delà de 5-6 langues ?
4. Faire du lot 0 un item du projet 2.1, et à quel rang ?
5. La politique de licence des listes de mots et des corpus : MPL et CC BY oui ; LGPL et GPL ?
6. Accepter une sortie « clavier + dictée sans polish » pour les langues qu'Apple FM ne couvre pas (question ouverte de #631) ?
7. Où trouver les relecteurs natifs (italien, portugais, néerlandais, nordique, russe) ?
