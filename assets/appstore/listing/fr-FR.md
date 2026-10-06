# App Store listing, fr-FR, 2.0.0 (draft)

Draft for issue #643, the French wave of the approved English set (`export/fr-FR/v15-B/`, slides in the same order). It mirrors `listing/en-GB.md`; the claims and their sources are the same, re-read below. **Nothing here is in App Store Connect.**

Register: **vous**, as DictusApp's French strings (the keyboard's own strings say "tu", see the PR). French typography: a non-breaking space (U+00A0) before `: ; ! ?` and inside « », typographic apostrophes, no em dashes.

Limits checked with `python3` (characters; keywords counted in UTF-8 bytes, where an accented letter weighs 2): see the table at the end.

**Depends on the 2.0.0 Pro flip**, as the English draft: the Pro and trial paragraphs describe the app once `PremiumFlags.paywallVisible` is `true` (#279).

## Name

- English: `Dictus: AI Voice Keyboard` (25/30)
- **Proposed: `Dictus : clavier vocal IA`** (25/30, with a non-breaking space before the colon)

Why localise it: the name is the most heavily weighted indexed field, and a French search says « clavier », « vocal », « IA », never "keyboard". It keeps the brand first and says the same thing. If Pierre prefers one name everywhere, keep the English one: nothing else in this file depends on it.

## Subtitle

**`Dictée privée, messages vocaux`** (30/30)

The English subtitle, `Private dictation, voice notes`, for the same reasons: it holds for every Pro buyer (voice notes need no Apple Intelligence), and it adds indexed words the name lacks. « Messages vocaux » is the app's own name for the feature (`Voice notes` → `Messages vocaux` in `DictusApp/Localizable.xcstrings`), and the phrase French users type. « Hors ligne » moves to the keywords and the description, as "offline" did.

## Promotional text

For launch week:

> Nouveau dans la 2.0 : Dictus Pro. Traduisez en parlant et lisez les vocaux de vos discussions dans votre clavier. Gratuit 14 jours sur les iPhone avec Apple Intelligence.

"Sur les iPhone avec Apple Intelligence" is load-bearing, as in English: the trial never starts on a device that cannot run Smart Modes (#593 decision 2).

## Keywords

**Proposed:** `transcription,texte,parole,traduction,traduire,audio,hors ligne,whisper,open source,résumé,note`

- **No ranking data was read.** These are chosen from the product's own vocabulary and the English set's reasoning, not from search volumes: nothing from App Store Connect analytics, Apple Ads or a third-party ASO tool was consulted.
- Words already in the proposed name or subtitle are not repeated (Apple combines fields): `dictus`, `clavier`, `vocal`, `IA`, `dictée`, `privée`, `messages`, `vocaux`.
- `texte` + `parole` + `vocal` (name) cover « parole en texte », « texte vocal »; `transcription` covers the generic search; `audio` covers « audio en texte ».
- `traduction` and `traduire` for Translate (Pro); `résumé` for Summary; `note` combines with `vocaux` and `vocal`.
- `hors ligne`, `whisper`, `open source`: the English set's technical and privacy terms. « Hors ligne » is the term a French user types, not "offline". `stt` was dropped: it took the list to 101 bytes, and French searches rarely use the English acronym.
- Not included: `traducteur` (costs 10 bytes; competes with dedicated translators), `micro`, language names (`français`, `anglais`), and no trademarks (guideline 2.3.7).

## Description

Follows the seven V15-B slides, in order and with their headlines.

```
Parlez au lieu de taper. Dictus est un clavier qui écrit ce que vous dites : touchez le micro, parlez, et vos mots s’affichent dans n’importe quelle app. La reconnaissance vocale tourne sur votre iPhone, même sans connexion.

DICTEZ DANS TOUTES VOS APPS

Messages, e-mails, notes, rappels : partout où vous pouvez écrire, Dictus est à portée de doigt. Parlez naturellement, et le texte arrive là où se trouve votre curseur.

TRADUISEZ EN PARLANT (PRO)

Les modes intelligents transforment votre dictée en texte prêt à envoyer, avant même qu’il soit tapé. Maintenez le micro, choisissez un mode, et parlez :
- Traduction : vers le français, l’anglais, l’allemand ou l’espagnol
- Message : le message court que vous auriez tapé
- Liste : vos idées sous forme de puces
- Structuré : une longue dictée en paragraphes clairs
- Résumé : l’essentiel de ce que vous avez dit

Les modes intelligents tournent sur votre iPhone avec Apple Intelligence (iPhone 15 Pro ou plus récent, iOS 26 ou plus récent). Vos mots ne partent vers aucun serveur.

LISEZ VOS VOCAUX DANS LE CLAVIER (PRO)

Un message vocal que vous ne pouvez pas écouter tout de suite ? Partagez-le vers Dictus depuis votre app de messagerie. Il est transcrit sur votre iPhone, et la transcription vous attend dans le clavier quand vous revenez dans la conversation. Lisez-la, puis insérez-la d’un geste si vous voulez la citer.

UN VRAI CLAVIER DANS VOTRE LANGUE

Dictus est un clavier complet, pas seulement un bouton micro. Dispositions AZERTY, QWERTY et QWERTZ, avec correction automatique et suggestions en français, en anglais, en allemand et en espagnol. Tapez quand vous voulez, parlez quand vous préférez.

VOTRE VOIX RESTE SUR VOTRE IPHONE

La reconnaissance vocale se fait sur l’appareil. Pas de compte, pas de pistage, pas de statistiques d’usage. Dictez en avion, dans le métro, partout. Les modèles sont sur votre iPhone : téléchargez-en un une fois, puis utilisez-le hors ligne, du plus compact et rapide au plus précis.

Dictus est open source (licence MIT). Chacun peut lire le code et vérifier ces engagements de confidentialité : github.com/getdictus/dictus-ios

DICTEZ DANS PLUS DE 40 LANGUES

La dictée fonctionne dans plus de 40 langues avec une qualité bonne ou correcte, et dans près de 100 avec les modèles Whisper, où la qualité varie selon la langue. Parakeet, le modèle par défaut, transcrit 25 langues européennes et reconnaît celle que vous parlez. Chaque modèle indique les langues qu’il gère bien avant que vous le téléchargiez.

DICTUS PRO

Pro ajoute les modes intelligents, les messages vocaux dans le clavier, l’historique de vos dictées et votre propre vocabulaire pour les noms et les termes techniques.

Essayez Pro gratuitement pendant 14 jours. Il n’y a rien à souscrire et rien ne se renouvelle : à la fin des 14 jours, Dictus repasse en version gratuite et vous demande si vous voulez garder Pro. Votre historique et votre vocabulaire sont conservés. L’essai est proposé sur les iPhone capables de faire tourner les modes intelligents. La dictée et le clavier restent gratuits.

Dictus ne collecte aucune donnée. Politique de confidentialité : getdictus.com/privacy
```

### Facts behind the copy

The same claims as `listing/en-GB.md`, with the same sources; re-check them at the 2.0.0 cut.

| Claim | Source |
|---|---|
| Five Smart Modes, French names Message, Liste, Structuré, Résumé, and Translate (shown as `→ EN` etc.) | `SmartModeCatalogue.builtIns`, `DictusKeyboard/Localizable.xcstrings` |
| Translate targets: French, English, German, Spanish | `SupportedLanguage.allCases` |
| Apple Intelligence: iPhone 15 Pro or later, iOS 26 or later | the app's own string `Requires Apple Intelligence (iPhone 15 Pro or later, iOS 26)`; **to confirm against Apple's current device list** |
| Pro = modes intelligents, messages vocaux, historique, vocabulaire | `ProFeature` |
| 14-day reverse trial, nothing to subscribe to, nothing renews, back to free at the end with an offer to keep Pro, data kept, no trial where Smart Modes can never run | `ProTrial.durationDays = 14`, `ProTrialPolicy` (definitive reasons), #593 decisions 1 and 2 |
| 40+ languages at good or fair quality, Parakeet 25 European, Whisper close to 100 | `ModelLanguageSupport.swift`, #488; slide 7 |
| Keyboard: 4 languages, 3 layouts | `SupportedLanguage.swift`, `KeyboardLayouts.swift` |
| No account, no tracking, no analytics, no data collected | App Privacy "Data Not Collected" |

## Length check

Measured with `python3` on this file's fenced and quoted texts (`len()` for characters, `len(s.encode("utf-8"))` for the keyword bytes):

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 25 |
| Subtitle | 30 | 30 |
| Promotional text | 170 | 170 |
| Keywords (bytes) | 100 | 97 |
| Description | 4000 | 3162 |
