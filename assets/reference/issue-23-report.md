# Retour automatique vers l’app hôte après un cold start déclenché depuis un clavier iOS

## Contexte précis et symptômes observés

Vous décrivez une architecture typique « clavier iOS + app conteneur » pour faire de la dictée/transcription : le clavier (extension) sert d’UI et de point d’entrée, et l’app (Dictus) sert à obtenir l’accès micro / audio système et à exécuter la pipeline de transcription. Ce découpage se heurte à plusieurs contraintes de plateforme, surtout visibles lors d’un *cold start* (app fermée/tuée), car l’ouverture de l’app conteneur casse le contexte de saisie dans l’app hôte et vous cherchez à y revenir automatiquement (sans action manuelle). citeturn25view0turn23view1turn18view1

Votre observation « ça marche mieux dans des apps très connues (Notes, WhatsApp, Facebook, Instagram…) mais pas dans une app exotique » est compatible avec deux réalités iOS :

1) certaines apps exposent (ou non) des mécanismes de (re)lancement via deep links / Universal Links, ce qui rend toute “navigation retour” partielle et non universelle (par définition) ; citeturn4view0turn10view0turn18view1  
2) iOS ne fournit pas une API publique “retour à l’app précédente”, donc tout comportement qui ressemble à un “retour automatique partout” est soit une illusion UX (le retour est en fait manuel/assisté), soit une implémentation non standard et fragile. citeturn5view1turn18view1turn5view0

Enfin, l’élément « une autorisation la première fois, puis plus ensuite » correspond souvent (dans ce type de produit) à **deux autorisations iOS incontournables** :  
- l’autorisation micro (au niveau app) ; citeturn23view2turn10view0  
- l’activation **“Allow Full Access”** (clavier) pour pouvoir communiquer avec l’app conteneur via App Groups et/ou réseau, et – point très important en 2026 – pour ouvrir l’app conteneur depuis le clavier sur certaines versions récentes d’iOS. citeturn25view2turn18view1turn19search0

## Ce que la plateforme permet officiellement et ce qu’elle interdit

### Le point bloquant fondamental : pas de micro dans un clavier iOS
Selon la doc archive d’entity["company","Apple","consumer electronics company"] sur les claviers personnalisés, « les claviers personnalisés (…) n’ont pas accès au microphone de l’appareil, donc la dictée n’est pas possible ». Autrement dit : **une extension clavier ne peut pas, de façon standard, enregistrer l’audio micro**. citeturn25view0turn25view1

### Les extensions ne peuvent pas “tricher” avec l’audio en arrière-plan
Plus largement, dans les guides Apple sur les app extensions, Apple indique explicitement que les extensions ne peuvent pas faire certains “vrais” background tasks (ex : VoIP, audio en arrière-plan). Et si vous tentez d’ajouter `UIBackgroundModes` dans le `Info.plist` d’une extension, l’extension peut être rejetée. Conséquence : si vous voulez garder une capture audio ou une “session micro” active en arrière-plan, **ça doit être l’app conteneur**, pas l’extension. citeturn23view1

### Ouvrir l’app conteneur depuis le clavier est permis (avec nuances)
Un ingénieur DTS Apple (janvier 2026) confirme que **lancer l’app conteneur depuis un clavier** est accepté (exemple “barcode scanning”), et donne un exemple technique via la chaîne de responders jusqu’à `UIApplication.open`. citeturn18view1

Mais, dans la même discussion, un point opérationnel ressort : sur “iOS 26” (selon la terminologie utilisée dans le thread), certains devs observent que l’ouverture de l’app conteneur **échoue si Full Access n’est pas activé** (“Error Domain=NSOSStatusErrorDomain Code=-54 … request not allowed”), et l’ingénieur DTS estime que le changement est probablement intentionnel (puisque App Groups implique Full Access), en recommandant de déposer un Feedback si besoin. citeturn18view1turn19search0

### Le deuxième point bloquant fondamental : pas d’API publique “retour à l’app précédente”
Sur la question exacte « ramener automatiquement l’app hôte au premier plan » : Apple (forums) répond simplement que **ça n’existe pas** (« No, there isn't an API for this. »), et le même ingénieur DTS (janvier 2026) réaffirme noir sur blanc : « **Il n’y a pas d’API pour que l’app conteneur ramène l’app hôte automatiquement au foreground** ». citeturn5view1turn18view1turn5view0

iOS propose néanmoins un compromis UX : après ouverture depuis une autre app (ou depuis un contexte assimilé), le système affiche souvent une **flèche “Back” en haut à gauche** que l’utilisateur peut toucher pour revenir à l’app précédente. C’est explicitement mentionné comme solution de repli par Apple DTS dans le thread de janvier 2026. citeturn18view1

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["iOS back to previous app button top left","iPhone back to app arrow top left status bar"],"num_per_query":1}

## Ce que font les concurrents en pratique et pourquoi cela semble “magique”

### Le modèle “session micro” (exemple Wispr Flow)
Un article de entity["organization","9to5Mac","apple news site"] décrit précisément le contournement : entity["company","Wispr Flow","ai dictation app"] fonctionnerait via des “Flow Sessions”, c.-à-d. des fenêtres de temps où l’utilisateur “laisse l’app accéder au micro”. Le flux décrit est : tap sur “Start Flow” depuis le clavier → ouverture de l’app Flow → activation de la session → retour à “là où l’on était”, puis la capture/transcription peut se faire ensuite. citeturn10view0

La logique produit derrière ce modèle est cohérente avec les contraintes Apple : puisque l’extension ne peut pas accéder au microphone, on “prime” l’accès micro côté app conteneur, puis on utilise le clavier comme interface “remote control” tant que la session audio est active. citeturn25view0turn23view1turn10view0

Un papier de entity["organization","TechCrunch","technology news site"] sur la sortie iOS de Wispr Flow confirme l’existence d’une app iOS qui “double” comme clavier, pour dicter dans d’autres apps (contexte marché / crédibilité du pattern). citeturn6search12

### Pourquoi certains utilisateurs disent quand même “je dois revenir à la main”
Des avis publics indiquent que, sur iPhone, l’app “doit se rouvrir” et que l’utilisateur doit parfois “swipe back” plusieurs fois, ce qui contredit l’idée d’un retour parfaitement automatique et universel. citeturn9search9turn6search13

Autrement dit : une partie de l’effet “retour auto” peut être une **simplification journalistique** ou un **retour assisté** (flèche système), pas un retour programmatique garanti.

### Le “consentement une fois” : très souvent, Full Access + micro
Dans la doc Apple sur les claviers, “Open Access / Full Access” change drastiquement les capacités (réseau, shared container, etc.) et les attentes de confidentialité. citeturn25view2turn25view0  
Et côté concurrents, on voit noir sur blanc dans la doc Wispr Flow que “Full Access” est requis pour transcrire (notamment si audio envoyé serveur) et que l’utilisateur doit l’activer dans Réglages. citeturn7search1

Cela colle fortement à votre observation d’un prompt d’autorisation “la première fois”.

## Pistes techniques réalistes pour obtenir un “retour” et explication du caractère non universel

### Piste A : assumer qu’un retour totalement automatique est impossible, et concevoir autour
C’est la piste la plus “compliant” et stable parce qu’elle s’aligne sur la position Apple DTS : **pas d’API de retour automatique**. citeturn18view1turn5view1

Concrètement, cela revient à optimiser trois choses :
- démarrage ultra-rapide de l’app sur deep link (écran minimal “Activation micro…”),  
- activation immédiate de la session audio côté app conteneur,  
- guidance UX explicite “Touchez ‘Retour à <App>’ en haut à gauche” (et éventuellement animation/flèche).

Ce n’est pas “aussi magique”, mais c’est robuste et App Store-safe. citeturn18view1turn23view1

### Piste B : retour “semi-automatique” via deep links/Universal Links… mais seulement pour une liste d’apps
Si vous voulez reproduire l’impression “ça marche dans WhatsApp/Instagram/etc.”, la voie la plus plausible (sans API privée) est :

1) identifier l’app hôte (ou l’origine) ;  
2) ouvrir explicitement cette app via un mécanisme qu’elle supporte (custom URL scheme ou Universal Link).

Le problème structurel : **il n’existe pas de moyen public de “lancer une app par bundle id”**, et vous ne pouvez pas dériver automatiquement le scheme ou les Universal Links d’une app tierce inconnue. Donc vous finissez avec… une base de correspondances pour les apps populaires (d’où votre observation “connues vs exotique”). citeturn18view1turn4view0turn5view1

#### Comment identifier l’app hôte ?
Il existe trois familles de solutions, avec des niveaux de risques différents :

- **API privée `_hostBundleID` côté extension** : de nombreux exemples historiques montrent qu’on pouvait lire le bundle id de l’hôte via `valueForKey("_hostBundleID")` dans un clavier. C’est explicitement montré sur Stack Overflow. citeturn16search1turn16search0  
  Mais c’est *private API* et fragile : des discussions récentes mentionnent des blocages/retours `nil` sur des versions récentes d’iOS, et des libs comme entity["organization","KeyboardKit","iOS keyboard framework"] documentent des régressions où l’“host application bundle id” devient vide, impactant notamment la capacité à “naviguer de retour vers le clavier depuis l’app principale” pour des features comme la dictée. citeturn16search18turn16search8  
  En pratique : c’est une piste de R&D (pour comprendre), mais risquée pour un produit App Store.

- **`sourceApplication` lors de l’ouverture d’URL** : Apple documente que `sourceApplication` correspond au bundle ID de l’app qui a demandé l’ouverture d’URL. citeturn21search2turn21search0  
  Problème : dans votre cas, la demande d’ouverture vient souvent d’un `UIApplication.open` trouvé via la chaîne de responders dans le contexte du clavier, ce qui peut être attribué à l’app hôte, mais Apple n’expose pas (dans les threads cités) une garantie spécifique “clavier → app conteneur” sur ce champ, et le thread Apple “Detecting host app bundle ID…” (jan 2026) n’a pas de réponse officielle. citeturn18view0turn18view1  
  Cela reste néanmoins une piste “propre” à tester (instrumentation sur device) : si `sourceApplication` renvoie effectivement le bundle id de l’app hôte, vous pouvez au moins savoir *dans quel app vous étiez* sans API privée.

- **Liste statique d’apps supportées** : c’est ce que le post Reddit “return to previous app” suggère indirectement (Universal Links, coopération de l’app, etc.). citeturn4view0

#### Pourquoi l’app exotique ne marche pas
Même si vous connaissez le bundle id (ou le nom) de l’app tierce, vous aurez souvent un manque : un **endpoint de lancement** (scheme/universal link) stable. Les grosses apps (messagerie, réseaux sociaux) ont presque toujours des Universal Links/URL schemes documentés ou largement connus, alors qu’une petite app perso peut n’en avoir aucun, ou un scheme non documenté. C’est exactement le type de différentiel qui produit un “ça marche dans WhatsApp/Instagram mais pas ailleurs”. citeturn4view0turn18view1

### Piste C : réduire drastiquement le besoin d’ouvrir l’app conteneur en créant une “session” longue (et expliquer les compromis)
Si votre objectif est surtout “ne pas casser le flux utilisateur”, le pattern “session” est probablement le plus proche des concurrents (et le plus réaliste).

Mais il a des contraintes fortes : pour continuer à enregistrer en arrière-plan, une app audio doit se configurer correctement (modes audio, UIBackgroundModes, catégories AVAudioSession, gestion interruptions). Les guides audio Apple recommandent aussi d’éviter des stratégies douteuses comme “streaming silence” juste pour ne pas être suspendu, et de demander explicitement la permission micro via `requestRecordPermission` au lieu d’attendre un prompt “automatique”. citeturn23view2turn23view3

Et côté extensions, rappelez-vous : vous ne pouvez pas déplacer `UIBackgroundModes` dans l’extension (rejet), donc tout doit être porté par l’app conteneur. citeturn23view1

## Recommandation d’architecture pour Dictus en 2026

### Le design cible “compliant” qui maximise l’impression de continuité
Pour un comportement stable et acceptable App Store, la synthèse des sources mène à ce design :

1) **Dans le clavier**  
   - Bouton micro = “Démarrer une session Dictus” (si session inactive).  
   - Une fois session active, le bouton micro déclenche la capture/stream et l’insertion de texte via `textDocumentProxy.insertText`, sans rouvrir l’app.  
   Les App Groups + Full Access sont généralement nécessaires pour partager état/audio/transcript entre app et extension. citeturn25view2turn23view1  

2) **Au premier démarrage (cold start)**  
   - Le tap micro ouvre Dictus via un custom URL scheme. Apple DTS confirme qu’ouvrir l’app conteneur depuis le clavier est autorisé, et donne un exemple de code. citeturn18view1  
   - Dictus active la session audio (permission micro si nécessaire) et affiche un écran minimal avec une instruction claire “Touchez Retour à <App> en haut à gauche”. Apple DTS cite explicitement cette flèche comme mécanisme prévu par le système, en rappelant qu’il n’existe pas de retour automatique. citeturn18view1turn5view1  

3) **Gestion du “Full Access”**  
   - Anticiper qu’en iOS récent, l’ouverture de l’app conteneur depuis le clavier peut exiger Full Access (sinon code -54), et construire l’onboarding en conséquence : si Full Access désactivé, afficher un UI qui guide vers Réglages (et explique pourquoi). Les discussions 2025–2026 montrent ce changement côté OS et l’incertitude autour d’exceptions observées sur certains claviers. citeturn18view1turn19search0turn25view2  

4) **Durée de session courte et explicite**  
   - Copier l’idée de “fenêtre de temps” (5 min, 15 min, 1 h…) décrite pour Wispr Flow : cela diminue l’aller-retour permanent et rend le produit plus prévisible. citeturn10view0turn9search16  
   - Attention UX/confiance : une session micro longue est sensible (indicateur micro, batterie, confidentialité). Des retours utilisateurs montrent que sur iPhone le mécanisme peut être ressenti comme “fiddly” avec des allers-retours. citeturn9search9turn6search13  

### Option “premium” : support partiel du retour automatique sur apps populaires
Si vous voulez vraiment un “retour automatique” **dans 10–30 apps majeures** (messagerie/social), vous pouvez envisager :

- détecter l’app hôte (via `sourceApplication` si exploitable dans vos tests, ou via une méthode non recommandée type `_hostBundleID` en R&D) ; citeturn21search2turn16search1turn16search18  
- maintenir une whitelist de cibles (ex : entity["company","WhatsApp","messaging app"], entity["company","Facebook","social network"], entity["company","Instagram","social network app"]) et ouvrir ces apps via Universal Links/URL schemes connus.

Mais il faut être lucide :  
- ce sera **non universel** (aucune solution “toutes les apps” sans coopération de l’app ou API système) ; citeturn18view1turn5view1turn4view0  
- les mappings link/scheme cassent parfois dans le temps, et certaines apps peuvent être configurées pour ne pas ouvrir les Universal Links automatiquement.

## Conclusion : ce qui est possible, ce qui ne l’est pas, et ce que je ferais à votre place

D’après la documentation Apple et les réponses récentes (janvier 2026) sur les forums développeurs, **il n’existe pas d’API publique App Store-safe permettant à votre app conteneur de ramener automatiquement au premier plan l’app hôte** après un cold start déclenché par une extension clavier. Le mécanisme officiellement prévu est la flèche “Back” en haut à gauche, actionnée par l’utilisateur. citeturn18view1turn5view1turn5view0

Ce que les concurrents semblent faire en pratique ressemble surtout à une combinaison de :  
- ouverture brève de l’app conteneur pour activer une “session micro”, puis retour *assisté* (souvent non parfait selon les retours publics) ; citeturn10view0turn9search9turn6search13  
- exigences d’autorisations (micro + Full Access) qui donnent l’impression d’un “consentement une fois”. citeturn7search1turn18view1turn25view2

Si votre objectif produit est “l’utilisateur dicte partout, y compris cold start, avec friction minimale”, la stratégie la plus robuste est : **modèle session + UX de retour via flèche système**, et éventuellement une couche “retour auto” limitée à une whitelist d’apps majeures (en assumant que ce ne sera jamais universel). citeturn18view1turn10view0turn4view0

Enfin, si vous voulez pousser le sujet au niveau plateforme, Apple DTS recommande explicitement de déposer un Feedback si vous avez un use case où l’exigence Full Access / les limites de navigation ne font pas sens. Dans votre cas (accessibilité/entrée vocale), il y a un argument produit sérieux. citeturn18view1